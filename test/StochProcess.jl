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
                                    [1,2,3.],             # v_init
                                    info_dummy_v_determ_bop,
                                    [0.0, 0.5, 1.0] )     # drift
info[D["geombrown"]] = StochProcessInfo(:GeomBrownian,
                                        :geombrown,
                                        [:a, :b, :c],
                                        [1,2,3.],         # v_init
                                        info_dummy_v_determ_bop,
                                        [0.0, 0.5, 1.0] ) # drift
info[D["cir"]] = StochProcessInfo(:CIR,
                                  :cir,
                                        [:a, :b, :c],
                                  [0.02],           # v_init
                                  info_dummy_v_determ_bop,
                                  [0.5, 0.01] )     # a, v_infty
info[D["vasicek"]] = StochProcessInfo(:Vasicek,
                                      :vasicek,
                                        [:a, :b, :c],
                                      [0.02],       # v_init
                                      info_dummy_v_determ_bop,
                                      [0.5, 0.01] ) # a, v_infty
info[D["manual"]] =
    StochProcessInfo(:ManualShortRate,
                     :manual,
                     [:a, :b, :c],
                     [-1000000.],   # v_init: to be ignored
                     info_dummy_v_determ_bop,
                     Float64[t/100 for mc=1:n_mc, t=1:tf.n_p+1, d=1] ) # v_bop
 
n_dim= [length(info[i].v_init) for i =1:length(D)]

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
                                      info[i].v_init, info[i].param,
                                      tf, cov[i], noise[i] )
end
    
msg_v_bop = Array(String,length(D))
test_v_bop = Array(Any,length(D))

msg_yield = Array(String,length(D))
tmp_v_bop = Array(Any,length(D))
test_yield = Array(Any,length(D))

msg_determbop = Array(String,length(D))
test_determbop = Array(Any,length(D))
proc_determ = Array(Process, length(D))

## v_bop test ------------------------------------------------------------------    

## Brownian: dv = (drift*dt+dW), where dW ~ N(0,cov)
i = D["brown"]
for mc = 1:n_mc, t = 1:tf.n_p, d= 1:proc[i].n
    if proc[i].v_bop[mc, t+1, d] > 0
        @test_approx_eq_eps(proc[i].v_bop[mc,t+1,d]- proc[i].v_bop[mc,t,d],
                            proc[i].drift[d] * tf.dt +
                            sqrt(tf.dt) * noise[i][mc,t,d],
                            tol )
    end
end

## Geom. Brownian: dlog(v) = (drift-0.5diag(Sigma)^2)*dt+sqrt(dt)* dW
i= D["geombrown"]
msg_v_bop[i] =
    "0 = dlog(v) - ((drift-0.5diag(Sigma)^2)*dt+sqrt(dt)* dW)" *
    ", where dW ~ N(0,cov)"
for mc = 1:n_mc, t = 1:tf.n_p, d = 1:proc[i].n
    @test_approx_eq_eps(log(proc[i].v_bop[mc,t+1,d])- log(proc[i].v_bop[mc,t,d]),
                        (proc[i].drift[d] - 0.5cov[i][d,d]) * tf.dt +
                        + sqrt(tf.dt) * noise[i][mc,t,d],
                        tol)
end

## Cox Ingersoll Ross: dv = a*(v_infty-v[t])*dt + sqrt(v[t])*sqrt(dt)*dW
i= D["cir"]
for mc = 1:n_mc, t = 1:tf.n_p, d= 1:proc[i].n
    @test_approx_eq_eps(proc[i].v_bop[mc,t+1,d]- proc[i].v_bop[mc,t,d],
                        proc[i].a * (proc[i].v_infty-proc[i].v_bop[mc,t,d]) * tf.dt +
                        sqrt(proc[i].v_bop[mc,t,d]) *  sqrt(tf.dt) * noise[i][mc,t,d],
                        tol)
end

## Vasicek: dv = a*(v_infty-v[t])*dt + sqrt(dt)*dW
i= D["vasicek"]
msg_v_bop[i] =
    "0 = dv - (a*(v_infty-v[t])*dt+sqrt(dt)*dW)" *
          ", where dW ~ N(0,cov)"
for mc = 1:n_mc, t = 1:tf.n_p, d= 1:proc[i].n
    @test_approx_eq_eps(proc[i].v_bop[mc,t+1,d]- proc[i].v_bop[mc,t,d],
                        proc[i].a * (proc[i].v_infty-proc[i].v_bop[mc,t,d]) * tf.dt +
                        sqrt(tf.dt) * noise[i][mc,t,d],
                        tol)
end

## Manual: v_bop is given directly -- no test    

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
                                        exp(tf.dt * proc[i].yield[mc,t,d]),
                                        tol)
                end
            end
        end
    end
end

## Processes that model short rates:  v[t] = yield[t] 
for i= 1:length(D)
    if typeof(proc[i]) <: ProcessShortRate
        for mc = 1:n_mc, d = 1:proc[i].n, t = 1:tf.n_p
            @test_approx_eq_eps(proc[i].v_bop[mc,t,d], proc[i].yield[mc,t,d],
                                tol)
        end
    end
end
    
##  determbop test: determbop(proc) = v_bop, where noise is zero ---------------
for i= 1:length(D)
    if info[i].type_name == :ManualShortRate
        param = mean(info[i].param,1)
    else
        param = info[i].param
    end
    noise_det = zeros(Float64, (1, tf.n_p, n_dim[i]))
    proc_determ[i] =
        eval(info[i].type_name)(info[i].name, info[i].cpnt,
                                info[i].v_init, param, tf,
                                zeros(Float64, (n_dim[i] ,n_dim[i])),
                                noise_det  )
    @test_approx_eq_eps(determbop(proc[i]),
                        reshape(proc_determ[i].v_bop, tf.n_p+1, n_dim[i] ),
                        tol)
end
