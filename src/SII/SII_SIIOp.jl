# Constructors -----------------------------------------------------------------
function SIIOp()
  tf = TimeFrame()
  prem_earned = 0.0
  prem_earned_prev = 0.0
  tp = 0.0
  cost_ul = 0.0
  return SIIOp(tf, prem_earned, prem_earned_prev, tp, cost_ul)
end

function SIIOp(tf::TimeFrame,
               tp::Float64,
               cost_ul::Float64,
               df_lc_various::DataFrame)
  me = SIIOp()
  me.tf = tf
  me.prem_earned = df_lc_various[1,:EarnedPrem]
  me.prem_earned_prev = df_lc_various[1,:pEarnedPrem]
  me.tp = tp
  me.cost_ul = cost_ul
  return me
end

## Interface -------------------------------------------------------------------

function scr(me::SIIOp, bscr::Float64)
  scr_op_prem =
    -0.04 * (me.prem_earned +
               max(0, 1.2 * (me.prem_earned - me.prem_earned_prev))
             )
  scr_op_tp = 0.0045 * min(0, me.tp)
  return  max(0.3 * bscr, min(scr_op_prem, scr_op_tp)) + 0.25 * me.cost_ul
end
