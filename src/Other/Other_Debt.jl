## Constructors ----------------------------------------------------------------

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
    cf_fut= ones(Float64, n_cycles) * me.nominal * (exp(me.interest) - 1)
    cf_fut[n_cycles] += me.nominal
    return dot(discount[1:n_cycles], cf_fut)
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
    cf_fut= ones(Float64, n_cycles-1) * me.nominal * (exp(me.interest) - 1)
    cf_fut[n_cycles-1] += me.nominal
    return dot(discount[2:n_cycles], cf_fut) / discount[1]
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

## Private ---------------------------------------------------------------------

