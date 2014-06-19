# Constructors -----------------------------------------------------------------
function SIIDef()
  tf = TimeFrame()
  dim = [:TYPE1, :TYPE2]
  corr = zeros(Float64, 1, 1)
  type1 = SIIDefType1()
  type2 = SIIDefType2()
  return SIIDef(tf, dim, corr, type1, type2)
end

function SIIDef(tf::TimeFrame,
                balance::DataFrame,
                invest_be::Invest,
                sp_cqs::Dict{UTF8String,Int64},
                df_sii_def_corr::DataFrame,
                df_sii_def_type1_prob::DataFrame)
  me = SIIDef()
  me.tf = tf

  me.corr = array(df_sii_def_corr)

  me.type1 =  SIIDefType1(me.tf, invest_be, sp_cqs, df_sii_def_type1_prob)
  me.type2 =  SIIDefType2(me.tf, balance)

  return me
end

## Interface -------------------------------------------------------------------

function scr(me::SIIDef, sii::SII)
  for (i,ind) in enumerate(me.dim)  eval(:($ind = $i)) end

  scr_vec_net = zeros(Float64, length(me.dim))
  scr_vec_gross = zeros(Float64, length(me.dim))

  shock!(me.type2,
         sii.buckets_be, sii.other_be, sii.capmkt_dfs, sii.invest_dfs, sii.dyn)
  scr_vec_net[TYPE1], scr_vec_gross[TYPE1] = scr(me.type1)
  scr_vec_net[TYPE2], scr_vec_gross[TYPE2] = scr(me.type2)

  scr_net = -sqrt(scr_vec_net' * me.corr * scr_vec_net)[1]
  scr_gross= -sqrt(scr_vec_gross' * me.corr * scr_vec_gross)[1]

  return scr_net, scr_gross
end
