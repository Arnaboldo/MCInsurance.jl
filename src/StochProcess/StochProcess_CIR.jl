## Constructors --------------------------------------------
## Standard
function CIR (name::Symbol,
              labels::Vector{Symbol},
              v_init::Float64,
              a::Float64,
              v_infty::Float64,
              tf::TimeFrame,
              cov::Float64,
              noise::Array{Float64,2} )
    dim = 1
    n_mc = size(noise,1)
    dt = tf.dt
    n_p = tf.n_p
    v_bop = zeros(Float64, (n_mc, n_p+1, dim))
    for mc = 1:n_mc, t = 0:n_p, d =1:dim
        if t==0
            v_bop[mc, t+1,1] = v_init
        else
            v_bop[mc, t+1,1] =
                v_bop[mc, t,1] +
            a * ( v_infty - v_bop[mc,t,1] ) * dt +
            sqrt( abs(v_bop[mc, t,1]) * dt ) * noise[mc,t]
        end
    end
    yield = Array(Float64, (n_mc, n_p, dim))
    yield = v_bop[:,1:n_p,:]
    CIR( name, labels, v_init, a, v_infty,
        cov, noise, dim, v_bop, yield,
        n_mc, dt, n_p )
end

## Interface to AssetGroupShortRate
function CIR(name::Symbol,
             labels::Vector{Symbol},
             v_init::Vector{Float64},
             param::Vector{Float64},
             tf::TimeFrame,
             cov::Array{Float64, 2},
             noise::Array{Float64,3})
    CIR(name, labels, v_init[1], param[1], param[2],
        tf, cov[1,1], noise[:,:,1])
end

## Construct Process including noise
function CIR(name::Symbol,
             labels::Vector{Symbol},
             v_init::Float64,
             a::Float64,
             v_infty::Float64,
             tf::TimeFrame,
             cov::Float64,
             n_mc::Int )
    noise =  reshape(rand( Normal(0,sqrt(cov)), n_mc*tf.n_p ),
                     n_mc,
                     tf.n_p )
    CIR( name, labels, v_init, a, v_infty, tf, cov, noise )
end

## Utility functions ---------------------------------------------
function show(io::IO, me::CIR)
    print(io,"Type          : ");
    println(io, string(typeof(me)))
    print(io,"name          : "); println(io,me.name)
    print(io,"v_init     : "); println(io,me.v_init)
    print(io,"(a, v_infty)  : "); print(io,[me.a,me.v_infty]')
    print(io,"cov           : "); println(io,me.cov)
    print(io,"dt            : "); println(io,me.dt)
    print(io,"(n_mc n_p): "); print(io, size(me.noise))
end

## deterministic yields for noise=0, relative to beginning of pd.
determbop(me::CIR) =
    [me.v_infty + (1-me.a*me.dt)^t * (me.v_init-me.v_infty)
     for t = 0:me.n_p, d= 1:me.dim ]

## forward rate relative to beginning of period
function forwardbop(me::CIR, mc::Int, t::Int, delta_t::Int)
    gamma = sqrt( me.a^2 + 2me.cov )
    dexp_gamma = exp( gamma * delta_t ) - 1
    B = 2dexp_gamma / ( (gamma+me.a)dexp_gamma +2gamma )
    A = ( 2gamma * exp( (gamma+me.a)delta_t / 2 ) /
         ( (gamma+me.a)dexp_gamma +2gamma )
         )^( 2me.a * me.v_infty / me.cov )
    return (B * me.v_bop[mc,t,1] -log(A)) / delta_t
end

function forwardbop(me::CIR, t::Int, delta_t::Int)
    gamma = sqrt( me.a^2 + 2me.cov )
    dexp_gamma = exp( gamma * delta_t ) - 1
    B = 2dexp_gamma / ( (gamma+me.a)dexp_gamma +2gamma )
    A = ( 2gamma * exp( (gamma+me.a)delta_t / 2 ) /
         ( (gamma+me.a)dexp_gamma +2gamma )
         )^( 2me.a * me.v_infty / me.cov )
    return (B * me.v_bop[:,t,1] -log(A)) / delta_t
end

