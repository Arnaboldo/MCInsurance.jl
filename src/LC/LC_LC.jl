## Constructors ----------------------------------------------------------------

function LC(lc_all::DataFrame)
    n = size(lc_all,1)
    age_min = 0
    age_max = 0
    return LC(n, age_min, age_max, lc_all)
end

function LC(df_lc::DataFrame,
            df_products::DataFrame,
            df_ph::DataFrame,
            df_qx::DataFrame,
            df_tech_interest::DataFrame,
            tf::TimeFrame)              
    lc = LC(df_lc)
    lc!(lc, df_products, df_ph, tf, df_qx, df_tech_interest)
    return lc
end

## Interface functions for LC types --------------------------------------------


## get parameters for  loadings type: "cost"  or "profit"
function loadings(lc::LC,
                  i::Int,
                  products::DataFrame,
                  ind::Vector{Symbol})
    load = Array(Float64, 6)
    for L in (L_INIT_ABS, L_INIT_IS, L_ABS, L_IS, L_PREM, L_INFL)
        load[L] =  products[lc.all[i, :prod_id], ind[L]]
    end
    return load
end

function costloadings(lc::LC, i::Int, products::DataFrame)
    return loadings(lc, i, products,
                    [:cost_INIT_ABS, :cost_INIT_IS,
                     :cost_ABS, :cost_IS, :cost_PREM,
                     :cost_INFL])
end    

function profitloadings(lc::LC, i::Int, products::DataFrame)
    return loadings(lc, i, products,
                    [:profit_INIT_ABS, :profit_INIT_IS,
                     :profit_ABS, :profit_IS, :profit_PREM,
                     :profit_INFL])
end    


function profile(lc::LC,
                 i::Int,
                 products::DataFrame ,
                 costs::Vector{Float64})
    # prof: QX SX PX PREM
    prof = zeros( Float64, lc.all[i, :dur], N_PROF )
    
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

    prof[1, C_INIT_ABS]  = costs[L_INIT_ABS]
    prof[1, C_INIT_IS] = costs[L_INIT_IS]
    prof[:, C_ABS] = costs[L_ABS] * exp([1:(lc.all[i,:dur])] * costs[L_INFL])
    prof[:, C_IS] = costs[L_IS] * exp([1:(lc.all[i,:dur])] * costs[L_INFL])
    prof[:, C_PREM] =
        costs[L_PREM] * prof[:,PREM] .* exp([1:(lc.all[i,:dur])] * costs[L_INFL])

    return prof
end


## conditional cashflow
function condcf(is::Float64,
                prem::Float64,
                products::DataFrame,
                prof::Array{Float64,2}
                )
 #   prof = profile(lc, i, products, costs)
    dur = size(prof,1)
    cf = Array(Float64, dur, N_COND)

    cf[:,QX]     = - prof[:,QX] * is
    cf[:,SX]     = - prof[:,SX] .* [1:dur] * prem
    cf[:,PX]     = - prof[:,PX] * is
    cf[:,PREM]   =   prof[:,PREM] * prem
    cf[:,C_INIT] = - prof[:,C_INIT_ABS] - prof[:, C_INIT_IS] * is
    cf[:,C_ABS]  = - prof[:,C_ABS] 
    cf[:,C_IS]   = - prof[:,C_IS] * is
    cf[:,C_PREM] = - prof[:,C_PREM] * prem

    return cf
end

## surrender probabilities: linearly increasing or decreasing
function sx( lc::LC, i::Int, products::DataFrame )
    prob_sx = zeros( Float64,
                    lc.all[i,:ph_age_end]-lc.all[i,:ph_age_start]+1)

    if !((lc.all[i, :c_start_SX]==0) | (lc.all[i, :c_end_SX]==0))
        prob_sx[lc.all[i, :c_start_SX]:lc.all[i, :c_end_SX] ] =
            linspace(products[lc.all[i,:prod_id], :start_SX],
                     products[lc.all[i,:prod_id], :end_SX],
                     lc.all[i, :c_end_SX] - lc.all[i, :c_start_SX] + 1)
    end
    return prob_sx
end


## price of an insurance contract
function price(lc::LC,
               i::Int,
               products::DataFrame,
               load::Vector{Float64},    # cost loadings
               qx_df::DataFrame,
               tech_interest::DataFrame
               )

    age_range = [lc.all[i,:ph_age_start]:lc.all[i,:ph_age_end]]
    prob    = zeros( Float64, (length(age_range), 3) )
    ## qx_df starts with age_period = 1, i.e. age = 0. Hence +1
    prob[:,QX] = qx_df[age_range .+ 1, lc.all[i, :qx_name] ]
    prob[:,SX] = sx(lc, i, products)
    prob[:,PX] = 1 .- prob[:,QX] - prob[:,SX]

    prof = profile(lc, i, products, load ) 
    lx_bop = cumprod(prob[:,PX])
    unshift!(lx_bop,1)
    pop!(lx_bop)
    v = cumprod(exp(-convert(Array,
                             tech_interest[1:lc.all[i,:dur],
                                           products[lc.all[i,:prod_id],
                                                    :interest_name] ] ) ) )
    v_bop = deepcopy(v)
    unshift!(v_bop,1)
    pop!(v_bop)

    num =
        prof[1, C_INIT_ABS] + prof[1, C_INIT_IS] * lc.all[i, :is] +
        sum( lx_bop .* v .* (prof[:, C_ABS] +
                             lc.all[i, :is] * (prof[:,C_IS] +
                                               prob[:,PX] .* prof[:,PX] +
                                               prob[:,QX] .* prof[:,QX]) ) )
    denom =  sum(lx_bop .*
                 (prof[:,PREM] .* (v_bop - v .* prof[:, C_PREM]) -
                  v .* prob[:,SX] .* prof[:,SX] .* cumsum(prof[:,PREM]) ) )
    return num/denom
end

   

## Technical provisions

function tpeop (prob::Array{Float64,2},
                tech_discount::Vector{Float64},
                cond_cf::Array{Float64,2} )
    dur = size(cond_cf,1)
    tp = 0.0
    if dur > 0
        for t in (dur-1):-1:1
            tp = tpprev(tp,
                        reshape(prob[t+1,:], size(prob,2)),
                        tech_discount[t+1],
                        reshape(cond_cf[t+1,:], size(cond_cf,2)) )
        end
    end
    return tp
end


function tpprev(tp::Float64,
                prob::Vector{Float64},
                tech_discount::Float64,
                cond_cf::Vector{Float64})
    cond_cf[PREM] + cond_cf[C_INIT] +
    (cond_cf[C_ABS] + cond_cf[C_IS] + cond_cf[C_PREM] +
     prob[QX]*cond_cf[QX] + prob[SX]*cond_cf[SX] + prob[PX]*(cond_cf[PX] + tp)) *
    tech_discount
end



## combine all pertinent information into lc.all
function lc!(lc::LC,
             products::DataFrame,
             ph::DataFrame,
             tf::TimeFrame,   ## not used
             qx_df::DataFrame,
             tech_interest::DataFrame)
    lc.age_min =  1 
    lc.age_max =  nrow(qx_df) - 1 
    prod_id_dict = Dict(products[:name],[1:size(products,1)])

    lc.all = join(ph, lc.all, on = :ph_id, kind = :inner)
    lc.n = size(lc.all,1)    
    lc.all[:prod_id] = [prod_id_dict[lc.all[i, :prod_name]] for i = 1:lc.n]
    lc.all[:ph_age_start] =  lc.all[:y_start] - lc.all[:ph_y_birth]
    lc.all[:qx_name] =
        [ symbol( lc.all[i, :ph_gender] * "_" *
                products[prod_id_dict[lc.all[i, :prod_name]], :qx_name])
            for i = 1:lc.n]
    for ind in [:c_start_QX, :c_end_QX, :c_start_SX, :c_end_SX,
                :c_start_PX, :c_end_PX, :c_start_PREM, :c_end_PREM]
        ## We replace NA by 0 in order to be able to work with 
        ## int64 arrays rather than with arrays of NAtype
        ## lc.all[ind] = int64( min( array(lc.all[ind],0),
        ##                          lc.age_max+1-lc.all[:ph_age_start]) )

        ## broken in Julia 0.3.0 preview:                            
        #   lc.all[ind] = int64( min(lc.all[ind],
        #                       lc.age_max+1-lc.all[:ph_age_start]) )
        ## work-around:
        for i = 1:lc.n
            lc.all[ind] = int64( min(lc.all[i, ind],
                                 lc.age_max+1-lc.all[i, :ph_age_start]) )
        end
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
                
    lc.all[:ph_age_end] = lc.all[:ph_age_start]+lc.all[:dur] .- 1
    lc.all[:risk] = ones(Int,lc.n)  ## currently a dummy variable

    lc.all[:prem] = zeros(Float64, lc.n)
    for i = 1:lc.n
        lc.all[i, :prem] =  price(lc, i, products,
                                  costloadings(lc,i,products) +
                                  profitloadings(lc,i,products),
                                  qx_df, tech_interest)
    end
    return lc
end

