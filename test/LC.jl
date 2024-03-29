using Distributions
using DataFrames
using Base.Test

using MCInsurance

## Test that ph data have correctly been joined to lc: -------------------------
for i = 1:lc.n
  for col in names(df_lc_ph)
    @test lc.all[i,col] == df_lc_ph[lc.all[i, :ph_id],col]
  end
end


#-------------------------------

sx_dur = function(i::Int)
  ## born on January 1st, 0:00h; contract ends December 31st
  ## otherwise no +1 (and a more complicated time model)
  if ( (lc.all[i, :c_start_SX] == 0) | (lc.all[i, :c_end_SX] == 0) )
    return 0
  else
    return lc.all[i, :c_end_SX] - lc.all[i, :c_start_SX] + 1
  end
end

## Test sx-probabilities -------------------------------------------------------
msg_sx =
  "Test that sx-probabilities have been calculated correctly " *
  "1: first value correct, 2: linear, 3: last value correct"
  test_sx = zeros(Float64,lc.n,3)
msg_prof = "Test that benefit-premium profile is correct"
test_prof = zeros(Float64, lc.n, 4)

for i in 1:lc.n
  if sx_dur(i) != 0
    # First sx-value is correct
    @test_approx_eq_eps(df_lc_prod[lc.all[i, :prod_id], :start_SX],
                        MCInsurance.probsxraw(lc,i,df_lc_prod)[1],
                        tol)
    # Last sx-value is correct
    if sx_dur(i) > 1 # sx_dur = 1: we take first value regardless of last value
      @test_approx_eq_eps(df_lc_prod[lc.all[i, :prod_id], :end_SX],
                          MCInsurance.probsxraw(lc,i,df_lc_prod)[sx_dur(i)],
                          tol)
    end
    # sx-values are linear
    if sx_dur(i) >=3  # we need at least 3 points to check linearity
      for d = 3:sx_dur(i)
        @test_approx_eq_eps(MCInsurance.probsxraw(lc,i,df_lc_prod)[2]-
                              MCInsurance.probsxraw(lc,i,df_lc_prod)[1],
                              MCInsurance.probsxraw(lc,i,df_lc_prod)[d]-
                                MCInsurance.probsxraw(lc,i,df_lc_prod)[d-1],
                                tol
                            )
      end
    end
  end
end

## Test benefit-premium profile ------------------------------------------------
for i in 1:lc.n
  prod_id = lc.all[i, :prod_id]
  dur = lc.all[i, :dur]
  prob_sx = zeros(Float64, dur)
  sx_prof = zeros(Float64, dur)
  qx = df_lc_qx[:,lc.all[i, :qx_name]] ## according to age cycle
  tech_int = df_lc_interest[:,df_lc_prod[prod_id,:interest_name]]
  costs = loadings(df_lc_load, df_lc_prod[lc.all[i, :prod_id],:cost_be_name])
  prof = profile(lc, i, df_lc_prod, costs)
  for t = 1:dur
    ## check qx and px profile
    if lc.all[i,:prod_name] == :M_CB_CP
      @test_approx_eq_eps(prof[t,QX], 1, tol)
      if (t == dur)
        @test_approx_eq_eps(prof[t,PX], 1, tol)
      elseif (t < dur)
        @test_approx_eq_eps(prof[t,PX], 0, tol)
      end
    elseif lc.all[i,:prod_name] == :T_CB_CP
      @test_approx_eq_eps(prof[t,QX], 1, tol)
      @test_approx_eq_eps(prof[t,PX], 0, tol)
    elseif lc.all[i,:prod_name] == :T_DB_CP
      @test_approx_eq_eps(prof[t,QX], 1-(t-1)/(dur-1) , tol)
      @test_approx_eq_eps(prof[t,PX], 0, tol)
    elseif lc.all[i,:prod_name] == :A_CB_CP
      @test_approx_eq_eps(prof[t,QX], 0, tol)
      if (t < lc.all[i, :c_start_PX])
        @test_approx_eq_eps(prof[t,PX], 0, tol)
      else
        @test_approx_eq_eps(prof[t,PX], 1, tol)
      end
    else
      print("lc.all: $i, There is no test for " *
            " Contract type $(lc.all[i,:prod_name])" )
    end
    ## check sx profile
    if sx_dur(i) > 0
      for d = 0:(sx_dur(i)-1)
        sx_prof[lc.all[i, :c_start_SX]+d] =
          df_lc_prod[prod_id, :prof_start_SX] +
            d * (df_lc_prod[prod_id, :prof_end_SX] -
                   df_lc_prod[prod_id, :prof_start_SX]
                 ) /  max(sx_dur(i)-1, 1)
      end
    end
    @test_approx_eq_eps(prof[t,SX], sx_prof[t], tol)
    ## check prem profile
    prem_prof = [ones(Float64, lc.all[i, :c_end_PREM]),
                 zeros(Float64, dur-lc.all[i, :c_end_PREM])]
    @test_approx_eq_eps(prof[t,PREM], prem_prof[t], tol)
  end
end

msg_price = "Test that equivalence principle holds"
test_price = zeros(Float64,lc.n)
i = 1

## Test pricing by testing that the equivalence principle holds ----------------
for i = 1:lc.n
  ## On first sight the price for i==1 appears to be extremely
  ## high. This is due to the fact that absolute cost/profit
  ## loadings are so high that a lapse benefit of 90% premium
  ## sum is only sustainable at a very high premium level.
  load = loadings(df_lc_load, df_lc_prod[lc.all[i, :prod_id],:cost_price_name])
  age_range = [lc.all[i,:ph_age_start]:(lc.all[i,:ph_age_start]
                                        + lc.all[i,:dur] - 1)]
  qx = df_lc_qx[age_range .+ 1, lc.all[i, :qx_name]]
  prob_sx = MCInsurance.probsxraw(lc, i, df_lc_prod)
  px = 1 .- qx - prob_sx
  interest = convert(Array,
                     df_lc_interest[1:length(age_range),
                                    df_lc_prod[lc.all[i, :prod_id],
                                               :interest_name] ] )
  v = cumprod(exp(-interest))
  prof = profile(lc, i, df_lc_prod, load)
  prob = MCInsurance.probprice(lc, i, df_lc_prod,  df_lc_qx )
  interest = convert(Array,
                     df_lc_interest[1:lc.all[i,:dur],
                                    df_lc_prod[lc.all[i,:prod_id],
                                               :interest_name] ])
  P = price(lc.all[i,:is], df_lc_prod, prof, prob, interest)
  cum_px = 1
  tmp_equiv = -load[L_INIT_ABS]-load[L_INIT_IS] * lc.all[i,:is]
  for t = 1:length(age_range)
    ## cashflow at the beginning of period
    ## projected to the end of the period
    tmp_equiv +=
      cum_px * v[t] * exp(interest[t]) * prof[t,PREM] * P
    ## cashflow at the end of period
    tmp_equiv -=
      cum_px * v[t] * (load[L_ABS] * exp(t*load[L_INFL]) +
                         lc.all[i,:is] * load[L_IS] * exp(t*load[L_INFL]) +
                           P * prof[t,PREM] * load[L_PREM] * exp(t*load[L_INFL])
                       )
    tmp_equiv -=
      cum_px * v[t] * (px[t] * prof[t,PX] * lc.all[i,:is] +
                         qx[t] * prof[t,QX] * lc.all[i,:is]
                       )
    tmp_equiv -=
      cum_px * v[t] * prob_sx[t] * prof[t,SX] * sum(prof[1:t,PREM]) * P
    cum_px *= px[t]
  end
  @test_approx_eq_eps(tmp_equiv,0, tol)

end

## Test that technical provisions are correct ----------------------------------
for i = 1:lc.n
  tmp_tpg = zeros(Float64, lc.all[i,:dur])
  prob = Array(Float64, lc.all[i,:dur], 3)
  r = 0.03 * ones(Float64,lc.all[i,:dur])
  v = cumprod(exp(-r))

  age_range = [lc.all[i,:ph_age_start]:(lc.all[i,:ph_age_start]
                                        + lc.all[i,:dur] - 1)]
  prob[:,QX] = df_lc_qx[age_range .+ 1, lc.all[i, :qx_name]]
  prob[:,SX] = MCInsurance.probsxraw(lc, i, df_lc_prod)
  prob[:,PX] = 1 .- prob[:,QX] - prob[:,SX]
  load =  loadings(df_lc_load, df_lc_prod[lc.all[i, :prod_id],:cost_be_name])
  prof = profile(lc, i, df_lc_prod, load)
  cond_cf = condcf(lc.all[i,:is], lc.all[i,:prem], df_lc_prod, prof)

  for tau = 1:lc.all[i,:dur]
    ## Technical provisions are counted negative.
    ## Initial costs are not relevant for this calculation
    cum_px = 1
    for t = (tau+1):lc.all[i,:dur]
      tmp_tpg[tau] +=
        cum_px * exp(r[t]) * v[t] / v[tau] * cond_cf[t,PREM]
      tmp_tpg[tau] +=
        cum_px * v[t] / v[tau] * (cond_cf[t,C_DIR_EOC])
      tmp_tpg[tau] +=
        cum_px * v[t] / v[tau] *  prob[t,QX]*cond_cf[t,QX]
      tmp_tpg[tau] +=
        cum_px * v[t] / v[tau] *  prob[t,SX]*cond_cf[t,SX]
      tmp_tpg[tau] +=
        cum_px * v[t] / v[tau] *  prob[t,PX]*cond_cf[t,PX]
      cum_px *= prob[t,PX]
    end
    @test_approx_eq_eps(tmp_tpg[tau],
                        tpgeoc(prob[tau:lc.all[i,:dur],:],
                               cumprod(exp(-r)[tau:lc.all[i,:dur]]),
                               cond_cf[tau:lc.all[i,:dur],:]),
                        tol)
  end
end

