## Constructors ----------------------------------------------------------------
## Standard constructor
function CapMkt(name::Symbol,
                tf::TimeFrame,
                n_mc::Int64,
                stoch::Vector{Bool},
                cov::Array{Float64,2},
                proc_info::Vector{StochProcessInfo}
                )

  n = length(proc_info)

  if n_mc <= 1
    n_mc = 1
    cov *= 0.0
    noise = zeros(Float64,  n_mc, tf.n_p, size(cov,1))
  else
    noise = reshape(rand( MvNormal(cov), n_mc * tf.n_p )',
                    n_mc, tf.n_p, size(cov,1) )
  end
  proc = Array(Process, n)
  cum_n_cpnt = 0
  cum_stoch_n_cpnt = 0
  for i = 1:n
    n_cpnt = length(proc_info[i].cpnt)
    if stoch[cum_n_cpnt+1]
      proc[i] =
        eval(proc_info[i].type_name)(proc_info[i].name,
                                     proc_info[i].cpnt,
                                     proc_info[i].init,
                                     proc_info[i].param,
                                     tf,
                                     cov[(cum_stoch_n_cpnt+(1:n_cpnt)),
                                         (cum_stoch_n_cpnt+(1:n_cpnt))],
                                     noise[:,
                                           :,
                                           cum_stoch_n_cpnt+(1:n_cpnt)]
                                     )
      cum_stoch_n_cpnt += n_cpnt
    else
      if proc_info[i].type_name == :DetermShortRate
        proc_info[i].yield_determ = vec(proc_info[i].yield_determ)
      end
      proc[i] =
        eval(proc_info[i].type_name)(proc_info[i].name,
                                     proc_info[i].cpnt,
                                     proc_info[i].yield_determ,
                                     tf,
                                     n_mc
                                     )

    end
    cum_n_cpnt += n_cpnt
  end
  id = Dict(Symbol[proc[i].name for i = 1:n], 1:n)
  CapMkt(name, tf, n_mc, cov, noise, proc, id, n)
end

# Constructor from DataFrames
function CapMkt(name::Symbol,
                tf::TimeFrame,
                n_mc::Int,
                df_cap_1::DataFrame,
                df_cap_2::DataFrame)
  stoch = Array(Bool,0)
  stdev = Array(Float64,0)
  for i = 1:nrow(df_cap_2)
    if isna(df_cap_2[i,:std])
      push!(stoch,false)
    else
      push!(stoch,true)
      push!(stdev,df_cap_2[i,:std])
    end
  end
  corr = Array(Float64, (length(stdev),length(stdev)) )
  ctr_corr_col = 0
  ctr_col = 0
  for j = 1:ncol(df_cap_2)
    if ismatch(r"corr*",string(names(df_cap_2)[j]))
      ctr_corr_col += 1
      if stoch[ctr_corr_col]
        ctr_col += 1
        ctr_row = 0
        for k = 1:nrow(df_cap_2)
          if stoch[k]
            ctr_row += 1
            corr[ctr_row,ctr_col] = df_cap_2[k,j]
          end
        end
      end
    end
  end
  proc_info = Array(StochProcessInfo, nrow(df_cap_1))
  for i = 1:nrow(df_cap_1)
    proc_info[i] = StochProcessInfo(symbol(df_cap_1[i, :proc_name]),
                                    df_cap_1,
                                    df_cap_2)
  end
  CapMkt(name, tf, n_mc, stoch, (stdev*stdev') .* corr,  proc_info )
end


## Interface -------------------------------------------------------------------

function show(io::IO, me::CapMkt)
  println(io,"Type   : $(string(typeof(me)))")
  println(io,"name   : $(me.name)")
  println(io,"tf     : $(me.tf)")
  println(io,"n_mc   : $(me.n_mc)")
  println(io,"n      : $(me.n)")
  println(io,"cov    : \n$(me.cov)")
end
