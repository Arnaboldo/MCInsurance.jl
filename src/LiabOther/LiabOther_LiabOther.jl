## Constructors ----------------------------------------------------------------
function LiabOther()
  LiabOther(Array(Debt, 0), Array(Debt, 0))
end

## Interface  ------------------------------------------------------------------

function pvboc(me::LiabOther, t::Int, discount::Vector{Float64})
  value = 0.0
  value += pvboc(me.debt_subord, t, discount)
  value += pvboc(me.debt_regular, t, discount)
  return value
end

function pveoc(me::LiabOther, t::Int, discount::Vector{Float64})
  value = 0.0
  value += pveoc(me.debt_subord, t, discount)
  value += pveoc(me.debt_regular, t, discount)
  return value
end

function paydebt(me::LiabOther, t::Int)
  value = 0.0
  if length(me.debt_subord) > 0
    value += mapreduce(x -> paydebt(x,t), +, me.debt_subord)
  end
  if length(me.debt_regular) > 0
    value += mapreduce(x -> paydebt(x,t), +, me.debt_regular)
  end
  return value
end

function getdebt(me::LiabOther, t::Int)
  v = 0.0
  v += getdebt(me.debt_subord, t)
  v += getdebt(me.debt_regular, t)
  return v
end

## Private ---------------------------------------------------------------------

function goingconcern(me::Vector{Debt}, gc_c::Vector{Float64})
  new_debt_vec = Array(Debt, 0)
  for debt in me
    t0 = max(1, debt.t_init)
    diff_nom =
      vcat(-diff(gc_c[t0:debt.t_final]), gc_c[debt.t_final]) * debt.nominal
    for t = max(1, debt.t_init):debt.t_final
      push!(new_debt_vec, Debt(debt.t_init,
                               t,
                               diff_nom[t],
                               debt.interest))
    end
  end
  return(new_debt_vec)
end

function goingconcern!(me::LiabOther, gc_c::Vector{Float64})
  me.debt_subord = goingconcern(me.debt_subord, gc_c)
  me.debt_regular = goingconcern(me.debt_regular, gc_c)
end

