## Constructors ----------------------------------------------------------------

function InvestInfo(name::Symbol,
                    tf::TimeFrame,
                    df_inv::DataFrame,
                    df_inv_inv_init::DataFrame,
                    df_inv_asset::DataFrame,
                    )
  inv = df_inv[df_inv[:ig_name] .== string(name),:]
  inv_asset = df_inv_asset[df_inv_asset[:ig_name] .== string(name), :]
  inv_init = df_inv_inv_init[df_inv_inv_init[:ig_name].== string(name),:]
  asset_target = convert(Array, inv_asset[:asset_target])
  asset_mkt_benchmark = convert(Array, inv_asset[:market_benchmark])
  fields = [:mv_init, :rating, :lgd_rel, :sii_risk, :cp]
  if any(isna(inv_init[:asset_dur]))
    inv_init = inv_init[:, [:cpnt, fields]]
    asset = convert(Array{Symbol},inv_asset[:,:cpnt])
  else
    inv_init = inv_init[:,[:asset_dur, :asset_coupon, fields]]
    asset = convert(Array{Int},inv_asset[:,:asset_dur])
  end

  InvestInfo(name, inv[1, :ig_type], tf, inv[1, :proc_name],
             inv_init, asset, asset_target, asset_mkt_benchmark,
             inv[1, :cost_norm_rel_c]  * ones(Float64, tf.n_c),
             inv[1, :cost_norm_abs_c]  * ones(Float64, tf.n_c),
             inv[1, :cost_infl_rel_c]  * ones(Float64, tf.n_c),
             inv[1, :cost_infl_abs_c]  * ones(Float64, tf.n_c)
             )
end

