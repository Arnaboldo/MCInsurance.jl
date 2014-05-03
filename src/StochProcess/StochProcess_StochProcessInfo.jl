## Constructors ----------------------------------------------------------------
function StochProcessInfo(name::Symbol,
                          df_proc_1::DataFrame,
                          df_proc_2::DataFrame)
    
    proc_1 = df_proc_1[ df_proc_1[:proc_name] .== string(name), :]
    proc_2 = df_proc_2[ df_proc_2[:proc_name] .== string(name), :]   
    labels = Array(Symbol, 0)
    v_init = Array(Float64, 0)
    v_determ_bop = Array(Float64, nrow(proc_2), 0)
    for j = 1: nrow(proc_2)
        push!(labels, symbol(proc_2[j,:proc_labels]))
        if !isna(proc_2[j,:v_init])
            push!(v_init, proc_2[j,:v_init])
        end
    end
    param = Array(Float64,0)
    for j = 1:ncol(proc_1)
        if ismatch(r"param*", string(names(proc_1)[j])) & !isna(proc_1[1,j])
            push!(param,proc_1[1,j])
        end
    end
    for j = 1:ncol(proc_2)
        if ismatch(r"v_bop*",string(names(proc_2)[j])) & !isna(proc_2[1,j])
            v_determ_bop = hcat(v_determ_bop, proc_2[:,j])
        end
    end
    StochProcessInfo(symbol(proc_1[1, :proc_type]),
                     name, labels, v_init, v_determ_bop, param)
end
     
