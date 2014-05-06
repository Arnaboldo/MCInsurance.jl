time_start = time_ns()
##================================================================
using Distributions
using DataFrames
using Base.Test

using MCInsurance

@test tf.init == 2005
@test tf.final == 2011
@test tf.n_c == 6
@test tf.n_p == 12
@test_approx_eq_eps(tf.dt, 0.5, tol)
@test tf.n_dt == 2


v20 = float64([1:20])
v03 = float64([1:3])

@test insertc(tf,1800,v20) == zeros(Int,7)
@test insertc(tf,1991,v20) == [15:20,0]
@test insertc(tf,2001,v20) == [5:11]
@test insertc(tf,2007,v20) == [zeros(Int,2), [1:5]]
@test insertc(tf,2012,v20) == zeros(Int,7)

@test insertc(tf,2007,v03) == [zeros(Int,2), [1:3], zeros(Int,2)]

@test insertp(tf,1800//1,v20) == zeros(Int,13)
@test insertp(tf,2004+1//2,v20) == [2:14]
@test insertp(tf,2012//1,v20) == zeros(Int,13)

@test insertp(tf,2007//1,v03) == [zeros(Int,4), [1:3], zeros(Int,6)]

