## Constructors ----------------------------------------------------------------

function Fixed(invest::Invest, bkts::Buckets)
  extend(x, nc) = [x, x[end] * ones(Float64, max(0, nc - length(x)))]
  n_c = invest.tf.n_c
  for ig in invest.ig
    n_c = max(n_c, length(ig.cost.abs_c), bkts.n_c)
  end
  cost_abs_c = zeros(Float64, n_c)

  for ig in invest.ig
    cost_abs_c .+= extend(ig.cost.abs_c, n_c)
  end
  cost_abs_gc_c = [bkts.gc_c, zeros(Float64, max(0,n_c-bkts.n_c))] .* cost_abs_c

  Fixed(cost_abs_c, cost_abs_gc_c)
end


