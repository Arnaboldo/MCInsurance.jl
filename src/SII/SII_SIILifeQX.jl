# Constructors -----------------------------------------------------------------
function SIILifeQX()
  tf = TimeFrame()
  shock_type = :Buckets
  balance = DataFrame()
  shock = 0.0
  return SIILifeQX(tf, shock_type, balance, shock)
end


function SIILifeQX(tf::TimeFrame,
                   balance_be::DataFrame,
                   df_sii_life_general::DataFrame)
  me = SIILifeQX()
  me.tf = tf
  me.balance =  deepcopy(balance_be)
  me.shock = df_sii_life_general[1,:QX]
  return me
end

## Interface -------------------------------------------------------------------

function shock!(me::SIILifeQX,
                buckets::Buckets,
                other_be::Other,
                cap_mkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Dynamic)
  me.balance = me.balance[me.balance[:SCEN] .== :be, :]
  add!(me, :QX, cap_mkt_be, invest_dfs, buckets, other_be, dyn,
       (sii_qx, bkts) -> qxshock!(bkts, sii_qx) )
  return me
end

## Private ---------------------------------------------------------------------


function qxshock!(bkt::Bucket,  qx::SIILifeQX)
  if bkt.select[:QX] ## mortality character hence qx shock
    bkt.prob_be[:,QX] = min(1, (1 + qx.shock) * bkt.prob_be[:,QX])
    bkt.prob_be[:,SX] = min(1 .- bkt.prob_be[:,QX], bkt.prob_be[:,SX])
    bkt.prob_be[:,PX] =  1.0 .- bkt.prob_be[:,QX] - bkt.prob_be[:,SX]
  end
end


function qxshock!(me::Buckets, qx::SIILifeQX)
  for bkt in me.all
    qxshock!(bkt, qx)
  end
end

function scr(me::SIILifeQX)
  scr_net =  bof(me, :QX) - bof(me, :be)
  scr_gross =  scr_net + fdb(me, :be) - fdb(me, :QX)
  return scr_net, scr_gross
end
