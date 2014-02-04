using Distributions
using DataFrames
using Base.Test
using MCInsurance

# -----------------------------------------------------------------------------

mv_bop = Float64[10.0 * t for t = 1:tf.n_p]
for mc = 1:n_mc
    for t = 1:tf.n_p
        project!(invest,mc,t,mv_bop[t])
    end
end

# -----------------------------------------------------------------------------

i_bonds, i_stocks, i_cash = 1:3

inv_info = Array(InvestInfo, nrow(df_inv))
for i = 1:nrow(df_inv)
    inv_info[i] = InvestInfo(ascii(df_inv[i, "ig_name"]),
                             df_inv, df_inv_port_start, df_inv_target)
end

## Test asset allocation for each investment group: 1 = sum(asset_target[i]) ---
for j in 1:invest.n
    @test_approx_eq_eps(sum(invest.asset_target[j]), 1, tol)
end

## Test asset allocation for all investment groups: 1 = sum(ig_target) ---------
@test_approx_eq_eps(sum(invest.ig_target), 1, tol)

## Test that for each investment group:
##  mv_total_eop[mc,t] = cash_eop[mc,t] +sum(ig.mv_eop[mc,t,:]) ----------------
test_total_mv_ig = zeros(Float64,n_mc,tf.n_p,invest.n)
for j in 1:invest.n
    test_total_mv_ig[:,:,j] += invest.ig[j].cash_eop
    for i = 1:invest.ig[j].n
       test_total_mv_ig[:,:,j] +=  invest.ig[j].mv_eop[:,:,i]
    end
    test_total_mv_ig[:,:,j] -= invest.ig[j].mv_total_eop
    for mc = 1:n_mc, t = 1:tf.n_p
        @test_approx_eq_eps(test_total_mv_ig[mc,t,j], 0, tol)
    end
end

## Test invest.mv_total_eop is the sum of ig[:].mv_total_eop -------------------
for mc = 1:n_mc, t= 1:tf.n_p
    tmp_total_mv = 0
    for j = 1:invest.n
        tmp_total_mv += invest.ig[j].mv_total_eop[mc,t]
    end
    @test_approx_eq_eps(tmp_total_mv, invest.mv_total_eop[mc,t], tol)
end

## Test cash mv projection -----------------------------------------------------
for mc = 1:n_mc, t = 1:tf.n_p
    @test_approx_eq_eps(invest.ig[i_cash].mv_total_eop[mc,t],
                        invest.ig_target[i_cash] *
                        invest.asset_target[i_cash][1] *
                        mv_bop[t] *
                        exp(tf.dt*invest.ig[i_cash].proc.yield[mc,t,1]),
                        tol)  
end

## Test stocks mv projection ---------------------------------------------------
test_mv_stocks = zeros(Float64,n_mc, tf.n_p,invest.ig[i_stocks].n)
for  mc = 1:n_mc, t = 1:tf.n_p, j = 1:invest.ig[i_stocks].n
    @test_approx_eq_eps(invest.ig[i_stocks].mv_eop[mc,t,j],                       
                        invest.ig_target[i_stocks] *
                        invest.asset_target[i_stocks][j] *
                        mv_bop[t] *
                        exp(tf.dt * invest.ig[i_stocks].proc.yield[mc,t,j]),
                        tol)
end

## Test bond projection --------------------------------------------------------

## Re-initialize because order of calculation is important for testing bonds
inv_new = Invest("iii", cap_mkt, df_inv, df_inv_port_start, df_inv_target)

ig_bonds = inv_new.ig[i_bonds]

## Test initial mv for largest duration 

tau = ig_bonds.n

value_coup = sum(ig_bonds.amount_init[tau] *
                 ig_bonds.coupon_init[tau] *
                 exp( - tf.dt * [1:tau] .* ig_bonds.riskfree_bop[1:tau]) )
value_mat =
    ig_bonds.amount_init[tau] * exp(-tf.dt * tau * ig_bonds.riskfree_bop[tau])
@test_approx_eq_eps( ig_bonds.mv_init[tau], value_coup+value_mat, tol)

## Other bond tests

amount_new =   zeros(Float64, ig_bonds.n)
amount_old =   zeros(Float64, ig_bonds.n)

tmp_amount = zeros(Float64, n_mc, tf.n_p, ig_bonds.n)
tmp_coupon = zeros(Float64, n_mc, tf.n_p, ig_bonds.n)

for mc in 1:n_mc
    for t in  1:tf.n_p
        ig_bonds.mv_alloc_bop =
            mv_bop[t]*inv_new.ig_target[i_bonds]*inv_new.asset_target[i_bonds]
        if t == 1 MCInsurance.init!(ig_bonds,mc) end
        amount_old = min(ig_bonds.amount_curr,
                          ig_bonds.mv_alloc_bop ./ ig_bonds.mv_normbond_curr)
        amount_new =
            max( 0,
                ig_bonds.mv_alloc_bop - amount_old .* ig_bonds.mv_normbond_curr)
        ## Test bonds: check split in old / new nominal value
        @test_approx_eq_eps(sum(amount_old .* ig_bonds.mv_normbond_curr) +
                            sum(amount_new),
                            sum(ig_bonds.mv_alloc_bop),
                            tol)
        MCInsurance.reallocbop!(ig_bonds, mc, t)
        MCInsurance.mvnormbond!(ig_bonds)
        ## Test bonds: check that average coupon is correct
        @test_approx_eq_eps(sum((amount_old+amount_new) .*
                                ig_bonds.mv_normbond_curr),
                            sum(ig_bonds.mv_alloc_bop),
                            tol)
        ## Test bonds: Check that nominal values age correctly
        for j in 1:ig_bonds.n-1
            tmp_amount[mc,t,j] = ig_bonds.amount_curr[j+1]
            tmp_coupon[mc,t,j] = ig_bonds.coupon_curr[j+1]
        end
        MCInsurance.riskfreebop!(ig_bonds, mc, t+1)
        MCInsurance.mvnormcf!(ig_bonds) 
        tmp_coupon[mc,t,ig_bonds.n] =
            (1-exp(- ig_bonds.proc.dt * ig_bonds.riskfree_bop[ig_bonds.n] *
                   ig_bonds.n) ) /
            ig_bonds.mv_normcf_curr[ig_bonds.n]

        MCInsurance.valeop!(ig_bonds, mc, t)
        ig_bonds.mv_total_eop[mc,t] =
            sum( ig_bonds.mv_eop[mc,t,:] ) +
             ig_bonds.cash_eop[mc,t]
        for j in 1:ig_bonds.n
           @test_approx_eq_eps(tmp_amount[mc,t,j], ig_bonds.amount_curr[j], tol)
           @test_approx_eq_eps(tmp_coupon[mc,t,j], ig_bonds.coupon_curr[j], tol)
       end
   end
end

