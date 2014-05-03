## Constructors ----------------------------------------------------------------

## InvestInfo 

function InvestInfo(name::String,
                    df_inv::DataFrame,
                    df_inv_port_start::DataFrame,
                    df_inv_asset::DataFrame
                    )
    inv = df_inv[df_inv[:ig_name] .== name,:]
    inv_asset = df_inv_asset[df_inv_asset[:ig_name] .== name, :]
    port_start = df_inv_port_start[df_inv_port_start[:ig_name].== name, :]
    asset_target = convert(Array, inv_asset[:asset_target])
    asset_mkt_benchmark = convert(Array, inv_asset[:market_benchmark])
    if any(isna(port_start[:asset_dur]))
        port_start = port_start[:, [:proc_labels, :asset_amount]]
        id_asset = [symbol(inv_asset[i,:proc_labels]) for i = 1:nrow(inv_asset)]
    else
        port_start = port_start[:,[ :asset_dur, :asset_coupon, :asset_amount]]
        id_asset = [inv_asset[i,:asset_dur] for i = 1:nrow(inv_asset)]
    end

    InvestInfo(name, inv[1, :ig_type], inv[1, :proc_name],
               port_start, id_asset, asset_target, asset_mkt_benchmark )    
end


## Invest

# Main constructor

function Invest(name::String,
                cap_mkt::CapMkt,
                info::Vector{InvestInfo},
                ig_target::Vector{Float64} 
                )
    n_ig =          length(info)
    ig =            Array(IG, n_ig)
    ig_symb =       Array(Symbol,n_ig)
    port_start =    Array(DataFrame, n_ig)
    mv_total_init = 0.0
    mv_total_eop =  zeros(Float64, cap_mkt.n_mc, cap_mkt.tf.n_p )
    yield_total =   zeros(Float64, cap_mkt.n_mc, cap_mkt.tf.n_p )
    yield_market =  zeros(Float64, cap_mkt.n_mc, cap_mkt.tf.n_p )
    yield_cash =    Array(Float64, cap_mkt.n_mc, cap_mkt.tf.n_p )
    tmp_dict =      Array(Dict{Any,Float64},n_ig)
    asset_target =  Array(Any,0)
    asset_int =   Dict{Vector{Any}, Int}()
    for i = 1:n_ig
        ig_symb[i] = symbol(info[i].ig_name)
        push!(asset_target, Array(Float64,0) )
        ## match up process group definded by info[i] with cap_mkt
        ind_proc = 0
        for j = 1:cap_mkt.n
            if cap_mkt.proc[j].name == info[i].proc_name
                ind_proc = j
                break
            end
        end
        if ind_proc == 0
            error("Invest: proc $(info[i].proc_name) is not in capital market") 
        end
        
        if info[i].ig_type=="IGRiskfreeBonds"
            # n is equal to both max duration and number of assets
            n = maximum( chain(info[i].id_asset,
                               info[i].port_start[:asset_dur]) )
            ## cap_mkt has only 1 short rateprocess (dur = 1)
            ## all other durations are calculated using forwardbop
            ## we assume that port_stat is ordered with increasing duration
            asset_target[i] = zeros(Float64, n)
            ind_port = [1:nrow(info[i].port_start)]
            for j = 1:n
                if j in info[i].id_asset
                    ind_asset = findin(info[i].id_asset, j)[1]
                     asset_target[i][j] = info[i].asset_target[ind_asset]
                    merge!(asset_int, [{i, j} => j ])
                    for mc = 1:cap_mkt.n_mc, t = 1:cap_mkt.tf.n_p
                        yield_market[mc,t] +=
                            info[i].asset_mkt_benchmark[ind_asset] *
                            forwardbop(cap_mkt.proc[ind_proc], mc, t, j)
                    end
                end
            end
        else
            ## line up up proc in process group defined by info[i] with cap_mkt
            n = length(cap_mkt.proc[ind_proc].labels)
            asset_target[i] = zeros(Float64, n)
            ind_port = zeros(Int, n)
            for j = 1:n
                symb_cap_mkt_proc = symbol(cap_mkt.proc[ind_proc].labels[j])
                if symb_cap_mkt_proc in info[i].id_asset
                    ind_asset = findin(info[i].id_asset,[symb_cap_mkt_proc])[1]
                    asset_target[i][j] = info[i].asset_target[ind_asset]
                    merge!(asset_int, [{i, symb_cap_mkt_proc} => j])
                    yield_market += info[i].asset_mkt_benchmark[ind_asset] *
                                    cap_mkt.proc[ind_proc].yield[:,:,j]       
                    ind_port[j] = ind_asset
                end
            end
        end
        if info[i].ig_name == "cash"
            yield_cash = cap_mkt.proc[ind_proc].yield[:,:,1]
        end
        asset_target[i] /= max(eps(), sum(asset_target[i]))  

        ig[i] = eval(parse(info[i].ig_type))(info[i].ig_name,
                                             cap_mkt.proc[ind_proc],
                                             info[i].port_start[ind_port, :],
                                             n )
        mv_total_init += ig[i].mv_total_init        
    end
    ig_int = Dict(ig_symb, 1:length(ig_symb)) 
    ig_target /= max(eps(), sum(ig_target))

    Invest(name, cap_mkt, n_ig, ig,
           ig_symb, ig_int, ig_target, asset_target, asset_int,
           mv_total_init, mv_total_eop, yield_total, yield_cash, yield_market)
end
        
# Constructor from DataFrames
        
function Invest(name::String,
                cap_mkt::CapMkt,
                df_inv::DataFrame,
                df_inv_port_start::DataFrame,
                df_inv_target::DataFrame)
    invest_info = Array(InvestInfo, nrow(df_inv))
    ig_target = Array(Float64, nrow(df_inv))
    for i = 1:nrow(df_inv)
        invest_info[i] = InvestInfo(df_inv[i, :ig_name],
                                    df_inv, df_inv_port_start, df_inv_target)
        ig_target[i] = df_inv[i,:ig_target]
    end
    Invest(name, cap_mkt, invest_info, ig_target)
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
    
    mv_bop = mv_total_bop * me.ig_target
    me.mv_total_eop[mc,t] = 0
    for i = 1:me.n
        me.ig[i].mv_alloc_bop = mv_bop[i] * me.asset_target[i]
        project!(me.ig[i], mc, t)
        me.mv_total_eop[mc,t] += me.ig[i].mv_total_eop[mc,t]
    end
    me.yield_total[mc,t] = me.mv_total_eop[mc,t]/max(eps(), mv_total_bop) - 1
end

   
