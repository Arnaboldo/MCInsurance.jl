## Constructors ----------------------------------------------------------------

# function Debt(t_init::Int, t_final::Int, nominal::Float64, interest::Float64)
#   return Debt(t_init, t_final, nom_vec, interest)
# end

## Interface  ------------------------------------------------------------------



function pvboc(me::Debt, t::Int, discount::Vector{Float64})
  ##                             t                                     t_final
  ## |-------------|-------------|-------------|-------------|-------------|
  ##    t_initial         t                                       t_final
  ##             pvboc
  ##                \-----------------------------------------------------/
  ##                                n_cycles = t_final - t + 1
  ##  discount[1:dur] = discount_be[t:t_final]:
  ##               <-------------|<------------|<-------------|<-----------|
  ##                 discount[1]   discount[2]              discount[n_cycles]
  ##                  cf_fut[1]     cf_fut[2]                cf_fut[n_cycles]
  n_cycles = me.t_final - t + 1
  if  n_cycles <= 0
    return 0.0
  else
    cf_fut = me.nominal * ones(Float64, n_cycles) * (exp(me.interest) - 1)
    cf_fut[n_cycles] += me.nominal
    return discount[1:n_cycles] ⋅ cf_fut
  end
end

function pvboc(me::Vector{Debt}, t::Int, discount::Vector{Float64})
  if length(me) > 0
    return mapreduce(x -> pvboc(x, t, discount), +, me)
  else
    return 0.0
  end
end

function pveoc(me::Debt, t::Int, discount::Vector{Float64})
  ##                             t                                     t_final
  ## |-------------|-------------|-------------|-------------|-------------|
  ##    t_initial         t                                       t_final
  ##                           pveoc
  ##                \-----------------------------------------------------/
  ##                                n_cycles = t_final - t + 1
  ##  discount[1:n_cycles] = discount_be[t:t_final]:
  ##               <·············|<------------|<-------------|<-----------|
  ##                 discount[1]   discount[2]              discount[n_cycles]
  ##                                cf_fut[1]               cf_fut[n_cycles-1]
  n_cycles = me.t_final - t + 1
  if  n_cycles <= 1
    return 0.0
  else
    cf_fut = me.nominal * ones(Float64, n_cycles - 1) * (exp(me.interest) - 1)
    cf_fut[n_cycles-1] += me.nominal
    return (discount[2:n_cycles] ⋅ cf_fut) / discount[1]
  end
end

function pveoc(me::Vector{Debt}, t::Int, discount::Vector{Float64})
  if length(me) > 0
    return mapreduce(x -> pveoc(x, t, discount), +, me)
  else
    return 0.0
  end
end

function paydebt(me::Debt, t::Int)
  payment = 0.0
  if t <= me.t_final && t >= me.t_init
    payment += me.nominal * me.interest
  end
  if t == me.t_final
    payment += me.nominal
  end
  return payment
end

function getdebt!(me::Vector{Debt}, t::Int, finance::DataFrame)
  new_finance = finance[finance[:t_init] .== t, :]
  new_debt_nominal = 0.0
  for i = 1:nrow(new_finance)
    new_debt =  Debt(t,
                     new_finance[i, :t_final],
                     new_finance[i, :nominal],
                     new_finance[i, :interest])
    push!(me, new_debt)
    new_debt_nominal += new_finance[i, :nominal]
  end
  return new_debt_nominal
end

function plandebt!(me::DataFrame,
                   t_init::Int,
                   t_final::Int,
                   nominal::Float64,
                   interest::Float64)
  append!(me, DataFrame(t_init = t_init,
                       t_final = t_final,
                       nominal = nominal,
                       interest = interest))
end

## Private ---------------------------------------------------------------------

