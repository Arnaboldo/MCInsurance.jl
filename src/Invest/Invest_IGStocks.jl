## Constructors --------------------------------------------------

## Minimal constructor
function IGStocks(name::Symbol,
                  tf::TimeFrame,
                  proc::ProcessIndex,
                  inv_init::DataFrame,
                  n::Int,
                  cost_norm_rel::Vector{Float64},
                  cost_norm_abs::Vector{Float64},
                  cost_infl_rel::Vector{Float64},
                  cost_infl_abs::Vector{Float64},
                  n_c::Int = tf.n_c
                  )
  asset = proc.cpnt
  mv_init =       zeros(Float64, n )
  mv_eop =        zeros(Float64, proc.n_mc, proc.n_p, n )
  mv_total_eop =  zeros(Float64, proc.n_mc, proc.n_p )
  cash_eop =      zeros(Float64, proc.n_mc, proc.n_p )
  mv_alloc_bop =  zeros(Float64, n )
  sii_risk =      array(inv_init[:, :sii_risk])
  amount_bop =    zeros(Float64, n )

  cost =
    InvestCost(tf, cost_norm_rel, cost_norm_abs,
               cost_infl_rel, cost_infl_abs, n_c)

  amount_init = zeros(Float64, n)
  for j=1:n, k=1:nrow(inv_init)
    if inv_init[k, :cpnt] == string(proc.cpnt[j])
      amount_init[j] += inv_init[k, :mv_init]
    end
  end
  mv_init = amount_init .*  proc.init
  mv_total_init = sum( mv_init )

  counter_party = counterparty(inv_init)


  IGStocks(name, tf, proc, asset, n,
           mv_init, mv_total_init, mv_eop, mv_total_eop,
           cash_eop, mv_alloc_bop, counter_party, sii_risk, cost, amount_bop )
end

## Interface -------------------------------------------------------------------

function project!(me::IGStocks, mc::Int, t::Int)
  me.amount_bop =
    me.mv_alloc_bop ./ reshape(me.proc.v_bop[mc,t,:], me.n)
  me.mv_eop[mc,t,:] =
    reshape(me.amount_bop,1,1,me.n) .* me.proc.v_bop[mc,t+1,:]
  me.mv_total_eop[mc,t] =
    sum( me.mv_eop[mc,t,:] ) + me.cash_eop[mc,t]
end

# Private ---------------------------------------------------------------------

