# Constructors -----------------------------------------------------------------
function SIILifePX()
  tf = TimeFrame()
  shock_type = :Buckets
  balance = DataFrame()
  shock = 0.0
  bkt_select = Array(Bool,0)
  return SIILifePX(tf, shock_type, balance, shock, bkt_select)
end


function SIILifePX(tf::TimeFrame,
                   bkts_be::Buckets,
                   asset_other::AssetOther,
                   liab_other::LiabOther,
                   capmkt_be::CapMkt,
                   dyn::Dynamic,
                   inv_dfs::Vector{DataFrame},
                   balance_be::DataFrame,
                   df_sii_life_general::DataFrame)
  me = SIILifePX()
  me.tf = tf
  me.balance =  deepcopy(balance_be)
  me.shock = df_sii_life_general[1,:PX]
  ## select bucket to be shocked
  select!(me, bkts_be, liab_other, capmkt_be, inv_dfs, dyn)
  shock!(me, bkts_be, asset_other, liab_other, capmkt_be, inv_dfs, dyn)
  return me
end

## Interface -------------------------------------------------------------------

function scr(me::SIILifePX)
  scr_net =  bof(me, :PX) - bof(me, :be)
  scr_gross =  scr_net + fdb(me, :be) - fdb(me, :PX)
  return scr_net, scr_gross
end

## Private ---------------------------------------------------------------------

function shock!(me::SIILifePX,
                buckets::Buckets,
                asset_other::AssetOther,
                liab_other::LiabOther,
                capmkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Dynamic)
  me.balance = me.balance[me.balance[:SCEN] .== :be, :]
  add!(me, :PX, capmkt_be, invest_dfs, buckets, asset_other, liab_other, dyn,
       (sii_px, bkts) -> pxshock!(bkts, sii_px) )
  return me
end

function pxshock!(bkt::Bucket,  px::SIILifePX)
  bkt.prob_ie[:,QX] =  (1 + px.shock) * bkt.prob_ie[:,QX]
  ## px.shock < 0, hence bkt.prob_ie[:,SX] does not need to be adjusted
  bkt.prob_ie[:,PX] =  1.0 .- bkt.prob_ie[:,QX] - bkt.prob_ie[:,SX]
end


function pxshock!(me::Buckets, px::SIILifePX)
  for (b, bkt) in enumerate(me.all)
    if px.bkt_select[b]
      pxshock!(bkt, px)
    end
  end
end

## identify those buckets that are subject to mortality risk (fast version)
function select!(me::SIILifePX,
                 bkts::Buckets,
                 liab_oth_be::LiabOther,
                 capmkt_be::CapMkt,
                 invest_dfs::Any,
                 dyn::Dynamic)
  ## This function does not properly take into account second order
  ## effects due to the effect of boni.  Nevertheless for most portfolios the
  ## result should be the same as the result from testqx!.
  ## speed: ~ buckets.n

  me.bkt_select = Array(Bool, bkts.n)

  invest = Invest([:sii_inv, capmkt_be, invest_dfs]..., bkts.n_c)
  fixed = Fixed(invest, bkts)
  discount = meandiscrf(invest.c,invest.c.yield_rf_init, 1, bkts.n_c)

  for (b, bkt) in enumerate(bkts.all)
    tpg_be =  tpgeoc(vcat(zeros(Float64, 1, 3), bkt.prob_ie),
                     vcat(1.0, discount),
                     vcat(zeros(Float64, 1, N_COND), bkt.cond),
                     vcat(0, invest.ig[invest.id[:cash]].cost.rel_c),
                     vcat(0, bkt.portion_c .* fixed.cost_abs_gc_c))
    bkt_test = deepcopy(bkt)
    pxshock!(bkt_test, me)
    tpg_shock =  tpgeoc(vcat(zeros(Float64, 1, 3), bkt_test.prob_ie),
                        vcat(1.0, discount),
                        vcat(zeros(Float64, 1, N_COND), bkt_test.cond),
                        vcat(0, invest.ig[invest.id[:cash]].cost.rel_c),
                        vcat(0, bkt.portion_c .* fixed.cost_abs_gc_c))
    me.bkt_select[b] = (tpg_shock < tpg_be)
  end
end


