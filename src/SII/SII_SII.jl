# Constructors -----------------------------------------------------------------

function SII(buckets::Buckets,
             other::Other,
             capmkt_dfs::Vector{DataFrame},
             invest_dfs::Vector{DataFrame},
             dyn_dfs::Vector{DataFrame}
             )
  tf = buckets.tf
  ## construct objects prior to any shock
  capmkt_be = CapMkt([:be, tf, 1, capmkt_dfs]...)
  bkts_be = deepcopy(buckets)
  oth_be = deepcopy(other)
  for so in oth_be.debt_subord # SII liabiities ignore subordinated debt
    so.nominal = 0.0
    so.interest = 0.0
  end
  invest_be = Invest([:be, capmkt_be, invest_dfs]...)
  ## initialize dyn prior to any shock so that shock impacts dynamic rules
  dyn = Dynamic([invest_be, buckets, oth_be, dyn_dfs]...)


  bal_cols = [MCInsurance.col_V, :BONUS_EOC, :SCEN]
  balance = DataFrame([MCInsurance.col_V_TYPES, Float64, Symbol], bal_cols, 0)
  sp_cqs = [utf8("none") => -1]

  dim = [:MKT, :DEF, :LIFE, :HEALTH, :NONLIFE]
  corr = zeros(Float64, 1,1)
  mkt = SIIMkt()
  def = SIIDef()
  life = SIILife()
  op = SIIOp()

  return SII(tf, capmkt_dfs, invest_dfs, dyn_dfs,
             capmkt_be, invest_be, bkts_be, oth_be, dyn, balance, sp_cqs,
             dim,
             corr,
             mkt, def, life, op)
end


function SII(buckets::Buckets,
             other::Other,
             df_lc_various::DataFrame,
             df_sii_corr::DataFrame,
             df_sii_rating::DataFrame,
             sii_mkt_dfs::Vector{DataFrame},
             sii_def_dfs::Vector{DataFrame},
             sii_life_dfs::Vector{DataFrame},
             capmkt_dfs::Vector{DataFrame},
             invest_dfs::Vector{DataFrame},
             dyn_dfs::Vector{DataFrame})

  me = SII(buckets, other, capmkt_dfs, invest_dfs, dyn_dfs)
  me.corr = array(df_sii_corr)
  add!(me, :be, me.capmkt_be, me.inv_dfs,
       me.bkts_be, me.oth_be, me.dyn, nothing)
  cost_ul = 0.0 # fixme: unit linked not yet implemented
  me.sp_cqs = Dict(df_sii_rating[:SP],df_sii_rating[:CQS])
  me.mkt = SIIMkt(me.tf,
                  me.bkts_be, me.oth_be, me.capmkt_be, me.dyn, me.inv_dfs,
                  me.balance, sii_mkt_dfs...)
  me.def = SIIDef(me.tf,
                  me.bkts_be, me.oth_be, me.capmkt_be, me.dyn, me.inv_dfs,

                  me.balance, me.inv_be, me.sp_cqs, sii_def_dfs...)
  me.life = SIILife(me.tf,
                    me.bkts_be, me.oth_be, me.capmkt_be, me.dyn, me.inv_dfs,
                    me.balance, sii_life_dfs...)
  me.op = SIIOp(me.tf,
                me.balance[1, :TPG_EOC]+me.balance[1, :BONUS_EOC],
                cost_ul,
                df_lc_various)
  return me
end

## Interface -------------------------------------------------------------------

adjtp(me::SII, b_scr) = -min(max(b_scr[2] - b_scr[1], fdb(me, :be)), 0)

adjdt(me::SII) = 0.0

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

function scr(me::SII)
  # produce Int variables corresponding to the symbols in me.dim
  b_scr = bscr(me)
  return(b_scr[2] + adjtp(me, b_scr) + adjdt(me) +  scr(me.op, b_scr[2]))
end

## Private ---------------------------------------------------------------------
