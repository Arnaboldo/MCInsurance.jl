function Dynamic()
    probsx(mc::Int, t::Int, bkt::Bucket, invest::Invest, fluct::Fluct,
           dyn::Dynamic) =  bkt.prob_be[t:bucket.n_c, SX]
    alloc!(invest::Invest, mc::Int, t::Int, dyn::Dynamic) = false ## nothing done
    bonusrate(mc::Int, t::Int, bkt::Bucket, invest::Invest, dyn::Dynamic) = 0
    dividend(mc::Int, t::Int, invest::Invest, cf::CFlow, dyn::Dynamic) = 0
    expense(mc::Int, t::Int, invest::Invest, cf::CFlow, dyn::Dynamic) = 0
    bonus_factor = 0.0
    capital_dividend = 0.0
    hook = false
    Dynamic(probsx, alloc!, bonusrate, dividend, expense,
            bonus_factor, capital_dividend, hook)
end

function Dynamic(df_general::DataFrame)
  me = Dynamic()
  me.bonus_factor = df_general[1, :bonus_factor]
  me.capital_dividend = df_general[1, :capital_dividend]
  return me  
end
