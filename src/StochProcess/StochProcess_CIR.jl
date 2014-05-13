## Constructors ----------------------------------------------------------------
## Standard constructor
function CIR (name::Symbol,
              cpnt::Vector{Any},
              v_init::Float64,
              a::Float64,
              v_infty::Float64,
              tf::TimeFrame,
              cov::Float64,
              noise::Array{Float64,2} )
    n = 1
    n_mc = size(noise,1)
    dt = tf.dt
    n_p = tf.n_p
    v_bop = Array(Float64, (n_mc, n_p+1, n))
    for mc = 1:n_mc
        v_bop[mc,:,1] = vbopcir(mc, v_init, a, v_infty, tf, noise) 
    end 
    yield = Array(Float64, (n_mc, n_p, n))
    yield = v_bop[:,1:n_p,:]
    cpnt_id = Dict(cpnt, 1:length(cpnt))
    CIR( name, cpnt, cpnt_id,  v_init, a, v_infty,
        cov, noise, n, v_bop, yield,
        n_mc, dt, n_p )
end

## Constructor interface to CapMkt
function CIR(name::Symbol,
             cpnt::Vector{Any},
             v_init::Vector{Float64},
             param::Vector{Float64},
             tf::TimeFrame,
             cov::Array{Float64, 2},
             noise::Array{Float64,3})
    CIR(name, cpnt, v_init[1], param[1], param[2],
        tf, cov[1,1], noise[:,:,1])
end

## Constructor with automatic generation of noise
function CIR(name::Symbol,
             cpnt::Vector{Any},
             v_init::Float64,
             a::Float64,
             v_infty::Float64,
             tf::TimeFrame,
             cov::Float64,
             n_mc::Int )
    noise =  reshape(rand( Normal(0,sqrt(cov)), n_mc*tf.n_p ), n_mc, tf.n_p )
    CIR( name, cpnt, v_init, a, v_infty, tf, cov, noise )
end

## Interface functions ---------------------------------------------------------
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

function yieldc(me::CIR,  n_mc::Int, tf::TimeFrame, yield_init_c::Float64)
    yield_mc = Array(Float64, 1, tf.n_p, 1)
    yield_c = zeros(Float64, n_mc, tf.n_c, 1)
    noise = reshape(rand(Normal(0,sqrt(me.cov)), n_mc * tf.n_p ), n_mc, tf.n_p)
    for mc = 1:n_mc
        yield_mc[1, :, 1] = vbopcir(mc,
                                    yield_init_c/tf.n_dt,
                                    me.a,
                                    me.v_infty,
                                    tf,
                                    noise)[1:tf.n_p] 
        for t = 1:tf.n_c
            for d = 1:tf.n_dt
                yield_c[mc,t] += yield_mc[1, t-1+d, 1]
            end
        end
    end
    return yield_c
end
    
## deterministic yields for noise=0, relative to beginning of pd.
determbop(me::CIR) =
    [me.v_infty + (1-me.a*me.dt)^t * (me.v_init-me.v_infty)
     for t = 0:me.n_p, d= 1:me.n ]

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

## Private functions -----------------------------------------------------------
function vbopcir(mc::Int,
              v_init::Float64,
              a::Float64,
              v_infty::Float64,
              tf::TimeFrame,
              noise::Array{Float64,2}) 
    v_bop = Array(Float64, tf.n_p+1)
    for t = 0:tf.n_p
        if t==0
            v_bop[t+1] = v_init
        else
            v_bop[t+1] = v_bop[t] + a * ( v_infty - v_bop[t] ) * tf.dt +
                         sqrt( abs(v_bop[t]) * tf.dt ) * noise[mc,t]
        end
    end
    return v_bop
end
