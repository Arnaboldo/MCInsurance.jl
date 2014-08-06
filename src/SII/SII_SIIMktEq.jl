# Constructors -----------------------------------------------------------------
function SIIMktEq()
  tf = TimeFrame()
  shock_type = :Invest
  sub_modules =  [:type_1, :type_2]
  balance = DataFrame()
  corr = zeros(Float64, 1,1)
  shocks = [eq => 0.0 for eq in sub_modules]
  return SIIMktEq(tf, shock_type, sub_modules, balance, corr, shocks)
end


function SIIMktEq(tf::TimeFrame,
                  bkts_be::Buckets,
                  asset_other::AssetOther,
                  liab_other::LiabOther,
                  capmkt_be::CapMkt,
                  dyn::Dynamic,
                  inv_dfs::Vector{DataFrame},
                  balance_be::DataFrame,
                  df_sii_mkt_general::DataFrame,
                  df_sii_mkt_eq_corr::DataFrame)
  me = SIIMktEq()
  me.tf = tf
  me.balance =  deepcopy(balance_be)
  me.corr = array(df_sii_mkt_eq_corr)
  me.shocks = [eq => df_sii_mkt_general[1,eq] for eq in me.sub_modules]
  shock!(me, bkts_be, asset_other, liab_other, capmkt_be, inv_dfs, dyn)
  return me
end

## Interface -------------------------------------------------------------------

function scr(me::SIIMktEq)
  ind = [ sm in me.balance[:SCEN] ? 1.0 : 0.0  for sm in me.sub_modules ]
  scr_vec_net =
    float64([bof(me, sm) for sm in me.sub_modules ]) -  bof(me, :be) .* ind
  scr_vec_gross =
    scr_vec_net + fdb(me, :be) .* ind -
    float64([fdb(me, sm) for sm in me.sub_modules ])

  scr_net = - sqrt(scr_vec_net' * me.corr * scr_vec_net)[1]
  scr_gross = - sqrt(scr_vec_gross' * me.corr * scr_vec_gross)[1]
  return scr_net, scr_gross
end

## Private ---------------------------------------------------------------------

function shock!(me::SIIMktEq,
                buckets::Buckets,
                asset_other::AssetOther,
                liab_other::LiabOther,
                capmkt_be::CapMkt,
                invest_dfs::Any,
                dyn::Dynamic)
  me.balance =me.balance[me.balance[:SCEN] .== :be, :]
  for sm in me.sub_modules
    add!(me, sm, capmkt_be, invest_dfs, buckets, asset_other, liab_other, dyn,
         (sii_eq, inv) -> mkteqshock!(inv, sii_eq, sm) )
  end
  return me
end


function mkteqshock!(me::Invest, mkt_eq::SIIMktEq, sm::Symbol)
  for igr in me.ig
    if igr.name == :stocks ## fixme: Needs to be generalized
      for i = 1:igr.n
        if igr.sii_risk[i] == sm
          igr.mv_init[i] *= (1 + mkt_eq.shocks[sm])
        end ## else: produce another be scenario which does not generate scr
      end
      igr.mv_total_init = sum(igr.mv_init)
    end
    me.mv_total_init = mvtotalinit(me.ig)
  end
end

