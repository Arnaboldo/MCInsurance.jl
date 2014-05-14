## Constructors ----------------------------------------------------------------
## Standard constructor
function CIR (name::Symbol,
              cpnt::Vector{Any},
              init::Float64,
              a::Float64,
              yield_infty::Float64,
              tf::TimeFrame,
              cov::Float64,
              noise::Array{Float64,2} )
    n = 1
    n_mc = size(noise,1)
    dt = tf.dt
    n_p = tf.n_p
    yield = Array(Float64, n_mc, n_p + 1, n)
    for mc = 1:n_mc
        yield[mc,:,1] = yieldcir(mc, init, a, yield_infty, tf, noise) 
    end 
    cpnt_id = Dict(cpnt, 1:length(cpnt))
    CIR(name, cpnt, cpnt_id, init, a, yield_infty, cov, noise, n, yield,
        n_mc, dt, n_p )
end

## Constructor interface to CapMkt
function CIR(name::Symbol,
             cpnt::Vector{Any},
             init::Vector{Float64},
             param::Vector{Float64},
             tf::TimeFrame,
             cov::Array{Float64, 2},
             noise::Array{Float64,3})
    CIR(name, cpnt, init[1], param[1], param[2],
        tf, cov[1,1], noise[:,:,1])
end

## Constructor with automatic generation of noise
function CIR(name::Symbol,
             cpnt::Vector{Any},
             init::Float64,
             a::Float64,
             yield_infty::Float64,
             tf::TimeFrame,
             cov::Float64,
             n_mc::Int )
    noise =  reshape(rand( Normal(0,sqrt(cov)), n_mc*tf.n_p ), n_mc, tf.n_p )
    CIR( name, cpnt, init, a, yield_infty, tf, cov, noise )
end

## Interface functions ---------------------------------------------------------
function show(io::IO, me::CIR)
    print(io,"Type          : ");
    println(io, string(typeof(me)))
    print(io,"name          : "); println(io,me.name)
    print(io,"init     : "); println(io,me.init)
    print(io,"(a, yield_infty)  : "); print(io,[me.a,me.yield_infty]')
    print(io,"cov           : "); println(io,me.cov)
    print(io,"dt            : "); println(io,me.dt)
    print(io,"(n_mc n_p): "); print(io, size(me.noise))
end

function yieldeoc(me::CIR,  n_mc::Int, tf::TimeFrame, yield_init_c::Float64)
    ## This function calculates the yield retrospectively at eoc
    tf_tmp = TimeFrame(tf.init, tf.final+1, tf.n_p+tf.n_dt)
    yield_mc = Array(Float64, 1, tf_tmp.n_p+1, 1)
    yield_c = zeros(Float64, n_mc, tf.n_c + 1, 1)
    noise = reshape(rand(Normal(0,sqrt(me.cov)), n_mc * tf_tmp.n_p ),
                    n_mc, tf_tmp.n_p)
    ## |-.-.-.-|-.-.-.-|-.-.-.-|-.  here: tf.n_dt = 4, tf.n_c = 3
    ##         ^                          t=2  (unit: n_c)
    ##         t                          tau = (t-1) * tf.n_t + 1 (unit: n_p)
    ##         |-| known at time t: yield_mc for this interval
    ## Assumption: interest rate will not change for the rest of the cycle
    for mc = 1:n_mc
        yield_mc[1, :, 1] = yieldcir(mc,
                                     yield_init_c/tf.n_dt,
                                     me.a,
                                     me.yield_infty,
                                     tf_tmp,
                                     noise)
        for t = 1:(tf.n_c + 1)
            for d = 1:tf.n_dt
                yield_c[mc,t] += yield_mc[1, tf.n_dt*(t-1) + d, 1]
            end
        end
    end
    return yield_c
end
    
## deterministic yields for noise=0, relative to beginning of pd.
determbop(me::CIR) =
    [me.yield_infty + (1-me.a*me.dt)^(t-1) * (me.init-me.yield_infty)
     for t = 1:(me.n_p+1), d= 1:me.n ]

## forward rate relative to beginning of period
function forwardbop(me::CIR, mc::Int, t::Int, delta_t::Int)
    gamma = sqrt( me.a^2 + 2me.cov )
    dexp_gamma = exp( gamma * delta_t ) - 1
    B = 2dexp_gamma / ( (gamma+me.a)dexp_gamma +2gamma )
    A = ( 2gamma * exp( (gamma+me.a)delta_t / 2 ) /
         ( (gamma+me.a)dexp_gamma +2gamma )
         )^( 2me.a * me.yield_infty / me.cov )
    return (B * me.yield[mc,t,1] -log(A)) / delta_t
end

function forwardbop(me::CIR, t::Int, delta_t::Int)
    gamma = sqrt( me.a^2 + 2me.cov )
    dexp_gamma = exp( gamma * delta_t ) - 1
    B = 2dexp_gamma / ( (gamma+me.a)dexp_gamma +2gamma )
    A = ( 2gamma * exp( (gamma+me.a)delta_t / 2 ) /
         ( (gamma+me.a)dexp_gamma +2gamma )
         )^( 2me.a * me.yield_infty / me.cov )
    return (B * me.yield[:,t,1] -log(A)) / delta_t
end

## Private functions -----------------------------------------------------------
function yieldcir(mc::Int,
                 init::Float64,
                  a::Float64,
                  yield_infty::Float64,
                  tf::TimeFrame,
                  noise::Array{Float64,2}) 
    yield = Array(Float64, tf.n_p + 1)
    for t = 1:(tf.n_p + 1)
        if t==1
            yield[t] = init
        else
            yield[t] = yield[t-1] + a * ( yield_infty - yield[t-1] ) * tf.dt +
                         sqrt(abs(yield[t-1]) * tf.dt) * noise[mc,t-1]
        end
    end
    return yield
end
