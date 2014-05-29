## column names for CFlow.v.  QX, SX, PX, PREM, C_BOC, C_EOC: 1:6
export  DELTA_TP, BONUS, INVEST, OTHER, DIVID
export TP_EOC, OTHER_EOC, ASSET_EOC, SURPLUS_EOC, CYCLE
export Fluct
export CFlow, dfcf, dfv0, dfv, disccf, pvdfcf, vinit!
export Dynamic, getprob

const DELTA_TP, BONUS, INVEST, OTHER, DIVID = 7:11

const TP_EOC, OTHER_EOC, ASSET_EOC, SURPLUS_EOC, CYCLE = 1:5

const col_CF = [:QX, :SX, :PX, :PREM, :C_BOC, :C_EOC,
                   :DELTA_TP, :BONUS, :INVEST, :OTHER, :DIVID]

const col_V = [:TP_EOC, :OTHER_EOC, :ASSET_EOC, :SURPLUS_EOC, :CYCLE]

 
const col_FLUCT = [:QX, :SX, :C_BOC, :C_EOC]


type Fluct
    n::Int                        ## # of GeomBrownian 1d-processes
    kind::Symbol                  ## type of fluctuation factors
    fac::Array{Float64,3}         ## factors representing fluctuation
    d::Dict{Int,Int}              ## convenience to access factors
end

type CFlow
    n_mc::Int64                     ## # monte carlo scenarios
    n_cf::Int64                     ## # output quantities cash-flows 
    n_v::Int64                      ## # output quantities valuation
    tf::TimeFrame                  ## time frame (from buckets)
    cf::Array{Float64,3}           ## cash-flow values
    v_0::Array{Float64,3}           ## initial cash flow and valuation values
    v::Array{Float64,3}            ## valuation values
end

type Dynamic
    probsx::Function # bkt::Bucket, mc::Int, t::Int, invest::Invest
    alloc!::Function #invest::Invest, mc::Int, t::Int
    bonusrate::Function
    dividend::Function
    expense::Function
    # often used constants
    bonus_factor::Float64
    capital_dividend::Float64
    # hook for customization
    hook::Any
end 
