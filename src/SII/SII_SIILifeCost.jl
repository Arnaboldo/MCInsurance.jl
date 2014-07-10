# Constructors -----------------------------------------------------------------
function SIILifeCost()
  tf = TimeFrame()
  shock_type = :Buckets
  balance = DataFrame()
  shock_cost = 0.0
  shock_infl = 0.0
  return SIILifeCost(tf, shock_type, balance, shock_cost, shock_infl)
end


function SIILifeCost(tf::TimeFrame,
                     balance_be::DataFrame,
                     df_sii_life_general::DataFrame)
  me = SIILifeCost()
  me.tf = tf
  me.balance =  deepcopy(balance_be)
  me.shock_cost = df_sii_life_general[1,:COST]
  me.shock_infl = df_sii_life_general[1,:COST_INFL]
  return me
end

## Interface -------------------------------------------------------------------

function shock!(me::SIILifeCost,
                buckets::Buckets,
                other_be::Other,
                cap_mkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Dynamic)
  me.balance = me.balance[me.balance[:SCEN] .== :be, :]
  add!(me, :COST, cap_mkt_be, invest_dfs, buckets, other_be, dyn,
       (sii_cost, bkts) -> costshock!(bkts, sii_cost) )
  return me
end

## Private ---------------------------------------------------------------------

function costshock!(me::Buckets, cost::SIILifeCost)
  shock_boc = (1+cost.shock_cost) * exp([0:me.n_c-1] * cost.shock_infl)
  shock_eoc = shock_boc * exp(cost.shock_infl)
  for bkt in me.all
    bkt.cond[:,C_BOC] .*= shock_boc[1:bkt.n_c]
    bkt.cond[:,C_EOC] .*= shock_eoc[1:bkt.n_c]
    bkt.cond_nb[:,C_BOC] .*= shock_boc[1:bkt.n_c]
    bkt.cond_nb[:,C_EOC] .*= shock_eoc[1:bkt.n_c]
  end
end

function scr(me::SIILifeCost)
  scr_net =  bof(me, :COST) - bof(me, :be)
  scr_gross =  scr_net + fdb(me, :be) - fdb(me, :COST)
  return scr_net, scr_gross
end
