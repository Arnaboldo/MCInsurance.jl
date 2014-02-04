## column names for CFlow.v.  QX, SX, PX, PREM: 1:4 
export C_ALL, ASSET_EOP, TP_EOP, DIV_EOP, SURPLUS_EOP, CYCLE
export Fluct
export CFlow, df

const C_ALL, ASSET_EOP, TP_EOP, DIV_EOP, SURPLUS_EOP, CYCLE = 5:10


type Fluct
    n::Int                        ## # of GeomBrownian 1d-processes
    kind::String                  ## type of fluctuation factors
    labels::Vector{ASCIIString}   ## labels for GeomBrownian
    fac::Array{Float64,3}         ## factors representing fluctuation
    d::Dict{Int,Int}              ## convenience to access factors
end

type CFlow
    n::Int64                      ## # output quantities
    n_mc::Int64                   ## # monte carlo scenarios
    tf::TimeFrame                 ## time frame (from buckets)
    v::Array{Float64,3}           ## values
    labels::Vector{ASCIIString}   ## labels of output quantities
end
