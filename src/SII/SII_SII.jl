# Constructors -----------------------------------------------------------------

function SII(buckets::Buckets,
             other::Other,
             capmkt_dfs::Vector{DataFrame},
             invest_dfs::Vector{DataFrame},
             dyn_dfs::Vector{DataFrame}
             )
  tf = buckets.tf
  ## construct objects prior to any shock
  cap_mkt_be = CapMkt([:be, tf, 1, capmkt_dfs]...)
  buckets_be = deepcopy(buckets)
  other_be = deepcopy(other)
  for so in other_be.debt_subord # SII liabiities ignore subordinated debt
    so.nominal = 0.0
    so.interest = 0.0
  end
  invest_be = Invest([:be, cap_mkt_be, invest_dfs]...)
  ## initialize dyn prior to any shock so that shock impacts dynamic rules
  dyn = Dynamic([invest_be, buckets, other_be, dyn_dfs]...)


  bal_cols = [MCInsurance.col_V, :BONUS_EOC, :SCEN]
  balance = DataFrame([MCInsurance.col_V_TYPES, Float64, Symbol], bal_cols, 0)
  sp_cqs = [utf8("none") => -1]

  dim = [:MKT, :DEF, :LIFE, :HEALTH, :NONLIFE]
  corr = zeros(Float64, 1,1)

  mkt = SIIMkt()
  def = SIIDef()

  return SII(tf, capmkt_dfs, invest_dfs, dyn_dfs,
             cap_mkt_be, invest_be, buckets_be, other_be, dyn, balance, sp_cqs,
             dim,
             corr,
             mkt, def)
end


function SII(buckets::Buckets,
             other::Other,
             df_sii_corr::DataFrame,
             df_sii_rating::DataFrame,
             sii_mkt_dfs::Vector{DataFrame},
             sii_def_dfs::Vector{DataFrame},
             capmkt_dfs::Vector{DataFrame},
             invest_dfs::Vector{DataFrame},
             dyn_dfs::Vector{DataFrame})


  me = SII(buckets, other, capmkt_dfs, invest_dfs, dyn_dfs)
  me.corr = array(df_sii_corr)
  add!(me, :be, me.cap_mkt_be, me.invest_dfs,
       me.buckets_be, me.other_be, me.dyn, nothing)
  me.sp_cqs = Dict(df_sii_rating[:SP],df_sii_rating[:CQS])
  me.mkt = SIIMkt(me.tf, me.balance, sii_mkt_dfs...)
  me.def = SIIDef(me.tf, me.balance, me.invest_be, me.sp_cqs, sii_def_dfs...)

  return me
end

## Interface -------------------------------------------------------------------

function scr(me::SII)
  for (i,ind) in enumerate(me.dim)  eval(:($ind = $i)) end
#   for (i,mkt_ind) in enumerate(me.dim_mkt)  eval(:($mkt_ind = $i)) end

  scr_net = zeros(Float64, length(me.dim))
  scr_gross = zeros(Float64, length(me.dim))
  scr_op = 0.0
  scr_intang = 0.0
  adj_dt = 0.0

  scr_net[MKT], scr_gross[MKT] = scr(me.mkt, me)
  scr_net[DEF], scr_gross[DEF] = scr(me.def, me)

  bscr_net = - sqrt(scr_net' * me.corr * scr_net)[1] + scr_intang
  bscr_gross = - sqrt(scr_gross' * me.corr * scr_gross)[1] + scr_intang

  adj_tp = -min(max(bscr_gross - bscr_net, fdb(me, :be)), 0)

  return bscr_gross + adj_tp + adj_dt + scr_op
end

## Private ---------------------------------------------------------------------
