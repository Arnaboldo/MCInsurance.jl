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
  cpnt_id = Dict(cpnt, 1:length(cpnt))
  proc =  GeomBrownian(name, cpnt, cpnt_id, init, drift,  cov, noise, n,
                       zeros(Float64, n_mc, n_p+1, n), # v_bop
                       Array(Float64, n_mc, n_p, n),   # yield
                       n_mc, n_p  )
  cycle2period!(proc, tf)

  for mc = 1:n_mc, t = 0:n_p, d =1:n
    if t==0
      proc.v_bop[mc, t+1, d] = proc.init[d]
    else
      proc.v_bop[mc, t+1, d] =
        proc.v_bop[mc, t, d] * exp((proc.drift[d] - 0.5 * proc.cov[d,d])
                                   + proc.noise[mc,t,d])
    end
  end
  for t = 1:n_p
    proc.yield[:,t,:] = log(proc.v_bop[:,t+1,:] ./ proc.v_bop[:,t,:])
  end

  proc
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

## Interface  ------------------------------------------------------------------
function show(io::IO, me::GeomBrownian)
  print(io,"Type             : ");
  println(io, string(typeof(me)))
  print(io,"name              : "); println(io,me.name)
  print(io,"cpnt'           : "); println(io,transpose(me.cpnt))
  print(io,"init'           : "); println(io,me.init')
  print(io,"drift'            : "); println(io,me.drift')
  print(io,"cov               : ")
  println(io,me.cov)
  print(io,"(n_mc n_p n)    : "); print(io, size(me.noise))
end

determbop(me::GeomBrownian) =
  [ me.init[d] * exp((t-1) * me.drift[d]) for t = 1:(me.n_p+1), d= 1:me.n ]


function procinfo2det(me::GeomBrownian)
  proc_info = procinfo(me)
  variance = [me.cov[i,i] for i in 1:me.n]
  proc_info.param = proc_info.param .- variance / 2.0
  return proc_info
end
## Private ---------------------------------------------------------------------
function cycle2period!(me::GeomBrownian, tf::TimeFrame)
  # assumption: drift, cov, noise are given with respect to cycles
  # me.a: not changed
  me.drift *= tf.dt
  me.cov .*= tf.dt
  me.noise .*= sqrt(tf.dt)
end

function procinfo(me::GeomBrownian)
  proc_info = infoskeleton(me)
  proc_info.param = me.drift
  return proc_info
end
