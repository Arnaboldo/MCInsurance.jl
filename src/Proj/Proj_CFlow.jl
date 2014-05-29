## Constructors --------------------------------------------------

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
    ## buckets.tf == invest.cap_mkt.tf
    cflow = CFlow(buckets.tf, invest.cap_mkt.n_mc)
    yield_rf_init_c =
        invest.ig[invest.id[:cash]].proc.yield[1,1,1] * buckets.tf.n_dt
    disc =  meandiscrf(invest.c,yield_rf_init_c, buckets.tf.n_c)
    vinit!(cflow, buckets, invest, other, disc)
    for mc = 1:cflow.n_mc
        for t = 1:cflow.tf.n_c
            disc = meandiscrf(invest.c, invest.c.yield_rf_eoc[mc,t], buckets.n_c)
            projectcycle!(cflow, mc, t, buckets, invest, other, fluct, disc, dyn)
        end
    end
    cflow
end


## Interface functions ---------------------------------------------------------

function ==(cflow1::CFlow, cflow2::CFlow)
    cflow1.n == cflow2.n &&
    cflow1.n_mc == cflow2.n_mc &&
    cflow1.tf == cflow2.tf &&
    cflow1.cf == cflow2.cf &&
    cflow1.v_0 == cflow2.v_0 &&
    cflow1.v == cflow2.v 
 end


function vinit!(me::CFlow,
                buckets::Buckets,
                invest::Invest,
                other::Other,
                discount::Vector{Float64})
    me.v_0[1,1,TP_EOC] = 0.0
    for bkt in buckets.all
             me.v_0[1,1,TP_EOC] += bkt.tp_be_init
    end
    me.v_0[1,1,OTHER_EOC] = pvboc(other,1,discount)
    me.v_0[1,1,ASSET_EOC] = invest.mv_total_init
    me.v_0[1,1,SURPLUS_EOC] =
        me.v_0[1,1,ASSET_EOC] + me.v_0[1,1,TP_EOC] + me.v_0[1,1,OTHER_EOC]
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
        dframe[col_v[i]] =
            round(reshape(me.v[mc,:,i], size(me.v,2)), digits)
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

## Private functions -----------------------------------------------------------

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
    for bucket in buckets.all
        bucketprojectboc!(me, bucket, fluct, mc, t)
    end
    assetsprojecteoc!(me, invest, mc, t, dyn)
    for bucket in buckets.all
        bucketprojecteoc!(me, bucket, fluct, invest, discount, mc, t, dyn)
    end
    if t == 1
       me.cf[mc, t, DELTA_TP] = me.v[mc, t, TP_EOC] - me.v_0[1, 1, TP_EOC]
    else
       me.cf[mc, t, DELTA_TP] =  me.v[mc, t, TP_EOC] - me.v[mc, t-1, TP_EOC]
    end
    me.cf[mc, t, OTHER] += paydebt(other, t) #dyn.expense(mc, t, invest, me, dyn)
    me.v[mc, t, OTHER_EOC] += pveoc(other, t, discount)
    surplusprojecteoc!(me, invest, mc, t, dyn)
end

function bucketprojectboc!(me::CFlow,
                           bucket::Bucket,
                           fluct::Fluct,
                           mc::Int,
                           t:: Int)
    if t == 1  bucket.lx_boc = 1  end
    me.cf[mc,t,PREM] +=  bucket.lx_boc * bucket.cond[t,PREM]
    me.cf[mc,t,C_BOC] +=
        bucket.lx_boc * fluct.fac[mc,t,fluct.d[C_BOC]] * bucket.cond[t,C_BOC]
end

function assetsprojecteoc!(me::CFlow,
                           invest::Invest,
                           mc::Int,
                           t::Int,
                           dyn::Dynamic)
    mv_bop = t == 1 ? me.v_0[1,1,ASSET_EOC] : me.v[mc,t-1,ASSET_EOC]
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
    bucket.bonus_rate = dyn.bonusrate(mc, t, bucket, invest, dyn)
    prob = getprob(dyn, bucket, mc, t, invest, fluct)
    for X = (QX, SX, PX)
        me.cf[mc,t,X] += bucket.lx_boc * prob[t,X] * bucket.cond[t,X]
    end
    me.cf[mc,t,C_EOC] +=
        bucket.lx_boc * fluct.fac[mc,t,fluct.d[C_EOC]] * bucket.cond[t,C_EOC]
    me.v[mc,t,TP_EOC] +=
        bucket.lx_boc * prob[t,PX] * tpeoc(prob[ t:bucket.n_c, :],
                                           discount[t:bucket.n_c],
                                           bucket.cond[ t:bucket.n_c, :])
    if t == 1
        me.cf[mc,t,BONUS] += bucket.bonus_rate * bucket.tp_stat_init
    else
        ## me.v[mc,t, DELTA_TP] is calculated later in the calling function
        me.cf[mc,t,BONUS] +=
            bucket.lx_boc * bucket.bonus_rate * bucket.tp_stat[t-1]
    end
    ## roll forward lx to the next cycle
    bucket.lx_boc = bucket.lx_boc * prob[t,PX]
end


function surplusprojecteoc!(me::CFlow,
                            invest::Invest,
                            mc::Int,
                            t::Int,
                            dyn::Dynamic)
    me.v[mc,t,ASSET_EOC] = invest.mv_total_eop[mc, t * me.tf.n_dt]
    for j in [QX, SX, PX, C_EOC, OTHER, BONUS]
        me.v[mc,t,ASSET_EOC] += me.cf[mc, t, j]
    end
    me.cf[mc, t, DIVID] = dyn.dividend(mc, t, invest, me, dyn)
    me.v[mc, t, ASSET_EOC] += me.cf[mc, t, DIVID]
    me.v[mc, t, SURPLUS_EOC] =
        me.v[mc, t, ASSET_EOC] + me.v[mc, t, TP_EOC] + me.v[mc, t, OTHER_EOC]
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

