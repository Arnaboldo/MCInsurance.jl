export Other, pveoc, pvboc, paydebt, plandebt!, getdebt!
export Debt, goingconcern!

type  Debt
  t_init::Int
  t_final::Int
  nominal::Float64
  interest::Float64
end

type Other
  debt_subord::Vector{Debt}
  debt_regular::Vector{Debt}
  finance_subord::DataFrame
  finance_regular::DataFrame
end


