## Constructors --------------------------------------------------
## Minimal constructor
function IGCash(name::Symbol,
                proc::ProcessShortRate,
                inv_init::DataFrame,
                n::Int
                )
    asset =         convert(Array{Symbol,1}, [inv_init[1,:cpnt]])
    mv_init =       zeros(Float64,  n )
    mv_eop =        zeros(Float64, proc.n_mc, proc.n_p, n ) # = 0
    mv_total_eop =  zeros(Float64, proc.n_mc, proc.n_p )
    cash_eop =      zeros(Float64, proc.n_mc, proc.n_p )
    mv_alloc_bop =  zeros(Float64, n )
    mv_total_init = 0

    mv_total_init = inv_init[1, :asset_amount]

    IGCash(name, proc, asset, n,
           mv_init, mv_total_init, mv_eop, mv_total_eop, cash_eop,
           mv_alloc_bop)
end


## Interface functions for IG types ------------------------------

function project!(me::IGCash, mc::Int, t::Int)
    # mv_eop = 0 to avoid double-counting with cash_eop
    # field mv_eop is present to avoid access errors in Invest
    me.cash_eop[mc,t] = me.mv_alloc_bop[1] *
                        exp(me.proc.dt * me.proc.yield[mc,t,1])         
    me.mv_total_eop[mc,t] =  me.cash_eop[mc,t]
end

