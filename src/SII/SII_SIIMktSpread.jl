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
#  me.shocks = ????  Fixme: not yet implemented
  return me
end

## Interface -------------------------------------------------------------------

function shock!(me::SIIMktSpread,
                buckets::Buckets,
                other::Other,
                capmkt_dfs::Any,
                invest_dfs::Any,
                dyn::Dynamic)

  capmkt_be = CapMkt([:sii_mkt_eq, me.tf, 1, capmkt_dfs]...)

  me.balance =me.balance[me.balance[:SCEN] .== :be, :]
  for sm in [:CD_UP, :CD_DOWN]
    add!(me, sm, capmkt_be, invest_dfs, buckets, other, dyn,
         (sii_eq, inv) -> mkteqshock!(inv, sii_eq, sm) )
  end
  return me
end

## Private ---------------------------------------------------------------------

function mktshock!(me::Invest, mkt_eq::SIIMktSpread, sm::Symbol)
#   for igr in me.ig
#     if igr.name == :stocks ## Fixme: Needs to be generalized
#       for i = 1:igr.n
#         if igr.sii_risk[i] == sm
#           igr.mv_init[i] *= (1 + mkt_eq.shocks[sm])
#         end ## else: produce another be scenario which does not generate scr
#       end
#       igr.mv_total_init = sum(igr.mv_init)
#     end
#     me.mv_total_init = mvtotalinit(me.ig)
#   end
end

function scr(me::SIIMktSpread)
  warn("SII spread risk has not yet been implemented")
   return 0.0, 0.0
end
