## Constructors ----------------------------------------------------------------
## Standard constructor
function CIR (name::Symbol,
              cpnt::Vector{Any},
              init::Float64,
              a::Float64,
              yield_infty::Float64,
              tf::TimeFrame,
              cov::Float64,
              noise::Array{Float64,2} )
  n = 1
  n_mc = size(noise,1)
  dt = tf.dt
  n_p = tf.n_p
  cpnt_id = Dict(cpnt, 1:length(cpnt))
  yield = Array(Float64, n_mc, n_p + 1, n)
  proc = CIR(name, cpnt, cpnt_id, init, a, yield_infty, cov, noise, n, yield,
             n_mc, n_p )
  cycle2period!(proc, tf)
  for mc = 1:n_mc
    proc.yield[mc,:,1] =
      yieldbop(proc, 1, proc.init, n_p, vec(proc.noise[mc,:]))
  end
  proc
end

## Constructor interface to CapMkt
function CIR(name::Symbol,
             cpnt::Vector{Any},
             init::Vector{Float64},
             param::Vector{Float64},
             tf::TimeFrame,
             cov::Array{Float64, 2},
             noise::Array{Float64,3})
  CIR(name, cpnt, init[1], param[1], param[2],
      tf, cov[1,1], noise[:,:,1])
end

## Constructor with automatic generation of noise
function CIR(name::Symbol,
             cpnt::Vector{Any},
             init::Float64,
             a::Float64,
             yield_infty::Float64,
             tf::TimeFrame,
             cov::Float64,
             n_mc::Int )
  noise =  reshape(rand(Normal(0,sqrt(cov)), n_mc*tf.n_p), n_mc, tf.n_p )
  CIR( name, cpnt, init, a, yield_infty, tf, cov, noise )
end

# Interface -------------------------------------------------------------------
function show(io::IO, me::CIR)
  print(io,"Type          : ");
  println(io, string(typeof(me)))
  print(io,"name          : "); println(io,me.name)
  print(io,"init     : "); println(io,me.init)
  print(io,"(a, yield_infty)  : "); print(io,[me.a,me.yield_infty]')
  print(io,"cov           : "); println(io,me.cov)
  print(io,"(n_mc n_p): "); print(io, size(me.noise))
end


## deterministic yields for noise=0, relative to beginning of pd.
determbop(me::CIR) =
  [me.yield_infty + (1-me.a)^(t-1) * (me.init-me.yield_infty)
   for t = 1:(me.n_p+1), d= 1:me.n ]

## forward rate relative to beginning of period
function forwardbop(me::CIR, mc::Int, t::Int, delta_t::Int)
  gamma = sqrt( me.a^2 + 2me.cov )
  dexp_gamma = exp( gamma * delta_t ) - 1
  B = 2dexp_gamma / ( (gamma+me.a)dexp_gamma +2gamma )
  A = ( 2gamma * exp( (gamma+me.a)delta_t / 2 ) /
         ( (gamma+me.a)dexp_gamma +2gamma )
       )^( 2me.a * me.yield_infty / me.cov )
  return (B * me.yield[mc,t,1] -log(A)) / delta_t
end

function forwardbop(me::CIR, t::Int, delta_t::Int)
  gamma = sqrt( me.a^2 + 2me.cov )
  dexp_gamma = exp( gamma * delta_t ) - 1
  B = 2dexp_gamma / ( (gamma+me.a)dexp_gamma +2gamma )
  A = ( 2gamma * exp( (gamma+me.a)delta_t / 2 ) /
         ( (gamma+me.a)dexp_gamma +2gamma )
       )^( 2me.a * me.yield_infty / me.cov )
  return (B * me.yield[:,t,1] -log(A)) / delta_t
end

procinfo2det(me::CIR) = procinfo(me)

## Private ---------------------------------------------------------------------
function cycle2period!(me::CIR, tf::TimeFrame)
  # assumption: init, yield_infty, cov, noise are given with respect to cycles
  # me.a: not changed
  me.yield_infty *= tf.dt
  me.init *= tf.dt
  me.cov *= tf.dt
  me.noise .*= sqrt(tf.dt)
end

function yieldbop(me::CIR,
                  t_init::Int, # initial period, not used
                  init::Float64,
                  n_p::Int,
                  noise_vec::Vector{Float64})
  yield = Array(Float64, n_p + 1)
  for t = 1:(n_p + 1)
    if t==1
      yield[t] = init
    else
      yield[t] = yield[t-1] + me.a * ( me.yield_infty - yield[t-1] ) +
        sqrt(abs(yield[t-1])) * noise_vec[t-1]
    end
  end
  return yield
end

function procinfo(me::CIR)
  proc_info = infoskeleton(me)
  proc_info.param = [me.a, me.yield_infty]
  return proc_info
end
