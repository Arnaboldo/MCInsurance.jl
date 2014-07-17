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
                   bkts_be::Buckets,
                   oth_be::Other,
                   capmkt_be::CapMkt,
                   dyn::Dynamic,
                   inv_dfs::Vector{DataFrame},
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
  shock!(me, bkts_be, oth_be, capmkt_be, inv_dfs, dyn)
  return  me
end


## Interface -------------------------------------------------------------------

function scr(me::SIIMktInt)
  ind = float64([ sm in me.balance[:SCEN] ? 1 : 0  for sm in me.sub_modules ])
  scr_vec_net =
    float64([bof(me, sm) for sm in me.sub_modules ]) - bof(me, :be) .* ind
  scr_vec_gross =
    scr_vec_net + fdb(me, :be) .* ind -
    float64([fdb(me, sm) for sm in me.sub_modules])
  scen_up = scr_vec_net[1] < scr_vec_net[2]
  scr_net = minimum([0.0, scr_vec_net])
  scr_gross =
    min(0.0, scr_net < scr_vec_net[1] ? scr_vec_gross[2] : scr_vec_gross[1])
  return scr_net, scr_gross, scen_up
end

## Private ---------------------------------------------------------------------

function shock!(me::SIIMktInt,
                buckets::Buckets,
                other::Other,
                capmkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Any)

  me.balance =me.balance[me.balance[:SCEN] .== :be, :]
  for sm in me.sub_modules
    add!(me, sm, capmkt_be, invest_dfs, buckets, other, dyn,
         (sii_int, cpm) -> mktintshock!(cpm, sii_int, sm) )
  end
  return me
end

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
  n_mc = size(interest,1)
  n = size(interest,2)
  n_cpn = size(interest,3)

  spot =  cumsum(interest,2)./reshape([1:n],n_mc,n,n_cpn)
  spot_shocked = zeros(Float64, n_mc, n+1, n_cpn)
  spot_shocked_cum = Array(Float64, n_mc, n+1, n_cpn)
  forw_shocked = Array(Float64, size(spot))
  for mc = 1:n_mc, cpn = 1:n_cpn
    spot_shocked[mc,2:end,cpn] =
      max(spot[mc,:,cpn] +
            min(spot[mc,:,cpn] .* me.spot_down[mc,1:n,cpn],
                me.spot_down_abs_max),
          0.0
          )
    spot_shocked_cum[mc,:,cpn] =
      spot_shocked[mc,:,cpn] .* reshape([0:n],mc,n+1,cpn)
    forw_shocked[mc,:,cpn] =
      spot_shocked_cum[mc,2:end,cpn] - spot_shocked_cum[mc,1:end-1,cpn]
  end
  return forw_shocked
end

function scenup(me::SIIMktInt, interest::Array{Float64,3})
  n_mc = size(interest,1)
  n = size(interest,2)
  n_cpn = size(interest,3)

  spot =  cumsum(interest,2)./reshape([1:n],n_mc,n,n_cpn)
  spot_shocked = zeros(Float64, n_mc, n+1, n_cpn)
  spot_shocked_cum = Array(Float64, n_mc, n+1, n_cpn)
  forw_shocked = Array(Float64, size(spot))
  for mc = 1:n_mc, cpn = 1:n_cpn
    spot_shocked[mc,2:end,cpn] =
      spot[mc,:,cpn] + max(spot[mc,:,cpn] .* me.spot_up[mc,1:n,cpn],
                           me.spot_up_abs_min)

    spot_shocked_cum[mc,:,cpn] =
      spot_shocked[mc,:,cpn] .* reshape([0:n],mc,n+1,cpn)
    forw_shocked[mc,:,cpn] =
      spot_shocked_cum[mc,2:end,cpn] - spot_shocked_cum[mc,1:end-1,cpn]
  end
  return forw_shocked
end

