using Distributions
using DataFrames
using Base.Test

using MCInsurance

n_cf = 5 # QX, SX, PX, PREM, C_ALL



for mc = 1:n_mc
    tmp_tp = zeros(Float64, tf.n_c)
    tmp_cf = zeros(Float64, tf.n_c, n_cf) 
    for b = 1:buckets.n
        prob_b = Array(Float64, buckets.all[b].n_c, 3 )
        lx_boc = 1
        for t = 1:tf.n_c
            yield = 0.0
            for t_p in ((t-1) * tf.n_dt+1):(t * tf.n_dt)    
                yield += saved_yield_total[mc, t_p] ## defined in load_data.jl
            end
            bonus_rate =
                bonus_factor *
                (yield - df_tech_interest[t, buckets.all[b].cat[CAT_INTEREST]])
            prob_b[t:buckets.all[b].n_c, QX] =
                fluct.fac[mc, t, QX] *
                buckets.all[b].prob_be[t:buckets.all[b].n_c, QX]
            prob_b[t:buckets.all[b].n_c, SX] =
                dynprobsx(fluct.fac[mc, t, SX] *
                               buckets.all[b].prob_be[t:buckets.all[b].n_c, SX],
                          invest,
                          t,
                          mc,
                          bonus_rate)
            prob_b[:,PX] = 1 .- prob_b[:,QX] - prob_b[:,SX]
            # accumulate technical provisions
            tmp_tp[t] +=  lx_boc * prob_b[t,PX] *
                          tpeop(prob_b[t:buckets.all[b].n_c,:],
                                discount[t:buckets.all[b].n_c],
                                buckets.all[b].cond[t:buckets.all[b].n_c,:])
            # accumulate cashflows
            tmp_cf[t,QX] += lx_boc * prob_b[t,QX] * buckets.all[b].cond[t,QX]
            tmp_cf[t,SX] += lx_boc * prob_b[t,SX] * buckets.all[b].cond[t,SX]
            tmp_cf[t,PX] += lx_boc * prob_b[t,PX] * buckets.all[b].cond[t,PX]
            tmp_cf[t,PREM] += lx_boc * buckets.all[b].cond[t,PREM]
            tmp_cf[t,C_ALL] += lx_boc * (buckets.all[b].cond[t,C_INIT] +
                                         buckets.all[b].cond[t,C_ABS] +
                                         buckets.all[b].cond[t,C_IS] +
                                         buckets.all[b].cond[t,C_PREM])  
            lx_boc = lx_boc * prob_b[t,PX]
        end
    end
    for t = 1:tf.n_c
        ## Test that technical provisions are correct --------------------------
        @test_approx_eq_eps(tmp_tp[t], cflow.v[mc,t,TP_EOP], tol)
        ## Test that conditional cashflows are condensed correctluy ------------
        for j = 1:n_cf
            @test_approx_eq_eps(tmp_cf[t,j], cflow.v[mc,t,j], tol)
        end
    end
end

## Test that surplus is the sum of assets and (negative) technical provisions
## (after dividends have been paid)
test_cflow_surplus = 0
for mc = 1:n_mc
    for b = 1:buckets.n
        for t = 1:tf.n_c
            @test_approx_eq_eps(cflow.v[mc,t,SURPLUS_EOP],
                                cflow.v[mc,t,ASSET_EOP] + cflow.v[mc,t,TP_EOP],
                                tol)
        end
    end
end
