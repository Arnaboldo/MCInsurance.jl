## Constructors ----------------------------------------------------------------

function InvestCost(tf::TimeFrame,
                    cost_norm_rel_c::Vector{Float64},
                    cost_norm_abs_c::Vector{Float64},
                    cost_infl_rel_c::Vector{Float64},
                    cost_infl_abs_c::Vector{Float64},
                    n_c::Int = tf.n_c
                    )
  function cycle2period(x::Vector{Float64}, tf)
    result = zeros(Float64, tf.n_p)
    result[1:tf.n_dt] = x[1]
    for t = 2:tf.n_c
      result[(t-1)*tf.n_dt:t*tf.n_dt] = linspace( x[t-1], x[t], tf.n_dt + 1)
    end
    return result/tf.n_dt
  end
  extend(x, n_c) = [x, x[end] * ones(Float64, max(0,max(n_c, tf.n_c)-length(x)))]
  norm_rel_c = extend(cost_norm_rel_c, n_c)
  norm_abs_c = extend(cost_norm_abs_c, n_c)
  infl_rel_c = extend(cost_infl_rel_c, n_c)
  infl_abs_c = extend(cost_infl_abs_c, n_c)
  norm_rel = cycle2period(norm_rel_c, tf)
  norm_abs = cycle2period(norm_abs_c, tf)
  infl_rel = cycle2period(infl_rel_c, tf)
  infl_abs = cycle2period(infl_abs_c, tf)
  rel_c =  norm_rel_c .* exp(cumsum(infl_rel_c))
  abs_c =  norm_abs_c .* exp(cumsum(infl_abs_c))
  rel =  norm_rel .* exp(cumsum(infl_rel))
  abs =  norm_abs .* exp(cumsum(infl_abs))

  InvestCost(#norm_rel_c, norm_abs_c, norm_rel, norm_abs,
             #infl_rel_c, infl_abs_c, infl_rel, infl_abs,
             rel_c, abs_c, rel, abs,
             zeros(Float64, tf.n_p))
end

## Interface -------------------------------------------------------------------
function prepend_c(me::InvestCost, pre_c::Vector{Float64})
  result = deepcopy(me)
  result.rel_c = vcat(pre_c[1], result.rel_c)
  result.abs_c = vcat(pre_c[2], result.abs_c)
  return result
end

slice_c(me::InvestCost, c_start::Int, c_end::Int) =
  InvestCost(me.rel_c[c_start:c_end],
             me.abs_c[c_start:c_end],
             me.rel[c_start:c_end],
             me.abs[c_start:c_end],
             me.total[c_start:c_end])

