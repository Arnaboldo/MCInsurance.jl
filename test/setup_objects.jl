
srand(df_general[1, :random_seed])

n_mc = df_general[1, :n_mc]
tf =  TimeFrame(df_general[1, :tf_y_start], df_general[1, :tf_y_end],
                df_general[1, :tf_n_dt] *
                  (df_general[1, :tf_y_end]-df_general[1, :tf_y_start])
                )
cap_mkt  = CapMkt(:cap_mkt_rn, tf, n_mc, df_capmkt_1, df_capmkt_2)
cap_mkt_det  = CapMkt(:cap_mkt_det, tf, 1, df_capmkt_1, df_capmkt_2)



lc  = LC(df_lc_lc, df_lc_ph, df_lc_prod, df_lc_load,
         df_lc_qx, df_lc_interest, tf)

buckets  = Buckets(lc, tf, df_lc_prod, df_lc_load, df_lc_qx, df_lc_interest)

invest = Invest(:invest_rn, cap_mkt, df_general,
                df_inv_inv, df_inv_init, df_inv_asset, buckets.n_c)
invest_det = Invest(:invest_det, cap_mkt_det,
                    df_general, df_inv_inv, df_inv_init, df_inv_asset, buckets.n_c)


## customize Bucket:
type BucketHook
  statinterest::Function
  #    bonus_rate::Float64
end
getstatinterest(me::Bucket, t::Int) = df_lc_interest[t, me.cat[CAT_INTEREST]]
for b = 1:buckets.n
  buckets.all[b].hook = BucketHook(getstatinterest)
end

fluct    = Fluct(tf, n_mc, 1.0)


liab_other = LiabOther() ## No other liabilities
asset_other = AssetOther() ## No other assets

dyn = Dynamic([invest, buckets, liab_other,
              invest.c.mean_yield_mkt_eoc[1], dyn_dfs]...)

fixed = Fixed(invest, buckets)

cflow  = CFlow(buckets, invest, asset_other, liab_other, fixed, fluct, dyn)

