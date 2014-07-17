# Constructors -----------------------------------------------------------------
function SIILifeQX()
  tf = TimeFrame()
  shock_type = :Buckets
  balance = DataFrame()
  shock = 0.0
  return SIILifeQX(tf, shock_type, balance, shock)
end


function SIILifeQX(tf::TimeFrame,
                   bkts_be::Buckets,
                   oth_be::Other,
                   capmkt_be::CapMkt,
                   dyn::Dynamic,
                   inv_dfs::Vector{DataFrame},
                   balance_be::DataFrame,
                   df_sii_life_general::DataFrame)
  me = SIILifeQX()
  me.tf = tf
  me.balance =  deepcopy(balance_be)
  me.shock = df_sii_life_general[1,:QX]
  ## identify those buckets that are subject to mortality / longevity risk:
  ## bucket.select_qx = 1 / 0
  testqx!(bkts_be, me, oth_be, capmkt_be, inv_dfs, dyn)
  shock!(me, bkts_be, oth_be, capmkt_be, inv_dfs, dyn)
  return me
end

## Interface -------------------------------------------------------------------

function shock!(me::SIILifeQX,
                buckets::Buckets,
                oth_be::Other,
                capmkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Dynamic)
  me.balance = me.balance[me.balance[:SCEN] .== :be, :]
  add!(me, :QX, capmkt_be, invest_dfs, buckets, oth_be, dyn,
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

## identify those buckets that are subject to mortality risk (fast version)
function testqx!(me::Buckets,
                 siiqx::SIILifeQX,
                 oth_be::Other,
                 capmkt_be::CapMkt,
                 invest_dfs::Any,
                 dyn::Dynamic)
  ## This function does not properly take into account second order
  ## effects due to the effect of boni.  Nevertheless for most portfolios the
  ## result should be the same as the result from testqx!.
  ## speed: ~ buckets.n

  invest = Invest([:sii_inv, capmkt_be, invest_dfs]...)
  discount = meancumdiscrf(invest.c,invest.c.yield_rf_init, me.n_c)

  for (b, bkt) in enumerate(me.all)
    tpg_be =  tpgeoc(vcat(zeros(Float64, 1, 3), bkt.prob_be),
                     vcat(1.0, discount),
                     vcat(zeros(Float64, 1, N_COND), bkt.cond)
                     )
    bkt_test = deepcopy(bkt)
    merge!(bkt_test.select, [:QX => true])
    qxshock!(bkt_test, siiqx)
    tpg_shock =  tpgeoc(vcat(zeros(Float64, 1, 3), bkt_test.prob_be),
                        vcat(1.0, discount),
                        vcat(zeros(Float64, 1, N_COND), bkt_test.cond)
                        )
    me.all[b].select[:QX] = (tpg_shock < tpg_be)
  end
end


## identify those buckets that are subject to mortality risk (exact version)
function exacttestqx!(me::Buckets,
                      siiqx::SIILifeQX,
                      oth_be::Other,
                      capmkt_be::CapMkt,
                      invest_dfs::Any,
                      dyn::Dynamic)
  ## This function is exact but it can be very slow because for
  ## each bucket we project the whole portfolio of all buckets.
  ## speed: ~ buckets.n * buckets.n
  tp_be = siiqx.balance[1,:TPG_EOC] + siiqx.balance[1,:BONUS_EOC]
  bkts_test = deepcopy(me)
  for (b, bkt) in enumerate(bkts_test.all)
    merge!(me.all[b].select, [:QX => true])
    balance_shock =
      balance(siiqx, :test, capmkt_be, invest_dfs, bkts_test, oth_be, dyn,
              (sii_qx, bkts) -> qxshock!(bkts, sii_qx))
    tp_shock = balance_shock[1,:TPG_EOC] + balance_shock[1,:BONUS_EOC]
    bkt = deepcopy(me.all[b]) ## reverse the shock
    me.all[b].select[:QX] = (tp_shock < tp_be ? 1 : 0)
  end
end

