module MCInsurance

using Distributions
using DataFrames, DataArrays

import Base.show, Base.isequal
import Base.merge!

include("Time/Time__Types.jl")
include("Time/Time_TimeFrame.jl")

include("StochProcess/StochProcess__Types.jl")
include("StochProcess/StochProcess_StochProcessInfo.jl")
include("StochProcess/StochProcess_Brownian.jl")
include("StochProcess/StochProcess_GeomBrownian.jl")
include("StochProcess/StochProcess_ManualShortRate.jl")
include("StochProcess/StochProcess_Vasicek.jl")
include("StochProcess/StochProcess_CIR.jl")

include("CapMkt/CapMkt__Types.jl")
include("CapMkt/CapMkt_CapMkt.jl")

include("Invest/Invest__Types.jl")
include("Invest/Invest_IGCash.jl")
include("Invest/Invest_IGRiskfreeBonds.jl")
include("Invest/Invest_IGStocks.jl")
include("Invest/Invest_IG.jl")
include("Invest/Invest_Invest.jl")

include("LC/LC__Types.jl")
include("LC/LC_LC.jl")
include("LC/LC_Bucket.jl")

include("Proj/Proj__Types.jl")
include("Proj/Proj_Fluct.jl")
include("Proj/Proj_Cflow.jl")

end # module
