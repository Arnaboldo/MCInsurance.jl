## Constructors ----------------------------------------------------------------
function MktC(info::Vector{InvestInfo},
              cap_mkt::CapMkt,
              id::Dict{Symbol, Int},
              n_mean_mc::Int,
              n_mean_c::Int,
              n_mean_grid::Int
              )
  yield_rf_eoc = Array(Float64, cap_mkt.n_mc, cap_mkt.tf.n_c )
  yield_mkt_eoc = Array(Float64, cap_mkt.n_mc, cap_mkt.tf.n_c )
  yield_grid_rf = Array(Float64, cap_mkt.tf.n_c, n_mean_grid)
  mean_disc_rf = Array(Float64, n_mean_c, cap_mkt.tf.n_c, n_mean_grid)
  yield_eoc = zeros(Float64, cap_mkt.n_mc, cap_mkt.tf.n_c)

  ind_cash = cap_mkt.id[info[id[:cash]].proc_name]

  yield_rf_init = cap_mkt.tf.n_dt * mean(cap_mkt.proc[ind_cash].yield[:, 1, 1])
  yield_rf_eoc = yieldrfeoc(cap_mkt, ind_cash)
  yield_mkt_eoc = yieldmkteoc(info, cap_mkt)

  tf = TimeFrame(cap_mkt.tf.init,
                 cap_mkt.tf.init + n_mean_c,
                 cap_mkt.tf.n_dt * n_mean_c)

  for t = 1:cap_mkt.tf.n_c
    yield_grid_rf[t,:] =
      linspace(minimum(yield_rf_eoc[:,t]),
               maximum(yield_rf_eoc[:,t]),
               n_mean_grid)
    #   yield_rf_min = tf.n_dt * minimum(cap_mkt.proc[ind_cash].yield)
    #   yield_rf_max = tf.n_dt * maximum(cap_mkt.proc[ind_cash].yield)
    #   yield_grid_rf = linspace(yield_rf_min, yield_rf_max, n_mean_grid)
  end

  for t = 1:cap_mkt.tf.n_c, k = 1:n_mean_grid
    mean_disc_rf[:,t,k] =
      mean(exp(-cumsum(yieldeoc(cap_mkt.proc[ind_cash],
                                t,
                                yield_grid_rf[t,k],
                                n_mean_mc,
                                n_mean_c,
                                cap_mkt.tf.n_dt),
                       2)[:,1:n_mean_c]),
           1)
  end
  return MktC(yield_mkt_eoc, vec(mean(yield_mkt_eoc, 1)),
              yield_rf_init, yield_rf_eoc, yield_grid_rf,
              mean_disc_rf, yield_eoc)
end


## Interface  ------------------------------------------------------------------

function meandiscrf(me::MktC,
                    yield_rf::Float64, # yield during cycle t
                    t::Int,
                    t_final::Int = 0)
  len = (t_final == 0 ?
           length(me.mean_disc_rf[1,:,1]) :
           min(length(me.mean_disc_rf[1,:,1]), t_final - t + 1) )

  if yield_rf > me.yield_grid_rf[t, end]
    return  vec(me.mean_disc_rf[1:len, t, end])
  elseif yield_rf <= me.yield_grid_rf[t, 1]
    return  vec(me.mean_disc_rf[1:len, t, 1])
  end
  k = 0
  for j = 1:size(me.yield_grid_rf, 2)
    if yield_rf <= me.yield_grid_rf[t, j]
      k = j
      break
    end
  end
  lambda =
    (yield_rf - me.yield_grid_rf[t, k-1]) /
    (me.yield_grid_rf[t, k] - me.yield_grid_rf[t, k-1])
  return vec((1-lambda) * me.mean_disc_rf[1:len, t, k-1] +
               lambda * me.mean_disc_rf[1:len, t, k]
             )
end


## Private  --------------------------------------------------------------------

function yieldrfeoc(cap_mkt::CapMkt, ind_cash::Int)
  ## calculates riskfree interest retrospectively at eoc
  yield_rf_eoc = zeros(Float64, cap_mkt.n_mc, cap_mkt.tf.n_c )
  for mc = 1:cap_mkt.n_mc
    for t = 1:cap_mkt.tf.n_c
      for d = 1:cap_mkt.tf.n_dt
        yield_rf_eoc[mc,t] +=
          cap_mkt.proc[ind_cash].yield[mc, cap_mkt.tf.n_dt*(t-1) + d, 1]
      end
    end
  end
  return yield_rf_eoc
end

function yieldmkteoc(info::Vector{InvestInfo},
                     cap_mkt::CapMkt
                     )
  ## calculates market yield benchmark retrospectively at eoc
  yield_mkt_eoc = zeros(Float64, cap_mkt.n_mc, cap_mkt.tf.n_c ) # per cycle!
  for i = 1:length(info)
    ind_proc = cap_mkt.id[info[i].proc_name]
    if info[i].ig_type == :IGRiskfreeBonds
      for j in  info[i].asset
        ind_asset = findin(info[i].asset, [j])[1]
        for mc = 1:cap_mkt.n_mc
          for t = 1:cap_mkt.tf.n_c
            for d = 1:cap_mkt.tf.n_dt
              yield_mkt_eoc[mc,t] +=
                info[i].asset_mkt_benchmark[ind_asset] *
                forwardbop(cap_mkt.proc[ind_proc],
                           mc,
                           cap_mkt.tf.n_dt*(t-1)+d,
                           j)
            end
          end
        end
      end
    else  ## :IGCash, :IGStocks
      for cpnt in info[i].asset
        ind_asset = findin(info[i].asset,[cpnt])[1]
        ind_cpnt = cap_mkt.proc[ind_proc].cpnt_id[cpnt]
        for mc = 1:cap_mkt.n_mc
          for t = 1:cap_mkt.tf.n_c
            for d = 1:cap_mkt.tf.n_dt
              yield_mkt_eoc[mc,t] +=
                info[i].asset_mkt_benchmark[ind_asset] *
                cap_mkt.proc[ind_proc].yield[mc, t-1+d, ind_cpnt]
            end
          end
        end
      end
    end
  end
  return yield_mkt_eoc
end

