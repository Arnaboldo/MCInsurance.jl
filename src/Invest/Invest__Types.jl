export IGStocks, IGRiskfreeBonds, IGCash, Invest, InvestAlloc, project!
export InvestInfo
export meancumdiscountc, uncumul

## Investment Groups: IG #########################################
## Investment groups may differ from asset groups as one
## asset group may drive several investment groups. An
## example would be a ShortRate that drives both investments in
## bonds and in cash.

abstract IG 


type IGStocks <: IG
    ## constructor
    name::Symbol                      ## name of investment group
    proc::ProcessIndex                ## stochastic process
    port_start::DataFrame             ## initial portfolio
    labels::Vector{Symbol}            ## identifies assets
    n::Int                            ## # assets incl. durations
    ## interface
    mv_init::Vector{Float64}          ## market value beg. of pd.
    mv_total_init::Float64            ## total market value bop
    mv_eop::Array{Float64,3}          ## market value beg. of pd.
    mv_total_eop::Array{Float64,2}    ## total market value bop
    cash_eop::Array{Float64,2}        ## cash (dividends etc.)
    mv_alloc_bop::Vector{Float64}     ## market value beg. of pd.
    ## internal
    amount_bop::Array{Float64,1}      ## number of shares
end

type IGRiskfreeBonds <: IG
    ## constructor
    name::Symbol                      ## name of investment group
    proc::ProcessShortRate            ## stochastic process
    port_start::DataFrame             ## initial portfolio
    labels::Vector{Int}               ## identifies assets
    n::Int                            ## # assets incl. durations
    ## interface
    mv_init::Vector{Float64}          ## market value beg. of pd.
    mv_total_init::Float64            ## total market value bop
    mv_eop::Array{Float64,3}          ## market value beg. of pd.
    mv_total_eop::Array{Float64,2}    ## total market value bop
    cash_eop::Array{Float64,2}        ## cash (coupons, maturing)
    mv_alloc_bop::Vector{Float64}     ## market value beg. of pd.
    ## internal
    riskfree_bop::Vector{Float64}     ## riskfree int. curve
    amount_init::Vector{Float64}      ## initial nominal values
    amount_curr::Vector{Float64}      ## current nominal values
    coupon_init::Vector{Float64}      ## initial coupons
    coupon_curr::Vector{Float64}      ## curr. average coupons
    mv_normcf_init::Vector{Float64}   ## initial. norm. cf value
    mv_normcf_curr::Vector{Float64}   ## curr. norm. cf value
    mv_normbond_init::Vector{Float64} ## init. norm. market value
    mv_normbond_curr::Vector{Float64} ## curr. norm. market value
end

type IGCash <: IG
    ## constructor
    name::Symbol                      ## name investment group
    proc::ProcessShortRate            ## stochastic process
    port_start::DataFrame             ## initial portfolio
    labels::Vector{Symbol}            ## identifies assets
    n::Int                            ## # assets incl. durations
    ## interface
    mv_init::Vector{Float64}          ## market value beg. of pd.
    mv_total_init::Float64            ## total market value bop
    mv_eop::Array{Float64,3}          ## == 0
    mv_total_eop::Array{Float64,2}    ## total market value eop
    cash_eop::Array{Float64,2}        ## cash == mv_total_eop
    mv_alloc_bop::Vector{Float64}     ## market value bop
    ## internal
end


type InvestInfo
    ig_name::Symbol                   ## name of investment group
    ig_type::Symbol                   ## type of investment
    proc_name::Symbol                 ## name of associated stochastic process
    port_start::DataFrame             ## initial portfolio
    id_asset::Vector{Any}             ## identifies assets in asset_xxx below
    asset_target::Vector{Float64}     ## asset allocation within ig
    asset_mkt_benchmark::Vector{Float64} ## percentage of market benchmark
end

type InvestAlloc
    ig_target::Vector{Float64}        ## target allocation for IGs
    ig_target_std::Vector{Float64}    ## standard target allocation for IGs
    ig_int::Dict{Symbol, Int}         ## identifier for IG: ig.name  -> Int
    asset_target::Vector{Vector{Float64}}     ## target allocation within IG
    asset_target_std::Vector{Vector{Float64}} ## standard target alloc within IG
    asset_int:: Dict{Vector{Any}, Int} ## identifier for asset targets
end

type Invest
    name::Symbol                      ## name of investment scheme
    cap_mkt::CapMkt                   ## capital market
    n::Int                            ## # investment groups
    ig::Vector{IG}                    ## investment groups: IG
    ig_symb::Vector{Symbol}           ## identifier for IG: Int -> ig.name
    alloc::InvestAlloc                ## initial target asset allocation
    mv_total_init::Float64            ## initial market value
    mv_total_eop::Array{Float64,2}    ## market value at end of period
    yield_total::Array{Float64,2}     ## investment yield per period
    yield_cash_c::Array{Float64,2}    ## cash yield per cycle (not per period!)
    yield_market_c::Array{Float64,2}  ## benchmark y. per cycle (not per period!)
    yield_init_grid::Vector{Float64}
    mean_cum_discount_c::Array{Float64,2}
    hook::Any                         ## hook for attaching custom types 
end



