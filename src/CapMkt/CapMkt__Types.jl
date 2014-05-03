export CapMkt

type CapMkt
    name::Symbol                   ## name of the capital market
    tf::TimeFrame                  ## defines dt and n_p
    n_mc::Int64                    ## number of Monte Carlo scen.
    stoch::Vector{Bool}            ## indicator for stochastic 1d-processes  
    cov::Array{Float64,2}          ## covariance matrix for noise
    noise::Array{Float64,3}        ## noise for all stoch.processes
    proc::Vector{Process}          ## StochProcess in capital market
    n::Int                         ## number of process groups
    dict_proc::Dict{Symbol,Int}    ## proc-name -> index in proc
end
