## Constructors ----------------------------------------------------------------

# Bucket: Only standard constructor --------------------------------------------

# Buckets: Minimal constructor (empty list)
function Buckets(tf::TimeFrame)
    Buckets( 0, 0, Array(Bucket,0), tf)
end

# Buckets: Standard constructor
function Buckets(lc::LC,
                 tf::TimeFrame,
                 df_prod::DataFrame,
                 df_load::DataFrame,
                 df_qx::DataFrame,
                 df_interest::DataFrame)
    buckets = Buckets(tf)
    for i = 1:lc.n
        add!(buckets,1, lc, i, df_prod, df_load, df_qx, df_interest, true)     
    end
    for b = 1:buckets.n
        buckets.n_c = max(buckets.n_c, buckets.all[b].n_c)
    end
    buckets
end

## Interface functions for Bucket and Buckets  ---------------------------------

function isequal(b1::Bucket, b2::Bucket)
    isequal(b1.n, b2.n) &&
    isequal(b1.n_c, b2.n_c) &&
    isequal(b1.cat, b2.cat) &&
    isequal(b1.cond, b2.cond) &&
    isequal(b1.tp_stat, b2.tp_stat) &&
    isequal(b1.prob_be, b2.prob_be) &&
    isequal(b1.sx_weights, b2.sx_weights)
end

function isequal(buckets_1::Buckets, buckets_2::Buckets)
    isequal(buckets_1.n, buckets_2.n) &&
    isequal(buckets_1.all, buckets_2.all) &&
    isequal(buckets_1.tf, buckets_2.tf) 
end

function add!(me::Buckets,              
              c_curr::Int,           # current projection cycle
              lc::LC,                # portfolio of contracts
              i::Int,                # contract to be added
              df_prod::DataFrame,    # product information
              df_load::DataFrame,    # cost information
              df_qx::DataFrame,      # mortality tables
              interest::DataFrame,   # technical interest rates
              existing::Bool = true) # default: add existing contract

    c_start = lc.all[i, :y_start]-me.tf.init+1 # inception cycle
    if ((c_curr < c_start) |                   # no future contracts 
        (!existing & (c_curr > c_start))   )   # add existing contr.?
        return
    end    
    cat = getcat(lc, i, me.tf, df_prod, df_load)

    ## find bucket
    b = getind(me, cat)    
    ## prepare data for bucket
    if b == 0
        b_n_c = 0
    else
        b_n_c = me.all[b].n_c
    end
    dur = max(lc.all[i, :dur]- (me.tf.init-lc.all[i, :y_start]),  b_n_c)
    n_c = max(dur, me.tf.n_c)
    tf_cond = TimeFrame(me.tf.init, me.tf.init+n_c )
    cond = zeros(Float64, n_c, N_COND)
    prof = profile(lc,
                   i,
                   df_prod,
                   loadings(df_load, df_prod[lc.all[i, :prod_id],:cost_be_name]))
    cond_cf = condcf(lc.all[i,:is], lc.all[i,:prem], df_prod, prof)
    for j = 1:N_COND
        cond[:,j] = insertc(tf_cond, lc.all[i, :y_start], cond_cf[:,j], true)
    end
    tp_stat_calc =
        tpveceop(getprob(lc, i, df_prod, df_qx),
                         exp(-convert(Array, interest[1:lc.all[i,:dur],
                                                      df_prod[lc.all[i,:prod_id],
                                                               :interest_name]])),
                         cond_cf)
    tp_stat = insertc(tf_cond, lc.all[i, :y_start], tp_stat_calc, true)
    if lc.all[i, :y_start] < me.tf.init
        tp_stat_init = tp_stat_calc[ me.tf.init-lc.all[i, :y_start]]
    else
        tp_stat_init = 0.0
    end
    prob_be = zeros( Float64, n_c, 2)
    prob_be[:,QX] = df_qx[ cat[CAT_AGE] .+ [1:n_c], cat[CAT_QXBE] ]
    # we insure that sx-prob = 0 if there is no sx-benefit,
    # even if lc-data record sx-prob != 0
    prob_be[:,SX] =
        lc.all[i, :be_sx_fac] *
        insertc(tf_cond, lc.all[i, :y_start], getprobsx(lc,i,df_prod), true) .*
        cond[:,SX ] ./ min(-eps(), cond[:,SX ])

    # create new bucket or merge into existing bucket 
    if b == 0 
        me.n += 1
        push!(me.all, Bucket(1, n_c, dur, cat, cond, tp_stat, tp_stat_init,
                             prob_be, cond[:,SX], 1, 0.0, false))
    else
        merge!(me, b, n_c, cat, cond, tp_stat, tp_stat_init, prob_be) 
    end    
end

## for each bucket in Buckets get an array with the corresponding
## contract indices
function listcontracts(me::Buckets,
                       lc::LC,
                       df_prod::DataFrame,
                       df_load::DataFrame)
    contracts_per_bucket = Array(Any,me.n)
    for b = 1:me.n
        contracts_per_bucket[b] = Array(Int,0)
        for i = 1:lc.n
            if getcat(lc,i,me.tf, df_prod, df_load) == me.all[b].cat
                push!(contracts_per_bucket[b],i)
            end
        end
    end
    return contracts_per_bucket
end


## Private functions for Bucket and Buckets  -----------------------------------

## merge a condtional cash-flow and probabilties into an existing
## bucket 
function merge!(me::Buckets,
                b::Int,                       # Bucket
                n_c::Int,                     # length of cond
                cat::Vector{Any},             # bucket id
                cond::Array{Float64,2},       # cond. cash-flows
                tp_stat::Vector{Float64},
                tp_stat_init::Float64,
                prob_be::Array{Float64,2} )   # biom. prob
    if n_c > me.all[b].n_c
        grow!(me.all[b], n_c, prob_be[:,QX])
    end
    me.all[b].n += 1
    for j = 1:N_COND       
        me.all[b].cond[:,j] += cond[:,j]
    end
    me.all[b].tp_stat += tp_stat
    me.all[b].tp_stat_init += tp_stat_init
    me.all[b].prob_be[:,SX] =
        (cond[:,SX] .* prob_be[:,SX] +
         me.all[b].sx_weights .* me.all[b].prob_be[:,SX] ) ./
         min(-eps(), cond[:,SX] + me.all[b].sx_weights )
    me.all[b].sx_weights += cond[:,SX]
end

## grow duration of table Bucket.cond if current duration is too short
function grow!(me::Bucket,
               n_c::Int,
               prob_be_qx::Vector{Float64})
    cond = zeros(Float64, n_c, N_COND)
    prob_be = zeros(Float64, n_c, 2)
    sx_weights = zeros(Float64, n_c)
    tp_stat = zeros(Float64, n_c)
    for j = 1:N_COND
        cond[1:me.n_c,j] = me.cond[:,j]
    end
    tp_stat[1:me.n_c] = me.tp_stat
    prob_be[:,QX] =  prob_be_qx
    prob_be[1:me.n_c,SX] = me.prob_be[:,SX]
    sx_weights[1:me.n_c] = me.sx_weights

    me.n_c = n_c
    me.cond = cond  
    me.tp_stat = tp_stat
    me.prob_be = prob_be
    me.sx_weights = sx_weights
end    


function show(io::IO, me::Bucket)
    println( io, "Type:       $(string(typeof(me)))")
    println( io, "n:          $(me.n)")
    println( io, "n_c:        $(me.n_c)")
    println( io, "dur:        $(me.dur)")
    println( io, "            age  gender  qx_be  risk_class")
    println( io, "cat:        $(transpose(me.cat))")
    print(   io, "cond:       conditional cash-flow, ")
    println( io, "size = $(size(me.cond))")
    print(   io, "tp_stat:    statutory technical provisions, ")
    println( io, "size = $(size(me.tp_stat))")
    print(   io, "prob_be:    best estimate prob qx, sx, ")
    println( io, "size = $(size(me.prob_be))")
end


function getind(me::Buckets,  cat::Vector{Any})
    ind = 0
    if me.n > 0
        for b = 1:me.n
            if all(cat .== me.all[b].cat)
                ind = b
                break
            end
        end
    end
    return ind
end

function getcat(lc::LC,
                i::Int,
                tf::TimeFrame,
                df_prod::DataFrame,
                df_load::DataFrame)

    load_name = df_prod[lc.all[i, :prod_id],:cost_be_name]
    [tf.init-lc.all[i, :ph_y_birth],                    # current age
     if lc.all[i, :ph_gender] == "M" 1 else 2 end,      # gender
     lc.all[i, :ph_qx_be_name],                         # qx_be table
     df_prod[lc.all[i,:prod_id],:interest_name],        # interest for pricing
     df_load[df_load[:name] .== load_name, :infl][1,1], # be cost inflation
     lc.all[i, :risk]]                                  # risk class  
end

