## Constructors --------------------------------------------------

function CFlow(tf::TimeFrame, n_mc::Int)
    labels = ["QX","SX", "PX", "PREM", "C_ALL", "ASSET_EOP", "TP_EOP",
              "DIV_EOP", "SURPLUS_EOP", "BONUS", "CYCLE"]
    n = length(labels)
    v = zeros(Float64, (n_mc, tf.n_c, n ))
    CFlow(n, n_mc, tf, v, labels)
end


function bucketprojectboc!(cf::CFlow,
                           bucket::Bucket,
                           fluct::Fluct,
                           t::Int,
                           mc:: Int,
                           cost_init::Vector{Float64})
    if t == 1  bucket.lx_boc = 1  end 
    cf.v[mc,t,PREM] +=  bucket.lx_boc * bucket.cond[t,PREM]
    cost_init[1] +=
        bucket.lx_boc * fluct.fac[mc,t,fluct.d[C_INIT]] * bucket.cond[t,C_INIT]
end


function assetsprojecteoc!(cf::CFlow,
                           invest::Invest,
                           t::Int,
                           mc::Int,
                           cost_init::Vector{Float64})
    if t == 1 
        asset_BOP = invest.mv_total_init
    else
        asset_BOP = cf.v[mc,t-1,ASSET_EOP] 
    end
    asset_BOP += cf.v[mc,t,PREM] + cost_init[1]
    # project assets  until t_p (period) corresponds to t (cycle)
  #  t_p = (t-1) * cf.tf.n_dt
 #   for delta_t in 1:cf.tf.n_dt
    for t_p in ((t-1) * cf.tf.n_dt+1):(t * cf.tf.n_dt)    
 #       t_p += 1  
        project!( invest, mc, t_p, asset_BOP )
        asset_BOP = invest.mv_total_eop[mc,t_p] 
    end
end

function bucketprojecteoc!(cf::CFlow,
                           bucket::Bucket,
                           fluct::Fluct,
                           invest::Invest,
                           discount::Vector{Float64},
                           t::Int,
                           mc::Int)
    prob = Array(Float64, max(bucket.n_c, cf.tf.n_c), 3)
    ## bucket.lx (initially) represents the value at BOP
    for X in (QX,SX)
        prob[t:bucket.n_c, X] =
            fluct.fac[mc,t,fluct.d[X]] * bucket.prob_be[t:bucket.n_c, X]
    end
    prob[:,PX] = 1 .- prob[:,QX] - prob[:,SX]
    for X = (QX, SX, PX)
        cf.v[mc,t,X] += bucket.lx_boc * prob[t,X] * bucket.cond[t,X]
    end
    cf.v[mc,t,TP_EOP] +=
        bucket.lx_boc * prob[t,PX] * tpeop(prob[ t:bucket.n_c, :],
                                           discount[t:bucket.n_c],
                                           bucket.cond[ t:bucket.n_c, :])
    for C in (C_INIT, C_ABS, C_IS, C_PREM)
        cf.v[mc,t,C_ALL] +=
            bucket.lx_boc * fluct.fac[mc,t,fluct.d[C]] * bucket.cond[t,C]
    end
    ## if t == 1
    ##     cf.v[mc,t,BONUS] +=
    ##         invest.yield_total[mc, t * cf.tf.n_dt] * bucket.tp_stat_init
    ## else
    ##     cf.v[mc,t,BONUS] +=
    ##         invest.yield_total[mc, t * cf.tf.n_dt] * bucket.tp_stat[t]  
    ## end

    ## roll forward lx to the end of period: EOP
    bucket.lx_boc = bucket.lx_boc * prob[t,PX]
end
               


function surplusprojecteoc!(cf::CFlow,
                            invest::Invest,
                            dividend::Float64,
                            t::Int,
                            mc::Int,
                            cost_init::Vector{Float64})
    cf.v[mc,t,ASSET_EOP] =
        invest.mv_total_eop[mc, t * cf.tf.n_dt] + 
    cf.v[mc,t,QX] +
    cf.v[mc,t,SX] +
    cf.v[mc,t,PX] +
    cf.v[mc,t,C_ALL] - cost_init[1]
    cf.v[mc,t,DIV_EOP] =
        - dividend * max(0,
                         cf.v[mc,t,ASSET_EOP] +
                         cf.v[mc,t,TP_EOP])
    cf.v[mc,t,ASSET_EOP] += cf.v[mc,t,DIV_EOP]               
    cf.v[mc,t,SURPLUS_EOP] =
        cf.v[mc,t,ASSET_EOP] + cf.v[mc,t,TP_EOP]
end

function CFlow(buckets::Buckets,
               fluct::Fluct,
               invest::Invest,
               discount::Vector{Float64},
               dividend::Float64)
    ## buckets.tf == invest.cap_mkt.tf
    cf = CFlow(buckets.tf, invest.cap_mkt.n_mc)
    cost_init = Array(Float64,1) # 1-vector: can be passed as reference
    for mc = 1:cf.n_mc
        for t = 1:cf.tf.n_c
            cost_init[1] = 0.0
            cf.v[mc,t,CYCLE] = cf.tf.init - 1 + t
            for bucket in buckets.all
                bucketprojectboc!(cf::CFlow, bucket, fluct, t, mc, cost_init)
            end
            assetsprojecteoc!(cf,  invest, t, mc, cost_init)
            for bucket in buckets.all
                bucketprojecteoc!(cf, bucket, fluct, invest, discount, t, mc)
            end
            surplusprojecteoc!(cf, invest, dividend, t, mc, cost_init)
        end
    end
    cf
end


## Interface functions ---------------------------------------------------------

function isequal(cf1::CFlow, cf2::CFlow)
    cf1.n == cf2.n &&
    cf1.n_mc == cf2.n_mc &&
    cf1.tf == cf2.tf &&
    cf1.v == cf2.v
    # labels are constant and therefore equal for all instances of CFlow  
end


function df(cf::CFlow, mc::Int, digits::Int=1)
   ## use showall for printing to screen
   dframe = DataFrame()
#    digits = 2
    for i = 1:size(cf.v,3)
        dframe[symbol(cf.labels[i])] =
            round(reshape(cf.v[mc,:,i], size(cf.v,2)), digits)
    end
    dframe[:CYCLE] = int( dframe[:CYCLE])
    dframe
end
    
