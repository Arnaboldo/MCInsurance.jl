## Constructors ----------------------------------------------------------------
## Standard constructor
function ManualShortRate (name::Symbol,
                          cpnt::Vector{Any},
                          v_bop::Array{Float64, 3},
                          tf::TimeFrame
                          )

    n = 1
    n_mc = size(v_bop,1)
    dt = tf.dt
    n_p = tf.n_p
    v_init = v_bop[:,1,1]
    yield = Array(Float64, (n_mc, n_p, n))
    yield = v_bop[:,1:n_p,:]
    cpnt_id = Dict(cpnt, 1:length(cpnt))

    ManualShortRate( name, cpnt, cpnt_id, v_init, v_bop, n, yield,
                    n_mc, dt, n_p )
end

## Constructor interface to CapMkt
function ManualShortRate(name::Symbol,
                         cpnt::Vector{Any},
                         v_init::Vector{Float64},
                         param::Array{Float64, 3},
                         tf::TimeFrame,
                         cov::Array{Float64, 2},
                         noise::Array{Float64,3})
    # We ignore v_init, cov, noise.
    # param contains the data for v_bop

    
    ManualShortRate( name, cpnt, param, tf)
end


## Interface functions ---------------------------------------------------------
function show(io::IO, me::ManualShortRate)
    println(io,"Type       : $(string(typeof(me)))")
    println(io,"name       : $(me.name)")
    println(io,"dt         : $(me.dt)")
    println(io,"(n_mc n_p) : ($(me.n_mc) $(me.n_p))")
end


function yieldc(me::ManualShortRate,
                n_mc::Int,
                tf::TimeFrame,
                yield_init_c::Float64)
    yield_c = zeros(Float64, n_mc, tf.n_c, 1)
    ind = rand(DiscreteUniform(1,me.n_mc), n_mc)
    for mc = 1:n_mc
        for t = 1:tf.n_c
            for d = 1:tf.n_dt
                yield_c[mc,t] += me.yield[ind[mc], t-1+d, 1]
            end
        end
    end
    return (yield_c .+ (yield_init_c .- yield_c[:,1]))
end



## deterministic yields for noise=0, relative to beginning of pd.
## we simply take the average for each time step
determbop(me::ManualShortRate) = vec(mean(me.v_bop,1))

## forward rate relative to beginning of period
function forwardbop(me::ManualShortRate,
                    mc::Int,
                    t::Int,
                    delta_t::Int)
    warn("ManualShortRate.forwardbop: Code reflects CIR and needs to be changed")
    gamma = sqrt( me.a^2 + 2me.cov )
    dexp_gamma = exp( gamma * delta_t ) - 1
    B = 2dexp_gamma / ( (gamma+me.a)dexp_gamma +2gamma )
    A = ( 2gamma * exp( (gamma+me.a)delta_t / 2 ) /
         ( (gamma+me.a)dexp_gamma +2gamma )
         )^( 2me.a * me.v_infty / me.cov )
    return (B * me.v_bop[mc,t,1] -log(A)) / delta_t
end

function forwardbop(me::ManualShortRate,
                    t::Int,
                    delta_t::Int)
    warn("ManualShortRate.forwardbop: Code reflects CIR and needs to be changed")
    gamma = sqrt( me.a^2 + 2me.cov )
    dexp_gamma = exp( gamma * delta_t ) - 1
    B = 2dexp_gamma / ( (gamma+me.a)dexp_gamma +2gamma )
    A = ( 2gamma * exp( (gamma+me.a)delta_t / 2 ) /
         ( (gamma+me.a)dexp_gamma +2gamma )
         )^( 2me.a * me.v_infty / me.cov )
    return (B * me.v_bop[:,t,1] -log(A)) / delta_t
end
