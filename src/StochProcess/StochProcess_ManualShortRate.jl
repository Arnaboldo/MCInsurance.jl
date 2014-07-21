## Constructors ----------------------------------------------------------------
## Standard constructor
function ManualShortRate (name::Symbol,
                          cpnt::Vector{Any},
                          yield_input::Array{Float64, 3},
                          tf::TimeFrame
                          )
  n = 1
  n_mc = size(yield_input, 1)
  dt = tf.dt
  n_p = tf.n_p

  init = yield_input[1,1,1]
  if size(yield_input) != (n_mc, n_p + 1, n)
    error("ManualShortRate: yield_input has incorrect dimensions")
  end
  for mc = 1:n_mc
    if init != yield_input[mc,1,1]
      error("ManualShortRate: yield_input[$mc,1,1] != yield_input[1,1,1]")
    end
  end
  cpnt_id = Dict(cpnt, 1:length(cpnt))
  proc = ManualShortRate(name, cpnt, cpnt_id, init, n, yield_input, n_mc, n_p)
  cycle2period!(proc, tf)
  proc
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
  # param contains the yield for each mc and each t
  ManualShortRate( name, cpnt, param, tf)
end

## Interface  ------------------------------------------------------------------
function show(io::IO, me::ManualShortRate)
  println(io,"Type       : $(string(typeof(me)))")
  println(io,"name       : $(me.name)")
  println(io,"(n_mc n_p) : ($(me.n_mc) $(me.n_p))")
end

function yieldeoc(me::ManualShortRate,
                  t::Int,
                  init_c::Float64,
                  n_mc::Int,
                  n_c::Int,
                  n_dt::Int)
  n_p = n_c * n_dt
  ## This function calculates the yield retrospectively at eoc
  yield_c = zeros(Float64, n_mc, n_c + 1, 1)
  ind = Array(Int, n_mc, n_p )
  ind = rand!(DiscreteUniform(1, me.n_mc), ind)

  yield_c[:, 1, 1] = mean(yield_c[:,1,1])
  for mc = 1:n_mc
    for τ = 2:(n_c + 1)
      for d = 1:n_dt
        yield_c[mc, τ, 1] +=
          me.yield[ind[mc,τ], t - 1 + n_dt * (τ - 1) + d, 1]
      end
    end
  end
  return yield_c .+ (init_c .- mean(yield_c[:,1,1]))
end


## deterministic yields for noise=0, relative to beginning of pd.
## we simply take the average for each time step
determbop(me::ManualShortRate) = vec(mean(me.yield,1))

## forward rate relative to beginning of period
function forwardbop(me::ManualShortRate,
                    mc::Int,
                    t::Int,
                    delta_t::Int)
  warn("ManualShortRate.forwardbop: Code not implented, gives 0")
  return 0.
end

function forwardbop(me::ManualShortRate,
                    t::Int,
                    delta_t::Int)
  warn("ManualShortRate.forwardbop: Code not implented, gives [0, ..., 0]")
  return [ 0. for mc in 1:me.n_mc]
end

## Private ---------------------------------------------------------------------
function cycle2period!(me::ManualShortRate, tf::TimeFrame)
  ## assumption: init, yield are given with respect to cycles
  me.yield .*= tf.dt
  me.init *= tf.dt
end


