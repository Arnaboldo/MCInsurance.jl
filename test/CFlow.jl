using Distributions
using DataFrames
using Base.Test

using MCInsurance

n_cf = 6 # QX, SX, PX, PREM, C_BOC, C_EOC


tst_discount = Array(Float64, buckets.n_c)

for mc = 1:n_mc
  tmp_tpg = zeros(Float64, tf.n_c)
  tmp_cf = zeros(Float64, tf.n_c, n_cf)
  for b = 1:buckets.n
    prob_b = Array(Float64, buckets.all[b].n_c, 3 )
    lx_boc = 1
    for t = 1:tf.n_c
      tst_discount =
        meancumdiscrf(invest.c, invest.c.yield_rf_eoc[mc,t], buckets.n_c)

      yield = 0.0
      for t_p in ((t-1) * tf.n_dt+1):(t * tf.n_dt)
        yield += invest.yield_total[mc, t_p]
      end
      dyn.alloc!(mc, t, invest, dyn)
      buckets.all[b].bonus_rate =
        dyn.bonusrate( mc, t,  buckets.all[b], invest, dyn)
      prob_b[t:buckets.all[b].n_c, QX] =
        fluct.fac[mc, t, QX] *
          buckets.all[b].prob_be[t:buckets.all[b].n_c, QX]
      prob_b[t:buckets.all[b].n_c, SX] =
        dyn.probsx(mc, t, buckets.all[b], invest,  fluct, dyn)
      prob_b[:,PX] = 1 .- prob_b[:,QX] - prob_b[:,SX]

      # accumulate technical provisions

      tmp_tpg[t] +=  lx_boc * prob_b[t,PX] *
        tpgeoc(prob_b[t:buckets.all[b].n_c,:],
               tst_discount[t:buckets.all[b].n_c],
               buckets.all[b].cond[t:buckets.all[b].n_c,:])
      # accumulate cashflows
      tmp_cf[t,QX] += lx_boc * prob_b[t,QX] * buckets.all[b].cond[t,QX]
      tmp_cf[t,SX] += lx_boc * prob_b[t,SX] * buckets.all[b].cond[t,SX]
      tmp_cf[t,PX] += lx_boc * prob_b[t,PX] * buckets.all[b].cond[t,PX]
      tmp_cf[t,PREM] += lx_boc * buckets.all[b].cond[t,PREM]
      tmp_cf[t,C_BOC] += lx_boc * buckets.all[b].cond[t,C_BOC]
      tmp_cf[t,C_EOC] += lx_boc * buckets.all[b].cond[t,C_EOC]
      lx_boc = lx_boc * prob_b[t,PX]
    end
  end
  for t = 1:tf.n_c
    ## Test that technical provisions are correct --------------------------
    @test_approx_eq_eps(tmp_tpg[t], cflow.v[mc,t,TPG_EOC], tol)
    ## Test that conditional cashflows are condensed correctluy ------------
    for j = 1:n_cf
      #print("j:  $j,   $(cflow.labels[j]) ")
      @test_approx_eq_eps(tmp_cf[t,j], cflow.cf[mc,t,j], tol)
    end
    ## for j = 1:cflow.n_v
    ##     #print("j:  $j,   $(cflow.labels[j]) ")
    ##     @test_approx_eq_eps(tmp_cf[t,j], cflow.v[mc,t,j], tol)
    ## end
  end

end

## Test that surplus is the sum of assets and (negative) technical provisions
## (after dividends have been paid)
test_cflow_surplus = 0
for mc = 1:n_mc
  for b = 1:buckets.n
    for t = 1:tf.n_c
      @test_approx_eq_eps(cflow.v[mc,t,SURPLUS_EOC],
                          cflow.v[mc,t,ASSET_EOC] + cflow.v[mc,t,TPG_EOC],
                          tol)
    end
  end
end
