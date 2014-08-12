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
  discount_init = Array(Float64,0)
  CFlow(n_mc, n_cf, n_v, tf, cf, v_0, v,
        model_new_tax_credit, tax_credit_init, tax_credit, discount_init)
end

function CFlow(bkts::Buckets,
               invest::Invest,
               asset_other::AssetOther,
               liab_other::LiabOther,
               fluct::Fluct,
               dyn::Dynamic)
  cflow = CFlow(bkts.tf, invest.cap_mkt.n_mc)
  cflow.v_0 = vinit(invest, bkts, liab_other)
  cflow.discount_init =
    meandiscrf(invest.c, invest.c.yield_rf_init, 1, bkts.n_c)
  cflow.model_new_tax_credit = asset_other.model_new_tax_credit
  cflow.tax_credit_init = asset_other.tax_credit_init
  for mc = 1:cflow.n_mc
    liab_other_mc = deepcopy(liab_other)
    for t = 1:cflow.tf.n_c
      discount = meandiscrf(invest.c, invest.c.yield_rf_eoc[mc,t], t, bkts.n_c)
      projectcycle!(cflow, mc, t, bkts, invest,
                    liab_other_mc, fluct, discount, dyn)
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

function dfcf(me::CFlow, mc::Int, prec::Int=-1)
  ## use showall for printing to screen
  dframe = DataFrame()
  for i = 1:size(me.cf,3)
    if prec < 0
      dframe[col_CF[i]] = reshape(me.cf[mc,:,i], size(me.cf,2))
    else
      dframe[col_CF[i]] = round(reshape(me.cf[mc,:,i], size(me.cf,2)), prec)
    end
  end
  dframe
end

function dfv(me::CFlow, mc::Int, prec::Int=-1)
  ## use showall for printing to screen
  dframe = DataFrame()
  for i = 1:size(me.v,3)
    if prec < 0
      dframe[col_V[i]] = reshape(me.v[mc,:,i], size(me.v,2))
    else
      dframe[col_V[i]] = round(reshape(me.v[mc,:,i], size(me.v,2)), prec)
    end
  end
  dframe[:CYCLE] = int(dframe[:CYCLE])
  dframe
end

function dfv0(me::CFlow, prec::Int=-1)
  ## use showall for printing to screen
  dframe = DataFrame()
  for i = 1:size(me.v_0,3)
    if prec < 0
      dframe[col_V[i]] = reshape(me.v_0[1,:,i], size(me.v_0,2))
    else
      dframe[col_V[i]] = round(reshape(me.v_0[1,:,i], size(me.v_0,2)), prec)
    end
  end
  dframe[:CYCLE] = int(dframe[:CYCLE])
  dframe
end

function disccf(me::CFlow, invest::Invest, prec::Int=-1)
  ind = Int[eval(c) for c in col_CF]
  if prec < 0
    disc_cf = reshape(sum(cfdisccycles(me, ind, invest), 2),
                      size(me.v,1), length(ind))
  else
    disc_cf = round(reshape(sum(cfdisccycles(me, ind, invest), 2),
                            size(me.v,1), length(ind)),
                    prec)
  end
  df_disc_cf = convert(DataFrame, disc_cf)
  names!(df_disc_cf, col_CF)
  return df_disc_cf
end

function pvdfcf(me::CFlow, invest::Invest, prec::Int=-1)
  disc_cf = disccf(me, invest, -1)
  if prec < 0
    pv_cf = (Float64[x[1] for x in colwise(mean, disc_cf)])'
  else
    pv_cf = round((Float64[x[1] for x in colwise(mean, disc_cf)])',prec)
  end
  df_pv_cf = convert(DataFrame, pv_cf)
  names!(df_pv_cf, names(disc_cf))
  return df_pv_cf
end

function balance_det_init(cfl::CFlow, scen::Symbol, prec::Int = -1)
  bonus_eoc =  cfl.discount_init[1:cfl.tf.n_c] ⋅ dfcf(cfl,1)[:BONUS]
  tax_credit_eoc =  cfl.discount_init[1:cfl.tf.n_c] ⋅ dfcf(cfl,1)[:TAX_CREDIT]
  if prec >= 0
    bonus_eoc = round(bonus_eoc, prec)
  end
  return hcat(dfv0(cfl, prec), DataFrame(BONUS_EOC = bonus_eoc,
                                         TAX_CREDIT_EOC = tax_credit_eoc,
                                         SCEN = scen))
end

# function balance_det(cfl::CFlow, scen::Symbol, prec::Int = -1)
#   bonus_eoc =  cfl.discount_init[1:cfl.tf.n_c] ⋅ dfcf(cfl,1)[:BONUS]
#   if prec >= 0
#     bonus_eoc = round(bonus_eoc, prec)
#   end
#   return hcat(dfv0(cfl, prec), DataFrame(BONUS_EOC = bonus_eoc, SCEN = scen))
# end

## Private ---------------------------------------------------------------------

function vinit(invest::Invest,
               buckets::Buckets,
               l_oth::LiabOther)
  # Returns the initial balance sheet *without* accounting for
  # the value of future discretionary benefits.
  # They are implicitly included in SURPLUS_EOC
  discount = meandiscrf(invest.c,invest.c.yield_rf_init, 1, buckets.n_c)
  v_0 = zeros(Float64, 1, 1, length(col_V))
  v_0[1,1,CYCLE] = buckets.tf.init - 1
  v_0[1,1,TPG_EOC] = 0.0
  for bkt in buckets.all
    ## the first row is only used in discount -> discount_1c, so prepending
    ## 1 gives the correct discount_1c.
    ## The length of the vector forces tpgeoc to calculate the provisions
    ## at the end of the cycle prior to tf.init.
    v_0[1,1,TPG_EOC]  +=
      tpgeoc(vcat(zeros(Float64, 1, 3), bkt.prob_be),
             vcat(1.0, discount),
             vcat(zeros(Float64, 1, N_COND), bkt.cond), #- bkt.cond_nb
             prepend_c(invest.ig[invest.id[:cash]].cost, [0.0, 0.0]),
             vcat(0, bkt.portion_c))
  end
  v_0[1,1,L_OTHER_EOC] = pvboc(l_oth,1,discount)
  v_0[1,1,INVEST_EOC] = invest.mv_total_init
  v_0[1,1,SURPLUS_EOC] =
    v_0[1,1,INVEST_EOC] + v_0[1,1,TPG_EOC] + v_0[1,1,L_OTHER_EOC]
  return v_0
end

function projectcycle!(me::CFlow,
                       mc::Int,
                       t::Int,
                       buckets::Buckets,
                       invest::Invest,
                       liab_other::LiabOther,
                       fluct::Fluct,
                       discount::Vector{Float64},
                       dyn::Dynamic
                       )
  me.v[mc,t,CYCLE] = me.tf.init - 1 + t
  for bkt in buckets.all
    bucketprojectboc!(me, bkt, fluct, mc, t)
  end
  new_debt = getdebt(liab_other, t)
  investeoc!(me, invest, mc, t, new_debt, dyn)
  me.cf[mc,t,C_EOC] +=  costs(invest,t)
  me.cf[mc, t, L_OTHER] += paydebt(liab_other, t)
  me.v[mc, t, L_OTHER_EOC] += pveoc(liab_other, t, discount)
  for bkt in buckets.all
    bucketprojecteoc!(me, bkt, fluct, invest, discount, mc, t, dyn)
  end
  if t == 1
    me.cf[mc, t, DELTA_TPG] = me.v[mc, t, TPG_EOC] - me.v_0[1, 1, TPG_EOC]
  else
    me.cf[mc, t, DELTA_TPG] =  me.v[mc, t, TPG_EOC] - me.v[mc, t-1, TPG_EOC]
  end
  # assets before bonus, dividend, surplus, tax
  assetspreeoc!(me, invest, mc, t)
  # prepare dyn for bonus allocation and dividend declaration
  dyn.update!(dyn, t, me.cf[mc, t, :], me.v[mc, t, :])
  for bkt in buckets.all
    bucketbonuseoc!(me, bkt, invest, mc, t, dyn)
  end
  me.cf[mc, t, PROFIT] =
    sum(me.cf[mc, t,
              [QX, PX, SX, PREM, C_BOC, C_EOC, DELTA_TPG, BONUS, INVEST]])

  tax_profit = dyn.taxprofit(mc, t, me, dyn)
  tax_credit_pre_eoc = (t == 1 ? me.tax_credit_init : me.tax_credit[mc, t-1])

  me.cf[mc, t, TAX] = min(0, tax_credit_pre_eoc + tax_profit)
  me.cf[mc, t, TAX_CREDIT] =  me.cf[mc, t, TAX] - min(0.0, tax_profit)
  me.tax_credit[mc, t] =
    tax_credit_pre_eoc +
    (me.model_new_tax_credit ? max(0.0, tax_profit) : 0.0) -
    me.cf[mc, t, TAX_CREDIT]
  me.cf[mc, t, TAX] = min(0, tax_profit)
  # dividends, bonus, surplus, final assets
  surpluseoc!(me, invest, mc, t, dyn)
end

function bucketprojectboc!(me::CFlow,
                           bucket::Bucket,
                           fluct::Fluct,
                           mc::Int,
                           t:: Int)
  bucket.lx_boc = (t == 1 ? 1 : bucket.lx_boc_next)
  me.cf[mc,t,PREM] +=  bucket.lx_boc * bucket.cond[t,PREM]
  me.cf[mc,t,C_BOC] +=
    bucket.lx_boc * fluct.fac[mc,t,fluct.d[C_BOC]] * bucket.cond[t,C_BOC]
end

function investeoc!(me::CFlow,
                    invest::Invest,
                    mc::Int,
                    t::Int,
                    new_debt::Float64,
                    dyn::Dynamic)
  mv_boc = (t == 1 ? me.v_0[1,1,INVEST_EOC] : me.v[mc,t-1,INVEST_EOC])
  mv_boc -= new_debt  ## new debt is negative but increases assets
  mv_boc += me.cf[mc,t,PREM] + me.cf[mc,t,C_BOC]
#   mv_boc = mv_bop
#   for t_p in ((t-1) * me.tf.n_dt+1):(t * me.tf.n_dt)
#     dyn.alloc!(invest, mc, t, dyn)
#     project!( invest, mc, t_p, mv_bop)
#     mv_bop = invest.mv_total_eop[mc,t_p]
#   end
#   me.cf[mc,t,INVEST] += mv_bop - mv_boc
#   yield[mc, t] = log(mv_bop/max(mv_boc, eps()))
  me.cf[mc,t,INVEST] = projecteoc!(invest, mc, t, dyn, mv_boc)
end

function bucketprojecteoc!(me::CFlow,
                           bkt::Bucket,
                           fluct::Fluct,
                           invest::Invest,
                           discount::Vector{Float64},
                           mc::Int,
                           t::Int,
                           dyn::Dynamic)
  prob = getprob(dyn, bkt, mc, t, invest, fluct)
  bkt.lx_boc_next = bkt.lx_boc * prob[t,PX]
  for X = (QX, SX, PX)
    me.cf[mc,t,X] += bkt.lx_boc * prob[t,X] * bkt.cond[t,X]
  end
  me.cf[mc,t,C_EOC] +=
    bkt.lx_boc * fluct.fac[mc,t,fluct.d[C_EOC]] * bkt.cond[t,C_EOC]
  me.v[mc,t,TPG_EOC] +=
    bkt.lx_boc * prob[t,PX] * tpgeoc(prob[ t:bkt.n_c, :],
                                     discount[1:(bkt.n_c+1-t)],
                                     bkt.cond[ t:bkt.n_c, :],
                                     invest.ig[invest.id[:cash]].cost,
                                     bkt.portion_c)
end

function bucketbonuseoc!(me::CFlow,
                         bkt::Bucket,
                         invest::Invest,
                         mc::Int,
                         t::Int,
                         dyn::Dynamic)
  bkt.bonus_rate = dyn.bonusrate(mc, t, bkt, invest, dyn)
  if t == 1
    me.cf[mc,t,BONUS] += bkt.bonus_rate * bkt.tpg_price_init
  else
    me.cf[mc,t,BONUS] +=  bkt.lx_boc * bkt.bonus_rate * bkt.tpg_price[t-1]
  end
end

function assetspreeoc!(me::CFlow,
                       invest::Invest,
                       mc::Int,
                       t::Int)
  me.v[mc,t,INVEST_EOC] = invest.mv_total_eop[mc, t * me.tf.n_dt]
  for j in [QX, SX, PX, C_EOC, L_OTHER, BONUS]
    me.v[mc,t,INVEST_EOC] += me.cf[mc, t, j]
  end
end

function surpluseoc!(me::CFlow,
                     invest::Invest,
                     mc::Int,
                     t::Int,
                     dyn::Dynamic)
  me.cf[mc, t, DIVID] = dyn.dividend(mc, t, invest, me, dyn)
  me.v[mc, t, INVEST_EOC] +=  me.cf[mc, t, DIVID] +  me.cf[mc, t, TAX]
  me.v[mc, t, SURPLUS_EOC] =
    me.v[mc, t, INVEST_EOC] +
    me.v[mc, t, TPG_EOC] +
    me.v[mc, t, L_OTHER_EOC]
end

function cfdisccycles(me::CFlow, ind::Vector{Int}, invest::Invest)
  cfl = me.cf[:,:,ind]
  result = Array(Float64, size(cfl) )
  for mc = 1:size(cfl,1)
    for j = 1:size(cfl,3)
      result[mc,:,j] = map(*,
                           exp(-cumsum(invest.c.yield_rf_eoc,2))[mc,:],
                           cfl[mc,:,j])
    end
  end
  return result
end

