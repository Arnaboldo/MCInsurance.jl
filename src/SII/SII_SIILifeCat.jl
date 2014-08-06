# Constructors -----------------------------------------------------------------
function SIILifeCat()
  tf = TimeFrame()
  shock_type = :Buckets
  balance = DataFrame()
  shock = 0.0
  bkt_select = Array(Bool,0)
  return SIILifeCat(tf, shock_type, balance, shock, bkt_select)
end


function SIILifeCat(tf::TimeFrame,
                    bkts_be::Buckets,
                    asset_other::AssetOther,
                    liab_other::LiabOther,
                    capmkt_be::CapMkt,
                    dyn::Dynamic,
                    inv_dfs::Vector{DataFrame},
                    balance_be::DataFrame,
                    df_sii_life_general::DataFrame)
  me = SIILifeCat()
  me.tf = tf
  me.balance =  deepcopy(balance_be)
  me.shock = df_sii_life_general[1,:CAT]
  select!(me, bkts_be, liab_other, capmkt_be, inv_dfs, dyn)
  shock!(me, bkts_be, asset_other, liab_other, capmkt_be, inv_dfs, dyn)
  return me
end

## Interface -------------------------------------------------------------------

function scr(me::SIILifeCat)
  scr_net =  bof(me, :CAT) - bof(me, :be)
  scr_gross =  scr_net + fdb(me, :be) - fdb(me, :CAT)
  return scr_net, scr_gross
end

## Private ---------------------------------------------------------------------

function shock!(me::SIILifeCat,
                buckets::Buckets,
                asset_other::AssetOther,
                liab_other::LiabOther,
                capmkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Dynamic)
  me.balance = me.balance[me.balance[:SCEN] .== :be, :]
  add!(me, :CAT, capmkt_be, invest_dfs, buckets, asset_other, liab_other, dyn,
       (sii_cat, bkts) -> catshock!(bkts, sii_cat) )
  return me
end

function catshock!(bkt::Bucket,  cat::SIILifeCat)
  bkt.prob_be[1,QX] = min(1, bkt.prob_be[1,QX] .+ cat.shock)
  bkt.prob_be[1,SX] = min(1 .- bkt.prob_be[1,QX], bkt.prob_be[1,SX])
  bkt.prob_be[1,PX] =  1.0 .- bkt.prob_be[1,QX] - bkt.prob_be[1,SX]
end

function catshock!(me::Buckets, cat::SIILifeCat)
  for (b,bkt) in enumerate(me.all)
    if cat.bkt_select[b]
      catshock!(bkt, cat)
    end
  end
end

## identify those buckets that are subject to mortality risk (fast version)
function select!(me::SIILifeCat,
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
  discount = meandiscrf(invest.c,invest.c.yield_rf_init, 1, bkts.n_c)

  for (b, bkt) in enumerate(bkts.all)
    tpg_be =  tpgeoc(vcat(zeros(Float64, 1, 3), bkt.prob_be),
                     vcat(1.0, discount),
                     vcat(zeros(Float64, 1, N_COND), bkt.cond),
                     prepend_c(invest.ig[invest.id[:cash]].cost, [0.0, 0.0]),
                     vcat(0, bkt.portion_c))
    bkt_test = deepcopy(bkt)
    catshock!(bkt_test, me)
    tpg_shock =  tpgeoc(vcat(zeros(Float64, 1, 3), bkt_test.prob_be),
                        vcat(1.0, discount),
                        vcat(zeros(Float64, 1, N_COND), bkt_test.cond),
                        prepend_c(invest.ig[invest.id[:cash]].cost, [0.0, 0.0]),
                        vcat(0, bkt.portion_c))
    me.bkt_select[b] = (tpg_shock < tpg_be)
  end
end
