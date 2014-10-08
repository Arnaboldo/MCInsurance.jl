## Constructors ----------------------------------------------------------------

function LC(lc_all::DataFrame)
  n = size(lc_all,1)
  age_min = 0
  age_max = 0
  return LC(n, age_min, age_max, lc_all[lc_all[:process], :])
end

function LC(df_lc::DataFrame,
            df_ph::DataFrame,
            df_products::DataFrame,
            df_load::DataFrame,
            df_qx::DataFrame,
            df_tech_interest::DataFrame,
            tf::TimeFrame)
  lc = LC(df_lc)
  lc!(lc, df_ph, df_products, df_load, tf, df_qx, df_tech_interest)
  return lc
end

## Interface -------------------------------------------------------------------


## get parameters for  loadings
function loadings(df_load::DataFrame, load_name::Symbol)
  load_col = [:init_abs, :init_is, :abs, :is, :prem, :infl]
  load = Array(Float64, length(load_col))
  for j = 1:length(load_col)
    load[j] =  df_load[df_load[:name] .== load_name, load_col[j]][1,1]
  end
  return load
end


function profile(lc::LC,
                 i::Int,
                 products::DataFrame ,
                 costs::Vector{Float64},
                 delta_t_infl::Int = 0)  ## adj reference time for inflation

  prof = zeros( Float64, lc.all[i, :dur], N_PROF )
  cum_infl = exp(([1:lc.all[i,:dur]] .- delta_t_infl) * costs[L_INFL] )
  init_infl =  exp( -delta_t_infl * costs[L_INFL])

  ind = [[:c_start_QX   :c_end_QX   :prof_start_QX   :prof_end_QX],
         [:c_start_SX   :c_end_SX   :prof_start_SX   :prof_end_SX],
         [:c_start_PX   :c_end_PX   :prof_start_PX   :prof_end_PX],
         [:c_start_PREM :c_end_PREM :prof_start_PREM :prof_end_PREM]]

  for WX in (QX, SX, PX, PREM)
    if (lc.all[i, ind[WX, 1]] > 0) & (lc.all[i, ind[WX, 2]] > 0)
      prof[ lc.all[i, ind[WX, 1]]:lc.all[i, ind[WX, 2]], WX] =
        linspace(products[lc.all[i, :prod_id], ind[WX, 3]],
                 products[lc.all[i, :prod_id], ind[WX, 4]],
                 lc.all[i,ind[WX, 2]] - lc.all[i,ind[WX, 1]] + 1)
    end
  end
  prof[1, C_INIT_ABS]  = costs[L_INIT_ABS] * init_infl
  prof[1, C_INIT_IS] = costs[L_INIT_IS] * init_infl
  prof[:, C_ABS] = costs[L_ABS] * cum_infl
  prof[:, C_IS] = costs[L_IS] * cum_infl
  prof[:, C_PREM] = costs[L_PREM] * prof[:,PREM] .* cum_infl

  return prof
end


## conditional cashflow
function condcf(is::Float64,
                prem::Float64,
                products::DataFrame,
                prof::Array{Float64,2}
                )
  dur = size(prof,1)
  cf = Array(Float64, dur, N_COND)

  cf[:,QX]    = - prof[:,QX] * is
  cf[:,SX]    = - prof[:,SX] .* [1:dur] * prem
  cf[:,PX]    = - prof[:,PX] * is
  cf[:,PREM]  =   prof[:,PREM] * prem
  cf[:,C_BOC] = - prof[:,C_INIT_ABS] - prof[:, C_INIT_IS] * is
  cf[:,C_DIR_EOC] = - prof[:,C_ABS] - prof[:,C_IS] * is - prof[:,C_PREM] * prem
  return cf
end

## surrender probabilities: linearly increasing or decreasing
## may still need to be scaled, see probgeneral.
function probsxraw( lc::LC, i::Int, products::DataFrame)
  prob_sx = zeros( Float64,lc.all[i,:dur])
  if !((lc.all[i, :c_start_SX]==0) | (lc.all[i, :c_end_SX]==0))
    prob_sx[lc.all[i, :c_start_SX]:lc.all[i, :c_end_SX] ] =
      linspace(products[lc.all[i,:prod_id], :start_SX],
               products[lc.all[i,:prod_id], :end_SX],
               lc.all[i, :c_end_SX] - lc.all[i, :c_start_SX] + 1)
  end
  return prob_sx
end

function probgeneral(lc::LC,
                     i::Int,
                     df_prod::DataFrame,
                     df_qx::DataFrame,
                     qx_name::Symbol,
                     f_sx::Real
                     )
  age_range = (lc.all[i,:ph_age_start]+1) .+ [0: lc.all[i,:dur] - 1]
  prob    = zeros( Float64, length(age_range), 3)
  ## qx_df starts with age_period = 1, i.e. age = 0. Hence +1
  prob[:,QX] = df_qx[age_range, qx_name]
  prob[:,SX] = f_sx * probsxraw(lc, i, df_prod)
  prob[:,PX] = 1 .- prob[:,QX] - prob[:,SX]
  return prob
end

probie(lc::LC,
       i::Int,
       df_prod::DataFrame,
       df_qx::DataFrame,
       qx_name::Symbol) =
  probgeneral(lc, i, df_prod, df_qx, qx_name, lc.all[i, :f_sx_ie])

probprice(lc::LC,
          i::Int,
          products::DataFrame,
          qx_df::DataFrame) =
  probgeneral(lc, i, products, qx_df, lc.all[i, :qx_name], 1)


## price of an insurance contract
function price(is::Float64,
               products::DataFrame,
               prof::Array{Float64,2},
               prob::Array{Float64,2},
               tech_interest::Vector{Float64}
               )
  lx_boc = cumprod(prob[:,PX])
  unshift!(lx_boc,1)
  pop!(lx_boc)
  v = cumprod(exp(-tech_interest))
  v_boc = deepcopy(v)
  unshift!(v_boc,1)
  pop!(v_boc)

  num =
    prof[1, C_INIT_ABS] + prof[1, C_INIT_IS] * is +
    sum(lx_boc .* v .* (prof[:, C_ABS] + is * (prof[:,C_IS] +
                                                 prob[:,PX] .* prof[:,PX] +
                                                 prob[:,QX] .* prof[:,QX]
                                               ) ))
  denom =  sum(lx_boc .*
               (prof[:,PREM] .* (v_boc - v .* prof[:, C_PREM]) -
                  v .* prob[:,SX] .* prof[:,SX] .* cumsum(prof[:,PREM])
                ) )
  return num/denom
end

## Technical provisions
function tpgeoc (prob::Array{Float64,2},
                 discount::Vector{Float64},
                 cond_cf::Array{Float64,2} )
  discount_1c = discount ./ [1, discount[1:end-1]]
  dur = size(cond_cf,1)
  tpg = 0.0
  if dur > 0
    for t in (dur-1):-1:1
      tpg = tpgprev(tpg,
                    reshape(prob[t+1,:], size(prob,2)),
                    discount_1c[t+1],
                    reshape(cond_cf[t+1,:], size(cond_cf,2)) )
    end
  end
  return tpg
end

function tpgeoc (prob::Array{Float64,2},
                 discount_1c::Vector{Float64},
                 cond_cf::Array{Float64,2},
                 inv_cost_abs_gc_c::Vector{Float64})
  dur = size(cond_cf,1)
  tpg = 0.0
  fcp = 0.0
  if dur > 0
    for t in (dur-1):-1:1
      ## absolute invstment costs are already going concern
      tpg = tpgprev(tpg,
                    reshape(prob[t+1,:], size(prob,2)),
                    discount_1c[t+1],
                    reshape(cond_cf[t+1,:], size(cond_cf,2)))
       fcp = discount_1c[t+1] * (inv_cost_abs_gc_c[t+1] + fcp)
    end
  end
  return tpg + fcp
  #    return tpg + discount[2:end] ⋅ inv_cost_abs_gc_c[2:end] / discount[1]
end


function tpgeoc (prob::Array{Float64,2},
                 discount::Vector{Float64},
                 cond_cf::Array{Float64,2},
                 inv_cost_rel_c::Vector{Float64},
                 inv_cost_abs_gc_c::Vector{Float64})
  discount_1c = discount ./ [1, discount[1:end-1]]
  dur = size(cond_cf,1)
  tpg = 0.0
  fcp = 0.0
  if dur > 0
    for t in (dur-1):-1:1
      ## absolute invstment costs are already going concern
      tpg = tpgprev(tpg,
                    reshape(prob[t+1,:], size(prob,2)),
                    discount_1c[t+1],
                    reshape(cond_cf[t+1,:], size(cond_cf,2)),
                    inv_cost_rel_c[t+1])
      fcp = fcpprev(fcp,
                    discount_1c[t+1],
                    inv_cost_abs_gc_c[t+1],
                    inv_cost_rel_c[t+1])
    end
  end
  return tpg + fcp
  #    return tpg + discount[2:end] ⋅ inv_cost_abs_gc_c[2:end] / discount[1]
end


function tpgveceoc (prob::Array{Float64,2},
                    discount::Vector{Float64},
                    cond_cf::Array{Float64,2} )
  discount_1c = discount ./ [1, discount[1:end-1]]
  dur = size(cond_cf,1)
  tpg = zeros(Float64, dur)
  tpg[dur] = 0.0
  for t in (dur-1):-1:1
    tpg[t] = tpgprev(tpg[t+1],
                     reshape(prob[t+1,:], size(prob,2)),
                     discount_1c[t+1],
                     reshape(cond_cf[t+1,:], size(cond_cf,2)) )
  end
  return tpg
end

function tpgveceoc (prob::Array{Float64,2},
                    discount_1c::Vector{Float64},
                    cond_cf::Array{Float64,2},
                    inv_cost_abs_gc_c::Vector{Float64})
  dur = size(cond_cf,1)
  tpg = zeros(Float64, dur)
  fcp = zeros(Float64, dur)
  for t in (dur-1):-1:1
    tpg[t] = tpgprev(tpg[t+1],
                     reshape(prob[t+1,:], size(prob,2)),
                     discount_1c[t+1],
                     reshape(cond_cf[t+1,:], size(cond_cf,2)) )
    fcp[t] = discount_1c[t+1] * (inv_cost_abs_gc_c[t+1] + fcp[t+1])
   end
  return tpg + fcp
end

function tpgveceoc (prob::Array{Float64,2},
                    discount::Vector{Float64},
                    cond_cf::Array{Float64,2},
                    inv_cost_rel_c::Vector{Float64},
                    inv_cost_abs_gc_c::Vector{Float64})
  discount_1c = discount ./ [1, discount[1:end-1]]
  dur = size(cond_cf,1)
  tpg = zeros(Float64, dur)
  fcp = zeros(Float64, dur)
  for t in (dur-1):-1:1
    tpg[t] = tpgprev(tpg[t+1],
                     reshape(prob[t+1,:], size(prob,2)),
                     discount_1c[t+1],
                     reshape(cond_cf[t+1,:], size(cond_cf,2)) ,
                     inv_cost_rel_c[t+1])
    fcp[t] = fcpprev(fcp[t+1],
                     discount_1c[t+1],
                     inv_cost_abs_gc_c[t+1],
                     inv_cost_rel_c[t+1])
  end
  return tpg + fcp
end

function tpgprev(tpg::Float64,
                 prob::Vector{Float64},
                 discount_1c::Float64,
                 cond_cf::Vector{Float64})
  cond_cf[PREM] + cond_cf[C_BOC] +
    discount_1c * (cond_cf[C_DIR_EOC] +  prob[QX] * cond_cf[QX]
                   + prob[SX] * cond_cf[SX] + prob[PX] * (cond_cf[PX] + tpg))
end

function tpgprev(tpg::Float64,
                 prob::Vector{Float64},
                 discount_1c::Float64,
                 cond_cf::Vector{Float64},
                 inv_cost_rel::Float64)
  (cond_cf[PREM] + cond_cf[C_BOC] +
     discount_1c * (cond_cf[C_DIR_EOC] + prob[QX] * cond_cf[QX] +
                      prob[SX] * cond_cf[SX] + prob[PX] * (cond_cf[PX] + tpg))) /
    (1 + discount_1c * inv_cost_rel)
end

function fcpprev(fcp::Float64,
                 discount_1c::Float64,
                 fc::Float64,
                 inv_cost_rel::Float64)
  return discount_1c * (fc + fcp) /  (1 + discount_1c * inv_cost_rel)
end



## combine all pertinent information into lc.all
function lc!(lc::LC,
             df_ph::DataFrame,
             df_prod::DataFrame,
             df_load::DataFrame,
             tf::TimeFrame,   ## not used
             qx_df::DataFrame,
             tech_interest::DataFrame)

  prod_id_dict = Dict(df_prod[:name],[1:size(df_prod,1)])
  lc.age_min =  1
  lc.age_max =  nrow(qx_df) - 1

  lc.all = join(df_ph, lc.all, on = :ph_id, kind = :inner)
  lc.n = size(lc.all,1)

  lc.all[:ph_age_start] =  lc.all[:y_start] - lc.all[:ph_y_birth]
  # convert points in time to integer values
  for ind in (:c_start_QX, :c_end_QX, :c_start_SX, :c_end_SX,
              :c_start_PX, :c_end_PX, :c_start_PREM, :c_end_PREM)
    for i = 1:lc.n
      if isna(lc.all[i, ind])
        lc.all[i, ind] = 0
      end
    end
    lc.all[ind] =
      int(min(lc.all[ind], lc.age_max+1 .- lc.all[:ph_age_start]))
  end
  ## broken in Julia 0.3.0 preview:
  #lc.all[:dur] = max( lc.all["c_end_QX"], lc.all["c_end_SX"],
  #                     lc.all["c_end_PX"], lc.all["c_end_PREM"] )
  ## work-around:
  lc.all[:dur] = zeros(Int, lc.n)
  for i = 1:lc.n
    lc.all[i,:dur] =
      max(lc.all[i, :c_end_QX], lc.all[i, :c_end_SX],
          lc.all[i, :c_end_PX], lc.all[i, :c_end_PREM] )
  end

  lc.all[:prod_id] = [prod_id_dict[lc.all[i, :prod_name]] for i = 1:lc.n]
  lc.all[:qx_name] =
    [symbol( string(lc.all[i, :ph_gender]) * "_" *
            string(df_prod[lc.all[i, :prod_id], :qx_name]))
     for i = 1:lc.n]
  lc.all[:risk] = [1:lc.n] #ones(Int,lc.n)  ## currently a dummy variable

  lc.all[:prem] = zeros(Float64, lc.n)
  for i = 1:lc.n
    prof = profile(lc,
                   i,
                   df_prod,
                   loadings(df_load,
                            df_prod[lc.all[i, :prod_id],:cost_price_name]))
    prob = probprice(lc, i, df_prod,  qx_df)
    interest = convert(Array,
                       tech_interest[1:lc.all[i,:dur],
                                     df_prod[lc.all[i,:prod_id],
                                             :interest_name] ] )
    lc.all[i, :prem] =  price(lc.all[i,:is], df_prod, prof, prob, interest)
  end
  return lc
end


