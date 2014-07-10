module MCInsurance

using Distributions
using DataFrames, DataArrays
#using Iterators

import Base.show, Base.isequal
import Base.merge!

include("Time/Time__Types.jl")
include("Time/Time_TimeFrame.jl")

include("StochProcess/StochProcess__Types.jl")
include("StochProcess/StochProcess_StochProcessInfo.jl")
include("StochProcess/StochProcess_Brownian.jl")
include("StochProcess/StochProcess_GeomBrownian.jl")
include("StochProcess/StochProcess_ProcessShortRate.jl")
include("StochProcess/StochProcess_DetermShortRate.jl")
include("StochProcess/StochProcess_ManualShortRate.jl")
include("StochProcess/StochProcess_Vasicek.jl")
include("StochProcess/StochProcess_CIR.jl")

include("CapMkt/CapMkt__Types.jl")
include("CapMkt/CapMkt_CapMkt.jl")

include("Invest/Invest__Types.jl")
include("Invest/Invest_InvestInfo.jl")
include("Invest/Invest_IGCash.jl")
include("Invest/Invest_IGRiskfreeBonds.jl")
include("Invest/Invest_IGStocks.jl")
include("Invest/Invest_IG.jl")
include("Invest/Invest_Invest.jl")
include("Invest/Invest_MktC.jl")

include("LC/LC__Types.jl")
include("LC/LC_LC.jl")
include("LC/LC_Bucket.jl")

include("Other/Other__Types.jl")
include("Other/Other_Debt.jl")
include("Other/Other_Other.jl")

include("Proj/Proj__Types.jl")
include("Proj/Proj_Fluct.jl")
include("Proj/Proj_CFlow.jl")
include("Proj/Proj_Dynamic.jl")

include("SII/SII__Types.jl")
include("SII/SII_SII.jl")
include("SII/SII_SIIModule.jl")
include("SII/SII_SIIMkt.jl")
include("SII/SII_SIIMktInt.jl")
include("SII/SII_SIIMktEq.jl")
include("SII/SII_SIIMktSpread.jl")
include("SII/SII_SIIMktConc.jl")
include("SII/SII_SIIDef.jl")
include("SII/SII_SIIDefType1.jl")
include("SII/SII_SIIDefType2.jl")
include("SII/SII_SIILife.jl")
include("SII/SII_SIILifeQX.jl")
include("SII/SII_SIILifeSX.jl")
include("SII/SII_SIILifePX.jl")
include("SII/SII_SIILifeCost.jl")
include("SII/SII_SIILifeCat.jl")
include("SII/SII_SIIOp.jl")

end # module
