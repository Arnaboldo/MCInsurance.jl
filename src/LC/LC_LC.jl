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
                  l_type::String)
    load = zeros(Float64, 4)
    load[L_INIT] = products[lc.all[i, :prod_id],symbol(l_type * "_C_INIT")]
    load[L_ABS]  = products[lc.all[i, :prod_id],symbol(l_type * "_C_ABS")]
    load[L_IS]   = products[lc.all[i, :prod_id],symbol(l_type * "_C_IS")]
    load[L_PREM] = products[lc.all[i, :prod_id],symbol(l_type * "_C_PREM")]
    return load
end

function profile( lc::LC,
                 i::Int,
                 products::DataFrame )
    # prof: QX SX PX PREM
    prof = zeros( Float64, (lc.all[i, :dur], N_BEN_PREM) )

    d = ["QX"=>QX, "SX"=>SX, "PX"=>PX, "PREM"=>PREM]
    for WX in keys(d)
        if ((lc.all[i, symbol("c_start_"*WX)] > 0) &
            (lc.all[i, symbol("c_end_"*WX) ] > 0))
            prof[lc.all[i,symbol("c_start_"*WX)]:lc.all[i,symbol("c_end_"*WX)],
                 d[WX]] =
                     linspace(products[lc.all[i,:prod_id],
                                       symbol("prof_start_"*WX)],
                              products[lc.all[i,:prod_id],
                                       symbol("prof_end_"*WX)],
                              lc.all[i,symbol("c_end_"*WX)] -
                              lc.all[i,symbol("c_start_"*WX)] + 1)
        end
    end
    return prof
end


## conditional cashflow
function condcf(lc::LC,
                i::Int,
                products::DataFrame,
                costs::Vector{Float64})
    cf = ones(Float64,
              lc.all[i,:dur], length(costs)+N_BEN_PREM )

    prof = profile(lc,i, products )

    cf[:,QX] = -prof[:,QX] * lc.all[i, :is]
    cf[:,SX] = -prof[:,SX] .* [1:lc.all[i, :dur]] * lc.all[i, :prem]
    cf[:,PX] = -prof[:,PX] * lc.all[i, :is]
    cf[:,PREM] = prof[:,PREM] * lc.all[i, :prem]
    cf[:,C_INIT] = -[costs[L_INIT],
                     zeros(Float64, lc.all[i,:dur]-1)]
    cf[:,C_ABS] =  -costs[L_ABS] * cf[:,C_ABS]
    cf[:,C_IS] = -costs[L_IS] * lc.all[i, :is] * cf[:,C_IS]  
    cf[:,C_PREM] = -costs[L_PREM] * prof[:,PREM] * lc.all[i, :prem]

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

    prof = profile(lc, i, products ) 
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

    num = load[L_INIT] + sum( lx_bop .* v .*
                             ( load[L_ABS] .+
                              lc.all[i, :is] * (load[L_IS] .+
                                                prob[:,PX] .* prof[:,PX] +
                                                prob[:,QX] .* prof[:,QX]) ) )
    denom =  sum(lx_bop .*
                 (prof[:,PREM] .* (v_bop - v * load[L_PREM]) -
                  v .* prob[:,SX] .* cumsum(prof[:,PREM] .* prof[:,SX]) ) )
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
    lc.age_min =  int64(minimum(qx_df[:,:age_period])-1)
    lc.age_max = int64(maximum(qx_df[:, :age_period])-1)
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
                                  loadings(lc,i,products, "cost") +
                                  loadings(lc,i,products, "profit"),
                                  qx_df, tech_interest)
    end
    return lc
end

