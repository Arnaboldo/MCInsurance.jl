## Constructors ----------------------------------------------------------------

function CFlow(tf::TimeFrame, n_mc::Int)
  n_cf = length(col_CF)
  n_v = length(col_V)
  cf = zeros(Float64, n_mc, tf.n_c, n_cf )
  v_0 = zeros(Float64, 1, 1, n_v)
  v = zeros(Float64, n_mc, tf.n_c, n_v )
  model_new_tax_credit = true
  tax_credit_init = 0.0
  tax_credit = zeros(Float64, n_mc, tf.n_c)
  tax_credit_util = zeros(Float64, n_mc, tf.n_c)
  discount_init = Array(Float64,0)
  CFlow(n_mc, n_cf, n_v, tf, cf, v_0, v,
        model_new_tax_credit, tax_credit_init, tax_credit, tax_credit_util,
        discount_init)
end

function CFlow(bkts::Buckets,
               invest::Invest,
               asset_other::AssetOther,
               liab_other::LiabOther,
               fixed::Fixed,
               fluct::Fluct,
               dyn::Dynamic)
  cflow = CFlow(bkts.tf, invest.cap_mkt.n_mc)
  if cflow.tf.n_c < bkts.n_c
    warn("CFlow: buckets longer than time frame")
    len = cflow.tf.n_c
  else
    len = bkts.n_c
  end
  cflow.v_0 = vinit(invest, bkts, liab_other, fixed)
  cflow.discount_init =
    meandiscrf(invest.c, invest.c.yield_rf_init, 1, len)
  cflow.model_new_tax_credit = asset_other.model_new_tax_credit
  cflow.tax_credit_init = asset_other.tax_credit_init
  for mc = 1:cflow.n_mc
    liab_other_mc = deepcopy(liab_other)
    for t = 1:cflow.tf.n_c
      discount = meandiscrf(invest.c, invest.c.yield_rf_eoc[mc,t], t, len)
      disc_1c =  (discount ./ [1, discount[1:end-1]])
      disc_cost_1c =
        disc_1c ./
      (1 .+ invest.ig[invest.id[:cash]].cost.rel_c[t:len] .* disc_1c)

      projectcycle!(cflow, mc, t, bkts, invest,
                    liab_other_mc, fixed, fluct, disc_cost_1c, dyn, len)
    end
  end
  cflow
end

## Interface -------------------------------------------------------------------

function ==(cflow1::CFlow, cflow2::CFlow)
  cflow1.n == cflow2.n &&
    cflow1.n_mc == cflow2.n_mc &&
    cflow1.tf == cflow2.tf &&
    cflow1.cf == cflow2.cf &&
    cflow1.v_0 == cflow2.v_0 &&
    cflow1.v == cflow2.v
end

function dfcf(cfl::CFlow, mc::Int, prec::Int=-1)
  ## use showall for printing to screen
  dframe = DataFrame()
  for i = 1:size(cfl.cf, 3)
    if prec < 0
      dframe[col_CF[i]] = reshape(cfl.cf[mc, :, i], size(cfl.cf, 2))
    else
      dframe[col_CF[i]] =
        round(reshape(cfl.cf[mc, :, i], size(cfl.cf, 2)), prec)
    end
  end
  dframe
end

function dfv(cfl::CFlow, mc::Int, prec::Int=-1)
  ## use showall for printing to screen
  dframe = DataFrame()
  for i = 1:size(cfl.v, 3)
    if prec < 0
      dframe[col_V[i]] = reshape(cfl.v[mc, :, i], size(cfl.v, 2))
    else
      dframe[col_V[i]] = round(reshape(cfl.v[mc, :, i], size(cfl.v, 2)), prec)
    end
  end
  dframe[:CYCLE] = int(dframe[:CYCLE])
  dframe
end

function dfv0(cfl::CFlow, prec::Int=-1)
  ## use showall for printing to screen
  dframe = DataFrame()
  for i = 1:size(cfl.v_0, 3)
    if prec < 0
      dframe[col_V[i]] = reshape(cfl.v_0[1, :, i], size(cfl.v_0, 2))
    else
      dframe[col_V[i]] =
        round(reshape(cfl.v_0[1, :, i], size(cfl.v_0, 2)), prec)
    end
  end
  dframe[:CYCLE] = int(dframe[:CYCLE])
  dframe
end

function disccf(cfl::CFlow, invest::Invest, prec::Int=-1)
  ind = Int[eval(c) for c in col_CF]
  if prec < 0
    disc_cf = reshape(sum(cfdisccycles(cfl, ind, invest), 2),
                      size(cfl.v, 1), length(ind))
  else
    disc_cf = round(reshape(sum(cfdisccycles(cfl, ind, invest), 2),
                            size(cfl.v, 1), length(ind)),
                    prec)
  end
  df_disc_cf = convert(DataFrame, disc_cf)
  names!(df_disc_cf, col_CF)
  return df_disc_cf
end

function pvdfcf(cfl::CFlow, invest::Invest, prec::Int=-1)
  disc_cf = disccf(cfl, invest, -1)
  if prec < 0
    pv_cf = (Float64[x[1] for x in colwise(mean, disc_cf)])'
  else
    pv_cf = round((Float64[x[1] for x in colwise(mean, disc_cf)])', prec)
  end
  df_pv_cf = convert(DataFrame, pv_cf)
  names!(df_pv_cf, names(disc_cf))
  return df_pv_cf
end

function balance_det_init(cfl::CFlow, cost_rel::Vector{Float64},
                          scen::Symbol, prec::Int = -1)
  bonus_eoc = proveoc(cfl,
                      vcat(1, cfl.discount_init),
                      vcat(0, cost_rel),
                      BONUS)
  ## tax credit assets are not backed by investments -> no investment costs
  tax_credit_eoc = cfl.tax_credit_util[1,:] * cfl.discount_init
  if prec >= 0
    bonus_eoc = round(bonus_eoc, prec)
  end
  return hcat(dfv0(cfl, prec), DataFrame(BONUS_EOC = bonus_eoc,
                                         TAX_CREDIT_EOC = tax_credit_eoc,
                                         SCEN = scen))
end

function balance_det(cfl::CFlow,
                     mc::Int,
                     cost_rel::Vector{Float64},
                     scen::Symbol, prec::Int = -1)
  bonus_eoc = proveocvec(cfl,  cfl.discount_init,  cost_rel, BONUS)
  ## tax credit assets are not backed by investments ⇒ no investment costs
  ## tax credits cannot be utilized after end of projection
  ## ⇒ tax_credit_eoc[end] == 0
  tax_credit_eoc =
    [reverse(cumsum(reverse(vec(cfl.tax_credit_util[1,2:end]) .*
                            cfl.discount_init[2:end]))),
     0]
  if prec >= 0
    bonus_eoc = Float64[round(bon, prec) for bon in bonus_eoc]
    tax_credit_eoc = Float64[round(tc, prec) for tc in tax_credit_eoc]
  end
  return hcat(dfv(cfl, mc, prec), DataFrame(BONUS_EOC = bonus_eoc,
                                            TAX_CREDIT_EOC = tax_credit_eoc,
                                            SCEN = scen))
end

## get vector of provisions eoc (present value incl. relative costs)
function proveocvec(cfl::CFlow,
                    discount::Vector{Float64},
                    cost_rel::Vector{Float64},
                    col::Int)
  n_c = size(cfl.cf, 2)
  t = n_c -length(discount)+1
  prov = zeros(Float64, n_c-t+1)
  discount_1c = discount ./ [1, discount[1:end-1]]
  prov[end] = 0.0
  for τ in [n_c-t:-1:1]
    prov[τ] =
      discount_1c[τ+1] * (cfl.cf[1,t+τ,col] + prov[τ+1]) /
      (1 + discount_1c[τ+1] * cost_rel[τ+1])
  end
  return prov
end

function proveoc(cfl::CFlow,
                 discount::Vector{Float64},
                 cost_rel::Vector{Float64},
                 col::Int)
  n_c = size(cfl.cf, 2)
  t = n_c -length(discount)+1
  discount_1c = discount ./ [1, discount[1:end-1]]
  prov = 0.0
  for τ in [n_c-t:-1:1]
    prov =
      discount_1c[τ+1] * (cfl.cf[1,t+τ,col] + prov) /
      (1 + discount_1c[τ+1] * cost_rel[τ+1])
  end
  return prov
end


function proveoc(cf::Vector{Float64},
                 discount::Vector{Float64},
                 cost_rel::Vector{Float64})
  n_c = length(cf)
  t = n_c -length(discount)+1
  discount_1c = discount ./ [1, discount[1:end-1]]
  prov = 0.0
  for τ in [n_c-t:-1:1]
    prov =
      discount_1c[τ+1] * (cf[t+τ] + prov) /
      (1 + discount_1c[τ+1] * cost_rel[τ+1])
  end
  return prov
end


## Private ---------------------------------------------------------------------

function vinit(invest::Invest,
               bkts::Buckets,
               l_oth::LiabOther,
               fixed::Fixed)
  # Returns the initial balance sheet *without* accounting for
  # the value of future discretionary benefits.
  # They are implicitly included in SURPLUS_EOC
  if invest.tf.n_c < bkts.n_c
    warn("vinit: buckets longer than time frame")
    len = invest.tf.n_c
  else
    len = bkts.n_c
  end
  discount = meandiscrf(invest.c,invest.c.yield_rf_init, 1, len)
  disc_1c =  (discount ./ [1, discount[1:end-1]])
  disc_cost_1c =
    disc_1c ./
  (1 .+ invest.ig[invest.id[:cash]].cost.rel_c[1:len] .* disc_1c)

  v_0 = zeros(Float64, 1, 1, length(col_V))
  v_0[1,1,CYCLE] = bkts.tf.init - 1
  v_0[1,1,TPG_EOC] = 0.0
  for bkt in bkts.all
    ## the first row is only used in discount -> discount_1c, so prepending
    ## 1 gives the correct discount_1c.
    ## The length of the vector forces tpgeoc to calculate the provisions
    ## at the end of the cycle prior to tf.init.
    v_0[1,1,TPG_EOC]  +=
      tpgeoc(vcat(zeros(Float64, 1, 3), bkt.prob_ie[1:len, :]),
             vcat(1.0, disc_1c),
             vcat(zeros(Float64, 1, N_COND), bkt.cond[1:len, :]), #- bkt.cond_nb
             vcat(0,
                  bkt.portion_c[1:len] .* fixed.cost_abs_gc_c[1:len]))
  end
  v_0[1,1,L_OTHER_EOC] = pvboc(l_oth, 1, disc_1c)
  v_0[1,1,INVEST_EOC] = invest.mv_total_init
  v_0[1,1,SURPLUS_EOC] =
    -(v_0[1,1,INVEST_EOC] + v_0[1,1,TPG_EOC] + v_0[1,1,L_OTHER_EOC])
  return v_0
end


function projectcycle!(cfl::CFlow,
                       mc::Int,
                       t::Int,
                       buckets::Buckets,
                       invest::Invest,
                       liab_other::LiabOther,
                       fixed::Fixed,
                       fluct::Fluct,
                       disc_cost_1c::Vector{Float64},
                       dyn::Dynamic,
                       len::Int
                       )
  cfl.v[mc,t,CYCLE] = cfl.tf.init - 1 + t
  for bkt in buckets.all
    bucketprojectboc!(cfl, bkt, fluct, mc, t)
  end
  new_debt = getdebt(liab_other, t)
  projectinvesteoc!(cfl, invest, mc, t, new_debt, dyn)
  dyn.update!(mc, t, cfl, dyn)
  cfl.cf[mc,t,C_EOC] +=  costs(invest,t)
  cfl.cf[mc, t, L_OTHER] = paycoupon(liab_other, t)
  cfl.v[mc, t, L_OTHER_EOC] = pveoc(liab_other, t, disc_cost_1c)

  for bkt in buckets.all
    fixed_cost_scaled =
      bkt.portion_c[t:len] .* fixed.cost_abs_gc_c[t:len]
    bucketprojecteoc!(mc, t, dyn, invest, bkt, fluct, cfl,
                      disc_cost_1c, fixed_cost_scaled, len)
  end
  if t == 1
    cfl.cf[mc, t, DELTA_TPG] = cfl.v[mc, t, TPG_EOC] - cfl.v_0[1, 1, TPG_EOC]
  else
    cfl.cf[mc, t, DELTA_TPG] =  cfl.v[mc, t, TPG_EOC] - cfl.v[mc, t-1, TPG_EOC]
  end
  # prepare dyn for bonus allocation and dividend declaration
  for bkt in buckets.all
    bucketbonuseoc!(mc, t, dyn, invest, bkt, cfl)
  end
  cfl.cf[mc, t, PROFIT] =
    sum(cfl.cf[mc, t,
               [QX, SX, PX, PREM, C_BOC, C_EOC,  DELTA_TPG, BONUS,
                INVEST, L_OTHER]])
  tax = dyn.taxprofit(mc, t, dyn, cfl) ## could be positive -> tax credit
  tax_credit_pre_eoc = (t == 1 ? cfl.tax_credit_init : cfl.tax_credit[mc, t-1])
  cfl.cf[mc, t, TAX] = min(0, tax_credit_pre_eoc + tax)
  cfl.tax_credit[mc, t] =
    tax_credit_pre_eoc +
    (cfl.model_new_tax_credit ? tax : min(0.0, tax)) -
    cfl.cf[mc, t, TAX]
  cfl.tax_credit_util[mc, t] = tax_credit_pre_eoc - cfl.tax_credit[mc, t]
  cfl.v[mc, t, INVEST_EOC] = investpredivid(mc, t, invest, liab_other, cfl)
  cfl.cf[mc, t, DIVID] =
    dyn.dividend(mc, t, dyn, cfl, cfl.v[mc, t, INVEST_EOC])
  cfl.v[mc, t, INVEST_EOC] +=  cfl.cf[mc, t, DIVID]
  cfl.v[mc, t, SURPLUS_EOC] = surpluseoc(mc, t, dyn, invest, cfl)
end

function bucketprojectboc!(cfl::CFlow,
                           bucket::Bucket,
                           fluct::Fluct,
                           mc::Int,
                           t:: Int)
  bucket.lx_boc = (t == 1 ? 1 : bucket.lx_boc_next)
  cfl.cf[mc,t,PREM] +=  bucket.lx_boc * bucket.cond[t,PREM]
  cfl.cf[mc,t,C_BOC] +=
    bucket.lx_boc * fluct.fac[mc,t,fluct.d[C_BOC]] * bucket.cond[t,C_BOC]
end

## This function has two effects:
## 1) projection of investments for one cycle. This changes invest::Invest
## 2) update of cash-flow for investment income
function projectinvesteoc!(cfl::CFlow,
                           invest::Invest,
                           mc::Int,
                           t::Int,
                           new_debt::Float64,
                           dyn::Dynamic)
  mv_boc = (t == 1 ? cfl.v_0[1,1,INVEST_EOC] : cfl.v[mc,t-1,INVEST_EOC])
  mv_boc -= new_debt  ## new debt is negative but increases assets
  mv_boc += cfl.cf[mc,t,PREM] + cfl.cf[mc,t,C_BOC]
  cfl.cf[mc,t,INVEST] = projecteoc!(mc, t, dyn, invest, mv_boc)
end

function bucketprojecteoc!(mc::Int,
                           t::Int,
                           dyn::Dynamic,
                           invest::Invest,
                           bkt::Bucket,
                           fluct::Fluct,
                           cfl::CFlow,
                           disc_cost_1c::Vector{Float64},
                           fixed_cost_scaled::Vector{Float64},
                           len::Int)
  global cost_temp
  prob = getprob(mc, t, dyn, invest, bkt, fluct, len)
  bkt.lx_boc_next = bkt.lx_boc * prob[t,PX]
  for WX = (QX, SX, PX)
    cfl.cf[mc, t, WX] += bkt.lx_boc * prob[t, WX] * bkt.cond[t, WX]
  end
  cfl.cf[mc,t,C_EOC] +=
    bkt.lx_boc * fluct.fac[mc,t,fluct.d[C_DIR_EOC]] * bkt.cond[t,C_DIR_EOC]

  cfl.v[mc,t,TPG_EOC] +=
    bkt.lx_boc * prob[t,PX] *
    tpgeoc(prob[t:len, :],
           disc_cost_1c[1:(len + 1 - t)],
           bkt.cond[t:len, :],
           fixed_cost_scaled /  max(bkt.lx_boc * prob[t,PX], eps())
           )
end

function bucketbonuseoc!(mc::Int,
                         t::Int,
                         dyn::Dynamic,
                         invest::Invest,
                         bkt::Bucket,
                         cfl::CFlow)
  bkt.bonus_rate = dyn.bonusrate(mc, t, dyn, invest, bkt)
  if t == 1
    cfl.cf[mc,t,BONUS] += bkt.bonus_rate * bkt.tpg_price_init
  else
    cfl.cf[mc,t,BONUS] +=  bkt.lx_boc * bkt.bonus_rate * bkt.tpg_price[t-1]
  end
end

## Investments must have been projected previously
function investpredivid(mc::Int,
                        t::Int,
                        invest::Invest,
                        liab_other::LiabOther,
                        cfl::CFlow)
  invest_pre_divid_eoc = invest.mv_total_eop[mc, t * cfl.tf.n_dt]
  for j in [QX, SX, PX, C_EOC, L_OTHER, BONUS, DELTA_TPG, TAX]
    invest_pre_divid_eoc += cfl.cf[mc, t, j]
  end
  invest_pre_divid_eoc += paydebt(liab_other, t)
  return invest_pre_divid_eoc
end

surpluseoc(mc::Int, t::Int, dyn::Dynamic, invest::Invest, cfl::CFlow) =
  -(cfl.v[mc, t, INVEST_EOC] +
      cfl.v[mc, t, TPG_EOC] +
      cfl.v[mc, t, L_OTHER_EOC])

function cfdisccycles(cfl::CFlow, ind::Vector{Int}, invest::Invest)
  cflow = cfl.cf[:,:,ind]
  result = Array(Float64, size(cflow) )
  for mc = 1:size(cflow,1)
    for j = 1:size(cflow,3)
      result[mc,:,j] = map(*,
                           exp(-cumsum(invest.c.yield_rf_eoc,2))[mc,:],
                           cflow[mc,:,j])
    end
  end
  return result
end

