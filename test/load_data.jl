using Distributions
using DataFrames
using Base.Test

using MCInsurance

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

df_lc_lc[:prod_name] = convert(DataArray{Symbol,1}, df_lc_lc[:prod_name])
df_lc_load[:name] = convert(DataArray{Symbol,1}, df_lc_load[:name])
for col in (:name, :cost_name, :cost_be_name, :qx_name, :interest_name) 
    df_lc_prod[col] = convert(DataArray{Symbol,1}, df_lc_prod[col])
end
for col in (:ph_gender, :ph_qx_be_name)
    df_lc_ph[col] = convert(DataArray{Symbol,1}, df_lc_ph[col])
end


## Dynamic policy behavior -----------------------------------------------------
function dynprobsx(bucket::Bucket,
                   fluct::Fluct,
                ##   sx::Vector{Float64},
                   mc::Int,
                   t::Int,
                   invest::Invest, 
                   #bonus_rate::Float64
                   )
    if invest.c.yield_mkt_eoc[mc,t]/max(eps(),invest.c.yield_rf_eoc[mc,t]) < 1.1
        delta = 0.1
    else
        delta = 0.0
    end
    si = invest.c.yield_mkt_eoc[mc,t] /
         max(eps(), bucket.hook.bonus_rate + invest.c.yield_rf_eoc[mc,t])

    return  fluct.fac[mc, t, SX] * bucket.prob_be[t:bucket.n_c, SX] .+
            (delta + 0.05 * min(6,max(0, si - 1.4)))
 end

## Dynamic asset allocation ----------------------------------------------------
function dynalloc!(invest::Invest, mc::Int, t::Int)
    ## cash allocation is chosen dependent on market performance
    ## all other investments / assets are adjusted proportionally
    ## In-place computation for higher efficiency

   ## market performance indicator weighted with expected yield
   mkt_perf_ind =
       0.5 * (invest.c.yield_mkt_eoc[mc,t] + invest.hook.exp_yield_market) /
       max(0, invest.c.yield_rf_eoc[mc,t])
    
   alloc_cash = 1 - 0.5 * (1 - exp( - max(1, mkt_perf_ind) + 1))

    ## Now we adjust all allocations accordingly
   total_other = 1 - invest.alloc.ig_target_std[invest.id[:cash]]
   fac_other = (1-alloc_cash) / max(eps(), total_other)
    for i = 1:invest.n
      if invest.ig[i].name == :cash
          invest.alloc.ig_target[i] = alloc_cash
      else
          invest.alloc.ig_target[i] = fac_other * invest.alloc.ig_target_std[i]
      end
   end
end

## Dynamic bonus declaration ---------------------------------------------------
function   dynbonusrate!(bucket::Bucket,
                        mc::Int,
                        t::Int,
                        invest::Invest)
    bucket.bonus_rate = 
        invest.hook.bonus_factor *
        (1-invest.alloc.ig_target[invest.id[:cash]]) *
        max(0, invest.c.yield_mkt_eoc[mc,t] - bucket.hook.statinterest(bucket,t))
end

##------------------------------------------------------------------------------
srand(df_general[1, :random_seed])

n_mc     = df_general[1, :n_mc]
tf       = TimeFrame(df_general[1, :tf_y_start], df_general[1, :tf_y_end],
                     df_general[1, :tf_n_dt] *
                     (df_general[1, :tf_y_end]-df_general[1, :tf_y_start]))
cap_mkt  = CapMkt(:Capital_Market, tf, n_mc, df_capmkt_1, df_capmkt_2)
invest = Invest(:iii, cap_mkt, df_general, df_inv_inv, df_inv_init, df_inv_asset)
## Customize Invest:
type InvestHook
    bonus_factor::Float64
    exp_yield_market::Float64
end
invest.hook = InvestHook(df_general[1, :bonus_factor], 0.03)
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
cflow    = CFlow(buckets, fluct, invest, dividend,
                 dynbonusrate!, dynprobsx, dynalloc!)

##------------------------------------------------------------------------------


