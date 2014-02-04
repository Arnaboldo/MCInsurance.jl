## Constructors ----------------------------------------------------------------

## InvestInfo 

function InvestInfo(name::ASCIIString,
                    df_inv::DataFrame,
                    df_inv_port_start::DataFrame,
                    df_inv_target::DataFrame)

    inv = df_inv[df_inv["ig_name"] .== name,:]
    target = df_inv_target[df_inv_target["ig_name"] .== name, 2:end]
    port_start = df_inv_port_start[df_inv_port_start["ig_name"].== name, 2:end]
    target_dict = Dict{Any,Float64}()
    if any(isna(port_start["asset_dur"]))
        merge!(target_dict, Dict(target["proc_labels"], target["asset_target"]))
        port_start = port_start[:,["proc_labels","asset_amount"]]
        for j = 1:nrow(port_start)
            port_start[j,"proc_labels"] = ascii( port_start[j,"proc_labels"])
        end
    else
        merge!(target_dict, Dict(target["asset_dur"], target["asset_target"]) )
        port_start = port_start[:,["asset_dur", "asset_coupon", "asset_amount"]]
    end
    for j = 1:nrow(port_start)
        port_start[j,"asset_amount"] = float64( port_start[j,"asset_amount"])
    end
    
    InvestInfo(name, ascii(inv[1, "ig_type"]), ascii(inv[1, "proc_name"]),
               port_start, target_dict )    
end


## Invest

# Main constructor

function Invest(name::ASCIIString,
                cap_mkt::CapMkt,
                info::Vector{InvestInfo},
                target_dict::Dict{ASCIIString,Float64}
                )
    n_ig =          length(info)
    ig =            Array(IG, n_ig)
    port_start =    Array(DataFrame,n_ig)
    mv_total_init = 0.0
    mv_total_eop =  zeros(Float64, cap_mkt.n_mc, cap_mkt.tf.n_p )
    tmp_dict =      Array(Dict{Any,Float64},n_ig)    
    for i = 1:n_ig
        tmp_dict[i] = deepcopy(info[i].target_dict) # avoid side effects
        if info[i].ig_type=="IGRiskfreeBonds"
            n = max( maximum(keys(info[i].target_dict)),
                    maximum(info[i].port_start["asset_dur"]) )
            for j = 1:n
                if !(j in collect(keys(tmp_dict[i])))
                    merge!(tmp_dict[i],[j=>0.0])
                end
            end
        else
            n = cap_mkt.proc[cap_mkt.dict_proc[info[i].proc_name]].dim
            for j in cap_mkt.proc[cap_mkt.dict_proc[info[i].proc_name]].labels
                if !(j in collect(keys(tmp_dict[i])))  
                    merge!(tmp_dict[i],[j=>0.0])
                end
            end
        end
        ig[i] = eval(parse(info[i].ig_type))(
                  info[i].ig_name,
                  cap_mkt.proc[cap_mkt.dict_proc[info[i].proc_name]],
                  info[i].port_start,
                  n )
        mv_total_init += ig[i].mv_total_init
    end
    ## construct a target vector that lines up with ig numbering
    ig_target = Float64[target_dict[info[i].ig_name] for i = 1:n_ig]
    ig_target = ig_target / max(eps(),sum(ig_target))
    asset_target = Array(Any,n_ig)
    for i = 1:n_ig
        asset_target[i] =
            Float64[tmp_dict[i][ig[i].labels[j]] for j=1:ig[i].n]
        asset_target[i] =
            asset_target[i] / max(eps(),sum(asset_target[i]))
    end

    Invest(name, cap_mkt, n_ig, ig, ig_target, asset_target,
           mv_total_init, mv_total_eop)
end
        
# Constructor from DataFrames
        
function Invest(name::ASCIIString,
                cap_mkt::CapMkt,
                df_inv::DataFrame,
                df_inv_port_start::DataFrame,
                df_inv_target::DataFrame)
    invest_info = Array(InvestInfo, nrow(df_inv))
    for i = 1:nrow(df_inv)
        invest_info[i] = InvestInfo(ascii(df_inv[i, "ig_name"]),
                                    df_inv, df_inv_port_start, df_inv_target)
    end
    Invest(name, cap_mkt, invest_info,
           Dict(ASCIIString[df_inv[j,"ig_name"] for j in 1:nrow(df_inv)],
               Float64[df_inv[j,"ig_target"] for j in 1:nrow(df_inv)] ) )
end

        

## Interface functions for Invest types ----------------------------------------
        
function show(io::IO, me::Invest)
    println(io,"Type        : $(string(typeof(me)))")
    println(io,"name        : $(me.name)")
    println(io,"cap_mkt.tf  : $(me.cap_mkt.tf)")
    println(io,"cap_mkt.n_mc: $(me.cap_mkt.n_mc)")
    ig_names = [me.ig[i].name for i=1:me.n]
    print(io,"ig          : $(ig_names')")
    print(io,"target      : $(me.ig_target')")
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
    
    mv_bop =
        mv_total_bop * me.ig_target
    me.mv_total_eop[mc,t] = 0
    for i = 1:me.n
        me.ig[i].mv_alloc_bop = 
            mv_bop[i] * me.asset_target[i]
        project!(me.ig[i], mc, t)
        me.mv_total_eop[mc,t] += me.ig[i].mv_total_eop[mc,t]
    end
end

   
