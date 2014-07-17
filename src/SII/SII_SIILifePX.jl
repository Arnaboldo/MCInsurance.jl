# Constructors -----------------------------------------------------------------
function SIILifePX()
  tf = TimeFrame()
  shock_type = :Buckets
  balance = DataFrame()
  shock = 0.0
  return SIILifePX(tf, shock_type, balance, shock)
end


function SIILifePX(tf::TimeFrame,
                   bkts_be::Buckets,
                   oth_be::Other,
                   capmkt_be::CapMkt,
                   dyn::Dynamic,
                   inv_dfs::Vector{DataFrame},
                   balance_be::DataFrame,
                   df_sii_life_general::DataFrame)
  me = SIILifePX()
  me.tf = tf
  me.balance =  deepcopy(balance_be)
  me.shock = df_sii_life_general[1,:PX]
  shock!(me, bkts_be, oth_be, capmkt_be, inv_dfs, dyn)
  return me
end

## Interface -------------------------------------------------------------------

function shock!(me::SIILifePX,
                buckets::Buckets,
                oth_be::Other,
                capmkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Dynamic)
  me.balance = me.balance[me.balance[:SCEN] .== :be, :]
  add!(me, :PX, capmkt_be, invest_dfs, buckets, oth_be, dyn,
       (sii_px, bkts) -> pxshock!(bkts, sii_px) )
  return me
end

## Private ---------------------------------------------------------------------


function pxshock!(bkt::Bucket,  px::SIILifePX)
  if !(bkt.select[:QX]) ## longevity character hence px shock
    bkt.prob_be[:,QX] =  (1 + px.shock) * bkt.prob_be[:,QX]
    ## px.shock < 0, hence bkt.prob_be[:,SX] does not need to be adjusted
    bkt.prob_be[:,PX] =  1.0 .- bkt.prob_be[:,QX] - bkt.prob_be[:,SX]
  end
end


function pxshock!(me::Buckets, px::SIILifePX)
  for bkt in me.all
    pxshock!(bkt, px)
  end
end

function scr(me::SIILifePX)
  scr_net =  bof(me, :PX) - bof(me, :be)
  scr_gross =  scr_net + fdb(me, :be) - fdb(me, :PX)
  return scr_net, scr_gross
end
