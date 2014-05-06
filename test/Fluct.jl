using DataFrames, DataArrays
using Base.Test
using MCInsurance


fluct2 = Array(Fluct,3)
fac = Array(Float64, tf.n_c, 6)
for t= 1:tf.n_c, j = 1:6
    fac[t,j] = 10 * t + j
end

fac1 = 3.14
fluct2[1] = Fluct(tf, n_mc, df_proj_fluct)
fluct2[2] = Fluct(tf, n_mc, fac)
fluct2[3] = Fluct(tf, n_mc, fac1)

##  Test that array of factors has the correct dimension       
for k = 1:3
        @test size(fluct2[k].fac) == (n_mc,tf.n_c,fluct2[k].n)
end
