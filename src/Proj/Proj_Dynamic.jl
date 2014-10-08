## Constructors ----------------------------------------------------------------

function Dynamic()
  bonus_factor = 0.0
  capital_dividend = 0.0
  hook = false
  Dynamic(defaultprobsx, defaultalloc!, defaultbonusrate, defaultdividend,
          defaultexpense, defaulttaxprofit, defaultupdate!,
          bonus_factor, capital_dividend, hook)
end

function Dynamic(df_general::DataFrame)
  me = Dynamic()
  me.bonus_factor = df_general[1, :bonus_factor]
  me.capital_dividend = df_general[1, :capital_dividend]
  return me
end

## Interface functions ---------------------------------------------------------
defaultprobsx(mc::Int, t::Int, dyn::Dynamic, invest::Invest,
              bkt::Bucket, fluct::Fluct) =  bkt.prob_ie[t:bkt.n_c, SX]

defaultalloc!(invest::Invest, mc::Int, t::Int, dyn::Dynamic) = nothing

defaultbonusrate(mc::Int, t::Int, bkt::Bucket, invest::Invest, dyn::Dynamic) = 0

defaultdividend(mc::Int, t::Int, invest::Invest, cf::CFlow, dyn::Dynamic) = 0

defaultexpense(mc::Int, t::Int, invest::Invest, cf::CFlow, dyn::Dynamic) = 0

defaulttaxprofit(mc::Int, t::Int, cf::CFlow, dyn::Dynamic) = 0

function getprob(mc::Int, t::Int, dyn::Dynamic, invest::Invest,
                 bkt::Bucket, fluct::Fluct, len::Int)
  prob  = Array(Float64, len, 3)
  prob[t:len, QX] = fluct.fac[mc, t, QX] * bkt.prob_ie[t:len, QX]
  prob[t:len, SX] = dyn.probsx(mc, t, dyn, invest, bkt, fluct, len)
  prob[:,PX] = 1 .- prob[:,QX] - prob[:,SX]
  return prob
end

defaultupdate!(me::Int, t::Int, cflow::CFlow, dyn::Dynamic) =
  nothing
