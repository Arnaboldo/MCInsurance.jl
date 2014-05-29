export Other, cfl, pveoc, pvboc, paydebt
export SubordDebt

abstract Debt

type SubordDebt <: Debt
    t_init::Int
    t_final::Int
    nominal::Float64
    interest::Float64
end

type Other
 subord_debt::Vector{SubordDebt}
end

function Other()
    Other(Array(SubordDebt, 0))
end

function cfl(me::Other, t::Int)
  cf = 0.0
  if length(me.subord_debt) > 0
      for debt in me.subord_debt
          cf += paydebt(debt, t)
      end
  end
  return cf
end

function pveoc(me::Other, t::Int, discount::Vector{Float64})
    value = 0.0
    if length(me.subord_debt) > 0
        for debt in me.subord_debt
            value += pveoc(debt, t, discount)
        end
    end
    return value
end

function pvboc(me::Other, t::Int, discount::Vector{Float64})
    value = 0.0
    if length(me.subord_debt) > 0
        for debt in me.subord_debt
            value += pvboc(debt, t, discount)
        end
    end
    return value
end

function paydebt(me::Other, t::Int)
    value = 0.0
    if length(me.subord_debt) > 0
        for debt in me.subord_debt
            value += paydebt(debt, t)
        end
    end
    return value
end

