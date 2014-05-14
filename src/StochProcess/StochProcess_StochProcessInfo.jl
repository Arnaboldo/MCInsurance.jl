## Constructors ----------------------------------------------------------------
function StochProcessInfo(name::Symbol,
                          df_capmkt_1::DataFrame,
                          df_capmkt_2::DataFrame)
    
    capmkt_1 = df_capmkt_1[ df_capmkt_1[:proc_name] .== string(name), :]
    capmkt_2 = df_capmkt_2[ df_capmkt_2[:proc_name] .== string(name), :]   
    cpnt = Array(Symbol, 0)
    init = Array(Float64, 0)
    v_determ_bop = Array(Float64, nrow(capmkt_2), 0)
    for j = 1: nrow(capmkt_2)
        push!(cpnt, symbol(capmkt_2[j,:cpnt]))
        if !isna(capmkt_2[j,:init])
            push!(init, capmkt_2[j,:init])
        end
    end
    param = Array(Float64,0)
    for j = 1:ncol(capmkt_1)
        if ismatch(r"param*", string(names(capmkt_1)[j])) & !isna(capmkt_1[1,j])
            push!(param,capmkt_1[1,j])
        end
    end
    for j = 1:ncol(capmkt_2)
        if ismatch(r"v_bop*",string(names(capmkt_2)[j])) & !isna(capmkt_2[1,j])
            v_determ_bop = hcat(v_determ_bop, capmkt_2[:,j])
        end
    end
    StochProcessInfo(symbol(capmkt_1[1, :proc_type]),
                     name, cpnt, init, v_determ_bop, param)
end
     
