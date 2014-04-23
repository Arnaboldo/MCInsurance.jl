## Constructors ----------------------------------------------------------------
function CapMkt(name::String,
                tf::TimeFrame,
                n_mc::Int64,
                stoch::Vector{Bool},
                cov::Array{Float64,2},
                proc_info::Vector{StochProcessInfo}
               )

    n = length(proc_info)

    noise = reshape(rand( MvNormal(cov), n_mc * tf.n_p )',
                    n_mc, tf.n_p, size(cov,1) )

    dict_proc = Dict{String, Int64}()
    proc = Array(Process, n)
    cum_dim = 0
    cum_stoch_dim = 0
    for i = 1:n
        dim = length(proc_info[i].labels)
        if stoch[cum_dim+1]
            proc[i] =
                eval(parse(proc_info[i].type_name))(proc_info[i].name,
                                                proc_info[i].labels,
                                                    proc_info[i].v_init,
                                                    proc_info[i].param,
                                                    tf,
                                                    cov[(cum_stoch_dim+(1:dim)),
                                                        (cum_stoch_dim+(1:dim))],
                                                    noise[: , :,
                                                          (cum_stoch_dim+(1:dim))]
                                                    )
            cum_stoch_dim += dim
        else
            proc[i] =
                eval(parse(proc_info[i].type_name))(proc_info[i].name,
                                                    proc_info[i].labels,
                                                    proc_info[i].v_determ_bop,
                                                    #proc_info[i].v_init,
                                                    #proc_info[i].param,
                                                    tf,
                                                    n_mc
                                                    )

        end
        cum_dim += dim
        dict_proc[proc_info[i].name] = i
    end
    CapMkt( name, tf, n_mc, stoch, cov, noise, proc, n, dict_proc)
end

# Constructor from DataFrames
function CapMkt(name::String,
                tf::TimeFrame,
                n_mc::Int,
                df_proc_1::DataFrame,
                df_proc_2::DataFrame)
    stoch = Array(Bool,0)
    stdev = Array(Float64,0)
    for i = 1:nrow(df_proc_2)
        if isna(df_proc_2[i,:std])
            push!(stoch,false)
        else
            push!(stoch,true)
            push!(stdev,df_proc_2[i,:std])
        end
    end
    corr = Array(Float64, (length(stdev),length(stdev)) )
    ctr_corr_col = 0
    ctr_col = 0
    for j = 1:ncol(df_proc_2)
        if ismatch(r"corr*",string(names(df_proc_2)[j]))
            ctr_corr_col += 1
            if stoch[ctr_corr_col]
                ctr_col += 1
                ctr_row = 0
                for k = 1:nrow(df_proc_2)
                     if stoch[k]
                        ctr_row += 1
                        corr[ctr_row,ctr_col] = df_proc_2[k,j]
                    end
                end
            end
        end
    end
    proc_info = Array(StochProcessInfo, nrow(df_proc_1))
    for i = 1:nrow(df_proc_1)
        proc_info[i] = StochProcessInfo(df_proc_1[i, :proc_name],
                                        df_proc_1, df_proc_2)
    end
    CapMkt(name, tf, n_mc, stoch, (stdev*stdev') .* corr,  proc_info )
    
    ## stdev = Float64 [df_proc_2[j,:std] for j=1:nrow(df_proc_2)] 
    ## corr = Array(Float64, (length(stdev),length(stdev)) )
        
    ## offset = 0
    ## for j = 1:ncol(df_proc_2)
    ##     if ismatch(r"corr*",string(names(df_proc_2)[j]))
    ##         corr[:,j-offset] = df_proc_2[names(df_proc_2)[j]]
    ##     else
    ##         offset = j
    ##     end
    ## end
    ## proc_info = Array(StochProcessInfo, nrow(df_proc_1))
    ## for i = 1:nrow(df_proc_1)
    ##     proc_info[i] = StochProcessInfo(ascii(df_proc_1[i, :proc_name]),
    ##                                     df_proc_1, df_proc_2)
    ## end
    ## CapMkt(name, tf, n_mc, (stdev*stdev') .* corr,  proc_info )
end


## Interface functions for CapMkt types ----------------------------------------

function show(io::IO, me::CapMkt)
    println(io,"Type   : $(string(typeof(me)))")
    println(io,"name   : $(me.name)")
    println(io,"tf     : $(me.tf)")
    println(io,"n_mc   : $(me.n_mc)")
    println(io,"n      : $(me.n)")
    println(io,"cov    : \n$(me.cov)")
end
