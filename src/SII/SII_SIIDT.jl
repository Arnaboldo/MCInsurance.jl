# Constructors -----------------------------------------------------------------
function SIIDT()
  tf = TimeFrame()
  shock_type = :Invest
  balance = DataFrame()
  return SIIDT(tf, shock_type, balance, 0.0, 0.0, 0.0)
end


function SIIDT(tf::TimeFrame,
                  bkts_be::Buckets,
                  asset_other::AssetOther,
                  liab_other::LiabOther,
                  capmkt_be::CapMkt,
                  dyn::Dynamic,
                  inv_dfs::Vector{DataFrame},
                  balance_be::DataFrame,
                  bscr_value::Float64,
                    adj_tp::Float64,
               scr_op::Float64)
  me = SIIDT()
  me.tf = tf
  me.balance =  deepcopy(balance_be)
  me.bscr = bscr_value
  me.adj_tp = adj_tp
  me.scr_op = scr_op
  shock!(me, bkts_be, asset_other, liab_other, capmkt_be, inv_dfs, dyn)
  return me
end

## Interface -------------------------------------------------------------------

function adjdt(me::SIIDT)
  return   max(0.0,
               me.balance[me.balance[:SCEN] .== :dt, :TAX_CREDIT_EOC][1,1] -
                 me.balance[me.balance[:SCEN] .== :be, :TAX_CREDIT_EOC][1,1])
 end

## Private ---------------------------------------------------------------------

function shock!(me::SIIDT,
                buckets::Buckets,
                asset_other::AssetOther,
                liab_other::LiabOther,
                capmkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Dynamic)
  me.balance =me.balance[me.balance[:SCEN] .== :be, :]
    add!(me, :dt, capmkt_be, invest_dfs, buckets, asset_other, liab_other, dyn,
         (sii_dt, inv) -> dtshock!(inv, sii_dt) )
  return me
end


function dtshock!(me::Invest, dt::SIIDT)
    me.mv_total_init += dt.bscr + dt.adj_tp + dt.scr_op
end

