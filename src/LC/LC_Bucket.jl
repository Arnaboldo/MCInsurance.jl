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
  buckets.n_c =
    max(maximum(lc.all[:,:dur] - (buckets.tf.init .- lc.all[:, :y_start ])),
        tf.n_c)
  for i = 1:lc.n
    add!(buckets,1, lc, i, df_prod, df_load, df_qx,
         df_interest, true)
  end
  buckets
end

## Interface  ------------------------------------------------------------------

function ==(b1::Bucket, b2::Bucket)
  ==(b1.n, b2.n) &&
    ==(b1.n_c, b2.n_c) &&
      ==(b1.cat, b2.cat) &&
        ==(b1.cond, b2.cond) &&
          ==(b1.tpg_price, b2.tpg_price) &&
            ==(b1.prob_be, b2.prob_be) &&
              ==(b1.sx_weights, b2.sx_weights)
end

function ==(buckets_1::Buckets, buckets_2::Buckets)
  ==(buckets_1.n, buckets_2.n) &&
    ==(buckets_1.all, buckets_2.all) &&
      ==(buckets_1.tf, buckets_2.tf)
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
  dur = max(lc.all[i, :dur]- (me.tf.init-lc.all[i, :y_start]),
            b == 0 ? 0 : me.all[b].n_c )
  n_c = max(dur, me.tf.n_c)
  tf_cond = TimeFrame(me.tf.init, me.tf.init+n_c )
  ## Make sure that inflation is calculated with respect to me.tf.init
  delta_t_infl =  me.tf.init - lc.all[i, :y_start]
  prof = profile(lc,
                 i,
                 df_prod,
                 loadings(df_load, df_prod[lc.all[i, :prod_id],:cost_be_name]),
                 delta_t_infl)

  cond_cf = condcf(lc.all[i,:is], lc.all[i,:prem], df_prod, prof)
  cond = zeros(Float64, n_c, N_COND)
  cond_nb = zeros(Float64, n_c, N_COND)
  for j = 1:N_COND
    cond[:,j] = insertc(tf_cond, lc.all[i, :y_start], cond_cf[:,j], true)
  end
  if lc.all[i, :y_start] == me.tf.init
    cond_nb = deepcopy(cond)
  end

  # age_range refers to age_cycles from the inception of the contract
  age_range = (lc.all[i,:ph_age_start]+1) .+ [0: lc.all[i,:dur] - 1]
  prob_be = zeros( Float64, n_c, 3)
  prob_be_tmp = getprob(lc, i, df_prod, df_qx, cat[CAT_QXBE],
                        age_range,
                        lc.all[i, :be_sx_fac]
                        )
  for X in [QX,SX]
    prob_be[:,X] =
      insertc(tf_cond, lc.all[i, :y_start], prob_be_tmp[:,X], true)
  end
  prob_be[:,SX] .*= [ abs(x)>eps() ? 1 : 0 for x in cond[:,SX]]
  prob_be[:,PX] = 1 .- prob_be[:,QX] - prob_be[:,SX]

  prob_stat = getprob(lc, i, df_prod, df_qx, lc.all[i, :qx_name], age_range)
  tpg_price_tmp =
    tpgveceoc(prob_stat,
             exp(-cumsum(convert(Array,
                                 interest[1:lc.all[i,:dur],
                                          df_prod[lc.all[i,:prod_id],
                                                  :interest_name]]))),
             cond_cf)
  tpg_price = insertc(tf_cond, lc.all[i, :y_start], tpg_price_tmp, true)
  if lc.all[i, :y_start] < me.tf.init
    tpg_price_init = tpg_price_tmp[ me.tf.init-lc.all[i, :y_start]]
  else
    tpg_price_init = 0.0
  end
  # create new bucket or merge into existing bucket
  if b == 0
    me.n += 1
    push!(me.all, Bucket(1, n_c, dur, cat, cond, cond_nb,
                         tpg_price, tpg_price_init,
                         prob_be, cond[:,SX], 1.0, 1.0, 0.0, false))
  else
    merge!(me, b, n_c, cat, cond, cond_nb, tpg_price, tpg_price_init, prob_be)
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

## Private ---------------------------------------------------------------------

## merge a condtional cash-flow and probabilties into an existing
## bucket
function merge!(me::Buckets,
                b::Int,                       # Bucket
                n_c::Int,                     # length of cond
                cat::Vector{Any},             # bucket id
                cond::Array{Float64,2},       # cond. cash-flows
                cond_nb::Array{Float64,2},       # cond. cash-flows
                tpg_price::Vector{Float64},
                tpg_price_init::Float64,
                prob_be::Array{Float64,2} )   # biom. prob
  if n_c > me.all[b].n_c
    grow!(me.all[b], n_c, prob_be[:,QX])
  end
  me.all[b].n += 1
  for j = 1:N_COND
    me.all[b].cond[:,j] += cond[:,j]
    me.all[b].cond_nb[:,j] += cond_nb[:,j]
  end
  me.all[b].tpg_price += tpg_price
  me.all[b].tpg_price_init += tpg_price_init
  me.all[b].prob_be[:,SX] =
    (cond[:,SX] .* prob_be[:,SX] +
       me.all[b].sx_weights .* me.all[b].prob_be[:,SX]
     ) ./  min(-eps(), cond[:,SX] + me.all[b].sx_weights )
  me.all[b].sx_weights += cond[:,SX]
end

## grow duration of table Bucket.cond if current duration is too short
function grow!(me::Bucket,
               n_c::Int,
               prob_be_qx::Vector{Float64})
  cond = zeros(Float64, n_c, N_COND)
  cond_nb = zeros(Float64, n_c, N_COND)
  prob_be = zeros(Float64, n_c, 2)
  sx_weights = zeros(Float64, n_c)
  tpg_price = zeros(Float64, n_c)
  for j = 1:N_COND
    cond[1:me.n_c,j] = me.cond[:,j]
    cond_nb[1:me.n_c,j] = me.cond_nb[:,j]
  end
  tpg_price[1:me.n_c] = me.tpg_price
  prob_be[:,QX] =  prob_be_qx
  prob_be[1:me.n_c,SX] = me.prob_be[:,SX]
  sx_weights[1:me.n_c] = me.sx_weights

  me.n_c = n_c
  me.cond = cond
  me.cond_nb = cond_nb
  me.tpg_price = tpg_price
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
  print(   io, "tpg_price:    guaranteed technical provisions for pricing, ")
  println( io, "size = $(size(me.tpg_price))")
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
   lc.all[i, :ph_gender] == "M"  ? 1 : 2,             # gender
   lc.all[i, :ph_qx_be_name],                         # qx_be table
   df_prod[lc.all[i,:prod_id],:interest_name],        # interest for pricing
   df_load[df_load[:name] .== load_name, :infl][1,1], # be cost inflation
   lc.all[i, :risk]]                                  # risk class
end
