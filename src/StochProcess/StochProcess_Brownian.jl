## Constructors ----------------------------------------------------------------
## Standard constructor, interface to CapMkt
function Brownian(name::Symbol,
                  cpnt::Vector{Any},
                  v_init::Vector{Float64},
                  drift::Vector{Float64},
                  tf::TimeFrame,
                  cov::Array{Float64,2},
                  noise::Array{Float64,3})

    n = length(v_init)
    n_mc = size(noise,1)
    dt = tf.dt
    n_p = tf.n_p

    v_bop = zeros(Float64, (n_mc, n_p+1, n))
    for mc = 1:n_mc, t = 0:n_p, d =1:n
        if t==0
            v_bop[mc, t+1, d] = v_init[d]
        else
            v_bop[mc, t+1, d] =
                v_bop[mc, t, d] +
            drift[d] * dt + sqrt(dt) * noise[mc,t,d]
        end
    end  
    yield = Array(Float64, (n_mc, n_p, n))
    negative_values = false
    for mc = 1:n_mc, t = 1:n_p, d = 1:n
        if (v_bop[mc,t+1,d] <0) |  (v_bop[mc,t,d] <0)
            negative_values = true
            yield[mc,t,d] = -999.
        else
            yield[mc,t,d] =
                log( max(eps(),
                         v_bop[mc,t+1,d] ./ v_bop[mc,t,d])) / dt
        end
    end
    if negative_values
        warn("Brownian: Some projected values are negative.",
             " Corresponding yields are set to -999.")
    end

    cpnt_id = Dict(cpnt, 1:length(cpnt))

    Brownian(name, cpnt, cpnt_id, v_init, drift,
             cov, noise, n, v_bop, yield,
             n_mc, dt, n_p
             )
end

## Constructor with automatic generation of noise
function Brownian (name::Symbol,
                   cpnt::Vector{Any},
                   v_init::Vector{Float64},
                   drift::Vector{Float64},
                   tf::TimeFrame,
                   cov::Array{Float64,2},
                   n_mc::Int )

    noise = reshape(rand( MvNormal(cov), n_mc*tf.n_p )',
                    n_mc, tf.n_p, length(v_init) )
    Brownian(name, cpnt, v_init, drift, tf, cov, noise )
end

## Interface functions ---------------------------------------------------------
function show(io::IO, me::Brownian)
    print(io,  "Type            : ");
    println(io, string(typeof(me)))
    print(io,  "name           : "); println(io,me.name)
    println(io,"cpnt         : "); println(io,transpose(me.cpnt))
    print(io,  "v_init'        : "); println(io,me.v_init')
    print(io,  "drift'         : "); print\ln(io,me.drift')
    print(io,  "cov            : ")
    print(io,me.cov)
    print(io,  "dt             : "); println(io,me.dt)
    print(io,  "(n_mc n_p n) : "); print(io, size(me.noise))
end

determbop(me::Brownian) =
    [ me.v_init[d] + (t-1) * me.drift[d] * me.dt
     for t = 1:(me.n_p+1), d= 1:me.n ]

