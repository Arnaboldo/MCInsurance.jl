## Constructors ----------------------------------------------------------------
## Standard constructor
function ManualShortRate (name::Symbol,
                          cpnt::Vector{Any},
                          yield_manual::Array{Float64, 3},
                          tf::TimeFrame
                          )
    n = 1
    n_mc = size(yield_manual, 1)
    dt = tf.dt
    n_p = tf.n_p
    init = yield_manual[:,1,1]
    if size(yield_manual) != (n_mc, n_p + 1, n)
        error("ManualShortRate: yield_manual has incorrect dimensions")
    end
    cpnt_id = Dict(cpnt, 1:length(cpnt))
    ManualShortRate(name, cpnt, cpnt_id, init, n, yield_manual, n_mc, dt, n_p )
end

## Constructor interface to CapMkt
function ManualShortRate(name::Symbol,
                         cpnt::Vector{Any},
                         init::Vector{Float64},
                         param::Array{Float64, 3},
                         tf::TimeFrame,
                         cov::Array{Float64, 2},
                         noise::Array{Float64,3})
    # We ignore init, cov, noise.
    # param contains the yield for very mc and every t  
    ManualShortRate( name, cpnt, param, tf)
end


## Interface functions ---------------------------------------------------------
function show(io::IO, me::ManualShortRate)
    println(io,"Type       : $(string(typeof(me)))")
    println(io,"name       : $(me.name)")
    println(io,"dt         : $(me.dt)")
    println(io,"(n_mc n_p) : ($(me.n_mc) $(me.n_p))")
end


function yieldeoc(me::ManualShortRate,
                n_mc::Int,
                tf::TimeFrame,
                init_c::Float64)
    ## This function calculates the yield retrospectively at eoc
    yield_c = zeros(Float64, n_mc, tf.n_c + 1, 1)
    ind = rand(DiscreteUniform(1,me.n_mc), n_mc)
    ## |-.-.-.-|-.-.-.-|-.-.-.-|-.  here: tf.n_dt = 4, tf.n_c = 3
    ##         ^                          t=2  (unit: n_c)
    ##         t                          tau = (t-1) * tf.n_t + 1 (unit: n_p)
    ##         |-| known at time t: yield_mc for this interval
    ## Assumption: interest rate will not change for the rest of the cycle
    for mc = 1:n_mc
        for t = 1:(tf.n_c)
            for d = 1:tf.n_dt
                yield_c[mc,t] += me.yield[ind[mc], tf.n_dt*(t-1) + d, 1]
            end
        end
        ## for cycle tf.n_c+1 we only have the initial period yield
        yield_c[mc,tf.n_c+1] = tf.n_dt * me.yield[ind[mc], tf.n_p + 1, 1]
    end
    return (yield_c .+ (init_c .- yield_c[:,1]))
end

## deterministic yields for noise=0, relative to beginning of pd.
## we simply take the average for each time step
determbop(me::ManualShortRate) = vec(mean(me.yield,1))

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
