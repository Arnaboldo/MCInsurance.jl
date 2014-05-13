export StochProcessInfo,
       Brownian, CIR, GeomBrownian, DetermShortRate, ManualShortRate, Vasicek,
       ProcessIndex, ProcessShortRate, Process,
       determbop, forwardbop, yieldc      

type StochProcessInfo
    # Interface necessary because different asset groups
    # have different numbers of input parameters
    type_name::Symbol                 ## process type
    name::Symbol                      ## process name
    cpnt::Vector{Any}                 ## process components (usually type Symbol)
    v_init::Vector{Float64}           ## initial value
    v_determ_bop::Array{Float64,2}    ## only used for DetermShortRate
    param::Any                        ## process parameters
end


abstract Process
abstract ProcessIndex <: Process
abstract ProcessShortRate <: Process  

type Brownian <: ProcessIndex
    name::Symbol                ## name of process
    cpnt::Vector{Any}           ## process components
    cpnt_id::Dict{Any, Int}     ## id (vector index) of component
    v_init::Vector{Float64}     ## initial values
    drift::Vector{Float64}      ## parameter for process
    cov::Array{Float64,2}       ## covariance matrix for noise
    noise:: Array{Float64,3}    ## (no checks with cov)
    n::Int                      ## number of components
    v_bop::Array{Float64,3}     ## projected values beg. of step
    yield::Array{Float64,3}     ## relative return during step
    n_mc::Int                   ## number of Monte Carlo scenarios
    dt::Float64                 ## length of time step
    n_p::Int                    ## number of projection periods
end

type GeomBrownian <: ProcessIndex
    name::Symbol                ## name of process
    cpnt::Vector{Any}           ## process components
    cpnt_id::Dict{Any, Int}     ## id (vector index) of component
    v_init::Vector{Float64}     ## initial values
    drift::Vector{Float64}      ## parameter for process
    cov::Array{Float64,2}       ## covariance matrix for noise
    noise:: Array{Float64,3}    ## (no checks with cov)
    n::Int                      ## number of components
    v_bop::Array{Float64,3}     ## projected values beg. of step
    yield::Array{Float64,3}     ## relative return during step
    n_mc::Int                   ## number of Monte Carlo scenarios
    dt::Float64                 ## length of time step
    n_p::Int                    ## number of projection periods
end

type Vasicek <: ProcessShortRate
    name::Symbol                ## name of process
    cpnt::Vector{Any}           ## process components
    cpnt_id::Dict{Any, Int}     ## id (vector index) of component
    v_init::Float64             ## initial values
    a::Float64                  ## parameter for process
    v_infty::Float64            ## parameter for process
    cov::Float64                ## covariance matrix for noise
    noise:: Array{Float64,2}    ## (no checks with cov)
    n::Int                      ## number of components (=1)
    v_bop::Array{Float64,3}     ## projected values beg. of step
    yield::Array{Float64,3}     ## relative return during step
    n_mc::Int                   ## number of Monte Carlo scenarios
    dt::Float64                 ## length of time step
    n_p::Int                    ## number of projection periods
end

type CIR <: ProcessShortRate
    name::Symbol                ## name of process
    cpnt::Vector{Any}           ## process components
    cpnt_id::Dict{Any, Int}     ## id (vector index) of component
    v_init::Float64             ## initial values
    a::Float64                  ## parameter for process
    v_infty::Float64            ## parameter for process
    cov::Float64                ## covariance matrix for noise
    noise:: Array{Float64,2}    ## (no checks with cov)
    n::Int                      ## number of components (=1)
    v_bop::Array{Float64,3}     ## projected values beg. of step
    yield::Array{Float64,3}     ## relative return during step
    n_mc::Int                   ## number of Monte Carlo scenarios
    dt::Float64                 ## length of time step
    n_p::Int                    ## number of projection periods
end

type ManualShortRate <: ProcessShortRate
    name::Symbol                ## name of process
    cpnt::Vector{Any}           ## process components
    cpnt_id::Dict{Any, Int}     ## id (vector index) of component
    v_init::Vector{Float64}     ## initial values, filled by v_bob
    v_bop::Array{Float64,3}     ## projected values beg. of step
    n::Int                      ## number of components (=1)
    yield::Array{Float64,3}     ## relative return during step
    n_mc::Int                   ## number of Monte Carlo scenarios
    dt::Float64                 ## length of time step
    n_p::Int                    ## number of projection periods
end

type DetermShortRate <: ProcessShortRate
    name::Symbol                ## name of process
    cpnt::Vector{Any}           ## process components
    cpnt_id::Dict{Any, Int}     ## id (vector index) of component
    v_init::Vector{Float64}     ## initial values, filled by v_bob
    v_bop::Array{Float64,3}     ## projected values beg. of step
    n::Int                      ## number of components (=1)
    yield::Array{Float64,3}     ## relative return during step
    n_mc::Int                   ## number of Monte Carlo scenarios
    dt::Float64                 ## length of time step
    n_p::Int                    ## number of projection periods
end

