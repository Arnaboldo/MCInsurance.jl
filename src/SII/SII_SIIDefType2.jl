# Constructors -----------------------------------------------------------------
function SIIDefType2()
  tf = TimeFrame()
  shock_type = :Invest
  sub_modules =  [:def]
  balance = DataFrame()
  shocks = [def => 0.0 for def in sub_modules]
  return SIIDefType2(tf, shock_type, sub_modules, balance, shocks)
end


function SIIDefType2(tf::TimeFrame,
                     balance_be::DataFrame)
  me = SIIDefType2()
  me.tf = tf
  me.balance =  deepcopy(balance_be)
#  me.shocks = [def => df_sii_def_general[1,def] for def in me.sub_modules]
  return me
end

## Interface -------------------------------------------------------------------

function shock!(me::SIIDefType2,
                buckets::Buckets,
                other::Other,
                cap_mkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Dynamic)
  me.balance =me.balance[me.balance[:SCEN] .== :be, :]
  for sm in me.sub_modules
    add!(me, sm, cap_mkt_be, invest_dfs, buckets, other, dyn,
         (type2, inv) -> defshock!(inv, type2, sm) )
  end
  return me
end

## Private ---------------------------------------------------------------------

function defshock!(me::Invest, type2::SIIDefType2, sm::Symbol)
 # fixme: defshock not yet implemented
end

function scr(me::SIIDefType2)
#   ind = [ sm in me.balance[:SCEN] ? 1.0 : 0.0  for sm in me.sub_modules ]
#   scr_vec_net =
#     bof(me, :be) .* ind - float64([bof(me, sm) for sm in me.sub_modules ])
#   scr_vec_gross =
#     scr_vec_net + fdb(me, :be) .* ind -
#       float64([fdb(me, sm) for sm in me.sub_modules ])

  warn("SII default type 2 risk has not yet been implemented")
  scr_net = 0.0
  scr_gross = 0.0
  return scr_net, scr_gross
end
