## Constructors ----------------------------------------------------------------
function StochProcessInfo(name::ASCIIString,
                          df_proc_1::DataFrame,
                          df_proc_2::DataFrame)
    
    proc_1 = df_proc_1[df_proc_1["proc_name"].==name,:]
    proc_2 = df_proc_2[df_proc_2["proc_name"].==name,:]   
    labels = Array(ASCIIString, 0)
    v_init = Array(Float64, 0)
    for j = 1: nrow(proc_2)
        push!(labels, proc_2[j,"proc_labels"])
        push!(v_init, proc_2[j,"v_init"])
    end
    param = Array(Float64,0)
    for j = 1:ncol(proc_1)
        if ismatch(r"param*",names(proc_1)[j]) & !isna(proc_1[1,j])
            push!(param,proc_1[1,j])
        end
    end
    StochProcessInfo(ascii(proc_1[1,"proc_type"]), name, labels, v_init, param)
end
     
