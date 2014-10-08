# Constructors -----------------------------------------------------------------
function SIILifeCost()
  tf = TimeFrame()
  shock_type = :InvestBuckets
  balance = DataFrame()
  shock_cost = 0.0
  shock_infl = 0.0
  return SIILifeCost(tf, shock_type, balance, shock_cost, shock_infl)
end


function SIILifeCost(tf::TimeFrame,
                     bkts_be::Buckets,
                     asset_other::AssetOther,
                     liab_other::LiabOther,
                     capmkt_be::CapMkt,
                     dyn::Dynamic,
                     inv_dfs::Vector{DataFrame},
                     balance_be::DataFrame,
                     df_sii_life_general::DataFrame)
  me = SIILifeCost()
  me.tf = tf
  me.balance =  deepcopy(balance_be)
  me.shock_cost = df_sii_life_general[1,:COST]
  me.shock_infl = df_sii_life_general[1,:COST_INFL]
  shock!(me, bkts_be, asset_other, liab_other, capmkt_be, inv_dfs, dyn)
  return me
end

## Interface -------------------------------------------------------------------

function shock!(me::SIILifeCost,
                buckets::Buckets,
                asset_other::AssetOther,
                liab_other::LiabOther,
                capmkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Dynamic)
  me.balance = me.balance[me.balance[:SCEN] .== :be, :]
  add!(me, :COST, capmkt_be, invest_dfs, buckets, asset_other, liab_other, dyn,
       (sii_cost, inv, bkts) -> costshock!!(inv, bkts, sii_cost) )
  return me
end

## Private ---------------------------------------------------------------------

function costshock!!(inv::Invest, bkts::Buckets, cost::SIILifeCost)
  n_p = inv.cap_mkt.tf.n_p
  n_c = inv.cap_mkt.tf.n_c
  shock_boc = (1 + cost.shock_cost) * exp([0:n_c-1] * cost.shock_infl)
  shock_eoc = shock_boc * exp(cost.shock_infl)
  shock_eop =
    (1 + cost.shock_cost * n_c/n_p) * exp([1:n_p]* cost.shock_infl * n_c/n_p)
  for inv_group in inv.ig
    inv_group.cost.abs .*= shock_eop
    inv_group.cost.rel .*= shock_eop
  end
  for bkt in bkts.all
    bkt.cond[:,C_BOC] .*= shock_boc[1:n_c]
    bkt.cond[:,C_DIR_EOC] .*= shock_eoc[1:n_c]
    bkt.cond_nb[:,C_BOC] .*= shock_boc[1:n_c]
    bkt.cond_nb[:,C_DIR_EOC] .*= shock_eoc[1:n_c]
  end
end

function scr(me::SIILifeCost)
  scr_net =  bof(me, :COST) - bof(me, :be)
  scr_gross =  scr_net + fdb(me, :be) - fdb(me, :COST)
  return scr_net, scr_gross
end
