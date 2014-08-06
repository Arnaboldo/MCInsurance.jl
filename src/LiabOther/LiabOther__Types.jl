export LiabOther, pveoc, pvboc, paydebt, plandebt!, getdebt
export Debt, goingconcern!

type  Debt
  t_init::Int
  t_final::Int
  nominal::Float64
  interest::Float64
end

type LiabOther
  debt_subord::Vector{Debt}
#   debt_subord_plan::Vector{Debt}
  debt_regular::Vector{Debt}
#   debt_regular_plan::Vector{Debt}
end


