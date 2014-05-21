using Distributions
using DataFrames
using Base.Test

using MCInsurance

import MCInsurance.Dynamic

tol = 1e-8  # Testing tolerance for floating points

df_general = readtable(joinpath(dirname(@__FILE__), "input/General.csv"))
df_capmkt_1 = readtable(joinpath(dirname(@__FILE__), "input/CapMkt_1.csv"))
df_capmkt_2 = readtable(joinpath(dirname(@__FILE__), "input/CapMkt_2.csv"))
df_inv_inv = readtable(joinpath(dirname(@__FILE__), "input/Inv_Inv.csv"))
df_inv_asset = readtable(joinpath(dirname(@__FILE__), "input/Inv_Asset.csv"))
df_inv_init = readtable(joinpath(dirname(@__FILE__), "input/Inv_Init.csv"))
df_lc_interest = readtable(joinpath(dirname(@__FILE__), "input/LC_Interest.csv"))
df_lc_qx = readtable(joinpath(dirname(@__FILE__), "input/LC_QX.csv"))
df_lc_load = readtable(joinpath(dirname(@__FILE__), "input/LC_Load.csv"))
df_lc_prod = readtable(joinpath(dirname(@__FILE__), "input/LC_Prod.csv"))
df_lc_ph = readtable(joinpath(dirname(@__FILE__), "input/LC_PH.csv"))
df_lc_lc = readtable(joinpath(dirname(@__FILE__), "input/LC_LC.csv"))
df_proj_fluct = readtable(joinpath(dirname(@__FILE__), "input/Proj_Fluct.csv"))

## convert references from string to symbol
df_lc_lc[:prod_name] = convert(DataArray{Symbol,1}, df_lc_lc[:prod_name])
df_lc_load[:name] = convert(DataArray{Symbol,1}, df_lc_load[:name])
for col in (:name, :cost_name, :cost_be_name, :qx_name, :interest_name)
    df_lc_prod[col] = convert(DataArray{Symbol,1}, df_lc_prod[col])
end
for col in (:ph_gender, :ph_qx_be_name)
    df_lc_ph[col] = convert(DataArray{Symbol,1}, df_lc_ph[col])
end

tmp = Dynamic(df_general)


function Dynamic(invest::Invest, df_general::DataFrame)
    me = Dynamic(df_general)
    ## Dynamic policy behavior -------------------------------------------------
    function dynprobsx(mc::Int,
                       t::Int,
                       bucket::Bucket,
                       invest::Invest,
                       fluct::Fluct,
                       dyn::Dynamic
                       )
        delta = 1.0
        state_econ_quotient =
            (invest.c.yield_mkt_eoc[mc,t]/max(eps(),invest.c.yield_rf_eoc[mc,t])-1)/
        (invest.hook.yield_mkt_init/ max(eps(),invest.hook.yield_rf_init) - 1)
        
        if state_econ_quotient < 0.5
            delta += 0.15
        elseif  state_econ_quotient > 2.0
            delta -= 0.15
        end
        bonus_rate_init = dynbonusrate(t,
                                       bucket.hook.statinterest(bucket,t),
                                       dyn.bonus_factor,
                                       invest.alloc.ig_target_std[invest.id[:cash]],
                                       invest.hook.yield_mkt_init)
        bi_quotient =
            (invest.c.yield_mkt_eoc[mc,t] /
             max(eps(), bucket.hook.bonus_rate + invest.c.yield_rf_eoc[mc,t])) /
        (invest.hook.yield_mkt_init /
         max(eps(), bonus_rate_init + invest.hook.yield_rf_init)) 
        

        delta += 0.25 * min(4.0, max(0.0, bi_quotient - 1.2))
        
        return  min(1.0,
                    fluct.fac[mc, t, SX] * delta *
                    bucket.prob_be[t:bucket.n_c, SX])
    end

    ## Dynamic asset allocation ------------------------------------------------
    function dynalloc!(mc::Int, t::Int, invest::Invest, dyn::Dynamic)
        ## cash allocation is chosen dependent on market performance
        ## all other investments / assets are adjusted proportionally
        ## In-place computation for higher efficiency
        if t > 1 # allocation is boc.  For t= 1 we use original allocation
            ## market performance indicator weighted with expected yield
            mkt_perf_ind = 0.5 * (invest.c.yield_mkt_eoc[mc,t-1] +
                                  invest.hook.exp_yield_market) /
            max(0, invest.c.yield_rf_eoc[mc,t-1])

            alloc_cash = 1 - 0.5 * (1 - exp( - max(1, mkt_perf_ind) + 1))

            ## Now we adjust all allocations accordingly
            total_other = 1 - invest.alloc.ig_target_std[invest.id[:cash]]
            fac_other = (1-alloc_cash) / max(eps(), total_other)
            for i = 1:invest.n
                if invest.ig[i].name == :cash
                    invest.alloc.ig_target[i] = alloc_cash
                else
                    invest.alloc.ig_target[i] =
                        fac_other * invest.alloc.ig_target_std[i]
                end
            end
        end
    end

    ## Dynamic bonus declaration -----------------------------------------------    
    function   dynbonusrate(mc::Int,
                            t::Int,
                            bkt::Bucket,
                            invest::Invest,
                            dyn::Dynamic)
        return  dynbonusrate(t,
                              bkt.hook.statinterest(bkt,t),
                              dyn.bonus_factor,
                              invest.alloc.ig_target[invest.id[:cash]],
                              invest.c.yield_mkt_eoc[mc,t])
    end
    ##||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    function   dynbonusrate(t::Int,
                            stat_interest::Float64,
                            bonus_factor::Float64,
                            cash_target::Float64,
                            yield_mkt_eoc::Float64)
        return (bonus_factor * (1-cash_target) *
                max(0, yield_mkt_eoc - stat_interest))
    end

    ## Dynamic dividend declaration --------------------------------------------
    function dyndividend(mc::Int,
                         t::Int,
                         invest::Invest,
                         cf::CFlow,
                         dyn::Dynamic)
        return -dyn.capital_dividend *
               max(0, cf.v[mc, t, ASSET_EOC] + cf.v[mc, t, TP_EOC])
    end

    ## Dynamic expense ---------------------------------------------------------
    function dynexpense(mc::Int,
                        t::Int,
                        invest::Invest,
                        cf::CFlow,
                        dyn::Dynamic)
        return 0
    end
    ## -------------------------------------------------------------------------
    me.probsx = dynprobsx
    me.alloc! = dynalloc!
    me.bonusrate = dynbonusrate
    me.dividend = dyndividend
    me.expense = dynexpense
    return me
end
##------------------------------------------------------------------------------


srand(df_general[1, :random_seed])

n_mc     = df_general[1, :n_mc]
tf       = TimeFrame(df_general[1, :tf_y_start], df_general[1, :tf_y_end],
                     df_general[1, :tf_n_dt] *
                     (df_general[1, :tf_y_end]-df_general[1, :tf_y_start]))
cap_mkt  = CapMkt(:cap_mkt_rn, tf, n_mc, df_capmkt_1, df_capmkt_2)
cap_mkt_det  = CapMkt(:cap_mkt_det, tf, 1, df_capmkt_1, df_capmkt_2)

invest = Invest(:invest_rn, cap_mkt, df_general,
                df_inv_inv, df_inv_init, df_inv_asset)
invest_det = Invest(:invest_det, cap_mkt_det,
                    df_general, df_inv_inv, df_inv_init, df_inv_asset)
## Customize Invest:
type InvestHook
    bonus_factor::Float64
    exp_yield_market::Float64 ## with respect to risk-neutral probabilities
    yield_mkt_init::Float64
    yield_rf_init::Float64
end
invest.hook = InvestHook(df_general[1, :bonus_factor],
                         0.03,
                         invest_det.c.yield_mkt_eoc[1,1], ## approx only
                         invest_det.c.yield_rf_eoc[1,1])  ## approx only
discount_be = meandiscrf(invest.c, invest.c.yield_rf_eoc[1,1], 125)


lc       = LC(df_lc_lc, df_lc_ph, df_lc_prod, df_lc_load,
              df_lc_qx, df_lc_interest, tf)

buckets  = Buckets(lc, tf, df_lc_prod, df_lc_load, df_lc_qx, df_lc_interest,
                   discount_be)

## customize Bucket:
type BucketHook
    statinterest::Function
    bonus_rate::Float64
end
getstatinterest(me::Bucket, t::Int) = df_lc_interest[t, me.cat[CAT_INTEREST]]
for b = 1:buckets.n
    buckets.all[b].hook = BucketHook(getstatinterest, 0.0)
end
dividend = df_general[1, :capital_dividend]

fluct    = Fluct(tf, n_mc, 1.0)
expense = Any[false]

dyn = Dynamic(invest, df_general)
cflow    = CFlow(buckets, fluct, invest, dividend, expense, dyn)
          #       dynbonusrate, dynprobsx, dynalloc!, dyndividend, dynexpense)

##------------------------------------------------------------------------------


