## Constructors ----------------------------------------------------------------
function Other()
  finance_subord = emptyfinance()
  finance_regular = emptyfinance()
  Other(Array(Debt, 0), Array(Debt, 0), finance_subord, finance_regular)
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

function getdebt!(me::Other, t::Int)
  v = 0.0
  v += getdebt!(me.debt_subord, t, me.finance_subord)
  v += getdebt!(me.debt_regular, t, me.finance_regular)
  return v
end

## Private ---------------------------------------------------------------------

function goingconcern!!(debt_vec::Vector{Debt},   ## changed
                        finance::DataFrame,      ## changed
                        gc_c::Vector{Float64})
  gc = Array(Debt, 0)
  for debt in debt_vec
    push!(gc,
          Debt(debt.t_init, max(1, debt.t_init), debt.nominal, debt.interest))

    if debt.t_final > 1
      for t = max(2,debt.t_init):debt.t_final
        plandebt!(finance,
                  t,
                  t,
                  gc_c[t] * debt.nominal,
                  debt.interest)
      end
    end
  end
  debt_vec = deepcopy(gc)
end

function goingconcern!(me::Other, gc_c::Vector{Float64})
  goingconcern!!(me.debt_subord, me.finance_subord, gc_c)
  goingconcern!!(me.debt_regular, me.finance_regular, gc_c)
end

function emptyfinance()
  return DataFrame([Int, Int, Float64, Float64],
                             [:t_init, :t_final, :nominal, :interest], 0)
end
