# Constructors -----------------------------------------------------------------

function SII(buckets::Buckets,
             asset_other::AssetOther,
             liab_other::LiabOther,
             yield_mkt_init::Float64,
             capmkt_dfs::Vector{DataFrame},
             invest_dfs::Vector{DataFrame},
             dyn_dfs::Vector{DataFrame}
             )
  tf = buckets.tf
  ## construct objects prior to any shock
  capmkt_be = CapMkt([:be, tf, 1, capmkt_dfs]...)
  bkts_be = deepcopy(buckets)

  asset_oth_be = deepcopy(asset_other)

  liab_oth_be = deepcopy(liab_other)
  liab_oth_be.debt_subord = Array(Debt, 0)


  invest_be = Invest([:be, capmkt_be, invest_dfs]..., bkts_be.n_c)
  ## initialize dyn prior to any shock so that shock impacts dynamic rules
  dyn = Dynamic([invest_be, buckets, liab_oth_be, yield_mkt_init, dyn_dfs]...)


  bal_cols = [MCInsurance.col_V, :BONUS_EOC, :TAX_CREDIT_EOC, :SCEN]
  balance = DataFrame([MCInsurance.col_V_TYPES, Float64, Float64, Symbol],
                      bal_cols,
                      0)
  sp_cqs = [utf8("none") => -1]

  dim = [:MKT, :DEF, :LIFE, :HEALTH, :NONLIFE]
  corr = zeros(Float64, 1,1)
  mkt = SIIMkt()
  def = SIIDef()
  life = SIILife()
  op = SIIOp()
  dt = SIIDT()

  return SII(tf, capmkt_dfs, invest_dfs, dyn_dfs,
             capmkt_be, invest_be, bkts_be, asset_oth_be, liab_oth_be,
             dyn, balance, sp_cqs,
             dim,
             corr,
             mkt, def, life, op,
             dt,
             0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
end


function SII(buckets::Buckets,
             asset_other::AssetOther,
             liab_other::LiabOther,
             yield_mkt_init::Float64,
             df_lc_various::DataFrame,
             df_sii_corr::DataFrame,
             df_sii_rating::DataFrame,
             sii_mkt_dfs::Vector{DataFrame},
             sii_def_dfs::Vector{DataFrame},
             sii_life_dfs::Vector{DataFrame},
             capmkt_dfs::Vector{DataFrame},
             invest_dfs::Vector{DataFrame},
             dyn_dfs::Vector{DataFrame})

  me = SII(buckets, asset_other, liab_other, yield_mkt_init,
           capmkt_dfs, invest_dfs, dyn_dfs)

  asset_other_no_dt = deepcopy(me.asset_oth_be)
  ## existing tax credit is still modeled
  asset_other_no_dt.model_new_tax_credit = false


  me.corr = array(df_sii_corr)
  add!(me, :be, me.capmkt_be, me.inv_dfs,
       me.bkts_be, asset_other_no_dt, me.liab_oth_be, me.dyn, nothing)
  cost_ul = 0.0 # fixme: unit linked not yet implemented
  me.sp_cqs = Dict(df_sii_rating[:SP],df_sii_rating[:CQS])
  me.mkt = SIIMkt(me.tf,
                  me.bkts_be, asset_other_no_dt, me.liab_oth_be, me.capmkt_be,
                  me.dyn, me.inv_dfs,
                  me.balance, sii_mkt_dfs...)
  me.def = SIIDef(me.tf,
                  me.bkts_be, asset_other_no_dt, me.liab_oth_be, me.capmkt_be,
                  me.dyn, me.inv_dfs,
                  me.balance, me.inv_be, me.sp_cqs, sii_def_dfs...)
  me.life = SIILife(me.tf,
                    me.bkts_be, asset_other_no_dt, me.liab_oth_be, me.capmkt_be,
                    me.dyn, me.inv_dfs,
                    me.balance, sii_life_dfs...)
  me.op = SIIOp(me.tf,
                me.balance[1, :TPG_EOC]+me.balance[1, :BONUS_EOC],
                cost_ul,
                df_lc_various)

  me.bscr_net, me.bscr = bscr(me)
  me.scr_op = scr(me.op, me.bscr)

  me.adj_tp = adjtp(me)
  me.dt = SIIDT(me.tf,
                    me.bkts_be, me.asset_oth_be, me.liab_oth_be, me.capmkt_be,
                    me.dyn, me.inv_dfs,  me.balance,
                    me.bscr, me.adj_tp, me.scr_op)
  me.adj_dt = adjdt(me.dt)

  me.scr = me.bscr + me.adj_tp + me.adj_dt + me.scr_op
  return me
end

## Interface -------------------------------------------------------------------


function bscr(me::SII)
  for (i,ind) in enumerate(me.dim)  eval(:($ind = $i)) end

  scr_net = zeros(Float64, length(me.dim))
  scr_gross = zeros(Float64, length(me.dim))
  scr_intang = 0.0
  adj_dt = 0.0

  scr_net[MKT], scr_gross[MKT] = scr(me.mkt)
  scr_net[DEF], scr_gross[DEF] = scr(me.def)
  scr_net[LIFE], scr_gross[LIFE] = scr(me.life)

  bscr_net = - sqrt(scr_net' * me.corr * scr_net)[1] + scr_intang
  bscr_gross = - sqrt(scr_gross' * me.corr * scr_gross)[1] + scr_intang
  return bscr_net, bscr_gross
end

adjtp(me::SII) = -min(max(me.bscr - me.bscr_net, fdb(me, :be)), 0)

function adjdt(me::SII)

  return 0.0
end

# function getscr(me::SII)
#   # produce Int variables corresponding to the symbols in me.dim
#   b_scr = bscr(me)
#   return(b_scr[2] + adjtp(me, b_scr) + adjdt(me) +  scr(me.op, b_scr[2]))
# end

## Private ---------------------------------------------------------------------
