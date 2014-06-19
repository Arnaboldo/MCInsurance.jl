# Constructors -----------------------------------------------------------------
function SIIMktInt()
   tf = TimeFrame()
   shock_type = :CapMkt
   sub_modules = [:spot_up, :spot_down]
   balance = DataFrame()
   spot_down = Array(Float64, 1, 1, 1)
   spot_up = Array(Float64, 1, 1, 1)
   spot_down_abs_max = 0.0
   spot_up_abs_min = 0.0
   return SIIMktInt(tf, shock_type, sub_modules, balance,
                    spot_down, spot_up, spot_down_abs_max, spot_up_abs_min)
end

function SIIMktInt(tf::TimeFrame,
                   balance_be::DataFrame,
                   df_sii_mkt_general::DataFrame,
                   df_sii_mkt_interest::DataFrame)
  me = SIIMktInt()
  me.tf = tf
  me.balance = deepcopy(balance_be)
  me.spot_down =
    reshape(interpolate(convert(Array, df_sii_mkt_interest[:,:spot_down]), tf.n_dt),
            1, (nrow(df_sii_mkt_interest)-1) * tf.n_dt, 1)
  me.spot_up =
    reshape(interpolate(convert(Array, df_sii_mkt_interest[:,:spot_up]), tf.n_dt),
            1, (nrow(df_sii_mkt_interest)-1) * tf.n_dt, 1)
  me.spot_down_abs_max = df_sii_mkt_general[1,:spot_down_abs_max]/tf.n_dt
  me.spot_up_abs_min = df_sii_mkt_general[1,:spot_up_abs_min]/tf.n_dt
  return  me
end


## Interface -------------------------------------------------------------------

function shock!(me::SIIMktInt,
                buckets::Buckets,
                other::Other,
                capmkt_dfs::Any,
                invest_dfs::Any,
                dyn::Any)

  ## Modular approach
  capmkt_be = CapMkt([:sii_mkt_int, me.tf, 1, capmkt_dfs]...)

  me.balance =me.balance[me.balance[:SCEN] .== :be, :]
  for sm in me.sub_modules
    add!(me, sm, capmkt_be, invest_dfs, buckets, other, dyn,
         (sii_int, cpm) -> mktintshock!(cpm, sii_int, sm) )
  end
  return me
end


## Private ---------------------------------------------------------------------

function mktintshock!(me::CapMkt, sii_mkt_int::SIIMktInt, sm::Symbol)
  if sm == :spot_down
    scenshock = scendown
  else
    scenshock = scenup
  end
  for i = 1:me.n
    if typeof(me.proc[i]) <: ProcessInterest
      me.proc[i].yield = reshape(scenshock(sii_mkt_int, me.proc[i].yield),
                                 size(me.proc[i].yield))
    end
  end
end

function interpolate(v_c::Vector{Float64}, n_dt::Int)
  v_p = zeros(Float64, (length(v_c) -1) * n_dt)
  for t in 1:(length(v_c)-1)
    v_p[((t-1)*n_dt+1):(t*n_dt)] = linspace(v_c[t],v_c[t+1], n_dt+1)[2:end]
  end
  return v_p
end

function scendown(me::SIIMktInt, interest::Array{Float64,3})
  spot =cumsum(interest[1,:,1],2)
  spot_shocked = zeros(Float64, size(spot,1), size(spot,2)+1, size(spot,3))
  forw_shocked = Array(Float64, size(spot))
  for mc = 1:size(spot,1), j = 1:size(spot,3)
    spot_shocked[mc,2:end,j] =
      max(spot[mc,:,j] +
            min(spot[mc,:,j] .* me.spot_down[1,size(spot,2),1],
                me.spot_down_abs_max),
            0.0
          )
    forw_shocked[mc,:,j] =
      spot_shocked[mc,2:end,j] - spot_shocked[mc,1:end-1,j]
  end
  return forw_shocked
end

function scenup(me::SIIMktInt, interest::Array{Float64,3})
  spot =cumsum(interest[1,:,1],2)
  spot_shocked = zeros(Float64, size(spot,1), size(spot,2)+1, size(spot,3))
  forw_shocked = Array(Float64, size(spot))
  for mc = 1:size(spot,1), j = 1:size(spot,3)
    spot_shocked[mc,2:end,j] =
      spot[mc,:,j] + max(spot[mc,:,j] .* me.spot_up[1,size(spot,2),1],
                         me.spot_up_abs_min)
    forw_shocked[mc,:,j] =
      spot_shocked[mc,2:end,j] - spot_shocked[mc,1:end-1,j]
  end
  return forw_shocked
end

function scr(me::SIIMktInt)
  ind = [ sm in me.balance[:SCEN] ? 1 : 0  for sm in me.sub_modules ]
  scr_vec_net =
    float64(bof(me, :be) .* ind - [bof(me, sm) for sm in me.sub_modules ])
  scr_vec_gross =
    float64(scr_vec_net + fdb(me, :be) .* ind -
              [fdb(me, sm) for sm in me.sub_modules ]
            )
  scen_up = scr_vec_net[1] < scr_vec_net[2]
  scr_net = minimum([0.0, scr_vec_net])
  scr_gross =
    min(0.0, scr_net < scr_vec_net[1] ? scr_vec_gross[2] : scr_vec_gross[1])
  return scr_net, scr_gross, scen_up
end

# function scendiscount(scen_interest::Vector{Float64}, n_c::Int)
#   n_scen_interest = length(scen_interest)
#   if n_scen_interest >= n_c
#     return exp(-cumsum(scen_interest))[1:n_c]
#   else
#     interest = Array(Float64, n_c)
#     interest[1:n_scen_interest] = scen_interest
#     interest[n_scen_interest+1:end] = scen_interest[end]
#     return exp(-cumsum(interest))
#   end
# end


