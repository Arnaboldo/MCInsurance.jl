## Constructors --------------------------------------------------

## Minimal constructor
function IGStocks( name::Symbol,
                  proc::ProcessIndex,
                  inv_init::DataFrame,
                  n::Int
                  )
    asset = proc.cpnt
    mv_init =       zeros(Float64, n )
    mv_eop =        zeros(Float64, proc.n_mc, proc.n_p, n )
    mv_total_eop =  zeros(Float64, proc.n_mc, proc.n_p )
    cash_eop =      zeros(Float64, proc.n_mc, proc.n_p )
    mv_alloc_bop =  zeros(Float64, n )
    amount_bop =    zeros(Float64, n )

    amount_init = zeros(Float64, n)
    for j=1:n, k=1:nrow(inv_init)
        if inv_init[k, :proc_labels] == string(proc.cpnt[j])
            amount_init[j] += inv_init[k, :asset_amount]
        end
    end
    mv_init = amount_init .*  proc.v_init
    mv_total_init = sum( mv_init )    

    IGStocks(name, proc, inv_init, asset, n,
             mv_init, mv_total_init, mv_eop, mv_total_eop,
             cash_eop, 
             mv_alloc_bop,
             amount_bop )
end

## Interface functions for IG types ------------------------------

function project!(me::IGStocks, mc::Int, t::Int)
    me.amount_bop =
        me.mv_alloc_bop ./ reshape(me.proc.v_bop[mc,t,:], me.n)
    me.mv_eop[mc,t,:] =
        reshape(me.amount_bop,1,1,me.n) .* me.proc.v_bop[mc,t+1,:]
    me.mv_total_eop[mc,t] =
        sum( me.mv_eop[mc,t,:] ) + me.cash_eop[mc,t]
end

## Internal functions --------------------------------------------

