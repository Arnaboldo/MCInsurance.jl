export N_COND, QX, SX, PX, PREM, C_BOC, C_EOC,
       N_PROF, C_INIT_ABS, C_INIT_IS, C_ABS, C_IS, C_PREM, 
       N_CAT, CAT_AGE, CAT_GENDER, CAT_QXBE, CAT_INTEREST, CAT_INFL, CAT_RISK,
       L_INIT_ABS, L_INIT_IS, L_ABS, L_IS, L_PREM, L_INFL
        
export LC,  lc!, loadings, getprobsx, getprob,
       profile, condcf, price, tpeoc, tpveceoc, tpprev
export Bucket, Buckets, getcat, getind, add!, listcontracts

## Indices ---------------------------------------------------------------------
## Probabilities prob: QX, SX, PX
## Conditional Cashflows cond:
const N_COND = 6
const QX, SX, PX, PREM, C_BOC, C_EOC = 1:N_COND
## Profile prof
## (similar to cond but C_Init -> C_INIT_ABS, (nothing) ->  C_INIT_IS)
## QX, SX, PX, PREM, C_INIT_ABS, C_ABS, C_IS, C_PREM, C_INIT_IS
const N_PROF = 9
const C_INIT_ABS, C_INIT_IS, C_ABS, C_IS, C_PREM = 5:N_PROF
## Loadings
const L_INIT_ABS, L_INIT_IS, L_ABS, L_IS, L_PREM, L_INFL = 1:6
## categories for grouping buckets: cat
const N_CAT = 6
const CAT_AGE, CAT_GENDER, CAT_QXBE, CAT_INTEREST, CAT_INFL, CAT_RISK = 1:N_CAT

## Types -----------------------------------------------------------------------

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
    tp_stat::Vector{Float64}    ## statutory technical provisions
    tp_stat_init::Float64       ## initial statutory technical provisions
    tp_be_init::Float64         ## initial best estimate technical provisions
    prob_be::Array{Float64,2}   ## best estimate: QX, SX
    sx_weights::Vector{Float64} ## weights for est. average be SX
    lx_boc::Float64             ## current fraction of policy holders in-force
    bonus_rate::Float64         ## current bonus rate
    hook::Any                   ## hook for attaching custom types 
end

type Buckets
    n::Int                      ## number of buckets
    n_c::Int                    ## max projection cycles in  buckets
    all::Array{Bucket,1}        ## Vector of buckets
    tf::TimeFrame               ## Corresponding TimeFrame
end

