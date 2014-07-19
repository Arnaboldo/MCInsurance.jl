## Interface  ------------------------------------------------------------------

## The following function is overridden for
##  -  DetermShortRate
##  -  ManualShortRate
function yieldeoc(me::ProcessShortRate,
                  n_mc::Int,
                  n_c::Int,
                  n_dt::Int,
                  yield_init_c::Float64)
  n_p = n_c * n_dt
  dt = n_c / n_p
  ## This function calculates the yield retrospectively at eoc
  yield_mc = Array(Float64, 1, n_p + n_dt + 1, 1)
  yield_c = zeros(Float64, n_mc, n_c + 1, 1)
  if me.cov > eps()
    noise = reshape(rand(Normal(0,sqrt(me.cov)), n_mc * (n_p + n_dt) ),
                    n_mc, n_p + n_dt)
  else
    noise = zeros(Float64, n_mc, n_p + n_dt)
  end
  ## |-.-.-.-|-.-.-.-|-.-.-.-|-.  here: tf.n_dt = 4, tf.n_c = 3
  ##         ^                          t=2  (unit: n_c)
  ##         t                          tau = (t-1) * tf.n_t + 1 (unit: n_p)
  ##         |-| known at time t: yield_mc for this interval
  ## Assumption: interest rate will not change for the rest of the cycle
  for mc = 1:n_mc
    yield_mc[1, :, 1] =
      yieldbop(me, yield_init_c * dt, n_p + n_dt, vec(noise[mc, :]))
    for t = 1:(n_c + 1)
      for d = 1:n_dt
        yield_c[mc, t] += yield_mc[1, n_dt * (t - 1) + d, 1]
      end
    end
  end
  return yield_c
end

## Private ---------------------------------------------------------------------
