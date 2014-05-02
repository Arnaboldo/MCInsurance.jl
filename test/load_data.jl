using Distributions
using DataFrames
using Base.Test

using MCInsurance

tol = 1e-8  # Testing tolerance for floating points

file_general = joinpath(dirname(@__FILE__), "input/General.csv")
file_proc_1 = joinpath(dirname(@__FILE__), "input/Proc_1.csv")
file_proc_2 = joinpath(dirname(@__FILE__), "input/Proc_2.csv")
file_inv = joinpath(dirname(@__FILE__), "input/Inv.csv")
file_inv_target = joinpath(dirname(@__FILE__), "input/Inv_Target.csv")
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
df_inv_target = readtable(file_inv_target)
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

n_mc = df_general[1, :n_mc]
cap_mkt = CapMkt("Capital Market", tf, n_mc, df_proc_1, df_proc_2)
invest = Invest("iii", cap_mkt, df_inv, df_inv_port_start, df_inv_target)

lc = LC(df_lc, df_products, df_ph, df_qx, df_tech_interest, tf)
               
buckets = Buckets(lc, tf, df_products, df_qx, df_tech_interest)

dividend = df_general[1, :capital_dividend]
bonus_factor = df_general[1, :bonus_factor]
discount = exp(-0.01) * ones(Float64, buckets.n_c)  
fluct = Fluct(tf, n_mc, 1.0)
cflow = CFlow(buckets, fluct, invest, discount,  df_tech_interest,
              bonus_factor, dividend)

## for test in CFlow.jl:
## reason: in our tests we will project with different asset allocation,
##         which affects invest.yield_total
saved_yield_total = deepcopy(invest.yield_total)

