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
#  me.shocks = ????  Fixme: not yet implemented
  return me
end

## Interface -------------------------------------------------------------------

function shock!(me::SIIMktConc,
                buckets::Buckets,
                other::Other,
                capmkt_dfs::Any,
                invest_dfs::Any,
                dyn::Dynamic)

  capmkt_be = CapMkt([:sii_mkt_eq, me.tf, 1, capmkt_dfs]...)

  me.balance =me.balance[me.balance[:SCEN] .== :be, :]
  for sm in [:cp_1]
    add!(me, sm, capmkt_be, invest_dfs, buckets, other, dyn,
         (sii_eq, inv) -> mktconcshock!(inv, sii_eq, sm) )
  end
  return me
end

## Private ---------------------------------------------------------------------

function mktconcshock!(me::Invest, mkt_eq::SIIMktConc, sm::Symbol)
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

function scr(me::SIIMktConc)
  warn("SII concentration risk has not yet been implemented")
   return 0.0, 0.0
end
