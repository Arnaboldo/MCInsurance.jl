export SII, scr, bscr, adjtp, adjdt

SII_DIGITS = 3
abstract SIIModule


## SII market risk -------------------------------------------------------------
type SIIMktInt <: SIIModule
  tf::TimeFrame                   ## shared time frame
  shock_type::Symbol              ## indicates object type to be shocked
  sub_modules::Vector{Symbol}     ## all potential sub-modules
  balance::DataFrame              ## balance sheet for various shocks
  spot_down::Array{Float64,3}
  spot_up::Array{Float64,3}
  spot_down_abs_max::Float64
  spot_up_abs_min::Float64
end

type SIIMktEq <: SIIModule
  tf::TimeFrame                   ## shared time frame
  shock_type::Symbol              ## indicates object type to be shocked
  sub_modules::Vector{Symbol}     ## all potential sub-modules
  balance::DataFrame              ## balance sheet for various shocks
  corr::Matrix{Float64}
  shocks::Dict{Symbol,Any}        ## shocks[i] is always Float64,
end

type SIIMktSpread <: SIIModule
  tf::TimeFrame                   ## shared time frame
  shock_type::Symbol              ## indicates object type to be shocked
  sub_modules::Vector{Symbol}     ## all potential sub-modules
  balance::DataFrame              ## balance sheet for various shocks
  shocks::Dict{Symbol,Any}        ## shocks[i] is always Float64,
end

type SIIMktConc <: SIIModule
  tf::TimeFrame                   ## shared time frame
  shock_type::Symbol              ## indicates object type to be shocked
  sub_modules::Vector{Symbol}     ## all potential sub-modules
  balance::DataFrame              ## balance sheet for various shocks
  shocks::Dict{Symbol,Any}        ## shocks[i] is always Float64,
end

type SIIMkt <: SIIModule
  tf::TimeFrame                   ## shared time frame
  dim::Vector{Symbol}
  corr_up::Matrix{Float64}
  corr_down::Matrix{Float64}
  int::SIIMktInt
  eq::SIIMktEq
  spread::SIIMktSpread
  conc::SIIMktConc
end

## SII default risk ------------------------------------------------------------
type SIIDefType1 <: SIIModule
  tf::TimeFrame                   ## shared time frame
  tlgd::Vector{Float64}
  slgd::Vector{Float64}
  u::Matrix{Float64}
  v::Vector{Float64}
end

type SIIDefType2 <: SIIModule
  tf::TimeFrame                   ## shared time frame
  shock_type::Symbol              ## indicates object type to be shocked
  sub_modules::Vector{Symbol}     ## all potential sub-modules
  balance::DataFrame              ## balance sheet for various shocks
  shocks::Dict{Symbol,Any}        ## shocks[i] is always Float64,
end

type SIIDef <: SIIModule
  tf::TimeFrame                   ## shared time frame
  dim::Vector{Symbol}             ## submodules
  corr::Matrix{Float64}           ## correlation matrix for default risk
  type1::SIIDefType1              ## type 1: rated, factor based
  type2::SIIDefType2              ## type 2: unrated, scenario based
end

## SII life risk ---------------------------------------------------------------
type SIILifeQX <: SIIModule
  tf::TimeFrame                   ## shared time frame
  shock_type::Symbol              ## indicates object type to be shocked
  balance::DataFrame              ## balance sheet for various shocks
  shock::Float64
  bkt_select::Vector{Bool}         ## buckets selected for shocks
end

type SIILifeSX <: SIIModule
  tf::TimeFrame                   ## shared time frame
  shock_type::Symbol              ## indicates object type to be shocked
  sub_modules::Vector{Symbol}     ## all potential sub-modules
  balance::DataFrame              ## balance sheet for various shocks
  shock_down::Float64
  shock_down_abs::Float64
  shock_up::Float64
  shock_mass::Float64
  shock_mass_pension::Float64
  bkt_select::Dict{Symbol, Vector{Bool}}  ## buckets selected for shocks
end

type SIILifePX <: SIIModule
  tf::TimeFrame                   ## shared time frame
  shock_type::Symbol              ## indicates object type to be shocked
  balance::DataFrame              ## balance sheet for various shocks
  shock::Float64
  bkt_select::Vector{Bool}         ## buckets selected for shocks
end

type SIILifeCost <: SIIModule
  tf::TimeFrame                   ## shared time frame
  shock_type::Symbol              ## indicates object type to be shocked
  balance::DataFrame              ## balance sheet for various shocks
  shock_cost::Float64
  shock_infl::Float64
end

type SIILifeCat <: SIIModule
  tf::TimeFrame                   ## shared time frame
  shock_type::Symbol              ## indicates object type to be shocked
  balance::DataFrame              ## balance sheet for various shocks
  shock::Float64
  bkt_select::Vector{Bool}         ## buckets selected for shocks
end

type SIILife <: SIIModule
  tf::TimeFrame                   ## shared time frame
  dim::Vector{Symbol}
  corr::Matrix{Float64}
  qx::SIILifeQX                   ## moratlity risk
  sx::SIILifeSX                   ## surrender risk
  px::SIILifePX                   ## longevity risk
#   dm::SIILifeDM                   ## disabilitt/morbidity risk
  cost::SIILifeCost               ## expense risk
#   rev::SIILifeREV                 ## revision risk
  cat::SIILifeCat                 ## catastrophe risk
end

## SII operational risk --------------------------------------------------------
type SIIOp
  tf::TimeFrame
  prem_earned::Float64
  prem_earned_prev::Float64
  tp::Float64
  cost_ul::Float64
end

##  Adjustment for deferred taxes ----------------------------------------------
type SIIDT <: SIIModule
  tf::TimeFrame                   ## shared time frame
  shock_type::Symbol              ## indicates object type to be shocked
  balance::DataFrame              ## balance sheet for various shocks
  bscr::Float64
  adj_tp::Float64
  scr_op::Float64
end


## SII all risks ---------------------------------------------------------------

type SII <: SIIModule
  tf::TimeFrame
  capmkt_dfs::Vector{DataFrame}
  inv_dfs::Vector{DataFrame}
  dyn_dfs::Vector{DataFrame}
  capmkt_be::CapMkt               ## deterministic best estimate capital market
  inv_be::Invest
  bkts_be::Buckets
  asset_oth_be::AssetOther        ##
  liab_oth_be::LiabOther          ## without subordinated debt
  dyn::Dynamic                    ## initialized prior to any shock
  balance::DataFrame

  sp_cqs::Dict{UTF8String,Int64}  ## rating translation: Standard Poor's to CQS
  dim::Vector{Symbol}
  corr::Matrix{Float64}
  mkt::SIIMkt                     ## SII module market risk
  def::SIIDef                     ## SII module default risk
  life::SIILife                   ## SII module life risk
  op::SIIOp                       ## SII module operational risk
  dt::SIIDT                       ## module for calc of deferred tax adjustment
  bscr_net::Float64
  bscr::Float64
  scr_op::Float64
  adj_tp::Float64
  adj_dt::Float64
  scr::Float64
end

