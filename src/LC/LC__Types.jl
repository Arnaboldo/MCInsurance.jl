export QX, SX, PX, PREM, C_INIT, C_ABS, C_IS, C_PREM, N_COND,
       C_INIT_ABS, C_INIT_IS, N_PROF,
       L_INIT_ABS, L_INIT_IS, L_ABS, L_IS, L_PREM, L_INFL       
export LC,  lc!, costloadings, profitloadings, sx, profile, condcf, price, tpeop
export Bucket, Buckets, getcat, getind, add!, listcontracts

## Indices: Conditional Cashflows cond  (QX, SX are also used for probabilities)
const QX, SX, PX, PREM, C_INIT, C_ABS, C_IS, C_PREM = 1:8
const N_COND = 8
## Indices: Profile (C_INIT_ABS replaces C_INIT in cond, C_INIT_IS additional)
const C_INIT_ABS, C_INIT_IS, N_PROF = 5, 9, 9 
## Indices: Loadings
const L_INIT_ABS, L_INIT_IS, L_ABS, L_IS, L_PREM, L_INFL = 1:6

type LC
    n::Int                      ## # contracts
    age_min::Int                ## minimum age in qx-table
    age_max::Int                ## maxumum age in qx-table
    all::DataFrame              ## individual contract data
end


type Bucket
    n::Int                      ## # contracts in bucket
    n_c::Int                    ## max projection cycles
    dur::Int                    ## max remaining duration
    cat::Vector{Any}            ## age, gender, qx_be_name, risk
    cond::Array{Float64,2}      ## conditional cash-flows
    prob_be::Array{Float64,2}   ## best estimate: QX, SX
    sx_weights::Vector{Float64} ## weights for est. average be SX
end

type Buckets
    n::Int                      ## number of buckets
    n_c::Int                    ## max projection cycles in  buckets
    all::Array{Bucket,1}        ## Vector of buckets
    tf::TimeFrame               ## Corresponding TimeFrame
end

