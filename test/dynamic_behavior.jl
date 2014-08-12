import MCInsurance.Dynamic

type DynamicHook
  yield_mkt_init::Float64
  yield_rf_init::Float64
  tax_profit::Float64
end


function Dynamic(invest::Invest,
                 df_general::DataFrame,
                 yield_mkt_init::Float64,
                 yield_rf_init::Float64
                 )
  me = Dynamic(df_general)
  ## Dynamic policy behavior -------------------------------------------------
  function dynprobsx(mc::Int,
                     t::Int,
                     bucket::Bucket,
                     invest::Invest,
                     fluct::Fluct,
                     dyn::Dynamic
                     )
    delta = 1.0
    state_econ_quotient =
      (invest.c.yield_mkt_eoc[mc,t]/max(eps(),invest.c.yield_rf_eoc[mc,t])-1)/
      (dyn.hook.yield_mkt_init/ max(eps(),dyn.hook.yield_rf_init) - 1)

    if state_econ_quotient < 0.5
      delta += 0.15
    elseif  state_econ_quotient > 2.0
      delta -= 0.15
    end

  bonus_rate_init = bucket.bonus_rate_hypo
  bonus_rate = dynbonusrate(mc, t, bucket, invest,  dyn)
  bi_quotient =
    (invest.c.yield_mkt_eoc[mc,t] /
       max(eps(), bonus_rate + invest.c.yield_rf_eoc[mc,t])
     ) /
    (dyn.hook.yield_mkt_init /
       max(eps(), bonus_rate_init + dyn.hook.yield_rf_init)
     )

    delta += 0.25 * min(4.0, max(0.0, bi_quotient - 1.2))

    return  min(1.0,
                fluct.fac[mc, t, SX] * delta *
                  bucket.prob_be[t:bucket.n_c, SX]
                )
  end

  ## Dynamic asset allocation ------------------------------------------------
  function dynalloc!(invest::Invest, mc::Int, t::Int, dyn::Dynamic)
    ## cash allocation is chosen dependent on market performance
    ## all other investments / assets are adjusted proportionally
    ## In-place computation for higher efficiency
    if t > 1 # allocation is boc.  For t= 1 we use original allocation
      ## market performance indicator weighted with expected yield
      mkt_perf_ind = 0.5 * (invest.c.yield_mkt_eoc[mc,t-1] +
                              invest.c.mean_yield_mkt_eoc[t]
                            ) /  max(0, invest.c.yield_rf_eoc[mc,t-1])

      alloc_cash = 1 - 0.5 * (1 - exp( - max(1, mkt_perf_ind) + 1))

      ## Now we adjust all allocations accordingly
      total_other = 1 - invest.alloc.ig_target_std[invest.id[:cash]]
      fac_other = (1-alloc_cash) / max(eps(), total_other)
      for i = 1:invest.n
        if invest.ig[i].name == :cash
          invest.alloc.ig_target[i] = alloc_cash
        else
          invest.alloc.ig_target[i] =
            fac_other * invest.alloc.ig_target_std[i]
        end
      end
    end
  end

  ## Dynamic bonus declaration -----------------------------------------------
  dynbonusrate(bonus_fac::Float64, yield_eoc::Float64, int_price::Float64) =
    bonus_fac *  max(0, yield_eoc - int_price)
  ##||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
  function  dynbonusrate(mc::Int,
                         t::Int,
                         bkt::Bucket,
                         invest::Invest,
                         dyn::Dynamic)
      return  dynbonusrate(dyn.bonus_factor,
                               invest.c.yield_eoc[mc, t],
                               bkt.hook.statinterest(bkt,t))
  end

  ## Dynamic dividend declaration --------------------------------------------
  function dyndividend(mc::Int,
                       t::Int,
                       invest::Invest,
                       cf::CFlow,
                       dyn::Dynamic)
    return -dyn.capital_dividend *
      max(0,
          cf.v[mc, t, INVEST_EOC] +
            cf.v[mc, t, TPG_EOC]+
            cf.v[mc, t, L_OTHER_EOC]
          )
  end

  ## Dynamic expense ---------------------------------------------------------
  function dynexpense(mc::Int,
                      t::Int,
                      invest::Invest,
                      cf::CFlow,
                      dyn::Dynamic)
    return 0
  end
  ## -------------------------------------------------------------------------
  function dyntaxprofit(mc::Int, t::Int, cfl::CFlow, dyn::Dynamic)
    return cfl.cf[mc, t, PROFIT] * dyn.hook.tax_profit
  end
  ## -------------------------------------------------------------------------
  me.probsx = dynprobsx
  me.alloc! = dynalloc!
  me.bonusrate = dynbonusrate
  me.dividend = dyndividend
  me.taxprofit = dyntaxprofit
  me.expense = dynexpense
  me.hook = DynamicHook(yield_mkt_init, yield_rf_init,
                        df_general[1,:tax_profit])
  return me
end
##------------------------------------------------------------------------------

