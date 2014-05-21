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

## convert references from string to symbol
df_lc_lc[:prod_name] = convert(DataArray{Symbol,1}, df_lc_lc[:prod_name])
df_lc_load[:name] = convert(DataArray{Symbol,1}, df_lc_load[:name])
for col in (:name, :cost_name, :cost_be_name, :qx_name, :interest_name)
    df_lc_prod[col] = convert(DataArray{Symbol,1}, df_lc_prod[col])
end
for col in (:ph_gender, :ph_qx_be_name)
    df_lc_ph[col] = convert(DataArray{Symbol,1}, df_lc_ph[col])
end
