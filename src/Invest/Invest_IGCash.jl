## Constructors ----------------------------------------------------------------
## Minimal constructor
function IGCash(name::Symbol,
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
  asset =         convert(Array{Symbol,1}, [inv_init[1,:cpnt]])
  mv_init =       zeros(Float64,  n )
  mv_eop =        zeros(Float64, proc.n_mc, proc.n_p, n ) # = 0
  mv_total_eop =  zeros(Float64, proc.n_mc, proc.n_p )
  cash_eop =      zeros(Float64, proc.n_mc, proc.n_p )
  mv_alloc_bop =  zeros(Float64, n )
  rating =        fill!(Array(Symbol, n ), :na)
  sii_risk =      fill!(Array(Symbol, n ), :na)

  cost =  InvestCost(tf, cost_norm_rel, cost_norm_abs,
                     cost_infl_rel, cost_infl_abs, n_c)

  mv_total_init = 0
  for k = 1:nrow(inv_init)
    mv_total_init += inv_init[k, :mv_init]
  end
  counter_party = counterparty(inv_init)

  sii_risk[1] =  inv_init[1, :sii_risk]

  IGCash(name, tf, proc, asset, n,
         mv_init, mv_total_init, mv_eop, mv_total_eop, cash_eop,
         mv_alloc_bop, counter_party, sii_risk, cost)
end


## Interface -------------------------------------------------------------------

function project!(me::IGCash, mc::Int, t::Int)
  # mv_eop = 0 to avoid double-counting with cash_eop
  # field mv_eop is present to avoid access errors in Invest
  me.cash_eop[mc,t] = me.mv_alloc_bop[1] * exp(me.proc.yield[mc,t,1])
  me.mv_total_eop[mc,t] =  me.cash_eop[mc,t]
end

