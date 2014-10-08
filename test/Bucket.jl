using Distributions
using DataFrames
using Base.Test

using MCInsurance


get_lc_cat = function(i::Int)
  [tf.init-lc.all[i,:ph_y_birth],               # curr. age
   if lc.all[i,:ph_gender] == "M" 1 else 2 end, # gender
   lc.all[i,:ph_qx_be_name],                    # best est qx
   df_lc_prod[lc.all[i,:prod_id],:interest_name],
   lc.all[i,:risk] ]                            # risk class
end

lc_bucket = listcontracts(buckets, lc, df_lc_prod, df_lc_load)

## Test accumulation conditional cashflows and probabilities per bucket
tmp_cond = zeros(Float64,tf.n_c+1,N_COND, buckets.n)
tmp_exp_ben = zeros( Float64, tf.n_c+1, 2, buckets.n)
cond_start = zeros(Int,N_COND)
cond_end = zeros(Int,N_COND)
for b = 1:buckets.n
  for i in lc_bucket[b]
    cond_start[QX] =     lc.all[i, :c_start_QX]
    cond_start[SX] =     lc.all[i, :c_start_SX]
    cond_start[PX] =     lc.all[i, :c_start_PX]
    cond_start[PREM] =   1
    cond_start[C_BOC] =  1
    cond_start[C_DIR_EOC] =  1
    cond_end[QX] =       lc.all[i, :c_end_QX]
    cond_end[SX] =       lc.all[i, :c_end_SX]
    cond_end[PX] =       min(1000,lc.all[i, :c_end_PX])
    cond_end[PREM] =     lc.all[i, :c_end_PREM]
    cond_end[C_BOC] =    lc.all[i, :dur]
    cond_end[C_DIR_EOC] =    lc.all[i, :dur]

    delta_t_infl =  tf.init - lc.all[i, :y_start]
    prof = profile(lc,
                   i,
                   df_lc_prod,
                   loadings(df_lc_load,
                            df_lc_prod[lc.all[i, :prod_id],:cost_be_name]),
                   delta_t_infl)
    cond_cf_b = condcf(lc.all[i,:is], lc.all[i,:prem], df_lc_prod, prof)
    lc_start = lc.all[i, :y_start]
    for yr = tf.init:(tf.final-1)
      for j = 1:N_COND
        if ((lc_start+cond_start[j]-1 <= yr)
            & (lc_start+cond_end[j]-1 >= yr)
            & (lc_start <= yr))
          tmp_cond[yr-tf.init+1,j,b] += cond_cf_b[yr-lc_start+1,j]

          if j == QX
            tmp_exp_ben[yr-tf.init+1, QX,b] +=
              df_lc_qx[yr-lc.all[i, :ph_y_birth]+1,
                       symbol(lc.all[i, :ph_qx_be_name])] *
                cond_cf_b[yr- lc_start+1, QX]
          elseif j == SX
            tmp_exp_ben[yr-tf.init+1, SX,b] +=
              MCInsurance.probsxraw(lc,i,df_lc_prod)[yr-lc_start+1]*
                cond_cf_b[yr-lc_start+1,SX] *
                  lc.all[i, :f_sx_ie]
          end
        end
      end
    end
  end
  for t = 1:(tf.n_c), j = 1:N_COND
    ## Conditional cashflows are correct
    @test_approx_eq_eps(tmp_cond[t,j,b],
                        buckets.all[b].cond[t,j],
                        tol)
    if j in [QX,SX]
      ## Test that expected QX, SX benefits coincide
      #           println("$j $b $t $(buckets.all[b].prob_ie[t,j])")
      #          println("$(buckets.all[b].cat)")
      #         println("$(lc_bucket[b])")
      @test_approx_eq_eps(tmp_exp_ben[t,j,b],
                          buckets.all[b].cond[t,j] * buckets.all[b].prob_ie[t,j],
                          tol)
    end
  end
end


## Test that technical provisions calculated from buckets coincide with
## individual calculation, if for the averaging of sx is accounted for. --------

interest = 0.05
disc = exp(-interest) * ones(Float64, 200)
tpg = zeros(Float64,lc.age_max+1, buckets.n)
tpg_lc = zeros(Float64, lc.age_max+1, lc.n)

# Technical provisions per bucket
for b = 1:buckets.n
  b_n_c = buckets.all[b].n_c
  prob_b = Array(Float64, max(b_n_c, tf.n_c), 3 )
  for t = 1:b_n_c
    #   if t >
    for X in (QX,SX)
      prob_b[ t:b_n_c, X] = buckets.all[b].prob_ie[t:b_n_c, X]
    end
    prob_b[:,PX] = 1 .- prob_b[:,QX] - prob_b[:,SX]
    tpg[t,b] = tpgeoc(prob_b[t:b_n_c,:],
                      disc[t:b_n_c],
                      buckets.all[b].cond[t:b_n_c,:])
  end
end

# Technial provisions per contract, where we replace sx with the averaged
# sx over the corresponding bucket.
delta = Array(Int, lc.n) # delta between y_start of i and  smallest y_start
# in the same bucket
cond_cf = Array(Array{Float64,2}, lc.n) # conditional cashflows
ssx =  Array(Array{Float64,1}, lc.n)    # true sx probs before averaging

for b = 1:buckets.n
  qx_be_name = buckets.all[b].cat[3]
  new_bucket=true
  # In order to calculate the average SX we need to synchronize
  # the contracts in bucket b
  # lc 1: ......|----------------------------|........
  # lc 2: ...........|--------------|.................
  # lc 3: ..|----------------------------|............
  # delta:  0   4    9
  y_first = Inf
  for i in lc_bucket[b]
    y_first = int(min(y_first,lc.all[i, :y_start]))
  end
  for i in lc_bucket[b]
    delta[i] = lc.all[i, :y_start] - y_first

    delta_t_infl =  tf.init - lc.all[i, :y_start]
    prof = profile(lc,
                   i,
                   df_lc_prod,
                   loadings(df_lc_load,
                            df_lc_prod[lc.all[i, :prod_id],:cost_be_name]),
                   delta_t_infl)
    cond_cf[i] = condcf(lc.all[i,:is], lc.all[i,:prem], df_lc_prod, prof)
    ssx[i] =  MCInsurance.probsxraw(lc, i, df_lc_prod) * lc.all[i, :f_sx_ie]
  end
  ## calculate average sx for bucket
  prob_sx = zeros(Float64,2*lc.age_max)
  for t = 1:(2*lc.age_max)
    weight_sx = 0
    for i in lc_bucket[b]
      if ((t - delta[i]) >= 1) &
          (t-delta[i] <= lc.all[i, :dur])
        prob_sx[t] +=  ssx[i][t-delta[i]] * cond_cf[i][t-delta[i],SX]
        weight_sx += cond_cf[i][t-delta[i],SX]
      end
    end
    prob_sx[t] = prob_sx[t]/min(-eps(),weight_sx)
  end
  ## process all contracts in bucket
  for i in lc_bucket[b]
    age_range = lc.all[i,:ph_age_start] .+ [0:lc.all[i,:dur] - 1]
    prob_lc = Array(Float64, lc.all[i, :dur], 3)
    prob_lc[:,QX] =  df_lc_qx[age_range .+ 1, qx_be_name]
    for tau = 1:lc.all[i, :dur]
      prob_lc[tau,SX] = prob_sx[tau+delta[i]]
    end
    prob_lc[:,PX] = 1 .- prob_lc[:,QX] - prob_lc[:,SX]
    if i==4 (x=prob_lc) end
    for tau = 1:lc.all[i, :dur]
      tpg_lc[tau,i] = tpgeoc(prob_lc[tau:lc.all[i, :dur],:],
                             disc[tau:lc.all[i,:dur]],
                             cond_cf[i][tau:lc.all[i, :dur],:])
    end
  end
end

# test that the technical provisions calculated above coincide

for t = 1:lc.age_max
  for b = 1:buckets.n
    tmp_tpg = 0
    for i in lc_bucket[b]
      tau = t+(tf.init-lc.all[i, :y_start])
      if (tau > 0) & (tau <= lc.age_max)
        tmp_tpg += tpg_lc[tau,i]
      end
    end
    @test_approx_eq_eps(tpg[t,b], tmp_tpg, tol)
  end
end


## Test that future contracts are not processed --------------------------------
nf_lc_all = lc.all[lc.all[ :y_start] .<= tf.init,:]
nf_lc = LC(nrow(nf_lc_all), lc.age_min, lc.age_max, nf_lc_all)
nf_buckets = Buckets(nf_lc, tf, df_lc_prod, df_lc_load, df_lc_qx, df_lc_interest)
@test nf_buckets == buckets


## Test whether adding new contracts only works --------------------------------
new_lc_all = lc.all[lc.all[ :y_start] .== tf.init,:]
new_lc = LC(nrow(new_lc_all), lc.age_min, lc.age_max, new_lc_all)
new_buckets_direct =
  Buckets(new_lc, tf, df_lc_prod, df_lc_load, df_lc_qx, df_lc_interest)

new_buckets = Buckets(tf)
for i in 1:lc.n
  add!(new_buckets, 1, lc, i,df_lc_prod, df_lc_load,
       df_lc_qx, df_lc_interest, false)
end
@test new_buckets_direct == new_buckets
