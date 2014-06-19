## Constructors ----------------------------------------------------------------
function Other()
  Other(Array(Debt, 0), Array(Debt, 0))
end

## Interface  ------------------------------------------------------------------

function pvboc(me::Other, t::Int, discount::Vector{Float64})
  value = 0.0
  value += pvboc(me.debt_subord, t, discount)
  value += pvboc(me.debt_regular, t, discount)
  return value
end

function pveoc(me::Other, t::Int, discount::Vector{Float64})
  value = 0.0
  value += pveoc(me.debt_subord, t, discount)
  value += pveoc(me.debt_regular, t, discount)
  return value
end

function paydebt(me::Other, t::Int)
  value = 0.0
  if length(me.debt_subord) > 0
    value += mapreduce(x -> paydebt(x,t), +, me.debt_subord)
  end
  if length(me.debt_regular) > 0
    value += mapreduce(x -> paydebt(x,t), +, me.debt_regular)
  end
  return value
end


## Private ---------------------------------------------------------------------
