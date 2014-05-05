using Distributions
using DataFrames
using Base.Test

using MCInsurance

tol = 1e-8  # Testing tolerance for floating points

file_general = joinpath(dirname(@__FILE__), "input/General.csv")
file_proc_1 = joinpath(dirname(@__FILE__), "input/Proc_1.csv")
file_proc_2 = joinpath(dirname(@__FILE__), "input/Proc_2.csv")
file_inv = joinpath(dirname(@__FILE__), "input/Inv.csv")
file_inv_asset = joinpath(dirname(@__FILE__), "input/Inv_Asset.csv")
file_inv_Port_Start = joinpath(dirname(@__FILE__), "input/Inv_Port_Start.csv")
file_tech_interest = joinpath(dirname(@__FILE__), "input/Tech_Interest.csv")
file_qx = joinpath(dirname(@__FILE__), "input/QX.csv")
file_products = joinpath(dirname(@__FILE__), "input/Prod.csv")
file_ph = joinpath(dirname(@__FILE__), "input/PH.csv")
file_lc = joinpath(dirname(@__FILE__), "input/LC.csv")
file_fluct = joinpath(dirname(@__FILE__), "input/Rnd_Fluct.csv")

# General parameters
df_general = readtable(file_general)

# Capital market
df_proc_1 = readtable(file_proc_1)
df_proc_2 = readtable(file_proc_2)

# Investment strategy
df_inv = readtable(file_inv)
df_inv_asset = readtable(file_inv_asset)
df_inv_port_start = readtable(file_inv_Port_Start)

# life insurance contracts
df_tech_interest = readtable(file_tech_interest)
df_qx = readtable(file_qx)
df_products = readtable(file_products)

df_products[:interest_name] =
    [symbol(df_products[i,:interest_name]) for i=1:nrow(df_products)]
    
df_ph = readtable(file_ph)
df_ph[:ph_qx_be_name] =
    [symbol(df_ph[i,:ph_qx_be_name]) for i=1:nrow(df_ph)]

df_lc = readtable(file_lc)

# Projection
df_fluct = readtable(file_fluct)

# Process inputs: general ------------------------------------------------------


srand(df_general[1, :random_seed])

tf = TimeFrame(df_general[1, :tf_y_start], df_general[1, :tf_y_end],
               df_general[1, :tf_n_dt] *
               (df_general[1, :tf_y_end]-df_general[1, :tf_y_start]))

@test tf.init == 2005
@test tf.final == 2011
@test tf.n_c == 6
@test tf.n_p == 12
@test_approx_eq_eps(tf.dt, 0.5, tol)
@test tf.n_dt == 2



## Dynamic policy behavior
function dynprobsx(sx::Vector{Float64}, mc::Int, t::Int, invest::Invest, 
                   bonus_rate::Float64)
    if invest.yield_market_c[mc,t] / max(eps(),invest.yield_cash_c[mc,t]) < 1.1
        delta = 0.1
    else
        delta = 0.0
    end
    si = invest.yield_market_c[mc,t] /
         max(eps(), bonus_rate + invest.yield_cash_c[mc,t])

    return  sx .+ (delta + 0.05 * min(6,max(0, si - 1.4)))
 end

## Dynamic asset allocation
function dynalloc!(invest::Invest, mc::Int, t::Int,
                   exp_yield_market::Float64)
    ## cash allocation is chosen dependent on market performance
    ## all other investments / assets are adjusted proportionally
    ## In-place computation for higher efficiency

   ## market performance indicator weighted with expected yield
   mkt_perf_ind =
       0.5 * (invest.yield_market_c[mc,t] + exp_yield_market) /
       max(0, invest.yield_cash_c[mc,t])
    
   alloc_cash = 1 - 0.5 * (1 - exp( - max(1, mkt_perf_ind) + 1))

    ## Now we adjust all allocations accordingly
   total_other = 1 - invest.alloc.ig_target_std[invest.alloc.ig_int[:cash]]
   fac_other = (1-alloc_cash) / max(eps(), total_other)
    for i = 1:invest.n
      if invest.ig_symb[i] == :cash
          invest.alloc.ig_target[i] = alloc_cash
      else
          invest.alloc.ig_target[i] = fac_other * invest.alloc.ig_target_std[i]
      end
   end
end

function dynalloc!(invest::Invest, mc::Int, t::Int)
    dynalloc!(invest, mc, t, 0.03)
end

## Dynamic bonus declaration
function   dynbonusrate(bucket::Bucket,
                        mc::Int,
                        t::Int,
                        invest::Invest,
                        stat_interest::Float64,
                        bonus_factor::Float64)
    bonus_factor * (1-invest.alloc.ig_target[invest.alloc.ig_int[:cash]]) *
function dynalloc!(alloc::InvestAlloc, t::Int, mc::Int, invest::Invest)
    dynalloc!(alloc, t, mc, invest, 0.03)
end

## Dynamic bonus declaration
function   dynbonusrate(bucket::Bucket, t::Int, mc::Int,
                        invest::Invest,
                        stat_interest::Float64,
                        alloc::InvestAlloc, bonus_factor::Float64)
    bonus_factor * (1-alloc.ig_target[alloc.ig_int[:cash]]) *
    max(0, invest.yield_market_c[mc,t] - stat_interest)
end

n_mc = df_general[1, :n_mc]
cap_mkt = CapMkt(:Capital_Market, tf, n_mc, df_proc_1, df_proc_2)
invest = Invest(:iii, cap_mkt, df_inv, df_inv_port_start, df_inv_asset)
lc = LC(df_lc, df_products, df_ph, df_qx, df_tech_interest, tf)               
buckets = Buckets(lc, tf, df_products, df_qx, df_tech_interest)
dividend = df_general[1, :capital_dividend]
bonus_factor = df_general[1, :bonus_factor]
discount = exp(-0.01) * ones(Float64, buckets.n_c)  
fluct = Fluct(tf, n_mc, 1.0)
cflow = CFlow(buckets, fluct, invest, discount,  df_tech_interest,
              bonus_factor, dividend, dynbonusrate, dynprobsx, dynalloc!)
