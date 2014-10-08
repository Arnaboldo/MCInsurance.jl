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
  bkt_select = Dict{Symbol, Vector{Bool}}()
  return SIILifeSX(tf, shock_type, sub_modules, balance,
                   shock_down, shock_down_abs, shock_up,
                   shock_mass, shock_mass_pension,
                   bkt_select)
end

function SIILifeSX(tf::TimeFrame,
                   bkts_be::Buckets, ## from SII
                   asset_other::AssetOther,
                   liab_other::LiabOther,
                   capmkt_be::CapMkt,
                   dyn::Dynamic,
                   inv_dfs::Vector{DataFrame},
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
  ## select bukckets for each shock:
  select!(me, bkts_be, liab_other, capmkt_be, inv_dfs, dyn)
  shock!(me, bkts_be, asset_other, liab_other, capmkt_be, inv_dfs, dyn)
  return  me
end


## Interface -------------------------------------------------------------------

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

## Private ---------------------------------------------------------------------

function shock!(me::SIILifeSX,
                buckets::Buckets,
                asset_other::AssetOther,
                liab_other::LiabOther,
                capmkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Any)

  me.balance =me.balance[me.balance[:SCEN] .== :be, :]
  for sm in me.sub_modules
    add!(me, sm, capmkt_be, invest_dfs, buckets, asset_other, liab_other, dyn,
         (sii_sx, bkts) -> sxshock!(bkts, sii_sx, sm) )
  end
  return me
end

function sxshock!(me::Buckets, sx::SIILifeSX, sm::Symbol)
  for (b,bkt) in enumerate(me.all)
    if sx.bkt_select[sm][b]
      sxshock!(bkt, b, sx, sxshockfunction(sx, sm), sm)
    end
  end
end

function sxshockfunction(sx::SIILifeSX, sm::Symbol)
  if sm == :SX_DOWN
    shockfunc(sxprob) =
      max( (1 + sx.shock_down) * sxprob, sxprob .+ sx.shock_down_abs)
  elseif sm == :SX_UP
    shockfunc(sxprob) =  min( (1 + sx.shock_up) * sxprob, 1)
  else ## sm in [:mass, :mass_pension]
    shockfunc(sxprob) = [0, sxprob[2:end]]
  end
  return shockfunc
end

function sxshock!(bkt::Bucket, b::Int,
                  sx::SIILifeSX, shockfunc::Function, sm::Symbol)
  bkt.prob_ie[:,SX] = shockfunc( bkt.prob_ie[:,SX])
  if sm == :SX_MASS
    if sx.bkt_select[:SX_PENSION][b]
      bkt.prob_ie[1,SX] = sx.shock_mass_pension
    else
      bkt.prob_ie[1,SX] = sx.shock_mass
    end
  end
  bkt.prob_ie[:,QX] = min(1 .- bkt.prob_ie[:,SX], bkt.prob_ie[:,QX])
  bkt.prob_ie[:,PX] =  1.0 .- bkt.prob_ie[:,QX] - bkt.prob_ie[:,SX]
end

## identify those buckets that are subject to mortality risk (fast version)
function select!(me::SIILifeSX,
                 bkts::Buckets,
                 liab_oth_be::LiabOther,
                 capmkt_be::CapMkt,
                 invest_dfs::Any,
                 dyn::Dynamic)
  ## This function does not properly take into account second order
  ## effects due to the effect of boni.  Nevertheless for most portfolios the
  ## result should be the same as the result from an exact calculation.
  ## speed: ~ buckets.n

  invest = Invest([:sii_inv, capmkt_be, invest_dfs]..., bkts.n_c)
  fixed = Fixed(invest, bkts)
  discount = meandiscrf(invest.c, invest.c.yield_rf_init, 1, bkts.n_c)

  for sm in me.sub_modules
    merge!(me.bkt_select, [sm => fill(false, bkts.n)])
  end
  merge!(me.bkt_select, [:SX_PENSION => fill(false, bkts.n)])

  for (b, bkt) in enumerate(bkts.all)
    tpg_be =  tpgeoc(vcat(zeros(Float64, 1, 3), bkt.prob_ie),
                     vcat(1.0, discount),
                     vcat(zeros(Float64, 1, N_COND), bkt.cond),
                     vcat(0, invest.ig[invest.id[:cash]].cost.rel_c),
                     vcat(0, bkt.portion_c .* fixed.cost_abs_gc_c))
    ## fixme: currently :SX_PENSION contracts are not implemented.
    for sm in me.sub_modules
      bkt_test = deepcopy(bkt)
      sxshock!(bkt_test, b, me, sxshockfunction(me, sm), sm)
      tpg_shock =  tpgeoc(vcat(zeros(Float64, 1, 3), bkt_test.prob_ie),
                          vcat(1.0, discount),
                          vcat(zeros(Float64, 1, N_COND), bkt_test.cond),
                          vcat(0, invest.ig[invest.id[:cash]].cost.rel_c),
                          vcat(0, bkt.portion_c .* fixed.cost_abs_gc_c))
      me.bkt_select[sm][b] = (tpg_shock < tpg_be)
    end
  end
end
