## Constructors --------------------------------------------------

function CFlow(tf::TimeFrame, n_mc::Int)
    labels =
        ["QX","SX", "PX", "PREM", "C_ALL",
         "ASSET_EOP", "TP_EOP", "DIV_EOP", "SURPLUS_EOP", "CYCLE"]
    n = length(labels)
    v = zeros(Float64, (n_mc, tf.n_c, n ))
 #   d = Dict([QX,SX,PX,PREM],[CF_QX,CF_SX,CF_PX,CF_PREM])
    CFlow(n, n_mc, tf, v, labels)
end

function CFlow(buckets::Buckets,
               fluct::Fluct,
               invest::Invest,
               discount::Vector{Float64},
               dividend::Float64)
    ## buckets.tf == invest.cap_mkt.tf
    cf = CFlow(buckets.tf, invest.cap_mkt.n_mc)

    
    for mc = 1:cf.n_mc
        #mcinit!(invest,mc)
        lx = ones(Float64, buckets.n)
        t_p = 0
        for t = 1:cf.tf.n_c
            cost_init = 0
            cf.v[mc,t,CYCLE] = cf.tf.init - 1 + t
            for b = 1:buckets.n
                prob = Array(Float64,
                             max(buckets.all[b].n_c, cf.tf.n_c),
                             3 )
                ## lx (initially) represents the value at BOP
                for X in (QX,SX)
                    prob[ t:buckets.all[b].n_c, X] =
                        fluct.fac[mc,t,fluct.d[X]] *
                        buckets.all[b].
                            prob_be[t:buckets.all[b].n_c, X]
                end
                prob[:,PX] = 1 .- prob[:,QX] - prob[:,SX]
                for X = (QX, SX, PX)
                    cf.v[mc,t,X] +=
                        lx[b] * prob[t,X] *
                        buckets.all[b].cond[t,X]
                end
                cf.v[mc,t,PREM] +=
                    lx[b] * buckets.all[b].cond[t,PREM]
                for C in (C_INIT, C_ABS, C_IS, C_PREM)
                    cf.v[mc,t,C_ALL] +=
                        lx[b] * fluct.fac[mc,t,fluct.d[C]] *
                        buckets.all[b].cond[t,C]
                end
                cost_init +=
                    lx[b] * fluct.fac[mc,t,fluct.d[C_INIT]] *
                    buckets.all[b].cond[t,C_INIT]
                cf.v[mc,t,TP_EOP] +=
                    lx[b] * prob[t,PX] * tpeop(prob[ t:buckets.all[b].n_c, :],
                                               discount[t:buckets.all[b].n_c],
                                               buckets.all[b].
                                               cond[ t:buckets.all[b].n_c, :])
                ## roll forward lx to the end of period: EOP
                lx[b] = lx[b] * prob[t,PX]
            end
            if t == 1 
                asset_BOP = invest.mv_total_init
            else
                asset_BOP = cf.v[mc,t-1,ASSET_EOP] 
            end
            asset_BOP += cf.v[mc,t,PREM] + cost_init
            # project assets  until t_p (period) corresponds to t (cycle)
            for delta_t in 1:cf.tf.n_dt
                t_p += 1  
                project!( invest, mc, t_p, asset_BOP )
                asset_BOP = invest.mv_total_eop[mc,t_p] 
            end
            cf.v[mc,t,ASSET_EOP] =
                invest.mv_total_eop[mc,t_p] +  # now t_p corresponds to t
                cf.v[mc,t,QX] +
                cf.v[mc,t,SX] +
                cf.v[mc,t,PX] +
                cf.v[mc,t,C_ALL] - cost_init
            cf.v[mc,t,DIV_EOP] =
                - dividend * max(0,
                                 cf.v[mc,t,ASSET_EOP] +
                                 cf.v[mc,t,TP_EOP])
            cf.v[mc,t,ASSET_EOP] += cf.v[mc,t,DIV_EOP]               
            cf.v[mc,t,SURPLUS_EOP] =
                cf.v[mc,t,ASSET_EOP] + cf.v[mc,t,TP_EOP]
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
        dframe[cf.labels[i]] =
            round(reshape(cf.v[mc,:,i], size(cf.v,2)), digits)
    end
    dframe["CYCLE"] = int( dframe["CYCLE"])
    dframe
end
    
