## Constructors ----------------------------------------------------------------

function InvestCost(tf::TimeFrame,
                    cost_rel::Vector{Float64},
                    cost_abs::Vector{Float64},
                    cost_infl_rel::Vector{Float64},
                    cost_infl_abs::Vector{Float64},
                    n_c::Int = tf.n_c
                    )
  rel_c = Array(Float64, n_c)
  abs_c = Array(Float64, n_c)
  for t = 1:n_c
    τ = min(t, floor(min(length(cost_rel), length(cost_abs)) / tf.n_dt))
    rel_c[t] = mean(cost_rel[(τ - 1) * tf.n_dt + 1 : τ * tf.n_dt])
    abs_c[t] = sum(cost_abs[(τ - 1) * tf.n_dt + 1 : τ * tf.n_dt])
  end
  InvestCost(cost_rel, cost_abs, cost_infl_rel, cost_infl_abs,
             cost_rel .* exp(cumsum(cost_infl_rel)),
             cost_abs .*exp(cumsum(cost_infl_abs)),
             rel_c, abs_c,
             zeros(Float64, length(cost_rel)))
end

