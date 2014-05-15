## Constructors ----------------------------------------------------------------

function TimeFrame( init::Int,
                   final::Int,
                   n_p::Int )
    n_c = final - init
    n_dt = int(n_p // n_c)
    dt = n_c / n_p
    TimeFrame(init, final, n_p, n_c, n_dt, dt)
end

function TimeFrame( init::Int,
                   final::Int)
    TimeFrame(init, final, final - init)
end


## Interface functions for TimeFrame  ------------------------------------------

function ==(tf1::TimeFrame, tf2::TimeFrame)
    ==(tf1.init, tf2.init) &&
    ==(tf1.final, tf2.final) &&
    ==(tf1.n_p, tf2.n_p) &&
    ==(tf1.n_c, tf2.n_c) &&
    ==(tf1.n_dt, tf2.n_dt) &&
    ==(tf1.dt, tf2.dt)
end

function show(io::IO, me::TimeFrame)
  print(io,"$(me.init) .. (")
  print(io,"$(me.n_p) | $(me.dt)")
  print(io,") .. $(me.final)")
end

## Both insertc and insertp have the same logic:
## - returns a vector of length tf.n_c+1 (or tf.n_p+1)
##   corresponding to tf.init ... tf.final
## - The returned vector contains the maximum
##   possible cutout of vec that starts at the
##   position corresponding to init
## - This maximum possible cutout may be empty
## - The rest of the returned vector is padded
##   with zeros.
##  tf:      |--------------------------------|
##  init:    1234|                             1234
##  vec:              ***************
##  result:      00000***************00000000000000

function insertc(tf::TimeFrame,
                 init::Int,
                 vec::Vector{Float64},
                 is_cashflow::Bool=false)
    if is_cashflow # cash flow relates to cycles
        n_c = tf.n_c-1
        final = tf.final-1
    else  # otherwise we consider points in time
        n_c = tf.n_c
        final = tf.final
    end
        
    if (init <= tf.init-length(vec)) |  ( init > final) 
        return zeros(Float64, n_c+1)
    else
        vec_end = min( length(vec), final - init + 1 )
        return [ zeros( Float64, max(0, init - tf.init) ),
                vec[ max( 1, tf.init-init+1):vec_end ],
                zeros( Float64, final - init + 1 - vec_end ) ]
    end
end

function insertp(tf::TimeFrame,
                    init::Rational{Int},
                    vec::Vector{Float64},
                 is_cashflow::Bool=false)
    if is_cashflow # cash flow relates to periods
        n_p = tf.n_p-1
        final = tf.final-1
    else  # otherwise we consider points in time
        n_p = tf.n_p
        final = tf.final
    end

    if  ( init <= tf.init-length(vec)//tf.n_dt ) |
        ( init > final) 
        return zeros(Float64, n_p+1)
    else
        vec_end = min(length(vec),
                      int((final - init)*tf.n_dt) + 1  )
        return [zeros(Float64,
                       int(max(0, (init-tf.init)*tf.n_dt)) ),
                vec[ max( 1, (tf.init-init)*tf.
                         n_dt+1):vec_end ],
                zeros( Float64,
                      int((final-init)*tf.n_dt + 1 - vec_end))]
    end
end

