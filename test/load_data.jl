using Distributions
using DataFrames
using Base.Test

using MCInsurance

tol = 1e-8  # Testing tolerance for floating points

# General parameters
df_general = readtable("input/General.csv")

# Capital market
df_proc_1 = readtable("input/Proc_1.csv")
df_proc_2 = readtable("input/Proc_2.csv")

# Investment strategy
df_inv = readtable("input/Inv.csv")
df_inv_target = readtable("input/Inv_Target.csv")
df_inv_port_start = readtable("input/Inv_Port_Start.csv")

# life insurance contracts
df_tech_interest = readtable("input/Tech_Interest.csv")
df_qx = readtable("input/Qx.csv")
df_products = readtable("input/Prod.csv")
df_ph = readtable("input/PH.csv")
df_lc = readtable("input/LC.csv")

# Projection
df_fluct = readtable("input/Rnd_FLuct.csv")

# Process inputs: general ------------------------------------------------------


srand(df_general[1,"random_seed"])

tf = TimeFrame(df_general[1,"tf_y_start"], df_general[1,"tf_y_end"],
               df_general[1,"tf_n_dt"] *
               (df_general[1,"tf_y_end"]-df_general[1,"tf_y_start"]))

@test tf.init == 2005
@test tf.final == 2011
@test tf.n_c == 6
@test tf.n_p == 12
@test_approx_eq_eps(tf.dt, 0.5, tol)
@test tf.n_dt == 2

n_mc = df_general[1,"n_mc"]
cap_mkt = CapMkt("Capital Market", tf, n_mc, df_proc_1, df_proc_2)
invest = Invest("iii", cap_mkt, df_inv, df_inv_port_start, df_inv_target)

lc = LC(df_lc, df_products, df_ph, df_qx, df_tech_interest, tf)
               
buckets = Buckets(lc, tf, df_products, df_qx)

dividend = df_general[1,"capital_dividend"]
discount = exp(-0.05) * ones(Float64, buckets.n_c)  
fluct = Fluct(tf, n_mc, 1.0)
cflow = CFlow(buckets, fluct, invest, discount, dividend)
