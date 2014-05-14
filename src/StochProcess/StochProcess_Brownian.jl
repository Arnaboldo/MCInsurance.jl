## Constructors ----------------------------------------------------------------
## Standard constructor, interface to CapMkt
function Brownian(name::Symbol,
                  cpnt::Vector{Any},
                  init::Vector{Float64},
                  drift::Vector{Float64},
                  tf::TimeFrame,
                  cov::Array{Float64,2},
                  noise::Array{Float64,3})

    n = length(init)
    n_mc = size(noise,1)
    dt = tf.dt
    n_p = tf.n_p
    is_bankrupt = false
    v_bop = zeros(Float64, (n_mc, n_p+1, n))
    for mc = 1:n_mc
        for d = 1:n
            for t = 1:(n_p+1) 
                if t==1
                    v_bop[mc,t,d] = init[d]
                else
                    v_bop[mc,t,d] = v_bop[mc,t-1,d] + drift[d] * dt +
                                    sqrt(dt) * noise[mc,t-1,d]
                    if v_bop[mc,t,d] <= 0.0 ## bankruptcy
                        for tau = t:(n_p+1)
                            v_bop[mc,tau,d] = 0
                        end
                        is_bankrupt = true
                        break
                    end
                end
            end
        end
    end  
    yield = Array(Float64, (n_mc, n_p, n))
    for mc = 1:n_mc, t = 1:n_p, d = 1:n
        if v_bop[mc,t+1,d] < eps(1.0)
            if v_bop[mc,t,d] > eps(1.0)
                yield[mc,t,d] = -1.0
            else
                yield[mc,t,d] = 0.0
            end
        else
            yield[mc,t,d] = log(max(eps(), v_bop[mc,t+1,d]./v_bop[mc,t,d])) / dt
        end
    end
    if is_bankrupt
        info("Brownian: On some paths the index has become non-positive. From ",
             "then onwards it has been set to zero (index ceases to exist) ")
    end

    cpnt_id = Dict(cpnt, 1:length(cpnt))

    Brownian(name, cpnt, cpnt_id, init, drift,
             cov, noise, n, v_bop, yield,
             n_mc, dt, n_p
             )
end

## Constructor with automatic generation of noise
function Brownian (name::Symbol,
                   cpnt::Vector{Any},
                   init::Vector{Float64},
                   drift::Vector{Float64},
                   tf::TimeFrame,
                   cov::Array{Float64,2},
                   n_mc::Int )

    noise = reshape(rand( MvNormal(cov), n_mc*tf.n_p )',
                    n_mc, tf.n_p, length(init) )
    Brownian(name, cpnt, init, drift, tf, cov, noise )
end

## Interface functions ---------------------------------------------------------
function show(io::IO, me::Brownian)
    print(io,  "Type            : ");
    println(io, string(typeof(me)))
    print(io,  "name           : "); println(io,me.name)
    println(io,"cpnt         : "); println(io,transpose(me.cpnt))
    print(io,  "init'        : "); println(io,me.init')
    print(io,  "drift'         : "); println(io,me.drift')
    print(io,  "cov            : ")
    print(io,me.cov)
    print(io,  "dt             : "); println(io,me.dt)
    print(io,  "(n_mc n_p n) : "); print(io, size(me.noise))
end

determbop(me::Brownian) =
    [ me.init[d] + (t-1) * me.drift[d] * me.dt
     for t = 1:(me.n_p+1), d= 1:me.n ]

