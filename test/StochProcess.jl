using Distributions
using DataFrames
using Base.Test

using MCInsurance

srand(2) # make random numbers repeatible

tf = TimeFrame( 2005, 2011, 2 * (2011-2005) )
n_mc = 4

processes = ["brown", "geombrown", "cir", "vasicek", "manual"]
D = Dict( processes, [1:5] )

info = Array(StochProcessInfo,length(D))
info_dummy_v_determ_bop = Array(Float64,0,0)
info[D["brown"]] = StochProcessInfo(:Brownian,
                                    :brown,
                                    [:a, :b, :c],
                                    [1,2,3.],             # init
                                    info_dummy_v_determ_bop,
                                    [0.0, 0.5, 1.0] )     # drift
info[D["geombrown"]] = StochProcessInfo(:GeomBrownian,
                                        :geombrown,
                                        [:a, :b, :c],
                                        [1,2,3.],         # init
                                        info_dummy_v_determ_bop,
                                        [0.0, 0.5, 1.0] ) # drift
info[D["cir"]] = StochProcessInfo(:CIR,
                                  :cir,
                                        [:a, :b, :c],
                                  [0.02],           # init
                                  info_dummy_v_determ_bop,
                                  [0.5, 0.01] )     # a, v_infty
info[D["vasicek"]] = StochProcessInfo(:Vasicek,
                                      :vasicek,
                                        [:a, :b, :c],
                                      [0.02],       # init
                                      info_dummy_v_determ_bop,
                                      [0.5, 0.01] ) # a, v_infty
info[D["manual"]] =
    StochProcessInfo(:ManualShortRate,
                     :manual,
                     [:a, :b, :c],
                     [-1000000.],   # init: to be ignored
                     info_dummy_v_determ_bop,
                     Float64[t/100 for mc=1:n_mc, t=1:(tf.n_p+1), d=1] ) # yield
 
n_dim= [length(info[i].init) for i =1:length(D)]

cov = Array(Array{Float64},length(D))
cov[D["brown"]] =
    reshape( [[2.0, 0.5, 0.1],
              [0.5, 1.5, 0.2],
              [0.1, 0.2, 3.0]], (n_dim[D["brown"]],n_dim[D["brown"]]) )
cov[D["geombrown"]] = cov[D["brown"]]
for procname in ("cir", "vasicek", "manual")
    cov[D[procname]] = reshape([0.005^2],1,1)              
end
    
noise = Array(Any, length(D))
proc = Array(Process, length(D))
for i=1:length(D)
    noise[i] = reshape(rand( MvNormal(cov[i]), n_mc * tf.n_p )',
                       n_mc, tf.n_p, n_dim[i] )
    proc[i] = eval(info[i].type_name)(info[i].name, info[i].cpnt,
                                      info[i].init, info[i].param,
                                      tf, cov[i], noise[i] )
end
    

proc_determ = Array(Process, length(D))

noise_p = noise .* sqrt(tf.dt)
cov_p = cov .* tf.dt

## v_bop test ------------------------------------------------------------------    

## Brownian: dv = (drift*dt+dW), where dW ~ N(0,cov)
i = D["brown"]
for mc = 1:n_mc, t = 1:tf.n_p, d= 1:proc[i].n
    if proc[i].v_bop[mc, t+1, d] > 0
        @test_approx_eq_eps(proc[i].v_bop[mc,t+1,d]- proc[i].v_bop[mc,t,d],
                            proc[i].drift[d]  +
                            noise_p[i][mc,t,d],
                            tol )
    end
end

## Geom. Brownian: dlog(v) = (drift-0.5diag(Sigma)^2)*dt+sqrt(dt)* dW
i= D["geombrown"]
for mc = 1:n_mc, t = 1:tf.n_p, d = 1:proc[i].n
    @test_approx_eq_eps(log(proc[i].v_bop[mc,t+1,d])- log(proc[i].v_bop[mc,t,d]),
                        (proc[i].drift[d] - 0.5cov_p[i][d,d]) +
                        noise_p[i][mc,t,d],
                        tol)
end


## yield test ------------------------------------------------------------------
## Processes that model indices:  v[t+1] = v[t] * exp( dt* yield[t] )
#i = D["brown"]
## test only if v[s] > 0 for all s <= t+1 (otherwise log is not defined)
for i= 1:length(D)
    if typeof(proc[i]) <: ProcessIndex
        for mc = 1:n_mc, d = 1:proc[i].n
            for t = 1:tf.n_p
                if !((proc[i].v_bop[mc,t+1,d] < eps(1.0)) & (i == D["brown"]))
                    @test_approx_eq_eps(proc[i].v_bop[mc,t+1,d],
                                        proc[i].v_bop[mc,t,d] *
                                        exp(proc[i].yield[mc,t,d]),
                                        tol)
                end
            end
        end
    end
end

## Cox Ingersoll Ross: dy = a*(y_infty-y[t])*dt + sqrt(y[t])*sqrt(dt)*dW
i= D["cir"]
for mc = 1:n_mc, t = 1:(tf.n_p-1), d= 1:proc[i].n
    @test_approx_eq_eps(proc[i].yield[mc,t+1,d]- proc[i].yield[mc,t,d],
                        proc[i].a * (proc[i].yield_infty-proc[i].yield[mc,t,d]) +
                        sqrt(proc[i].yield[mc,t,d])  * noise_p[i][mc,t,d],
                        tol)
end

## Vasicek: dy = a*(y_infty-y[t])*dt + sqrt(dt)*dW
i= D["vasicek"]
for mc = 1:n_mc, t = 1:(tf.n_p-1), d= 1:proc[i].n
    @test_approx_eq_eps(proc[i].yield[mc,t+1,d]- proc[i].yield[mc,t,d],
                        proc[i].a * (proc[i].yield_infty-proc[i].yield[mc,t,d]) +
                        noise_p[i][mc,t,d],
                        tol)
end

## Manual: v_bop is given directly -- no test    


##  determbop test: determbop(proc) = v_bop or yield, where noise is zero ------
for i= 1:length(D)
    if info[i].type_name == :ManualShortRate
        param = mean(info[i].param,1)
    else
        param = info[i].param
    end
    noise_det = zeros(Float64, (1, tf.n_p, n_dim[i]))
    proc_determ[i] =
        eval(info[i].type_name)(info[i].name, info[i].cpnt,
                                info[i].init, param, tf,
                                zeros(Float64, n_dim[i] ,n_dim[i]),
                                noise_det  )
    if typeof(proc_determ[i]) <: ProcessIndex
        @test_approx_eq_eps(determbop(proc[i]),
                            reshape(proc_determ[i].v_bop, tf.n_p+1, n_dim[i] ),
                            tol)
    else
        @test_approx_eq_eps(determbop(proc[i]),
                            reshape(proc_determ[i].yield, tf.n_p+1, n_dim[i]),
                            tol)
    end
end
