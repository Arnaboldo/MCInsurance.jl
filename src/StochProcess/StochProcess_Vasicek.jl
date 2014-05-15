## Constructors ----------------------------------------------------------------
## Standard constructor
function Vasicek(name::Symbol,
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
    cpnt_id = Dict(cpnt, 1:length(cpnt))

    yield = Array(Float64, n_mc, n_p + 1, n)
    proc = Vasicek(name, cpnt, cpnt_id, init, a, yield_infty, cov, noise, n,
                   yield, n_mc, n_p )

    cycle2period!(proc, tf)

    for mc = 1:n_mc
        yield[mc,:,1] = yieldbop(proc, proc.init, n_p, vec(proc.noise[mc,:]))
    end 
    proc
end

## Constructor interface to CapMkt
function Vasicek(name::Symbol,
                 cpnt::Vector{Any},
                 init::Vector{Float64},
                 param::Vector{Float64},
                 tf::TimeFrame,
                 cov::Array{Float64,2},
                 noise::Array{Float64,3})
    Vasicek(name, cpnt, init[1], param[1], param[2],
            tf, cov[1,1], noise[:,:,1])
end

## Constructor with automatic generation of noise
function Vasicek(name::Symbol,
                 cpnt::Vector{Any},
                 init::Float64,
                 a::Float64,
                 yield_infty::Float64,
                 tf::TimeFrame,
                 cov::Float64,
                 n_mc::Int )
    noise =  reshape( rand(Normal(0,sqrt(cov)), n_mc*tf.n_p), n_mc, tf.n_p )
    Vasicek( name, cpnt, init, a, yield_infty, tf, cov, noise )
end

## Interface functions ---------------------------------------------------------
function show(io::IO, me::Vasicek)
    print(io,"Type             : ");
    println(io, string(typeof(me)))
    print(io,"name             : "); println(io,me.name)
    print(io,"init             : "); println(io,me.init)
    print(io,"(a, yield_infty) : "); print(io,[me.a,me.yield_infty]')
    print(io,"cov              : "); println(io,me.cov)
    print(io,"(n_mc n_p)       : "); print(io, size(me.noise))
end
    
## deterministic yields for noise=0, relative to beginning of pd.
determbop(me::Vasicek) =
    [me.yield_infty + (1-me.a)^(t-1) * (me.init-me.yield_infty)
     for t = 1:(me.n_p+1), d= 1:me.n ]

## forward rate relative to beginning of period
function forwardbop(me::Vasicek, mc::Int, t::Int, delta_t::Int)
    B = ( 1 - exp(-me.a * delta_t) )/ me.a
    logA = (B-delta_t)*(me.a^2*me.yield_infty - 0.5me.cov) / me.a^2 -
           me.cov * B^2 / 4me.a
    return (B * me.yield[mc,t,1] - logA) / delta_t
end

function forwardbop(me::Vasicek, t::Int, delta_t::Int)
    B = ( 1 - exp(-me.a * delta_t) )/ me.a
    logA = (B-delta_t)*(me.a^2*me.yield_infty - 0.5me.cov) /me.a^2 -
           me.cov * B^2 / 4me.a
    return (B * me.yield[:,t,1] - logA) / delta_t
end

## Private functions -----------------------------------------------------------
function cycle2period!(me::Vasicek, tf::TimeFrame)
    # assumption: init, yield_infty, cov, noise are given with respect to cycles
    # me.a: not changed
    me.yield_infty *= tf.dt
    me.init *= tf.dt
    me.cov *= tf.dt
    me.noise .*= sqrt(tf.dt)
end
    
function yieldbop(me::Vasicek,
                  init::Float64,
                  n_p::Int,
                  noise_vec::Vector{Float64}) 
    yield = Array(Float64, n_p + 1)
    for t = 1:(n_p + 1)
        if t==1
            yield[t] = init
        else
            yield[t] =
                yield[t-1] + me.a * (me.yield_infty-yield[t-1]) + noise_vec[t-1]
        end
    end
    return yield
end
