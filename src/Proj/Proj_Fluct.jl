## Constructors --------------------------------------------------

function Fluct(tf::TimeFrame, n_mc::Int, kind::ASCIIString)
    labels = ["QX", "SX", "C_INIT", "C_ABS", "C_IS", "C_PREM"]
    n = length(labels)
    d = Dict( int64([eval(parse(labels[i])) for i in 1:n]), [1:n] )
    fac = Array(Float64, n_mc, tf.n_c, n)
    Fluct(length(labels), kind, labels,fac,d)    
end

function Fluct(tf::TimeFrame, n_mc::Int,  df::DataFrame)
    ## data frame with the following structure:
    ## 8 rows: QX, SX, C_INIT, C_ABS, C_IS, C_PREM
    ## columns: labels:                 names of rows
    ##          init:                   initial value
    ##          drift:                  param (drift of Brownian)
    ##          std:                    param (std of Brownian)
    ##          corr.QX...corr.C_PREM:  correlation matrix
    fluct = Fluct(tf, n_mc, "GeomBrownian")
    cov = Array(Float64, fluct.n, fluct.n )
    col = 0
    for j = 1:size(df,2)
        if (ismatch(r"corr*",string(names(df)[j]))) & (!isna(df[1,j]))
            col += 1
            cov[:,col] = dropna(df[names(df)[j]])
        end
    end
    stdev = float(df[:std])
    cov =(stdev*stdev') .* cov
    tf_c = TimeFrame(tf.init, tf.final, tf.final-tf.init)
    fluct.fac = GeomBrownian("proc_fac",
                            fluct.labels,
                            float(df[:init]),
                            float(df[:drift]),
                            tf_c,
                            cov,
                            n_mc ).v_bop[:,2:end,:]
   return fluct
end

function Fluct(tf::TimeFrame, n_mc::Int, values::Array{Float64,2})
    fluct = Fluct(tf, n_mc, "Array")
    if ((tf.n_c == size(values,1)) & (fluct.n == size(values,2)) )
        v = Array(Float64, n_mc, size(values,1), size(values,2))
        for mc = 1:n_mc, t=1:tf.n_c, j = 1:fluct.n
            fluct.fac[mc,t,j] = values[t,j]
        end
    else
        error("size of array does not match")
    end
    return fluct
end

function Fluct(tf::TimeFrame, n_mc::Int, value::Float64)
    fluct = Fluct(tf, n_mc, "Array")
    fluct.fac[:,:,:] = value 
    return fluct
end
                  
## Interface functions ---------------------------------------------------------

function isequal(fluct1::Fluct, fluct2::Fluct)
    fluct1.n == fluct2.n &&
    fluct1.kind == fluct2.kind &&
    fluct1.fac == fluct2.fac
    # labels are constant and therefore always equal
    # d is constant and therefore always equal
end
    
function show(io::IO, me::Fluct)
    println(io, "Type:     $(string(typeof(me)))")
    println(io, "n:        $(me.n)")
    println(io, "kind:     $(me.kind)")
    println(  io, "labels:   $(transpose(me.labels))")
    println(io, "fac size: $(size(me.fac))")
 end

