## Constructors ----------------------------------------------------------------
function CapMkt(name::ASCIIString,
                tf::TimeFrame,
                n_mc::Int64,
                cov::Array{Float64,2},
                proc_info::Vector{StochProcessInfo}
               )

    n = length(proc_info)

    noise = reshape( rand( MvNormal(cov), n_mc * tf.n_p )',
                    n_mc, tf.n_p, size(cov)[1] )

    dict_proc = Dict{ASCIIString, Int64}()
    proc = Array(Process, n)
    cum_dim = 0
    for i = 1:n
        dim = length(proc_info[i].v_init)

        proc[i] =
            eval(parse(proc_info[i].type_name))(proc_info[i].name,
                                                proc_info[i].labels,
                                                proc_info[i].v_init,
                                                proc_info[i].param,
                                                tf,
                                                cov[(cum_dim+(1:dim)),
                                                    (cum_dim+(1:dim))],
                                                noise[: , :, (cum_dim +(1:dim))]
                                                )
        cum_dim += dim
        dict_proc[proc_info[i].name] = i
    end
    CapMkt( name, tf, n_mc, cov, noise, proc, n, dict_proc)
end

# Constructor from DataFrames
function CapMkt(name::ASCIIString,
                tf::TimeFrame,
                n_mc::Int,
                df_proc_1::DataFrame,
                df_proc_2::DataFrame)
    
    stdev = Float64 [df_proc_2[j,"std"] for j=1:nrow(df_proc_2)] 
    corr = Array(Float64, (length(stdev),length(stdev)) )
        
    offset = 0
    for j = 1:ncol(df_proc_2)
        if ismatch(r"corr*",names(df_proc_2)[j])
            corr[:,j-offset] = df_proc_2[names(df_proc_2)[j]]
        else
            offset = j
        end
    end
    proc_info = Array(StochProcessInfo, nrow(df_proc_1))
    for i = 1:nrow(df_proc_1)
        proc_info[i] = StochProcessInfo(ascii(df_proc_1[i, "proc_name"]),
                                        df_proc_1, df_proc_2)
    end
    CapMkt(name, tf, n_mc, (stdev*stdev') .* corr,  proc_info )
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
