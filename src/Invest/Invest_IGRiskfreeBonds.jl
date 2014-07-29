## Constructors ----------------------------------------------------------------
## Minimal constructor
function IGRiskfreeBonds(name::Symbol,
                         tf::TimeFrame,
                         proc::ProcessShortRate,
                         inv_init::DataFrame,
                         n::Int,
                         cost_norm_rel::Vector{Float64},
                         cost_norm_abs::Vector{Float64},
                         cost_infl_rel::Vector{Float64},
                         cost_infl_abs::Vector{Float64},
                         n_c::Int = tf.n_c
                         )
  asset = [1:n]

  mv_init =          zeros(Float64, n )
  mv_total_init =    0
  mv_eop =           zeros(Float64, proc.n_mc, proc.n_p, n )
  mv_total_eop =     zeros(Float64, proc.n_mc, proc.n_p )
  cash_eop =         zeros(Float64, proc.n_mc, proc.n_p )
  mv_alloc_bop =     zeros(Float64, n )
  sii_risk =         fill!(Array(Symbol, n ), :na)
  riskfree_bop =     zeros(Float64, n )
  amount_init =      zeros(Float64, n )
  amount_curr =      zeros(Float64, n )
  coupon_init =      zeros(Float64, n )
  coupon_curr =      zeros(Float64, n )
  mv_normcf_init =   zeros(Float64, n )
  mv_normcf_curr =   zeros(Float64, n )
  mv_normbond_init = zeros(Float64, n )
  mv_normbond_curr = zeros(Float64, n )

  cost =
    InvestCost(tf, cost_norm_rel, cost_norm_abs,
               cost_infl_rel, cost_infl_abs, n_c)


  for j=1:n, k=1:nrow(inv_init)
    if inv_init[k, :asset_dur] == j  ## duration
      coupon_init[j] += inv_init[k, :asset_coupon] * inv_init[k, :mv_init]
      amount_init[j] += inv_init[k, :mv_init]
    end
  end
  coupon_init = coupon_init ./ max(eps(), amount_init)

  for j = 1:n
    sii_risk[j] =  inv_init[1, :sii_risk]  # same sii risk for all durations
    # t=1: same value for all mc, hence mc=1:
    riskfree_bop[j] = forwardbop(proc, 1, 1, j)
    mv_normcf_init[j] =
      sum(exp( -riskfree_bop[1:j] .* [1:j]))
    mv_normbond_init[j] =
      coupon_init[j] * mv_normcf_init[j] +
      exp( - riskfree_bop[j] * j )
  end
  mv_init = amount_init .* mv_normbond_init
  # At beginning of first period we have not yet generated cash:
  mv_total_init = sum( mv_init )

  counter_party = counterparty(inv_init)


  IGRiskfreeBonds(name, tf, proc, asset, n,
                  mv_init, mv_total_init, mv_eop, mv_total_eop,
                  cash_eop, mv_alloc_bop, counter_party, sii_risk, cost,
                  riskfree_bop,
                  amount_init, amount_curr,
                  coupon_init, coupon_curr,
                  mv_normcf_init, mv_normcf_curr,
                  mv_normbond_init, mv_normbond_curr
                  )
end

## Interface -------------------------------------------------------------------

## 0) retrieve --> mv_bop(t), amount_bop(t)
## 1) reallocate at the beginning of period t
## 2) project during period t
## 3) evaluate mv_eop(t)
function project!(me::IGRiskfreeBonds, mc::Int, t::Int)
  if t == 1 init!(me, mc) end
  reallocbop!(me, mc, t)
  valeop!(me, mc, t)
  me.mv_total_eop[mc,t] =
    sum( me.mv_eop[mc,t,:] ) + me.cash_eop[mc,t]
end

## Private ---------------------------------------------------------------------

## Initialize projection (must be done seperately for each mc
function init!(me::IGRiskfreeBonds, mc::Int)
  riskfreebop!(me, mc, 1 )
  me.amount_curr = deepcopy(me.amount_init)
  me.coupon_curr = deepcopy(me.coupon_init)
  me.mv_normcf_curr = deepcopy(me.mv_normcf_init)
  me.mv_normbond_curr = deepcopy(me.mv_normbond_init)
end

## Update riskfree rate relative to beginning of period
function riskfreebop!(me::IGRiskfreeBonds, mc::Int, t::Int )
  for j in 1:me.n
    me.riskfree_bop[j] = forwardbop(me.proc, mc, t, j)
  end
end

## Update mv of normalized cashflow relative to end of period
function mvnormcf!(me::IGRiskfreeBonds)
  for j = 1:me.n
    me.mv_normcf_curr[j] =  sum(exp( - [1:j] .* me.riskfree_bop[1:j]))
  end
end

## Update mv of normalized bond relative to end of period
function mvnormbond!(me::IGRiskfreeBonds)
  for j = 1:me.n
    me.mv_normbond_curr[j] =
      me.coupon_curr[j] * me.mv_normcf_curr[j] +
      exp( - j * me.riskfree_bop[j] )
  end
end


function reallocbop!(me::IGRiskfreeBonds, mc::Int, t::Int )
  ## curr: ^prealloc_bop(t) = eop(t-1) -------------------------
  ## nominal values of existing investments
  amount_old =
    min(me.amount_curr,me.mv_alloc_bop ./ me.mv_normbond_curr)
  ## nominal values of new investments: equal to market values
  amount_new =
    max(0,me.mv_alloc_bop - amount_old .* me.mv_normbond_curr)
  ## coupon for new investments
  coupon_mkt =
    (1 .- exp(-[1:me.n] .* me.riskfree_bop)) ./ me.mv_normcf_curr
  ## curr: _bop(t) ---------------------------------------------
  me.amount_curr = amount_old + amount_new
  me.coupon_curr =
    ( amount_old .* me.coupon_curr +
       amount_new .* coupon_mkt
     ) ./  max(eps(),me.amount_curr)
end

## evaluate the portfolio at the end of the period to obtain
## mv_eop
function valeop!(me::IGRiskfreeBonds,
                 mc::Int,
                 t::Int  )
  ## curr: ^prealloc_bop(t+1) = _eop(t) ------------------------
  riskfreebop!(me, mc, t+1) # risk free curve at eop of period t
  mvnormcf!(me)             # normed cf value at eop of period t
  ## end of period calculation
  me.cash_eop[mc,t] =
    me.amount_curr[1] + sum(me.amount_curr .* me.coupon_curr)
  me.amount_curr[1:(me.n-1)] = me.amount_curr[2:me.n]
  me.amount_curr[me.n] = 0
  # update coupon_curr for period t+1 before reallocation:
  me.coupon_curr[1:(me.n-1)] = me.coupon_curr[2:me.n]
  me.coupon_curr[me.n] =
    (1-exp(- me.riskfree_bop[me.n] * me.n) ) / me.mv_normcf_curr[me.n]
  mvnormbond!(me)
  me.mv_eop[mc,t,:] =  me.amount_curr .* me.mv_normbond_curr
end


