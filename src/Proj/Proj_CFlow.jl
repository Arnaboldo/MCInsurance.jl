## Constructors ----------------------------------------------------------------

function CFlow(tf::TimeFrame, n_mc::Int)
  n_cf = length(col_CF)
  n_v = length(col_V)
  cf = zeros(Float64, n_mc, tf.n_c, n_cf )
  v_0 = zeros(Float64, 1, 1, n_v)
  v = zeros(Float64, n_mc, tf.n_c, n_v )
  CFlow(n_mc, n_cf, n_v, tf, cf, v_0, v)
end

function CFlow(buckets::Buckets,
               invest::Invest,
               other::Other,
               fluct::Fluct,
               dyn::Dynamic )
  cflow = CFlow(buckets.tf, invest.cap_mkt.n_mc)
  cflow.v_0 = vinit(invest, buckets, other)
  for mc = 1:cflow.n_mc
    for t = 1:cflow.tf.n_c
      discount = meancumdiscrf(invest.c,
                               invest.c.yield_rf_eoc[mc,t],
                               buckets.n_c)
      projectcycle!(cflow, mc, t, buckets, invest,
                    other, fluct, discount, dyn)
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


function vinit(invest::Invest,
               buckets::Buckets,
               other::Other)
  # Returns the initial balance sheet *without* accounting for
  # the value of future discretionary benefits.
  # They are implicitly included in SURPLUS_EOC
  discount = meancumdiscrf(invest.c,invest.c.yield_rf_init, buckets.n_c)
  v_0 = zeros(Float64, 1, 1, length(col_V))
  v_0[1,1,CYCLE] = buckets.tf.init - 1
  v_0[1,1,TPG_EOC] = 0.0
  for bkt in buckets.all
    ## the first row is only used in discount -> discount_1c, so prepending
    ## 1 gives the correct discount_1c.
    ## The length of the vector forces tpgeoc to calculate the provisions
    ## at the end of the cycle prior to tf.init.
    v_0[1,1,TPG_EOC]  += tpgeoc(vcat(zeros(Float64, 1, 3), bkt.prob_be),
                                 vcat(1.0, discount),
                                 vcat(zeros(Float64, 1, N_COND),
                                      bkt.cond - bkt.cond_nb))
  end
  v_0[1,1,OTHER_EOC] = pvboc(other,1,discount)
  v_0[1,1,ASSET_EOC] = invest.mv_total_init
  v_0[1,1,SURPLUS_EOC] =
    v_0[1,1,ASSET_EOC] + v_0[1,1,TPG_EOC] + v_0[1,1,OTHER_EOC]
  return v_0
end

function dfcf(me::CFlow, mc::Int, digits::Int=1)
  ## use showall for printing to screen
  dframe = DataFrame()
  for i = 1:size(me.cf,3)
    dframe[col_CF[i]] =
      round(reshape(me.cf[mc,:,i], size(me.cf,2)), digits)
  end
  dframe
end

function dfv(me::CFlow, mc::Int, digits::Int=1)
  ## use showall for printing to screen
  dframe = DataFrame()
  for i = 1:size(me.v,3)
    dframe[col_V[i]] =
      round(reshape(me.v[mc,:,i], size(me.v,2)), digits)
  end
  dframe[:CYCLE] = int(dframe[:CYCLE])
  dframe
end

function dfv0(me::CFlow, digits::Int=1)
  ## use showall for printing to screen
  dframe = DataFrame()
  for i = 1:size(me.v_0,3)
    dframe[col_V[i]] =
      round(reshape(me.v_0[1,:,i], size(me.v_0,2)), digits)
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

## Private ---------------------------------------------------------------------

function projectcycle!(me::CFlow,
                       mc::Int,
                       t::Int,
                       buckets::Buckets,
                       invest::Invest,
                       other::Other,
                       fluct::Fluct,
                       discount::Vector{Float64},
                       dyn::Dynamic,
                       )
  me.v[mc,t,CYCLE] = me.tf.init - 1 + t
  for bkt in buckets.all
    bucketprojectboc!(me, bkt, fluct, mc, t)
  end
  investeoc!(me, invest, mc, t, dyn)
  me.cf[mc, t, OTHER] += paydebt(other, t)
  me.v[mc, t, OTHER_EOC] += pveoc(other, t, discount)
  for bucket in buckets.all
    bucketprojecteoc!(me, bucket, fluct, invest, discount, mc, t, dyn)
  end
  if t == 1
    me.cf[mc, t, DELTA_TPG] = me.v[mc, t, TPG_EOC] - me.v_0[1, 1, TPG_EOC]
  else
    me.cf[mc, t, DELTA_TPG] =  me.v[mc, t, TPG_EOC] - me.v[mc, t-1, TPG_EOC]
  end
  # assets before bonus, dividend, surplus
  assetspreeoc!(me, invest, mc, t)
  # prepare dyn for bonus allocation and dividend declaration
  dyn.update!(dyn, t, me.cf[mc, t, :], me.v[mc, t, :])
  for bkt in buckets.all
    bucketbonuseoc!(me, bkt, invest, mc, t, dyn)
  end
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
                           dyn::Dynamic)
  mv_bop = (t == 1 ? me.v_0[1,1,ASSET_EOC] : me.v[mc,t-1,ASSET_EOC])
  mv_bop += me.cf[mc,t,PREM] + me.cf[mc,t,C_BOC]
  mv_boc = mv_bop
  for t_p in ((t-1) * me.tf.n_dt+1):(t * me.tf.n_dt)
    dyn.alloc!(mc, t, invest, dyn)
    project!( invest, mc, t_p, mv_bop)
    mv_bop = invest.mv_total_eop[mc,t_p]
  end
  me.cf[mc,t,INVEST] += invest.mv_total_eop[mc, t * me.tf.n_dt] - mv_boc
end

function bucketprojecteoc!(me::CFlow,
                           bucket::Bucket,
                           fluct::Fluct,
                           invest::Invest,
                           discount::Vector{Float64},
                           mc::Int,
                           t::Int,
                           dyn::Dynamic)
  prob = getprob(dyn, bucket, mc, t, invest, fluct)
  bucket.lx_boc_next = bucket.lx_boc * prob[t,PX]
  for X = (QX, SX, PX)
    me.cf[mc,t,X] += bucket.lx_boc * prob[t,X] * bucket.cond[t,X]
  end
  me.cf[mc,t,C_EOC] +=
    bucket.lx_boc * fluct.fac[mc,t,fluct.d[C_EOC]] * bucket.cond[t,C_EOC]
  me.v[mc,t,TPG_EOC] +=
    bucket.lx_boc * prob[t,PX] * tpgeoc(prob[ t:bucket.n_c, :],
                                       discount[t:bucket.n_c],
                                       bucket.cond[ t:bucket.n_c, :])
end

function bucketbonuseoc!(me::CFlow,
                           bucket::Bucket,
                           invest::Invest,
                           mc::Int,
                           t::Int,
                           dyn::Dynamic)
  bucket.bonus_rate = dyn.bonusrate(mc, t, bucket, invest, dyn)
  if t == 1
    me.cf[mc,t,BONUS] += bucket.bonus_rate * bucket.tpg_price_init
  else
    me.cf[mc,t,BONUS] +=
      bucket.lx_boc * bucket.bonus_rate * bucket.tpg_price[t-1]
  end
end

function assetspreeoc!(me::CFlow,
                            invest::Invest,
                            mc::Int,
                            t::Int)
  me.v[mc,t,ASSET_EOC] = invest.mv_total_eop[mc, t * me.tf.n_dt]
  for j in [QX, SX, PX, C_EOC, OTHER, BONUS]
    me.v[mc,t,ASSET_EOC] += me.cf[mc, t, j]
  end
end

function surpluseoc!(me::CFlow,
                            invest::Invest,
                            mc::Int,
                            t::Int,
                            dyn::Dynamic)
  me.cf[mc, t, DIVID] = dyn.dividend(mc, t, invest, me, dyn)
  me.v[mc, t, ASSET_EOC] += me.cf[mc, t, DIVID]
  me.v[mc, t, SURPLUS_EOC] =
    me.v[mc, t, ASSET_EOC] + me.v[mc, t, TPG_EOC] + me.v[mc, t, OTHER_EOC]
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

