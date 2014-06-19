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
  cpnt_id = Dict(cpnt, 1:length(cpnt))
  is_bankrupt = false
  proc = Brownian(name, cpnt, cpnt_id, init, drift,  cov, noise, n,
                  zeros(Float64, n_mc, n_p+1, n), # v_bop
                  Array(Float64, n_mc, n_p, n),   # yield
                  n_mc, n_p )
  cycle2period!(proc, tf)

  for mc = 1:n_mc
    for d = 1:n
      for t = 1:(n_p+1)
        if t==1
          proc.v_bop[mc,t,d] = proc.init[d]
        else
          proc.v_bop[mc,t,d] =
            proc.v_bop[mc,t-1,d] + proc.drift[d] +
              proc.noise[mc,t-1,d]
          if proc.v_bop[mc,t,d] <= 0.0 ## bankruptcy
            for tau = t:(n_p+1)
              proc.v_bop[mc,tau,d] = 0
            end
            is_bankrupt = true
            break
          end
        end
      end
    end
  end
  for mc = 1:n_mc, t = 1:n_p, d = 1:n
    if proc.v_bop[mc,t+1,d] < eps()
      if proc.v_bop[mc,t,d] > eps()
        proc.yield[mc,t,d] = -1.0
      else
        proc.yield[mc,t,d] = 0.0
      end
    else
      proc.yield[mc,t,d] =
        log(max(eps(), proc.v_bop[mc,t+1,d] ./ proc.v_bop[mc,t,d]))
    end
  end
  if is_bankrupt
    info("Brownian: On some paths the index has become non-positive. From ",
         "then onwards it has been set to zero (index ceases to exist) ")
  end
  proc
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

## Interface -------------------------------------------------------------------
function show(io::IO, me::Brownian)
  print(io,  "Type            : ");
  println(io, string(typeof(me)))
  print(io,  "name           : "); println(io,me.name)
  println(io,"cpnt         : "); println(io,transpose(me.cpnt))
  print(io,  "init'        : "); println(io,me.init')
  print(io,  "drift'         : "); println(io,me.drift')
  print(io,  "cov            : ")
  print(io,me.cov)
  print(io,  "(n_mc n_p n) : "); print(io, size(me.noise))
end

determbop(me::Brownian) =
  [ me.init[d] + (t-1) * me.drift[d] for t = 1:(me.n_p+1), d= 1:me.n ]

## Private ---------------------------------------------------------------------
function cycle2period!(me::Brownian, tf::TimeFrame)
  # assumption: drift, cov, noise  are given with respect to cycles
  # me.a: not changed
  me.drift *= tf.dt
  me.cov .*= tf.dt
  me.noise .*= sqrt(tf.dt)
end

