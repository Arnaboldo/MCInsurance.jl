# Constructors -----------------------------------------------------------------
function SIIMktSpread()
  tf = TimeFrame()
  shock_type = :na
  sub_modules =  [:BONDS, :SECUR, :CD_UP, :CD_DOWN]
  balance = DataFrame()
  shocks = [cd => 0.0 for cd in sub_modules]
  return SIIMktSpread(tf, shock_type, sub_modules, balance, shocks)
end


function SIIMktSpread(tf::TimeFrame,
                  balance_be::DataFrame,
                  df_sii_mkt_general::DataFrame,
                  df_sii_mkt_spread_fbonds::DataFrame)
  me = SIIMktSpread()
  me.tf = tf
  me.balance =  deepcopy(balance_be)
  return me
end

## Interface -------------------------------------------------------------------

function scr(me::SIIMktSpread)
  warn("SII spread risk has not yet been implemented")
   return 0.0, 0.0
end

## Private ---------------------------------------------------------------------

function shock!(me::SIIMktSpread,
                buckets::Buckets,
                asset_other::AssetOther,
                liab_other::LiabOther,
                capmkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Dynamic)
  me.balance =me.balance[me.balance[:SCEN] .== :be, :]
  for sm in [:CD_UP, :CD_DOWN]
    add!(me, sm, capmkt_be, invest_dfs, buckets, asset_other, liab_other, dyn,
         (sii_eq, inv) -> mkteqshock!(inv, sii_eq, sm) )
  end
  return me
end

function mktshock!(me::Invest, mkt_eq::SIIMktSpread, sm::Symbol)
  # fixme: mktschock for spread risk not yet implemented
end

