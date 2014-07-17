# Constructors -----------------------------------------------------------------
function SIIDefType1()
  tf = TimeFrame()

  tlgd = Array(Float64,0)
  slgd = Array(Float64,0)
  u = Array(Float64,0,0)
  v = Array(Float64,0)
  u::Matrix{Float64}
  v::Vector{Float64}

  return SIIDefType1(tf, tlgd, slgd, u, v)
end


function SIIDefType1(tf::TimeFrame,
                     invest_be::Invest,
                     sp_cqs::Dict{UTF8String,Int64},
                     df_sii_def_type1_prob::DataFrame)
  me = SIIDefType1()
  me.tf = tf

  cqs = array(df_sii_def_type1_prob[:cqs])
  prob = array(df_sii_def_type1_prob[:prob])

  me.tlgd = zeros(Float64, length(cqs))
  me.slgd = zeros(Float64, length(cqs))
  me.u = Array(Float64, length(cqs), length(cqs))
  me.v = Array(Float64, length(cqs))

  me.v = 1.5 * prob .* (1 .- prob) ./ (2.5 .- prob)
  for i = 1:size(me.u,1), j = 1:1:size(me.u,2)
    me.u[i,j] =
      (1-prob[i]) * prob[i] * (1-prob[j]) * prob[j] /
        (1.25 * (prob[i] + prob[j]) - prob[i] * prob[j])
  end
  for ig in invest_be.ig
    for j = 1:nrow(ig.counter_party)
      if ig.counter_party[j, :cp] != "na"
        if ig.counter_party[j, :rating] in collect(keys(sp_cqs))
          lgd = ig.counter_party[j,:mv_init] * ig.counter_party[j,:lgd_rel]
          ind = indexin([sp_cqs[ig.counter_party[j, :rating]]], cqs)[1]
          me.tlgd[ind] += lgd
          me.slgd[ind] += lgd * lgd
        else
          warn("Rating not found: $(ig.counter_party[j, :rating])")
        end
      else
      end
    end
  end

  return me
end

## Interface -------------------------------------------------------------------

function scr(me::SIIDefType1)
  var = (me.tlgd' * me.u * me.tlgd)[1] + dot(me.v, me.slgd)
  sigma_norm = -sqrt(var)/sum(me.tlgd)[1]
  if sigma_norm <= 0.07
    scr_net = -3 * sqrt(var)
  elseif sigma_norm <= 0.20
    scr_net = -5 * sqrt(var)
  else
    scr_net = sum(me.tlgd)[1]
  end
  scr_gross = scr_net
  return scr_net, scr_gross
end

## Private ---------------------------------------------------------------------


