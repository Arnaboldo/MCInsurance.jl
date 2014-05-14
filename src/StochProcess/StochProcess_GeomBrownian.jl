## Constructors ----------------------------------------------------------------
## Standard constructor, interface to CapMkt
function GeomBrownian(name::Symbol,
                      cpnt::Vector{Any},
                      init::Vector{Float64},
                      drift::Vector{Float64},
                      tf::TimeFrame,
                      cov::Array{Float64,2},
                      noise::Array{Float64,3} )

    n = length(init)
    n_mc = size(noise,1)
    dt = tf.dt
    n_p = tf.n_p

    v_bop = zeros(Float64, (n_mc, n_p+1, n))
    for mc = 1:n_mc, t = 0:n_p, d =1:n
        if t==0
            v_bop[mc, t+1, d] = init[d]
        else
            v_bop[mc, t+1, d] =
                v_bop[mc, t, d] *
            exp( (drift[d] - 0.5 * cov[d,d]) * dt  +
                sqrt(dt) * noise[mc,t,d] )
        end
    end
    yield = Array(Float64, (n_mc, n_p, n))
    for t = 1:n_p
        yield[:,t,:] = log(v_bop[:,t+1,:] ./ v_bop[:,t,:]) / dt
    end

    cpnt_id = Dict(cpnt, 1:length(cpnt))

    GeomBrownian(name, cpnt, cpnt_id, init, drift,
                 cov, noise, n, v_bop, yield,
                 n_mc, dt, n_p  )
end

## Constructor with automatic generation of noise

GeomBrownian(name::Symbol, cpnt::Vector{Symbol}, init::Vector{Float64},
             drift::Vector{Float64}, tf::TimeFrame, cov::Array{Float64,2},
             n_mc::Int64) =
                 GeomBrownian(name, convert(Array{Any,1}, cpnt), init, drift,
                              tf, cov, n_mc)

function GeomBrownian(name::Symbol,
                      cpnt::Vector{Any},
                      init::Vector{Float64},
                      drift::Vector{Float64},
                      tf::TimeFrame,
                      cov::Array{Float64,2},
                      n_mc::Int64
                      )
    noise = reshape(rand( MvNormal(cov), n_mc*tf.n_p )',
                    n_mc, tf.n_p, length(init) )


    GeomBrownian(name, cpnt, init, drift,
                 tf, cov, noise )
end

## Interface functions ---------------------------------------------------------
function show(io::IO, me::GeomBrownian)
    print(io,"Type             : ");
    println(io, string(typeof(me)))
    print(io,"name              : "); println(io,me.name)
    print(io,"cpnt'           : "); println(io,transpose(me.cpnt))
    print(io,"init'           : "); println(io,me.init')
    print(io,"drift'            : "); println(io,me.drift')
    print(io,"cov               : ")
    println(io,me.cov)
    print(io,"dt                : "); println(io,me.dt)
    print(io,"(n_mc n_p n)    : "); print(io, size(me.noise))
end

determbop(me::GeomBrownian) =
    [ me.init[d] * exp( (t-1) * me.drift[d] * me.dt )
    for t = 1:(me.n_p+1), d= 1:me.n ]
