# Constructors -----------------------------------------------------------------
function SIILifeSX()
  tf = TimeFrame()
  shock_type = :Buckets
  sub_modules = [:SX_DOWN, :SX_UP, :SX_MASS]
  balance = DataFrame()
  shock_down = 0.0
  shock_down_abs = 0.0
  shock_up = 0.0
  shock_mass = 0.0
  shock_mass_pension = 0.0
  return SIILifeSX(tf, shock_type, sub_modules, balance,
                   shock_down, shock_down_abs, shock_up,
                   shock_mass, shock_mass_pension)
end

function SIILifeSX(tf::TimeFrame,
                   balance_be::DataFrame,
                   df_sii_life_general::DataFrame)
  me = SIILifeSX()
  me.tf = tf
  me.balance = deepcopy(balance_be)
  me.shock_down = df_sii_life_general[1, :SX_DOWN]
  me.shock_down_abs = df_sii_life_general[1, :SX_DOWN_ABS]
  me.shock_up = df_sii_life_general[1, :SX_UP]
  me.shock_mass = df_sii_life_general[1, :SX_M_OTH]
  me.shock_mass_pension = df_sii_life_general[1, :SX_M_PENS]


  # ,SX_DOWN_ABS,SX_UP,SX_UP_ABS,SX_M_PENS,SX_M_OTH,]

  return  me
end


## Interface -------------------------------------------------------------------

function shock!(me::SIILifeSX,
                buckets::Buckets,
                other::Other,
                cap_mkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Any)

  me.balance =me.balance[me.balance[:SCEN] .== :be, :]
  for sm in me.sub_modules
    add!(me, sm, cap_mkt_be, invest_dfs, buckets, other, dyn,
         (sii_sx, bkts) -> sxshock!(bkts, sii_sx, sm) )
  end
  return me
end


## Private ---------------------------------------------------------------------

function sxshock!(me::Buckets, sx::SIILifeSX, sm::Symbol)
  for bkt in me.all
    sxshock!(bkt, sx, sxshockfunction(sx, sm), sm)
  end
end

function sxshockfunction(sx::SIILifeSX, sm::Symbol)
    if sm == :SX_DOWN
    shockfunc(sxprob) =
      max( (1 + sx.shock_down) * sxprob, sxprob .- sx.shock_down_abs)
  elseif sm == :SX_UP
    shockfunc(sxprob) =  min( (1 + sx.shock_up) * sxprob, 1)
  else ## sm in [:mass, :mass_pension]
    shockfunc(sxprob) = [0, sxprob[2:end]]
  end
  return shockfunc
end

function sxshock!(bkt::Bucket, sx::SIILifeSX, shockfunc::Function, sm::Symbol)
  if bkt.select[sm]
    bkt.prob_be[:,SX] = shockfunc( bkt.prob_be[:,SX])
    if sm == :SX_MASS
      if bkt.select[:SX_PENSION]
        bkt.prob_be[1,SX] = sx.shock_mass_pension
      else
        bkt.prob_be[1,SX] = sx.shock_mass
      end
    end
    bkt.prob_be[:,QX] = min(1 .- bkt.prob_be[:,SX], bkt.prob_be[:,QX])
    bkt.prob_be[:,PX] =  1.0 .- bkt.prob_be[:,QX] - bkt.prob_be[:,SX]
  end
end


function scr(me::SIILifeSX)
  ind = float64([ sm in me.balance[:SCEN] ? 1 : 0  for sm in me.sub_modules ])

  scr_vec_net =
    float64([bof(me, sm) for sm in me.sub_modules ]) - bof(me, :be) .* ind
  scr_vec_gross =
    scr_vec_net + fdb(me, :be) .* ind -
    float64([fdb(me, sm) for sm in me.sub_modules])

  scr_net, scr_net_index = findmin(scr_vec_net)
  scr_gross = scr_vec_gross[scr_net_index]
  return min(0,scr_net), min(0,scr_gross)
end
