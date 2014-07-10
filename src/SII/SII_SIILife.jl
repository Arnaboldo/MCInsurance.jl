# Constructors -----------------------------------------------------------------
function SIILife()
  tf = TimeFrame()
  dim = [:L_QX, :L_SX, :L_PX, :L_DM, :L_COST, :L_REV, :L_CAT]
  corr = zeros(Float64, 1, 1)
  qx =   SIILifeQX()
  sx =   SIILifeSX()
  px =   SIILifePX()
  cost = SIILifeCost()
  cat =  SIILifeCat()
  return SIILife(tf, dim, corr, qx, sx, px, cost, cat)
end


function SIILife(tf::TimeFrame,
                 balance_be::DataFrame,
                 df_sii_life_general::DataFrame,
                 df_sii_life_corr::DataFrame)
  me = SIILife()
  me.tf = tf
  me.corr = array(df_sii_life_corr)
  me.qx = SIILifeQX(tf, balance_be, df_sii_life_general)
  me.sx = SIILifeSX(tf, balance_be, df_sii_life_general)
  me.px = SIILifePX(tf, balance_be, df_sii_life_general)
  me.cost = SIILifeCost(tf, balance_be, df_sii_life_general)
  me.cat = SIILifeCat(tf, balance_be, df_sii_life_general)
  return me
end

## Interface -------------------------------------------------------------------

function scr(me::SIILife, sii::SII)
  for (i,ind) in enumerate(me.dim)  eval(:($ind = $i)) end
  scr_vec_net = zeros(Float64, length(me.dim))
  scr_vec_gross = zeros(Float64, length(me.dim))

  ## identify those buckets that are subject to mortality / longevity risk:
  ## bucket.select_qx = 1 / 0
  quicktestqx!(sii.buckets_be, me.qx, sii.other_be, sii.cap_mkt_be,
               sii.invest_dfs, sii.dyn)
  quicktestsx!(sii.buckets_be, me.sx, sii.other_be, sii.cap_mkt_be,
               sii.invest_dfs, sii.dyn)


  shock!(me.qx,
         sii.buckets_be, sii.other_be, sii.cap_mkt_be, sii.invest_dfs, sii.dyn)
  shock!(me.px,
         sii.buckets_be, sii.other_be, sii.cap_mkt_be, sii.invest_dfs, sii.dyn)
  shock!(me.sx,
         sii.buckets_be, sii.other_be, sii.cap_mkt_be, sii.invest_dfs, sii.dyn)
  shock!(me.cost,
         sii.buckets_be, sii.other_be, sii.cap_mkt_be, sii.invest_dfs, sii.dyn)
  shock!(me.cat,
         sii.buckets_be, sii.other_be, sii.cap_mkt_be, sii.invest_dfs, sii.dyn)

  scr_vec_net[L_QX],    scr_vec_gross[L_QX]      =  scr(me.qx)
  scr_vec_net[L_SX],    scr_vec_gross[L_SX]      =  scr(me.sx)
  scr_vec_net[L_PX],    scr_vec_gross[L_PX]      =  scr(me.px)
  scr_vec_net[L_COST],  scr_vec_gross[L_COST]    =  scr(me.cost)
  scr_vec_net[L_CAT],   scr_vec_gross[L_CAT]     =  scr(me.cat)

  scr_net = -sqrt(scr_vec_net' * me.corr * scr_vec_net)[1]
  scr_gross= -sqrt(scr_vec_gross' * me.corr * scr_vec_gross)[1]

  return scr_net, scr_gross
end

## Private ---------------------------------------------------------------------

## identify those buckets that are subject to mortality risk (fast version)
function quicktestsx!(me::Buckets,
                      sx::SIILifeSX,
                      other_be::Other,
                      capmkt_be::CapMkt,
                      invest_dfs::Any,
                      dyn::Dynamic)
  ## This function does not properly take into account second order
  ## effects due to the effect of boni.  Nevertheless for most portfolios the
  ## result should be the same as the result from an exact calculation.
  ## speed: ~ buckets.n

  invest = Invest([:sii_inv, capmkt_be, invest_dfs]...)
  discount = meancumdiscrf(invest.c,invest.c.yield_rf_init, me.n_c)

  for bkt in me.all
    tpg_be =  tpgeoc(vcat(zeros(Float64, 1, 3), bkt.prob_be),
                     vcat(1.0, discount),
                     vcat(zeros(Float64, 1, N_COND), bkt.cond)
                     )
    merge!(bkt.select, [:SX_PENSION => false]) ## fixme: pension not implemented
    for sm in sx.sub_modules
      bkt_test = deepcopy(bkt)
      merge!(bkt_test.select, [sm => true])
      sxshock!(bkt_test, sx, sxshockfunction(sx, sm), sm)
      tpg_shock =  tpgeoc(vcat(zeros(Float64, 1, 3), bkt_test.prob_be),
                          vcat(1.0, discount),
                          vcat(zeros(Float64, 1, N_COND), bkt_test.cond)
                          )
      if tpg_shock < tpg_be
        merge!(bkt.select, [sm => true])
      else
        merge!(bkt.select, [sm => false])
      end
    end
  end
end


## identify those buckets that are subject to mortality risk (exact version)
function testqx!(me::Buckets,
                 siiqx::SIILifeQX,
                 other_be::Other,
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
      balance(siiqx, :test, capmkt_be, invest_dfs, bkts_test, other_be, dyn,
              (sii_qx, bkts) -> qxshock!(bkts, sii_qx))
    tp_shock = balance_shock[1,:TPG_EOC] + balance_shock[1,:BONUS_EOC]
    bkt = deepcopy(me.all[b]) ## reverse the shock
    me.all[b].select[:QX] = (tp_shock < tp_be ? 1 : 0)
  end
end

## identify those buckets that are subject to mortality risk (fast version)
function quicktestqx!(me::Buckets,
                      siiqx::SIILifeQX,
                      other_be::Other,
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
    merge!(me.all[b].select, [:QX => true])
    qxshock!(bkt, siiqx)
    tpg_shock =  tpgeoc(vcat(zeros(Float64, 1, 3), bkt.prob_be),
                        vcat(1.0, discount),
                        vcat(zeros(Float64, 1, N_COND), bkt.cond)
                        )
    me.all[b].select[:QX] = (tpg_shock < tpg_be)
  end
end
