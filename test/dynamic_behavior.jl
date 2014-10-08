## _Toy: Custom dynamic functions ------------------------------------------
import MCInsurance.Dynamic

type DynamicHook
  yield_mkt_init::Float64
  yield_rf_init::Float64
  ind_surplus::Vector{Float64}
  ind_surplus_threshold::Vector{Float64}
  ind_surplus_init::Float64
  ind_surplus_threshold_init::Float64
  ind_surplus_factor::Float64
  tax_profit::Float64
end


function Dynamic(invest::Invest,
                 buckets::Buckets,
                 liab_other::LiabOther,
                 yield_mkt_init::Float64,
                 df_general::DataFrame,
                 df_dyn::DataFrame
                 )
  me = Dynamic(df_general)
  me.probsx = dynprobsx
  me.alloc! = dynalloc!
  me.bonusrate = dynbonusrate
  me.dividend = dyndividend
  me.taxprofit = dyntaxprofit
  me.update! = dynupdate!

  fixed = Fixed(invest, buckets)
  ind_surplus = zeros(Float64, invest.cap_mkt.tf.n_c)
  ind_surplus_threshold = zeros(Float64, invest.cap_mkt.tf.n_c)
  ind_surplus_init = df_dyn[1, :ind_surp_init]
  ind_surplus_threshold_init = df_dyn[1, :ind_surp_threshold_init]
  indsurplus(vinit(invest, buckets, liab_other, fixed))

  me.hook = DynamicHook(yield_mkt_init,
                        invest.c.yield_rf_eoc[1,1],
                        ind_surplus,
                        ind_surplus_threshold,
                        ind_surplus_init,
                        ind_surplus_threshold_init,
                        df_dyn[1, :ind_surp_fac],
                        df_general[1, :tax_profit]
                        )
  return me
end



indsurplus(v::Array{Float64,3}) =
  -v[1, 1, INVEST_EOC] /
  min(-eps(), v[1, 1, TPG_EOC] + v[1,1,L_OTHER_EOC]) - 1.0

indsurplus(mc::Int, t::Int, cflow::CFlow) =
  t == 1 ?
  indsurplus(cflow.v_0) :
  indsurplus(cflow.v[mc, t-1, :])

function dynupdate!(mc::Int,
                    t::Int,
                    cflow::CFlow,
                    dyn::Dynamic)
  ## currently, ind_surplus still refers to the previous cycle
  dyn.hook.ind_surplus_threshold[t] =
    dyn.hook.ind_surplus_factor *
    max(0,  (t <= 1 ?
               max(dyn.hook.ind_surplus_init,
                   dyn.hook.ind_surplus_threshold_init) :
               max(dyn.hook.ind_surplus[t-1],
                   dyn.hook.ind_surplus_threshold[t-1])
             )
        )
  ## update ind_surplus
  if t >= 1
    dyn.hook.ind_surplus[t]  = indsurplus(mc, t, cflow)
  end
end

## Dynamic policy behavior -----------------------------------------------------

## State of the economy
stateecon(yield_mkt::Real, yield_rf::Real) =
  yield_mkt / max(eps(), yield_rf) - 1

stateeconinit(dyn::Dynamic) =
  dyn.hook.yield_mkt_init / max(eps(), dyn.hook.yield_rf_init) - 1

stateeconavg(yield_mkt_prev::Real, yield_mkt_mean::Real, yield_rf::Real) =
  0.5 * (yield_mkt_prev + yield_mkt_mean) / max(eps(), yield_rf)-1


## Bonus indicator
function biquotient(t::Int, bkt::Bucket, dyn::Dynamic,
                    yield_mkt::Real, yield_rf::Real, yield::Real)
  bonus_rate =  dynbonusrate(t, dyn, bkt, yield)
  ind_bonus =  yield_mkt / max(eps(), log(1+bonus_rate) + yield_rf)
  ind_bonus_hypo =
    dyn.hook.yield_mkt_init /
    max(eps(), log(1 + bkt.bonus_rate_hypo) + dyn.hook.yield_rf_init)
  return ind_bonus / ind_bonus_hypo
end

## surrender factor
## general calculation of surrender factor without fluctuation
function deltasx(t::Int,
                 bkt::Bucket,
                 dyn::Dynamic,
                 yield_mkt::Real,
                 yield_rf::Real,
                 yield::Real)
  state_econ_quotient =
    stateecon(yield_mkt, yield_rf) / stateeconinit(dyn)
  bi_quotient = biquotient(t, bkt, dyn, yield_mkt, yield_rf, yield)
  δ_SX = 1.0
  if state_econ_quotient < 0.5
    δ_SX += 0.15
  elseif  state_econ_quotient > 2.0
    δ_SX -= 0.15
  end
  δ_SX += 0.25 * min(4.0, max(0.0, bi_quotient - 1.2))
  return δ_SX
end

## current surrender factor without fluctuation
deltasx(mc::Int,
        t::Int,
        bkt::Bucket,
        invest::Invest,
        fluct::Fluct,
        dyn::Dynamic) =
  deltasx(t, bkt, dyn,
          invest.c.yield_mkt_eoc[mc, t],
          invest.c.yield_rf_eoc[mc, t],
          invest.c.yield_eoc[mc, t])

function meanyield(yield_mkt::Vector, yield_rf::Vector, alloc::Real)
  ## This function does not account for future changes in asset allocation
  return alloc * yield_mkt .+ (1-alloc) * yield_mkt
end

function deltasxvec(mc::Int,
                    t::Int,
                    dyn::Dynamic,
                    invest::Invest,
                    bkt::Bucket,
                    fluct::Fluct)
  len = min(bkt.n_c, invest.tf.n_c)
  discount = meandiscrf(invest.c, invest.c.yield_rf_eoc[mc, t], t, len)
  yield_rf = -log(discount ./ [1, discount[1:end-1]])
  yield_mkt = invest.c.mean_yield_mkt_eoc[t:len]
  if t <= 1
    alloc = invest_det.alloc.ig_target_std[invest_det.id[:stocks]]
  else
    alloc =  allocindex(stateeconavg(invest.c.mean_yield_mkt_eoc[t-1],
                                     yield_mkt[1],
                                     yield_rf[1]))
  end
  yield =  meanyield(yield_mkt, yield_rf, alloc)
  δ_SX = Array(Float64, length(discount))
  ## Actual value now
  δ_SX[1] = fluct.fac[mc, t, SX] * deltasx(mc, t, bkt, invest, fluct, dyn)
  ## future estimate (via best estimate of underlyin drivers)
  if length(discount) > 1
    for τ = 2:length(discount)
      ## fluct needs to refer to current time t
      δ_SX[τ] =
        fluct.fac[mc, t, SX] *
        deltasx(t+τ-1, bkt, dyn, yield_mkt[τ], yield_rf[τ], yield[τ])
    end
  end
  return δ_SX
end

## Surrender probability
dynprobsx(mc::Int, t::Int, dyn::Dynamic, invest::Invest,  bkt::Bucket,
          fluct::Fluct, len::Int) =
  min(1.0,
      bkt.prob_ie[t:len, SX] .* deltasxvec(mc, t, dyn, invest, bkt, fluct))

## Dynamic asset allocation ----------------------------------------------------

allocindex(state_econ_avg::Float64) = 0.5 * (1 - exp( - max(0, state_econ_avg)))

function dynalloc!(mc::Int, t::Int, dyn::Dynamic, invest::Invest)
  if t == 1
    # allocation is boc.  For t= 1 we use original allocation
    invest.alloc.ig_target = deepcopy(invest.alloc.ig_target_std)
  else
    ## cash allocation is chosen dependent on market performance
    ## all other investments / assets are adjusted proportionally
    ## market performance indicator weighted with expected yield
    alloc_cash = 1 - allocindex(stateeconavg(invest.c.yield_mkt_eoc[mc, t-1],
                                             invest.c.mean_yield_mkt_eoc[t],
                                             invest.c.yield_rf_eoc[mc,t]))

    ## Now we adjust all allocations accordingly
    total_other = 1 - invest.alloc.ig_target_std[invest.id[:cash]]
    fac_other = (1-alloc_cash) / max(eps(), total_other)
    for i = 1:invest.n
      if invest.ig[i].name == :cash
        invest.alloc.ig_target[i] = alloc_cash
      else
        invest.alloc.ig_target[i] = fac_other * invest.alloc.ig_target_std[i]
      end
    end
  end
end


## Dynamic bonus declaration ---------------------------------------------------
function dynbonusrate(t::Int, dyn::Dynamic, bkt::Bucket, yield_eoc::Real)
  if dyn.hook.ind_surplus[t] >= dyn.hook.ind_surplus_threshold[t]
    return max(exp(dyn.bonus_factor *
                     (yield_eoc - bkt.hook.statinterest(bkt, t))) - 1.0,
               0.0)
  else
    return 0.0
  end
end

dynbonusrate(mc::Int, t::Int, dyn::Dynamic, invest::Invest, bkt::Bucket) =
  dynbonusrate(t, dyn, bkt, invest.c.yield_eoc[mc, t])


## Dynamic dividend declaration ------------------------------------------------
function dyndividend(mc::Int,
                     t::Int,
                     dyn::Dynamic,
                     cflow::CFlow,
                     invest_pre_divid::Float64)
  if dyn.hook.ind_surplus[t] >= dyn.hook.ind_surplus_threshold[t]
    return  - (dyn.capital_dividend / (1 + dyn.capital_dividend) *
                 max(0, invest_pre_divid + cflow.v[mc, t, TPG_EOC] ))
  else
    return 0.0
  end
end

function dyntaxprofit(mc::Int, t::Int, dyn::Dynamic, cfl::CFlow)
  return cfl.cf[mc, t, PROFIT] * dyn.hook.tax_profit
end
