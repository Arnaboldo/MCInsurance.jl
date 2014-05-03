## Constructors --------------------------------------------
## Standard
function DetermShortRate (name::Symbol,
                          labels::Vector{Symbol},
                          v_bop::Array{Float64, 3},
                          tf::TimeFrame,
                          dim::Int,
                          n_mc::Int
                          )

    dt = tf.dt
    n_p = tf.n_p
    v_init = v_bop[:,1,1]
    yield = Array(Float64, (n_mc, n_p, dim))
    yield = v_bop[:,1:n_p,:]
    DetermShortRate( name, labels, v_init, v_bop, dim, yield,
                    n_mc, dt, n_p )
end

## Interface to CapMkt
function DetermShortRate(name::Symbol,
                         labels::Vector{Symbol},
                         v_determ_bop::Array{Float64,2},
                         tf::TimeFrame,
                         n_mc::Int)
    dim = 1
    while size(v_determ_bop,2) < tf.n_p+1
       v_determ_bop = hcat(v_determ_bop, v_determ_bop[:,end])
    end
    v_determ_bop = v_determ_bop[:,1:(tf.n_p+1)]'
    v_bop = zeros(Float64, n_mc, tf.n_p+1, dim)
    for mc = 1:n_mc
        v_bop[mc,:,:] = v_determ_bop[:,:]
    end
    DetermShortRate( name, labels, v_bop, tf, dim, n_mc)
end


## Utility functions ---------------------------------------------
function show(io::IO, me::DetermShortRate)
    println(io,"Type       : $(string(typeof(me)))")
    println(io,"name       : $(me.name)")
    println(io,"dt         : $(me.dt)")
    println(io,"(n_mc n_p) : ($(me.n_mc) $(me.n_p))")
end

## deterministic yields for noise=0, relative to beginning of pd.
## we simply take the average for each time step
determbop(me::DetermShortRate) = vec(mean(me.v_bop,1))

## forward rate relative to beginning of period
function forwardbop(me::DetermShortRate,
                    mc::Int,
                    t::Int,
                    delta_t::Int)
    warn("DetermShortRate.forwardbop: Code reflects CIR and needs to be changed")
    gamma = sqrt( me.a^2 + 2me.cov )
    dexp_gamma = exp( gamma * delta_t ) - 1
    B = 2dexp_gamma / ( (gamma+me.a)dexp_gamma +2gamma )
    A = ( 2gamma * exp( (gamma+me.a)delta_t / 2 ) /
         ( (gamma+me.a)dexp_gamma +2gamma )
         )^( 2me.a * me.v_infty / me.cov )
    return (B * me.v_bop[mc,t,1] -log(A)) / delta_t
end

function forwardbop(me::DetermShortRate,
                    t::Int,
                    delta_t::Int)
    warn("DetermShortRate.forwardbop: Code reflects CIR and needs to be changed")
    gamma = sqrt( me.a^2 + 2me.cov )
    dexp_gamma = exp( gamma * delta_t ) - 1
    B = 2dexp_gamma / ( (gamma+me.a)dexp_gamma +2gamma )
    A = ( 2gamma * exp( (gamma+me.a)delta_t / 2 ) /
         ( (gamma+me.a)dexp_gamma +2gamma )
         )^( 2me.a * me.v_infty / me.cov )
    return (B * me.v_bop[:,t,1] -log(A)) / delta_t
end
