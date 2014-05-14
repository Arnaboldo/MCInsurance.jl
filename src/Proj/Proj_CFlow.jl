## Constructors --------------------------------------------------

function CFlow(tf::TimeFrame, n_mc::Int)
    labels = ["QX","SX", "PX", "PREM", "C_BOC", "C_EOC", "DELTA_TP", "BONUS",
              "DIVID", "TP_EOC", "ASSET_EOC", "SURPLUS_EOC", "CYCLE"]
    n = length(labels)
    v = zeros(Float64, (n_mc, tf.n_c, n ))
    CFlow(n, n_mc, tf, v, labels)
end

function CFlow(buckets::Buckets,
               fluct::Fluct,
               invest::Invest,
               dividend::Float64,
               dynbonusrate!::Function = defaultdynbonusrate!,
               dynprobsx::Function = defaultdynprobsx,
               dynalloc!::Function = defaultdynalloc!
              )
    ## buckets.tf == invest.cap_mkt.tf
    cf = CFlow(buckets.tf, invest.cap_mkt.n_mc)    
    for mc = 1:cf.n_mc
        for t = 1:cf.tf.n_c
            disc = meandiscrf(invest.c, invest.c.yield_rf_eoc[mc,t], buckets.n_c)                                       
            projectcycle(cf, mc, t, buckets, fluct, invest, disc, dividend,
                         dynbonusrate!, dynprobsx, dynalloc!)
        end
    end
    cf
end


## Interface functions for CFlow -----------------------------------------------

function isequal(cf1::CFlow, cf2::CFlow)
    cf1.n == cf2.n &&
    cf1.n_mc == cf2.n_mc &&
    cf1.tf == cf2.tf &&
    cf1.v == cf2.v
    # labels are constant and therefore the same for all instances of CFlow  
end

function df(cf::CFlow, mc::Int, digits::Int=1)
   ## use showall for printing to screen
   dframe = DataFrame()
    for i = 1:size(cf.v,3)
        dframe[symbol(cf.labels[i])] =
            round(reshape(cf.v[mc,:,i], size(cf.v,2)), digits)
    end
    dframe[:CYCLE] = int( dframe[:CYCLE])
    dframe
end
    
## Private functions for Cflow -------------------------------------------------

function projectcycle(cf::CFlow,
                      mc::Int,
                      t::Int, 
                      buckets::Buckets,
                      fluct::Fluct,
                      invest::Invest,
                      discount::Vector{Float64},
                      dividend::Float64,
                      dynbonusrate!::Function,
                      dynprobsx::Function,
                      dynalloc!::Function)
    cf.v[mc,t,CYCLE] = cf.tf.init - 1 + t
    for bucket in buckets.all
        bucketprojectboc!(cf::CFlow, bucket, fluct, mc, t)
    end
    assetsprojecteoc!(cf, invest, mc, t, dynalloc!)
    for bucket in buckets.all
        bucketprojecteoc!(cf, bucket, fluct, invest, discount, mc, t,
                          dynbonusrate!, dynprobsx)
    end
    if t == 1
       cf.v[mc,t, DELTA_TP]  += cf.v[mc, t, TP_EOC]  
    else
       cf.v[mc,t, DELTA_TP] =  cf.v[mc, t, TP_EOC] - cf.v[mc, t-1, TP_EOC]
    end
    surplusprojecteoc!(cf, invest, dividend, mc, t)
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
                           dynalloc!::Function)
    if t == 1 
        asset_BOC = invest.mv_total_init
    else
        asset_BOC = cf.v[mc,t-1,ASSET_EOC] 
    end
    asset_BOC += cf.v[mc,t,PREM] + cf.v[mc,t,C_BOC]
    for t_p in ((t-1) * cf.tf.n_dt+1):(t * cf.tf.n_dt)
        dynalloc!(invest, mc, t)
        project!( invest, mc, t_p, asset_BOC)
        asset_BOC = invest.mv_total_eop[mc,t_p]
    end
end

function bucketprojecteoc!(cf::CFlow,
                           bucket::Bucket,
                           fluct::Fluct,
                           invest::Invest,
                           discount::Vector{Float64},
                           mc::Int,
                           t::Int,
                           dynbonusrate!::Function,
                           dynprobsx::Function)
    prob = Array(Float64, max(bucket.n_c, cf.tf.n_c), 3)
    ## bucket.lx (initially) represents the value at BOP
    dynbonusrate!(bucket, mc, t, invest)
    prob[t:bucket.n_c, QX] =
        fluct.fac[mc, t, QX] * bucket.prob_be[t:bucket.n_c, QX]
    prob[t:bucket.n_c, SX] = dynprobsx(bucket, fluct, mc, t, invest)
    prob[:,PX] = 1 .- prob[:,QX] - prob[:,SX]
    for X = (QX, SX, PX)
        cf.v[mc,t,X] += bucket.lx_boc * prob[t,X] * bucket.cond[t,X]
    end
    cf.v[mc,t,C_EOC] +=
        bucket.lx_boc * fluct.fac[mc,t,fluct.d[C_EOC]] * bucket.cond[t,C_EOC]
    cf.v[mc,t,TP_EOC] +=
        bucket.lx_boc * prob[t,PX] * tpeoc(prob[ t:bucket.n_c, :],
                                           discount[t:bucket.n_c],
                                           bucket.cond[ t:bucket.n_c, :])
    ## print("mc: $mc, t: $t, discount: $(round(discount[t],3)), ")
    ## tptemp = tpprev(cf.v[mc,t,TP_EOC],
    ##                 reshape(prob[t,:], 3),
    ##                 discount[t],
    ##                 reshape(bucket.cond[t,:], N_COND))
    ## println("TPEOC: $(round(cf.v[mc,t,TP_EOC],1)), TPBOC: $(round(tptemp,1))")
    ## println(round(reshape(prob[t,:], 3),4))
    ## println(round(reshape(bucket.cond[t,:], N_COND),4))
    if t == 1
        cf.v[mc,t, DELTA_TP] -= prob[t,PX] * bucket.tp_be_init # completed later
        cf.v[mc,t,BONUS] += bucket.bonus_rate * bucket.tp_stat_init
    else
        ## cf.v[mc,t, DELTA_TP] is calculated later
        cf.v[mc,t,BONUS] +=  bucket.bonus_rate * bucket.tp_stat[t-1] 
    end
    ## roll forward lx to the end of period: EOC
    bucket.lx_boc = bucket.lx_boc * prob[t,PX]
end              


function surplusprojecteoc!(cf::CFlow,
                            invest::Invest,
                            dividend::Float64,
                            mc::Int,
                            t::Int)
    cf.v[mc,t,ASSET_EOC] =
        invest.mv_total_eop[mc, t * cf.tf.n_dt]
    for j in [QX, SX, PX, C_EOC, BONUS]
        cf.v[mc,t,ASSET_EOC] += cf.v[mc, t, j]
    end
    cf.v[mc, t, DIVID] =
        - dividend * max(0, cf.v[mc, t, ASSET_EOC] + cf.v[mc, t, TP_EOC])
    cf.v[mc, t, ASSET_EOC] += cf.v[mc, t, DIVID]               
    cf.v[mc, t, SURPLUS_EOC] = cf.v[mc, t, ASSET_EOC] + cf.v[mc, t, TP_EOC]
end

function defaultdynbonusrate!(bucket::Bucket, mc::Int, t::Int, invest::Invest)
   bucket.bonus_rate = 0.0
end

function defaultdynprobsx(sx::Vector{Float64}, mc...)
    return sx
end

function defaultdynalloc!(invest::Invest, mc...)
    invest.alloc.asset_target = invest.alloc.asset_target_std
    invest.alloc.ig_target = invest.alloc.ig_target_std
end

