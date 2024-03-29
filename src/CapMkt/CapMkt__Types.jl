export CapMkt

type CapMkt
  name::Symbol                   ## name of the capital market
  tf::TimeFrame                  ## defines dt and n_p
  n_mc::Int64                    ## number of Monte Carlo scen.
  cov::Array{Float64,2}          ## covariance matrix for noise
  noise::Array{Float64,3}        ## noise for all stoch.processes
  proc::Vector{Process}          ## processes (StochProcess) in capital market
  id::Dict{Symbol, Int}          ## id (vector index) of process
  n::Int                         ## number of processes
end

