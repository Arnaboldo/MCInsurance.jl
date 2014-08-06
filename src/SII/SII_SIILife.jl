# Constructors -----------------------------------------------------------------
function SIILife()
  tf = TimeFrame()
  dim = [:L_QX, :L_PX, :L_DM, :L_SX, :L_COST, :L_REV, :L_CAT]
  corr = zeros(Float64, 1, 1)
  qx =   SIILifeQX()
  sx =   SIILifeSX()
  px =   SIILifePX()
  cost = SIILifeCost()
  cat =  SIILifeCat()
  return SIILife(tf, dim, corr, qx, sx, px, cost, cat)
end


function SIILife(tf::TimeFrame,
                 bkts_be::Buckets,
                 asset_other::AssetOther,
                 liab_other::LiabOther,
                 capmkt_be::CapMkt,
                 dyn::Dynamic,
                 inv_dfs::Vector{DataFrame},
                 balance_be::DataFrame,
                 df_sii_life_general::DataFrame,
                 df_sii_life_corr::DataFrame)
  me = SIILife()
  me.tf = tf
  me.corr = array(df_sii_life_corr)
  ## The constructors of me.qx and me.sx change bkts.be, which
  ## is a field in the SII object that calls SIILife.
  ## Order is important because me.px depends on the change
  ## of bkts.be made by the constructor of me.qx
  me.qx = SIILifeQX(tf, bkts_be, asset_other, liab_other, capmkt_be,
                    dyn, inv_dfs, balance_be, df_sii_life_general)
  me.sx = SIILifeSX(tf, bkts_be, asset_other, liab_other, capmkt_be,
                    dyn, inv_dfs, balance_be, df_sii_life_general)
  me.px = SIILifePX(tf, bkts_be, asset_other, liab_other, capmkt_be,
                    dyn, inv_dfs, balance_be, df_sii_life_general)
  me.cost = SIILifeCost(tf, bkts_be, asset_other, liab_other, capmkt_be,
                        dyn, inv_dfs, balance_be, df_sii_life_general)
  me.cat = SIILifeCat(tf, bkts_be, asset_other, liab_other, capmkt_be,
                      dyn, inv_dfs, balance_be, df_sii_life_general)
  return me
end

## Interface -------------------------------------------------------------------

function scr(me::SIILife)
  for (i,ind) in enumerate(me.dim)  eval(:($ind = $i)) end
  scr_vec_net = zeros(Float64, length(me.dim))
  scr_vec_gross = zeros(Float64, length(me.dim))


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

