export TimeFrame,  insertc, insertp

type TimeFrame
    ## Input
    init::Int       # time at the start of the projection
    final::Int      # time at the end of the projection
    n_p::Int        # number of periods
    n_c::Int        # number of cycles (as if dt==1)
    n_dt::Int       # periods per cycle
    ## Calculated
    dt::Float64     # period size
end
