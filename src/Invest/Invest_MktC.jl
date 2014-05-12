## Constructors ----------------------------------------------------------------
function MktC(info::Vector{InvestInfo},
              cap_mkt::CapMkt,
              ig_symb::Vector{Symbol},
              n_mean_mc::Int,
              n_mean_c::Int,
              n_mean_grid::Int
              )
    yield_rf = Array(Float64, cap_mkt.n_mc, cap_mkt.tf.n_c )
    yield_mkt = Array(Float64, cap_mkt.n_mc, cap_mkt.tf.n_c )
    mean_cum_disc_rf = Array(Float64, n_mean_c, n_mean_grid) 


    proc_cash_name = info[findin(ig_symb,[:cash])[1]].proc_name
    ind_cash = cap_mkt.proc_int[proc_cash_name]
    
    yield_rf = yieldrf(cap_mkt, proc_cash_name)
    yield_mkt = yieldmkt(info, cap_mkt)
    
    tf = TimeFrame(cap_mkt.tf.init,
                   cap_mkt.tf.init + n_mean_c,
                   cap_mkt.tf.n_dt * n_mean_c)       
    yield_rf_min = tf.n_dt * minimum(cap_mkt.proc[ind_cash].yield)
    yield_rf_max = tf.n_dt * maximum(cap_mkt.proc[ind_cash].yield)
    yield_grid_rf = linspace(yield_rf_min, yield_rf_max, n_mean_grid)
    
    for k = 1:n_mean_grid
        mean_cum_disc_rf[:,k] = mean(exp(-cumsum(yieldc(cap_mkt.proc[ind_cash],
                                                        n_mean_mc,
                                                        tf,
                                                        yield_grid_rf[k]),
                                                 2)),
                                     1)
    end                        
    return MktC(yield_mkt, yield_rf, yield_grid_rf, mean_cum_disc_rf)
end


## Interface functions for MarketCycle -----------------------------------------
## Interface functions for MktC ------------------------------------------------


function meancumdiscrf(me::MktC, yield_init_rf::Float64, len::Int=0)
    len = (len == 0 ?
           length(me.mean_cum_disc_rf) :
           min(length(me.mean_cum_disc_rf),len))
    
    if yield_init_rf >= me.yield_grid_rf[end]
        return  me.mean_cum_discount_c[1:len, end]
    elseif yield_init_rf < me.yield_grid_rf[1]
        return  me.mean_cum_disc_rf[1:len, 1]
    end
   
    k = 0
    for j = 1:length(me.yield_grid_rf)
        if yield_init_rf <= me.yield_grid_rf[j]
            k = j
            break
        end
    end
    lambda = (yield_init_rf - me.yield_grid_rf[k]) /
             (me.yield_grid_rf[k+1] - me.yield_grid_rf[k])
    return ((1-lambda) * me.mean_cum_disc_rf[1:len, k] +
             lambda * me.mean_cum_disc_rf[1:len, k+1] )
end

function meandiscrf(me::MktC, yield_init_rf::Float64, len::Int = 0)
    len = (len == 0 ?
           length(me.mean_cum_disc_rf) :
           min(length(me.mean_cum_disc_rf),len))

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

## Private functions for MarketCycle -------------------------------------------

function yieldrf(cap_mkt::CapMkt, proc_cash_name::Symbol)
    yield_rf = zeros(Float64, cap_mkt.n_mc, cap_mkt.tf.n_c )
    ind_cash = cap_mkt.proc_int[proc_cash_name]
    for mc = 1:cap_mkt.n_mc
        for t = 1:cap_mkt.tf.n_c
            for d = 1:cap_mkt.tf.n_dt
                yield_rf[mc,t] +=  cap_mkt.proc[ind_cash].yield[mc, t-1+d, 1]
            end
        end
    end
    return yield_rf
end

function yieldmkt(info::Vector{InvestInfo},
                  cap_mkt::CapMkt
                  )
    yield_mkt = zeros(Float64, cap_mkt.n_mc, cap_mkt.tf.n_c ) # per cycle!
    for i = 1:length(info)
        ind_proc = cap_mkt.proc_int[info[i].proc_name]
        if info[i].ig_type == :IGRiskfreeBonds
            for j in  info[i].id_asset
                ind_asset = findin(info[i].id_asset, [j])[1]
                for mc = 1:cap_mkt.n_mc
                    for t = 1:cap_mkt.tf.n_c
                        for d = 1:cap_mkt.tf.n_dt
                            yield_mkt[mc,t] +=
                                info[i].asset_mkt_benchmark[ind_asset] *
                                forwardbop(cap_mkt.proc[ind_proc], mc, t-1+d, j)
                        end
                    end
                end
            end
        else ## :IGCash, :IGStocks
            for proc_label in info[i].id_asset
                ind_asset = findin(info[i].id_asset,[proc_label])[1]
                ind_comp = cap_mkt.proc[ind_proc].comp_int[proc_label]
                for mc = 1:cap_mkt.n_mc
                    for t = 1:cap_mkt.tf.n_c
                        for d = 1:cap_mkt.tf.n_dt
                            yield_mkt[mc,t] +=
                                info[i].asset_mkt_benchmark[ind_asset] *
                                cap_mkt.proc[ind_proc].yield[mc, t-1+d, ind_comp]  
                        end
                    end
                end 
            end
        end
    end
    return yield_mkt
end
    
