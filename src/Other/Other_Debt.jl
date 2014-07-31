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
  pv_boc = 0.0
  for debt in me
    pv_boc += pvboc(debt, t, discount)
    ## index of discount reflects paymebt BOC rather than EOC.
    ## Example: t_init = t+1 => no discount
    if debt.t_init == t
      pv_boc -= debt.nominal
    elseif debt.t_init > t
      pv_boc -= discount[debt.t_init - t] * debt.nominal
    end
  end
  return pv_boc
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
  pv_eoc = 0.0
  for debt in me
    pv_eoc += pveoc(debt, t, discount)
    ## index of discount reflects paymebt BOC rather than EOC.
    ## Example: t_init = t+1 => no discount
    if debt.t_init > t
      pv_eoc -= discount[debt.t_init - t] * debt.nominal / discount[1]
    end
  end
  return pv_eoc
end

function paydebt(me::Debt, t::Int)
  payment = 0.0
  if me.t_init <= t <= me.t_final
    payment += me.nominal * me.interest
  end
  if t == me.t_final
    payment += me.nominal
  end
  return payment
end

function getdebt(me::Vector{Debt}, t::Int)
  debt_nominal = 0.0
  for debt in me
    if t == debt.t_init
      debt_nominal += debt.nominal
    end
  end
  return debt_nominal
end


## Private ---------------------------------------------------------------------

