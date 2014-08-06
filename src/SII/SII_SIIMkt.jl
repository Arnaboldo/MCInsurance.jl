# Constructors -----------------------------------------------------------------
function SIIMkt()
  tf = TimeFrame()
  dim = [:INT, :EQ, :PROP, :SPREAD, :FX, :CONC]
  corr_up = zeros(Float64, 1, 1)
  corr_down = zeros(Float64, 1, 1)
  int =    SIIMktInt()
  eq =     SIIMktEq()
  spread = SIIMktSpread()
  conc =   SIIMktConc()
  return SIIMkt(tf, dim, corr_up, corr_down, int, eq, spread, conc)
end

function SIIMkt(tf::TimeFrame,
                bkts_be::Buckets,
                asset_other::AssetOther,
                liab_other::LiabOther,
                capmkt_be::CapMkt,
                dyn::Dynamic,
                inv_dfs::Vector{DataFrame},
                balance::DataFrame,
                df_sii_mkt_general::DataFrame,
                df_sii_mkt_corr_up::DataFrame,
                df_sii_mkt_corr_down::DataFrame,
                df_sii_mkt_interest::DataFrame,
                df_sii_mkt_eq_corr::DataFrame,
                df_sii_mkt_spread_fbonds::DataFrame)
  me = SIIMkt()
  me.tf = tf
  me.corr_up = array(df_sii_mkt_corr_up)
  me.corr_down = array(df_sii_mkt_corr_down)

  me.int =    SIIMktInt(me.tf, bkts_be, asset_other, liab_other, capmkt_be,
                        dyn, inv_dfs,
                        balance, df_sii_mkt_general, df_sii_mkt_interest)
  me.eq =     SIIMktEq(me.tf, bkts_be, asset_other, liab_other, capmkt_be,
                       dyn, inv_dfs,
                       balance, df_sii_mkt_general, df_sii_mkt_eq_corr)
  # me.spread =
  # me.conc =
  return me
end

## Interface -------------------------------------------------------------------

function scr(me::SIIMkt)
  for (i,ind) in enumerate(me.dim)  eval(:($ind = $i)) end

  scr_vec_net = zeros(Float64, length(me.dim))
  scr_vec_gross = zeros(Float64, length(me.dim))

  scr_vec_net[INT],    scr_vec_gross[INT],   scen_up =  scr(me.int)
  scr_vec_net[EQ],     scr_vec_gross[EQ] =              scr(me.eq)
  scr_vec_net[SPREAD], scr_vec_gross[SPREAD] =          scr(me.spread)
  scr_vec_net[CONC],   scr_vec_gross[CONC]   =          scr(me.conc)

  corr = (scen_up ? me.corr_up : me.corr_down )

  scr_net = -sqrt(scr_vec_net' * corr * scr_vec_net)[1]
  scr_gross= -sqrt(scr_vec_gross' * corr * scr_vec_gross)[1]

  return scr_net, scr_gross
end
