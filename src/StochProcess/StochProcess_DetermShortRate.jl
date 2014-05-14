## Constructors ----------------------------------------------------------------
## Standard constructor
function DetermShortRate (name::Symbol,
                          cpnt::Vector{Any},
                          yield::Array{Float64, 3},
                          tf::TimeFrame,
                          n::Int,
                          n_mc::Int
                          )
    dt = tf.dt
    n_p = tf.n_p
    if size(yield) != (n_mc, n_p + 1, n)
        error("DetermShortRate: yield has incorrect dimensions")
    end
    init = yield[:,1,1]
    cpnt_id = Dict(cpnt, 1:length(cpnt))
    DetermShortRate(name, cpnt, cpnt_id, init, n, yield,
                    n_mc, dt, n_p )
end

## Constructor interface to CapMkt
function DetermShortRate(name::Symbol,
                         cpnt::Vector{Any},
                         yield_input::Vector{Float64},
                         tf::TimeFrame,
                         n_mc::Int)
    n = 1
    while length(yield_input) < (tf.n_p + 1)
       yield_input = vcat(yield_input, yield_input[end])
    end
    yield = Array(Float64, n_mc, tf.n_p + 1, n)
    for mc = 1:n_mc
        yield[mc,:,1] = yield_input
    end
    DetermShortRate( name, cpnt, yield, tf, n, n_mc)
end


## Interface functions ---------------------------------------------------------
function show(io::IO, me::DetermShortRate)
    println(io,"Type       : $(string(typeof(me)))")
    println(io,"name       : $(me.name)")
    println(io,"dt         : $(me.dt)")
    println(io,"(n_mc n_p) : ($(me.n_mc) $(me.n_p))")
end

function yieldeoc(me::DetermShortRate,
                n_mc::Int,
                tf_curr::TimeFrame, ## in general different from CapMkt.tf
                init_c::Float64)
    ## This function calculates the yield retrospectively at eoc
    while length(yield_input) < tf_curr.n_p  + tf_curr.n_dt
       me.yield_input = vcat(me.yield_input, me.yield_input[end])
    end
    yield_c = zeros(Float64, n_mc, tf_curr.n_c + 1, 1)
    ## |-.-.-.-|-.-.-.-|-.-.-.-|-.  here: tf.n_dt = 4, tf.n_c = 3
    ##         ^                          t=2  (unit: n_c)
    ##         t                          tau = (t-1) * tf.n_t + 1 (unit: n_p)
    ##         |-| known at time t: yield_mc for this interval
    ## Assumption: interest rate will not change for the rest of the cycle
    for mc = 1:n_mc
        for t = 1:(tf.n_c + 1)
            for d = 1:tf.n_dt
                yield_c[mc,t] += me.yield_input[1, tf.n_dt*(t-1) + d, 1]
            end
        end
    end
    return (yield_c .+ (init_c - yield_c[1,1]))
end


## deterministic yields for noise=0, relative to beginning of pd.
## we simply take the average for each time step
determbop(me::DetermShortRate) = vec(mean(me.yield,1))

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
