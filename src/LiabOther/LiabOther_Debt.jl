## Constructors ----------------------------------------------------------------

# function Debt(t_init::Int, t_final::Int, nominal::Float64, interest::Float64)
#   return Debt(t_init, t_final, nom_vec, interest)
# end

## Interface  ------------------------------------------------------------------



function pvboc(debt::Debt, t::Int, disc_1c::Vector{Float64})
  ## interest:     x             o             o             o             o
  ##                             t                                     t_final
  ## |-------------|-------------|-------------|-------------|-------------|
  ##    t_initial         t            t+1                        t_final
  ##                           pveoc
  ##                \-----------------------------------------------------/
  ##                                n_cycles = t_final - t + 1
  ##  disc_1c[1:n_cycles] relates to cycles [t:t_final]
  ##               <·············|<------------|<-------------|<-----------|
  ##                  disc_1c[1]    disc_1c[2]                disc_1c[n_cycles]
  n_cycles = debt.t_final - t + 1
  if  (debt.t_final < t) | ( t < debt.t_init)
    return 0.0
  else
    interest = debt.nominal * (exp(debt.coupon) - 1)
    pv_boc = debt.nominal
    for τ = (n_cycles - 1) : -1 : 0
      pv_boc = disc_1c[τ + 1] * (interest + pv_boc)
    end
    return pv_boc
  end
end

function pvboc(debts::Vector{Debt}, t::Int, disc_1c::Vector{Float64})
  pv_boc = 0.0
  for debt in debts
    pv_boc += pvboc(debt, t, disc_1c)
    ## index of discount reflects paymebt BOC rather than EOC.
    ## Example: t_init = t+1 => no discount
  end
  return pv_boc
end


function pveoc(debt::Debt, t::Int, disc_1c::Vector{Float64})
  ## interest:     x             x             o             o             o
  ##                             t                                     t_final
  ## |-------------|-------------|-------------|-------------|-------------|
  ##    t_initial         t            t+1                        t_final
  ##                           pveoc
  ##                \-----------------------------------------------------/
  ##                                n_cycles = t_final - t + 1
  ##  disc_1c[1:n_cycles] relates to cycles [t:t_final]
  ##               <·············|<------------|<-------------|<-----------|
  ##                  disc_1c[1]    disc_1c[2]                disc_1c[n_cycles]
  n_cycles = debt.t_final - t + 1
  if  (debt.t_final <= t) | ( t < debt.t_init)
    return 0.0
  else
    coupon = debt.nominal * debt.coupon
    pv_eoc = debt.nominal
    for τ = (n_cycles - 1) : -1 : 1
      pv_eoc = disc_1c[τ + 1] * (coupon + pv_eoc)
    end
    return pv_eoc
  end
end

function pveoc(debts::Vector{Debt}, t::Int, disc_1c::Vector{Float64})
  pv_eoc = 0.0
  for debt in debts
    pv_eoc += pveoc(debt, t, disc_1c)
  end
  return pv_eoc
end

function paycoupon(debt::Debt, t::Int)
  if debt.t_init <= t <= debt.t_final
    return  debt.coupon * debt.nominal
  else
    return 0.0
  end
end

function paydebt(debt::Debt, t::Int)
  if t == debt.t_final
    return debt.nominal
  else
    return 0
  end
end

function getdebt(debts::Vector{Debt}, t::Int)
  debt_nominal = 0.0
  for debt in debts
    if t == debt.t_init
      debt_nominal += debt.nominal
    end
  end
  return debt_nominal
end


## Private ---------------------------------------------------------------------

