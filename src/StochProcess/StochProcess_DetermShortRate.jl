## Constructors ----------------------------------------------------------------
## Standard constructor, interface to CapMkt
function DetermShortRate (name::Symbol,
                          cpnt::Vector{Any},
                          yield_input::Vector{Float64},
                          tf::TimeFrame,
                          n_mc::Int )
  n = 1
  dt = tf.dt
  n_p = tf.n_p
  yield = Array(Float64, n_mc, n_p + 1, n)
  while length(yield_input) < n_p + 1
    yield_input = vcat(yield_input, yield_input[end])
  end
  for mc = 1:n_mc
    yield[mc,:,1] = yield_input[1:(n_p+1)]
  end
  init = yield_input[1]
  cpnt_id = Dict(cpnt, 1:length(cpnt))
  proc = DetermShortRate(name, cpnt, cpnt_id, init, n, yield, yield_input,
                         n_mc, n_p )
  cycle2period!(proc, tf)
  proc
end

## Interface  ------------------------------------------------------------------
function show(io::IO, me::DetermShortRate)
  println(io,"Type       : $(string(typeof(me)))")
  println(io,"name       : $(me.name)")
  println(io,"(n_mc n_p) : ($(me.n_mc) $(me.n_p))")
end

function yieldeoc(me::DetermShortRate,
                  t::Int,
                  init_c::Float64,
                  n_mc::Int,
                  n_c::Int,
                  n_dt::Int)
  ## This function calculates the yield retrospectively at eoc
  n_p = n_c * n_dt
  yield_input = deepcopy(me.yield_input)
  while length(yield_input) < n_p  + t * n_dt
    yield_input = vcat(yield_input, yield_input[end])
  end
  yield_c = zeros(Float64, n_mc, n_c + 1, 1)
  for mc = 1:n_mc
    for τ = 1:(n_c + 1)
      for d = 1:n_dt
        yield_c[mc, τ, 1] += yield_input[(t-1) + n_dt * (τ-1)  + d]
      end
    end
  end
  return yield_c[:,:,1] .+ (init_c - mean(yield_c[:,1,1]))
end


## deterministic yields for noise=0, relative to beginning of pd.
## we simply take the average for each time step
determbop(me::DetermShortRate) = vec(mean(me.yield,1))

## forward rate relative to beginning of period
function forwardbop(me::DetermShortRate,
                    mc::Int,
                    t::Int,
                    delta_t::Int)
  last_init = min(length(yield_init), t+delta_t -1)
  excess_time = t+deta_t-1 - last_init
  if  excess_time > 0
    excess_yield = excess_time * yield_init[end]
  else
    excess_yield = 0.0
  end
  return (sum(yield_init[t:(t+delta_t-1)]) + excess_yield) / delta_t
end

function forwardbop(me::DetermShortRate,
                    t::Int,
                    delta_t::Int)
  forward_bop = forwardbop(me,1,t,delta_t)
  return [forward_bop for mc = 1:me.n_mc]
end

procinfo2det(me::DetermShortRate) = procinfo(me)

isstoch(me::DetermShortRate) = false

## Private ---------------------------------------------------------------------
function cycle2period!(me::DetermShortRate, tf::TimeFrame)
  ## assumption: init, yield are given with respect to cycles
  me.yield .*= tf.dt
  me.yield_input .*= tf.dt
  me.init *= tf.dt
end

function procinfo(me::DetermShortRate)
  proc_info = infoskeleton(me)
  proc_info.yield_determ = deepcopy(me.yield_input)
  return proc_info
end

