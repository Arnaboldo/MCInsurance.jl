## Constructors ----------------------------------------------------------------

function InvestInfo(name::Symbol,
                    df_inv::DataFrame,
                    df_inv_inv_init::DataFrame,
                    df_inv_asset::DataFrame
                    )
    inv = df_inv[df_inv[:ig_name] .== string(name),:]
    inv_asset = df_inv_asset[df_inv_asset[:ig_name] .== string(name), :]
    inv_init = df_inv_inv_init[df_inv_inv_init[:ig_name].== string(name),:]
    asset_target = convert(Array, inv_asset[:asset_target])
    asset_mkt_benchmark = convert(Array, inv_asset[:market_benchmark])
    if any(isna(inv_init[:asset_dur]))
        inv_init = inv_init[:, [:proc_labels, :asset_amount]]
        asset = convert(Array{Symbol},inv_asset[:,:proc_labels])
    else
        inv_init = inv_init[:,[ :asset_dur, :asset_coupon, :asset_amount]]
        asset = convert(Array{Int},inv_asset[:,:asset_dur])
    end

    InvestInfo(name, inv[1, :ig_type], inv[1, :proc_name],
               inv_init, asset, asset_target, asset_mkt_benchmark )    
end

