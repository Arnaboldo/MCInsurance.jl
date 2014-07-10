# Constructors -----------------------------------------------------------------
function SIILifeCat()
  tf = TimeFrame()
  shock_type = :Buckets
  balance = DataFrame()
  shock = 0.0
  return SIILifeCat(tf, shock_type, balance, shock)
end


function SIILifeCat(tf::TimeFrame,
                   balance_be::DataFrame,
                   df_sii_life_general::DataFrame)
  me = SIILifeCat()
  me.tf = tf
  me.balance =  deepcopy(balance_be)
  me.shock = df_sii_life_general[1,:CAT]
  return me
end

## Interface -------------------------------------------------------------------

function shock!(me::SIILifeCat,
                buckets::Buckets,
                other_be::Other,
                cap_mkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Dynamic)
  me.balance = me.balance[me.balance[:SCEN] .== :be, :]
  add!(me, :CAT, cap_mkt_be, invest_dfs, buckets, other_be, dyn,
       (sii_cat, bkts) -> catshock!(bkts, sii_cat) )
  return me
end

## Private ---------------------------------------------------------------------


function catshock!(bkt::Bucket,  cat::SIILifeCat)
  if bkt.select[:QX] ## mortality character hence cat shock
    bkt.prob_be[1,QX] = min(1, bkt.prob_be[1,QX] .+ cat.shock)
    bkt.prob_be[1,SX] = min(1 .- bkt.prob_be[1,QX], bkt.prob_be[1,SX])
    bkt.prob_be[1,PX] =  1.0 .- bkt.prob_be[1,QX] - bkt.prob_be[1,SX]
  end
end


function catshock!(me::Buckets, cat::SIILifeCat)
  for bkt in me.all
    catshock!(bkt, cat)
  end
end

function scr(me::SIILifeCat)
  scr_net =  bof(me, :CAT) - bof(me, :be)
  scr_gross =  scr_net + fdb(me, :be) - fdb(me, :CAT)
  return scr_net, scr_gross
end
