# Constructors -----------------------------------------------------------------
function SIIMktConc()
  tf = TimeFrame()
  shock_type = :na
  sub_modules =  [:na]
  balance = DataFrame()
  shocks = [cp => 0.0 for cp in [:cp_1]]
  return SIIMktConc(tf, shock_type, sub_modules, balance, shocks)
end


function SIIMktConc(tf::TimeFrame,
                  balance_be::DataFrame,
                  df_sii_mkt_general::DataFrame)
  me = SIIMktConc()
  me.tf = tf
  me.balance =  deepcopy(balance_be)
  return me
end

## Interface -------------------------------------------------------------------

function scr(me::SIIMktConc)
  warn("SII concentration risk has not yet been implemented")
   return 0.0, 0.0
end

## Private ---------------------------------------------------------------------

function shock!(me::SIIMktConc,
                buckets::Buckets,
                other::Other,
                capmkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Dynamic)
  me.balance =me.balance[me.balance[:SCEN] .== :be, :]
  for sm in [:cp_1]
    add!(me, sm, capmkt_be, invest_dfs, buckets, other, dyn,
         (sii_eq, inv) -> mktconcshock!(inv, sii_eq, sm) )
  end
  return me
end

function mktconcshock!(me::Invest, mkt_eq::SIIMktConc, sm::Symbol)
  # fixme: mktconcshock not yet implemented
end

