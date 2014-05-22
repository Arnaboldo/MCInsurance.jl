## Constructors --------------------------------------------------

function CFlow(tf::TimeFrame, n_mc::Int)
    n = length(col_CFLOW)
    v = zeros(Float64, (n_mc, tf.n_c, n ))
    CFlow(n, n_mc, tf, v)
end

function CFlow(buckets::Buckets,
               invest::Invest,
               other::Other,
               fluct::Fluct,
               dyn::Dynamic )
    ## buckets.tf == invest.cap_mkt.tf
    cf = CFlow(buckets.tf, invest.cap_mkt.n_mc)
    for mc = 1:cf.n_mc
        for t = 1:cf.tf.n_c
            disc = meandiscrf(invest.c, invest.c.yield_rf_eoc[mc,t], buckets.n_c)
            projectcycle(cf, mc, t, buckets, invest, other, fluct, disc, dyn)
        end
    end
    cf
end


## Interface functions ---------------------------------------------------------

function ==(cf1::CFlow, cf2::CFlow)
    cf1.n == cf2.n &&
    cf1.n_mc == cf2.n_mc &&
    cf1.tf == cf2.tf &&
    cf1.v == cf2.v
 end

function cf(me::CFlow, mc::Int, digits::Int=1)
   ## use showall for printing to screen
   dframe = DataFrame()
    for i = 1:size(me.v,3)
        dframe[col_CFLOW[i]] =
            round(reshape(me.v[mc,:,i], size(me.v,2)), digits)
    end
    dframe[:CYCLE] = int( dframe[:CYCLE])
    dframe
end

function disccf(me::CFlow, invest::Invest, prec::Int=-1)
    cols = [:PX, :QX, :SX, :PREM, :C_BOC, :C_EOC, :INVEST, :OTHER,
            :BONUS, :DIVID]
    ind = Int[eval(c) for c in cols]



    if prec < 0
        disc_cf = reshape(sum(cfdisccycles(me, ind, invest), 2),
                          size(me.v,1), length(ind))
    else
        disc_cf = round(reshape(sum(cfdisccycles(me, ind, invest), 2),
                                size(me.v,1), length(ind)),
                        prec)
    end
    df_disc_cf = convert(DataFrame, disc_cf)
    names!(df_disc_cf, cols)
    return df_disc_cf
end

function pvcf(me::CFlow, invest::Invest, prec::Int=-1)
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

## Private functions -----------------------------------------------------------

function projectcycle(cf::CFlow,
                      mc::Int,
                      t::Int,
                      buckets::Buckets,
                      invest::Invest,
                      other::Other,
                      fluct::Fluct,
                      discount::Vector{Float64},
                      dyn::Dynamic,
                      )
    cf.v[mc,t,CYCLE] = cf.tf.init - 1 + t
    for bucket in buckets.all
        bucketprojectboc!(cf::CFlow, bucket, fluct, mc, t)
    end
    assetsprojecteoc!(cf, invest, mc, t, dyn)
    for bucket in buckets.all
        bucketprojecteoc!(cf, bucket, fluct, invest, discount, mc, t, dyn)
    end
    if t == 1
       cf.v[mc, t, DELTA_TP]  += cf.v[mc, t, TP_EOC]
    else
       cf.v[mc, t, DELTA_TP] =  cf.v[mc, t, TP_EOC] - cf.v[mc, t-1, TP_EOC]
    end
    cf.v[mc, t, OTHER] += cfl(other, t) #dyn.expense(mc, t, invest, cf, dyn)
    cf.v[mc, t, OTHER_EOC] += pveoc(other, t, discount)
    surplusprojecteoc!(cf, invest, mc, t, dyn)
end

function bucketprojectboc!(cf::CFlow,
                           bucket::Bucket,
                           fluct::Fluct,
                           mc::Int,
                           t:: Int)
    if t == 1  bucket.lx_boc = 1  end
    cf.v[mc,t,PREM] +=  bucket.lx_boc * bucket.cond[t,PREM]
    cf.v[mc,t,C_BOC] +=
        bucket.lx_boc * fluct.fac[mc,t,fluct.d[C_BOC]] * bucket.cond[t,C_BOC]
end

function assetsprojecteoc!(cf::CFlow,
                           invest::Invest,
                           mc::Int,
                           t::Int,
                           dyn::Dynamic)
    if t == 1
        mv_bop = invest.mv_total_init
    else
        mv_bop = cf.v[mc,t-1,ASSET_EOC]
    end
    mv_bop += cf.v[mc,t,PREM] + cf.v[mc,t,C_BOC]
    mv_boc = mv_bop
    for t_p in ((t-1) * cf.tf.n_dt+1):(t * cf.tf.n_dt)
        dyn.alloc!(mc, t, invest, dyn)
        project!( invest, mc, t_p, mv_bop)
        mv_bop = invest.mv_total_eop[mc,t_p]
    end
    cf.v[mc,t,INVEST] += invest.mv_total_eop[mc, t * cf.tf.n_dt] - mv_boc
end



function bucketprojecteoc!(cf::CFlow,
                           bucket::Bucket,
                           fluct::Fluct,
                           invest::Invest,
                           discount::Vector{Float64},
                           mc::Int,
                           t::Int,
                           dyn::Dynamic)
    bucket.bonus_rate = dyn.bonusrate(mc, t, bucket, invest, dyn)
    prob = getprob(dyn, bucket, mc, t, invest, fluct)
    for X = (QX, SX, PX)
        cf.v[mc,t,X] += bucket.lx_boc * prob[t,X] * bucket.cond[t,X]
    end
    cf.v[mc,t,C_EOC] +=
        bucket.lx_boc * fluct.fac[mc,t,fluct.d[C_EOC]] * bucket.cond[t,C_EOC]
    cf.v[mc,t,TP_EOC] +=
        bucket.lx_boc * prob[t,PX] * tpeoc(prob[ t:bucket.n_c, :],
                                           discount[t:bucket.n_c],
                                           bucket.cond[ t:bucket.n_c, :])
    if t == 1
        cf.v[mc,t, DELTA_TP] -= prob[t,PX] * bucket.tp_be_init # completed later
        cf.v[mc,t,BONUS] += bucket.bonus_rate * bucket.tp_stat_init
    else
        ## cf.v[mc,t, DELTA_TP] is calculated later in the calling function
        cf.v[mc,t,BONUS] +=
            bucket.lx_boc * bucket.bonus_rate * bucket.tp_stat[t-1]
    end
    ## roll forward lx to the next cycle
    bucket.lx_boc = bucket.lx_boc * prob[t,PX]
end


function surplusprojecteoc!(cf::CFlow,
                            invest::Invest,
                            mc::Int,
                            t::Int,
                            dyn::Dynamic)
    cf.v[mc,t,ASSET_EOC] =
        invest.mv_total_eop[mc, t * cf.tf.n_dt]
    for j in [QX, SX, PX, C_EOC, OTHER, BONUS]
        cf.v[mc,t,ASSET_EOC] += cf.v[mc, t, j]
    end
    cf.v[mc, t, DIVID] = dyn.dividend(mc, t, invest, cf, dyn)
    cf.v[mc, t, ASSET_EOC] += cf.v[mc, t, DIVID]
    cf.v[mc, t, SURPLUS_EOC] =
        cf.v[mc, t, ASSET_EOC] + cf.v[mc, t, TP_EOC] + cf.v[mc, t, OTHER_EOC]
end

function cfdisccycles(me::CFlow, ind::Vector{Int}, invest::Invest)
  cfl = me.v[:,:,ind]
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

