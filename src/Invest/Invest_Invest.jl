## Constructors ----------------------------------------------------------------

# Main constructor

function Invest(name::Symbol,
                cap_mkt::CapMkt,
                info::Vector{InvestInfo},
                ig_target::Vector{Float64}, 
                n_mean_mc::Int,
                n_mean_c::Int,
                n_mean_grid::Int
                )
    n_ig =            length(info)
    ig =              Array(IG, n_ig)
    mv_total_init =   0.0
    mv_total_eop =    zeros(Float64, cap_mkt.n_mc, cap_mkt.tf.n_p )
    yield_total =     zeros(Float64, cap_mkt.n_mc, cap_mkt.tf.n_p )
    asset_target =    Array(Any,0)
    asset_int =       Dict{Vector{Any}, Int}()
    for i = 1:n_ig
        push!(asset_target, Array(Float64,0) )
        ind_proc = cap_mkt.id[info[i].proc_name]
        
        if info[i].ig_type == :IGRiskfreeBonds
            # n is equal to both max duration and number of assets
            n = maximum( [info[i].asset,
                               info[i].inv_init[:asset_dur] ] )
            ## cap_mkt has only 1 short rateprocess (dur = 1)
            ## all other durations are calculated using forwardbop
            ## we assume that inv_init is ordered with increasing duration
            asset_target[i] = zeros(Float64, n)
            ind_inv_init = [1:nrow(info[i].inv_init)]
            for j in info[i].asset
                ind_asset = findin(info[i].asset, j)[1]
                asset_target[i][j] = info[i].asset_target[ind_asset]
                merge!(asset_int, [{i, j} => j ])
            end
        else
            ## line up up proc in process group defined by info[i] with cap_mkt
            n = length(cap_mkt.proc[ind_proc].cpnt)
            asset_target[i] = zeros(Float64, n)
            ind_inv_init = zeros(Int, n)
            for j = 1:n
                cap_mkt_proc_cpnt = cap_mkt.proc[ind_proc].cpnt[j]
                if cap_mkt_proc_cpnt in info[i].asset
                    ind_asset = findin(info[i].asset,[cap_mkt_proc_cpnt])[1]
                    asset_target[i][j] = info[i].asset_target[ind_asset]
                    merge!(asset_int, [{i, cap_mkt_proc_cpnt} => j])
                    ind_inv_init[j] = ind_asset
                end
            end
        end
        asset_target[i] /= max(eps(), sum(asset_target[i]))
        ig[i] = eval(info[i].ig_type)(info[i].ig_name,
                                      cap_mkt.proc[ind_proc],
                                      info[i].inv_init[ind_inv_init, :],
                                      n )
        mv_total_init += ig[i].mv_total_init        
    end
    id = Dict(Symbol[info[i].ig_name for i = 1:n_ig], 1:n_ig)
    ig_target /= max(eps(), sum(ig_target))    
    alloc = InvestAlloc(ig_target,    ## used by projection
                        ig_target,    ## standard benchmark for dyn. allocation
#                        id,
                        asset_target, ## used by projection
                        asset_target, ## standard benchmark for dyn. allocation
                        asset_int)

    mkt_c = MktC(info, cap_mkt, id, n_mean_mc, n_mean_c, n_mean_grid)
    
    Invest(name, cap_mkt, n_ig, ig, id, alloc,
           mv_total_init, mv_total_eop, yield_total, mkt_c, false)
end
        
# Constructor from DataFrames

function Invest(name::Symbol,
                cap_mkt::CapMkt,
                df_general::DataFrame,
                df_inv::DataFrame,
                df_inv_inv_init::DataFrame,
                df_inv_target::DataFrame)
    invest_info = Array(InvestInfo, nrow(df_inv))
    ig_target = Array(Float64, nrow(df_inv))
    for i = 1:nrow(df_inv)
        invest_info[i] = InvestInfo(symbol(df_inv[i, :ig_name]),
                                    df_inv, df_inv_inv_init, df_inv_target)
        ig_target[i] = df_inv[i,:ig_target]
    end
    Invest(name, cap_mkt, invest_info, ig_target,
           df_general[1, :n_mean_mc],
           df_general[1, :n_mean_c],
           df_general[1, :n_mean_grid], )
end

        

## Interface functions for Invest types ----------------------------------------
        
function show(io::IO, me::Invest)
    println(io,"Type        : $(string(typeof(me)))")
    println(io,"name        : $(me.name)")
    println(io,"cap_mkt.tf  : $(me.cap_mkt.tf)")
    println(io,"cap_mkt.n_mc: $(me.cap_mkt.n_mc)")
    ig_names = [me.ig[i].name for i=1:me.n]
    println(io,"ig          : $(transpose(ig_names))")
    println(io,"target      : $(me.ig_target')")
end


## Applies to a single Monte Carlo scenario
function project!(me::Invest,
                  mc::Int,
                  t::Int,
                  mv_total_bop::Float64)
    ## [-|-|---------------------|-]
    ## t | | ------------------> | t+1
    ##   | mv_total_alloc        project
    ##   mv_total_bop (pre alloc)
    
    mv_bop = mv_total_bop * me.alloc.ig_target
    me.mv_total_eop[mc,t] = 0
    for i = 1:me.n
        me.ig[i].mv_alloc_bop = mv_bop[i] * me.alloc.asset_target[i]
        project!(me.ig[i], mc, t)
        me.mv_total_eop[mc,t] += me.ig[i].mv_total_eop[mc,t]
    end
    me.yield_total[mc,t] = me.mv_total_eop[mc,t]/max(eps(), mv_total_bop) - 1
end


## Private functions for Invest ------------------------------------------------

