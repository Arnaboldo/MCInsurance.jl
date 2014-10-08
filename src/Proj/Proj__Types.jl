export  C_EOC, DELTA_TPG, BONUS, INVEST, L_OTHER, PROFIT, TAX, TAX_CREDIT, DIVID
export TPG_EOC, L_OTHER_EOC, INVEST_EOC, SURPLUS_EOC, CYCLE
export Fluct, Fixed
export CFlow, dfcf, dfv0, dfv, disccf, pvdfcf, vinit
export balance_det_init, balance_det, proveoc, proveocvec
export Dynamic, getprob

const C_EOC = 6
const DELTA_TPG, BONUS, INVEST, L_OTHER, PROFIT, TAX,  DIVID  = 7:14

const TPG_EOC, L_OTHER_EOC, INVEST_EOC, SURPLUS_EOC, CYCLE = 1:5

const col_CF = [:QX, :SX, :PX, :PREM, :C_BOC, :C_EOC,
                :DELTA_TPG, :BONUS, :INVEST, :L_OTHER,
                :PROFIT, :TAX, :DIVID]

const col_V = [:TPG_EOC, :L_OTHER_EOC, :INVEST_EOC,
               :SURPLUS_EOC, :CYCLE]
const col_V_TYPES = [Float64, Float64, Float64, Float64, Int]

const col_FLUCT = [:QX, :SX, :C_BOC, :C_DIR_EOC]

type Fixed
  cost_abs_c::Vector{Float64}
  cost_abs_gc_c::Vector{Float64}
end

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
  tf::TimeFrame                   ## time frame (from buckets)
  cf::Array{Float64,3}            ## cash-flow values
  v_0::Array{Float64,3}           ## initial cash flow and valuation values
  v::Array{Float64,3}             ## valuation values
  model_new_tax_credit::Bool      ## true: model arsing tax credit
  tax_credit_init::Float64        ## initial tax credit
  tax_credit::Array{Float64,2}    ## nominal values necessary for projection
  tax_credit_util::Array{Float64,2} ## utilization of tax credit
  discount_init::Array{Float64,1} ## discount rates at beginning of projection
end

type Dynamic
  probsx::Function # bkt::Bucket, mc::Int, t::Int, invest::Invest
  alloc!::Function #invest::Invest, mc::Int, t::Int
  bonusrate::Function
  dividend::Function
  expense::Function
  taxprofit::Function
  update!::Function # updates the structure based on current projection values
  # often used constants
  bonus_factor::Float64
  capital_dividend::Float64
  # hook for customization
  hook::Any
end
