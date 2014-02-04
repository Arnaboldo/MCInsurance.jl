export StochProcessInfo,
       Brownian, CIR, GeomBrownian, ManualShortRate, Vasicek,
       ProcessIndex, ProcessShortRate, Process,
       determbop, forwardbop      

type StochProcessInfo
    # Interface necessary because different asset groups
    # have different numbers of input parameters
    type_name::ASCIIString   ## process type
    name::ASCIIString
    labels::Vector{ASCIIString}
    v_init::Vector{Float64}
    param::Any
end


abstract Process

abstract ProcessIndex <: Process

abstract ProcessShortRate <: Process


type Brownian <: ProcessIndex
    name::ASCIIString           ## name of process
    labels::Vector{ASCIIString} ## labels for process components
    v_init::Vector{Float64}     ## initial values
    drift::Vector{Float64}      ## parameter for process
    cov::Array{Float64,2}       ## covariance matrix for noise
    noise:: Array{Float64,3}    ## (no checks with cov)
    dim::Int                    ## number of assets modeled
    v_bop::Array{Float64,3}     ## projected values beg. of step
    yield::Array{Float64,3}     ## relative return during step
    n_mc::Int                   ## number of Monte Carlo scenarios
    dt::Float64                 ## length of time step
    n_p::Int                    ## number of projection periods
end

type GeomBrownian <: ProcessIndex
    name::ASCIIString           ## name of process
    labels::Vector{ASCIIString} ## labels for process components
    v_init::Vector{Float64}     ## initial values
    drift::Vector{Float64}      ## parameter for process
    cov::Array{Float64,2}       ## covariance matrix for noise
    noise:: Array{Float64,3}    ## (no checks with cov)
    dim::Int                    ## number of assets modeled
    v_bop::Array{Float64,3}     ## projected values beg. of step
    yield::Array{Float64,3}     ## relative return during step
    n_mc::Int                   ## number of Monte Carlo scenarios
    dt::Float64                 ## length of time step
    n_p::Int                    ## number of projection periods
end

type Vasicek <: ProcessShortRate
    name::ASCIIString           ## name of process
    labels::Vector{ASCIIString} ## labels for process components
    v_init::Float64             ## initial values
    a::Float64                  ## parameter for process
    v_infty::Float64            ## parameter for process
    cov::Float64                ## covariance matrix for noise
    noise:: Array{Float64,2}    ## (no checks with cov)
    dim::Int                    ## number of assets modeled (=1)
    v_bop::Array{Float64,3}     ## projected values beg. of step
    yield::Array{Float64,3}     ## relative return during step
    n_mc::Int                   ## number of Monte Carlo scenarios
    dt::Float64                 ## length of time step
    n_p::Int                    ## number of projection periods
end

type CIR <: ProcessShortRate
    name::ASCIIString           ## name of process
    labels::Vector{ASCIIString} ## labels for process components
    v_init::Float64             ## initial values
    a::Float64                  ## parameter for process
    v_infty::Float64            ## parameter for process
    cov::Float64                ## covariance matrix for noise
    noise:: Array{Float64,2}    ## (no checks with cov)
    dim::Int                    ## number of assets modeled (=1)
    v_bop::Array{Float64,3}     ## projected values beg. of step
    yield::Array{Float64,3}     ## relative return during step
    n_mc::Int                   ## number of Monte Carlo scenarios
    dt::Float64                 ## length of time step
    n_p::Int                    ## number of projection periods
end

type ManualShortRate <: ProcessShortRate
    name::ASCIIString           ## name of process
    labels::Vector{ASCIIString} ## labels for process components
    v_init::Vector{Float64}     ## initial values, filled by v_bo[
    v_bop::Array{Float64,3}     ## projected values beg. of step
    dim::Int                    ## number of assets modeled (=1)
    yield::Array{Float64,3}     ## relative return during step
    n_mc::Int                   ## number of Monte Carlo scenarios
    dt::Float64                 ## length of time step
    n_p::Int                    ## number of projection periods
end

