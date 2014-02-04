export CapMkt

type CapMkt
  name::ASCIIString                  ## name of the capital market
  tf::TimeFrame                      ## defines dt and n_p
  n_mc::Int64                        ## number of Monte Carlo scen.
  cov::Array{Float64,2}              ## covariance matrix for noise
  noise::Array{Float64,3}            ## noise for all stoch.processes
  proc::Vector{Process}              ## StochProcess in capital market
  n::Int                             ## number of process groups
  dict_proc::Dict{ASCIIString,Int64} ## proc-name -> index in proc
end
