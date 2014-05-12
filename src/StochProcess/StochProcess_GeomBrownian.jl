
## Constructors --------------------------------------------------
## Standard, Interface to AssetGroupIndex
function GeomBrownian(name::Symbol,
                      labels::Vector{Symbol},
                      v_init::Vector{Float64},
                      drift::Vector{Float64},
                      tf::TimeFrame,
                      cov::Array{Float64,2},
                      noise::Array{Float64,3} )

    dim = length(v_init)
    n_mc = size(noise,1)
    dt = tf.dt
    n_p = tf.n_p

    v_bop = zeros(Float64, (n_mc, n_p+1, dim))
    for mc = 1:n_mc, t = 0:n_p, d =1:dim
        if t==0
            v_bop[mc, t+1, d] = v_init[d]
        else
            v_bop[mc, t+1, d] =
                v_bop[mc, t, d] *
            exp( (drift[d] - 0.5 * cov[d,d]) * dt  +
                sqrt(dt) * noise[mc,t,d] )
        end
    end
    yield = Array(Float64, (n_mc, n_p, dim))
    for t = 1:n_p
        yield[:,t,:] = log(v_bop[:,t+1,:] ./ v_bop[:,t,:]) / dt
    end

    comp_int = Dict(labels, 1:length(labels))

    GeomBrownian(name, labels, comp_int, v_init, drift,
                 cov, noise, dim, v_bop, yield,
                 n_mc, dt, n_p  )
end

## Construct Process including noise
function GeomBrownian(name::Symbol,
                      labels::Vector{Symbol},
                      v_init::Vector{Float64},
                      drift::Vector{Float64},
                      tf::TimeFrame,
                      cov::Array{Float64,2},
                      n_mc::Int64
                      )
    noise = reshape(rand( MvNormal(cov), n_mc*tf.n_p )',
                    n_mc, tf.n_p, length(v_init) )


    GeomBrownian(name, labels, v_init, drift,
                 tf, cov, noise )
end

## Utility functions ---------------------------------------------
function show(io::IO, me::GeomBrownian)
    print(io,"Type             : ");
    println(io, string(typeof(me)))
    print(io,"name              : "); println(io,me.name)
    print(io,"labels'           : "); println(io,transpose(me.labels))
    print(io,"v_init'           : "); println(io,me.v_init')
    print(io,"drift'            : "); println(io,me.drift')
    print(io,"cov               : ")
    println(io,me.cov)
    print(io,"dt                : "); println(io,me.dt)
    print(io,"(n_mc n_p dim)    : "); print(io, size(me.noise))
end

determbop(me::GeomBrownian) =
    [ me.v_init[d] * exp( (t-1) * me.drift[d] * me.dt )
    for t = 1:(me.n_p+1), d= 1:me.dim ]
