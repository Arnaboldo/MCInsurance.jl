export StochProcessInfo,
Brownian, CIR, GeomBrownian, DetermShortRate, ManualShortRate, Vasicek,
ProcessIndex, ProcessInterest, ProcessShortRate, Process,
determbop, forwardbop, yieldeoc

type StochProcessInfo
  # Interface necessary because different asset groups
  # have different numbers of input parameters
  type_name::Symbol                 ## process type
  name::Symbol                      ## process name
  cpnt::Vector{Any}                 ## process components (usually type Symbol)
  init::Vector{Float64}             ## initial value
  yield_determ::Array{Float64}      ## for ManualShortRate, DetermShortRate
  param::Any                        ## process parameters
end


abstract Process
abstract ProcessIndex <: Process
abstract ProcessInterest <: Process
abstract ProcessShortRate <: ProcessInterest


type Brownian <: ProcessIndex
  name::Symbol                ## name of process
  cpnt::Vector{Any}           ## process components
  cpnt_id::Dict{Any, Int}     ## id (vector index) of component
  init::Vector{Float64}       ## initial values
  drift::Vector{Float64}      ## parameter for process
  cov::Array{Float64,2}       ## covariance matrix for noise
  noise:: Array{Float64,3}    ## (no checks with cov)
  n::Int                      ## number of components
  v_bop::Array{Float64,3}     ## projected values beg. of step
  yield::Array{Float64,3}     ## relative return during step
  n_mc::Int                   ## number of Monte Carlo scenarios
  n_p::Int                    ## number of full projection periods
end

type GeomBrownian <: ProcessIndex
  name::Symbol                ## name of process
  cpnt::Vector{Any}           ## process components
  cpnt_id::Dict{Any, Int}     ## id (vector index) of component
  init::Vector{Float64}       ## initial values
  drift::Vector{Float64}      ## parameter for process
  cov::Array{Float64,2}       ## covariance matrix for noise
  noise:: Array{Float64,3}    ## (no checks with cov)
  n::Int                      ## number of components
  v_bop::Array{Float64,3}     ## projected values beg. of step
  yield::Array{Float64,3}     ## relative return during step
  n_mc::Int                   ## number of Monte Carlo scenarios
  n_p::Int                    ## number of full projection periods
end

type Vasicek <: ProcessShortRate
  name::Symbol                ## name of process
  cpnt::Vector{Any}           ## process components
  cpnt_id::Dict{Any, Int}     ## id (vector index) of component
  init::Float64             ## initial values
  a::Float64                  ## parameter for process
  yield_infty::Float64            ## parameter for process
  cov::Float64                ## covariance matrix for noise
  noise:: Array{Float64,2}    ## (no checks with cov)
  n::Int                      ## number of components (=1)
  yield::Array{Float64,3}     ## relative return during step
  n_mc::Int                   ## number of Monte Carlo scenarios
  n_p::Int                    ## number of full projection periods
end

type CIR <: ProcessShortRate
  name::Symbol                ## name of process
  cpnt::Vector{Any}           ## process components
  cpnt_id::Dict{Any, Int}     ## id (vector index) of component
  init::Float64               ## initial values
  a::Float64                  ## parameter for process
  yield_infty::Float64        ## parameter for process
  cov::Float64                ## covariance matrix for noise
  noise:: Array{Float64,2}    ## (no checks with cov)
  n::Int                      ## number of components (=1)
  yield::Array{Float64,3}     ## relative return during step
  n_mc::Int                   ## number of Monte Carlo scenarios
  n_p::Int                    ## number of full projection periods
end

type ManualShortRate <: ProcessShortRate
  name::Symbol                ## name of process
  cpnt::Vector{Any}           ## process components
  cpnt_id::Dict{Any, Int}     ## id (vector index) of component
  init::Float64               ## initial values, filled by yield
  n::Int                      ## number of components (=1)
  yield::Array{Float64,3}     ## relative return during step
  n_mc::Int                   ## number of Monte Carlo scenarios
  n_p::Int                    ## number of full projection periods
end

type DetermShortRate <: ProcessShortRate  # 1-dimensional short rate
  name::Symbol                ## name of process
  cpnt::Vector{Any}           ## process components
  cpnt_id::Dict{Any, Int}     ## id (vector index) of component
  init::Float64               ## initial values, filled by v_bob
  n::Int                      ## number of components (=1)
  yield::Array{Float64,3}     ## relative return during step
  yield_input::Vector{Float64} ## yield input may exceed time frame
  n_mc::Int                   ## number of Monte Carlo scenarios
  n_p::Int                    ## number of full projection periods
end

