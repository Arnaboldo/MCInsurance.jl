## Constructors ----------------------------------------------------------------

function Dynamic()
  bonus_factor = 0.0
  capital_dividend = 0.0
  hook = false
  Dynamic(defaultprobsx, defaultalloc!, defaultbonusrate, defaultdividend,
          defaultexpense, defaultupdate!, bonus_factor, capital_dividend, hook)
end

function Dynamic(df_general::DataFrame)
  me = Dynamic()
  me.bonus_factor = df_general[1, :bonus_factor]
  me.capital_dividend = df_general[1, :capital_dividend]
  return me
end

## Interface functions ---------------------------------------------------------
defaultprobsx(mc::Int, t::Int, bkt::Bucket, invest::Invest, fluct::Fluct,
              dyn::Dynamic) =  bkt.prob_be[t:bkt.n_c, SX]

defaultalloc!(invest::Invest, mc::Int, t::Int, dyn::Dynamic) = nothing

defaultbonusrate(mc::Int, t::Int, bkt::Bucket, invest::Invest, dyn::Dynamic) = 0

defaultdividend(mc::Int, t::Int, invest::Invest, cf::CFlow, dyn::Dynamic) = 0

defaultexpense(mc::Int, t::Int, invest::Invest, cf::CFlow, dyn::Dynamic) = 0

function getprob(dyn::Dynamic, bkt::Bucket, mc::Int, t::Int,
                 invest::Invest, fluct::Fluct)
  prob  = Array(Float64, bkt.n_c, 3)
  prob[t:bkt.n_c, QX] = fluct.fac[mc, t, QX] * bkt.prob_be[t:bkt.n_c, QX]
  prob[t:bkt.n_c, SX] = dyn.probsx(mc, t, bkt, invest, fluct, dyn)
  prob[:,PX] = 1 .- prob[:,QX] - prob[:,SX]
  return prob
end

defaultupdate!(me::Dynamic, t::Int, cf::Array{Float64,3}, v::Array{Float64,3}) =
  nothing
