## Constructors --------------------------------------------
## Standard
function ManualShortRate (name::Symbol,
                          labels::Vector{Symbol},
                          v_bop::Array{Float64, 3},
                          tf::TimeFrame
                          )

    dim = 1
    n_mc = size(v_bop,1)
    dt = tf.dt
    n_p = tf.n_p
    v_init = v_bop[:,1,1]
    yield = Array(Float64, (n_mc, n_p, dim))
    yield = v_bop[:,1:n_p,:]
    comp_int = Dict(labels, 1:length(labels))

    ManualShortRate( name, labels, comp_int, v_init, v_bop, dim, yield,
                    n_mc, dt, n_p )
end

## Interface to CapMkt
function ManualShortRate(name::Symbol,
                         labels::Vector{Symbol},
                         v_init::Vector{Float64},
                         param::Array{Float64, 3},
                         tf::TimeFrame,
                         cov::Array{Float64, 2},
                         noise::Array{Float64,3})
    # We ignore v_init, cov, noise.
    # param contains the data for v_bop

    
    ManualShortRate( name, labels, param, tf)
end


## Utility functions ---------------------------------------------
function show(io::IO, me::ManualShortRate)
    println(io,"Type       : $(string(typeof(me)))")
    println(io,"name       : $(me.name)")
    println(io,"dt         : $(me.dt)")
    println(io,"(n_mc n_p) : ($(me.n_mc) $(me.n_p))")
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
