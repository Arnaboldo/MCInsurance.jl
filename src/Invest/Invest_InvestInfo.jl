## Constructors ----------------------------------------------------------------

function InvestInfo(name::Symbol,
                    df_inv::DataFrame,
                    df_inv_port_start::DataFrame,
                    df_inv_asset::DataFrame
                    )
    inv = df_inv[df_inv[:ig_name] .== string(name),:]
    inv_asset = df_inv_asset[df_inv_asset[:ig_name] .== string(name), :]
    port_start = df_inv_port_start[df_inv_port_start[:ig_name].== string(name),:]
    asset_target = convert(Array, inv_asset[:asset_target])
    asset_mkt_benchmark = convert(Array, inv_asset[:market_benchmark])
    if any(isna(port_start[:asset_dur]))
        port_start = port_start[:, [:proc_labels, :asset_amount]]
        id_asset = convert(Array{Symbol},inv_asset[:,:proc_labels])
    else
        port_start = port_start[:,[ :asset_dur, :asset_coupon, :asset_amount]]
        id_asset = convert(Array{Int},inv_asset[:,:asset_dur])
    end

    InvestInfo(name, inv[1, :ig_type], inv[1, :proc_name],
               port_start, id_asset, asset_target, asset_mkt_benchmark )    
end

