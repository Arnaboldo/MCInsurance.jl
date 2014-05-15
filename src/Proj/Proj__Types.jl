## column names for CFlow.v.  QX, SX, PX, PREM, C_BOC, C_EOC: 1:6
export  DELTA_TP, BONUS, INVEST, DIVID, TP_EOC, ASSET_EOC, SURPLUS_EOC, CYCLE
export Fluct
export CFlow, df

const DELTA_TP, BONUS, INVEST, DIVID, TP_EOC,
      ASSET_EOC, SURPLUS_EOC, CYCLE = 7:14

const col_CFLOW = [:QX, :SX, :PX, :PREM, :C_BOC, :C_EOC, :DELTA_TP, :BONUS,
                   :INVEST, :DIVID, :TP_EOC, :ASSET_EOC, :SURPLUS_EOC, :CYCLE]

const col_FLUCT = [:QX, :SX, :C_BOC, :C_EOC]


type Fluct
    n::Int                        ## # of GeomBrownian 1d-processes
    kind::Symbol                  ## type of fluctuation factors
    fac::Array{Float64,3}         ## factors representing fluctuation
    d::Dict{Int,Int}              ## convenience to access factors
end

type CFlow
    n::Int64                      ## # output quantities
    n_mc::Int64                   ## # monte carlo scenarios
    tf::TimeFrame                 ## time frame (from buckets)
    v::Array{Float64,3}           ## values
end
