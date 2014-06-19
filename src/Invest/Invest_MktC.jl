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
  mean_cum_disc_rf = Array(Float64, n_mean_c, n_mean_grid)

  ind_cash = cap_mkt.id[info[id[:cash]].proc_name]

  yield_rf_init = cap_mkt.tf.n_dt * mean(cap_mkt.proc[ind_cash].yield[:, 1, 1])
  yield_rf_eoc = yieldrfeoc(cap_mkt, ind_cash)
  yield_mkt_eoc = yieldmkteoc(info, cap_mkt)

  tf = TimeFrame(cap_mkt.tf.init,
                 cap_mkt.tf.init + n_mean_c,
                 cap_mkt.tf.n_dt * n_mean_c)
  yield_rf_min = tf.n_dt * minimum(cap_mkt.proc[ind_cash].yield)
  yield_rf_max = tf.n_dt * maximum(cap_mkt.proc[ind_cash].yield)
  yield_grid_rf = linspace(yield_rf_min, yield_rf_max, n_mean_grid)

  for k = 1:n_mean_grid
    mean_cum_disc_rf[:,k] = mean(exp(-cumsum(yieldeoc(cap_mkt.proc[ind_cash],
                                                      n_mean_mc,
                                                      tf,
                                                      yield_grid_rf[k]),
                                             2)[:,1:tf.n_c]),
                                 1)
  end
  return MktC(yield_mkt_eoc, yield_rf_init, yield_rf_eoc, yield_grid_rf,
              mean_cum_disc_rf)
end


## Interface  ------------------------------------------------------------------

function meancumdiscrf(me::MktC, yield_init_rf::Float64, len::Int=0)
  len = (len == 0 ?
           length(me.mean_cum_disc_rf) :
             min(length(me.mean_cum_disc_rf),len)
         )
  if yield_init_rf > me.yield_grid_rf[end]
    return  me.mean_cum_disc_rf[1:len, end]
  elseif yield_init_rf <= me.yield_grid_rf[1]
    return  me.mean_cum_disc_rf[1:len, 1]
  end

  k = 0
  for j = 1:length(me.yield_grid_rf)
    if yield_init_rf <= me.yield_grid_rf[j]
      k = j
      break
    end
  end
  lambda = (yield_init_rf - me.yield_grid_rf[k-1]) /
    (me.yield_grid_rf[k] - me.yield_grid_rf[k-1])
  return ((1-lambda) * me.mean_cum_disc_rf[1:len, k-1] +
            lambda * me.mean_cum_disc_rf[1:len, k]
          )
end

function meandiscrf(me::MktC, yield_init_rf::Float64, len::Int = 0)
  len = (len == 0 ?
           length(me.mean_cum_disc_rf) :
             min(length(me.mean_cum_disc_rf),len)
         )
  mean_cum_disc_rf = meancumdiscrf(me, yield_init_rf, len)
  mean_disc_rf = Array(Float64, len)
  mean_disc_rf[1] = mean_cum_disc_rf[1]
  if len > 1
    for t = 2:len
      mean_disc_rf[t] =
        mean_cum_disc_rf[t] / max(eps(), mean_cum_disc_rf[t-1])
    end
  end
  return mean_disc_rf
end


## Private  ----------------------------------------------------------

function yieldrfeoc(cap_mkt::CapMkt, ind_cash::Int)
  ## calculates riskfree interest retrospectively at eoc
  yield_rf_eoc = zeros(Float64, cap_mkt.n_mc, cap_mkt.tf.n_c )
  for mc = 1:cap_mkt.n_mc
    for t = 1:cap_mkt.tf.n_c
      for d = 1:cap_mkt.tf.n_dt
        yield_rf_eoc[mc,t] +=
          cap_mkt.proc[ind_cash].yield[mc,
                                       cap_mkt.tf.n_dt*(t-1) + d, 1]
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

