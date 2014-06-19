## Interface -------------------------------------------------------------------
function show(io::IO, me::IG)
    println(io,"Type      : $(string(typeof(me)))")
    println(io,"name      : $(me.name)")
    println(io,"asset     : $(transpose(me.asset))")
    println(io,"n         : $(me.n)")
end

# Private ---------------------------------------------------------------------

function mvtotalinit(ig::Array{IG,1})
  mv_total_init = 0.0
  for igr in ig
    mv_total_init += igr.mv_total_init
  end
  return mv_total_init
end

# cp_types = [NAtype,UTF8String,Float64, Float64]
function counterparty(inv_init::DataFrame)
  cp_types = [UTF8String,UTF8String,Float64, Float64]
  cp_cols = [:cp, :rating, :mv_init, :lgd_rel]

  counter_party = DataFrame(cp_types, cp_cols , 0)
  counter_party_row = DataFrame(cp_types, cp_cols , 1)
  for k = 1:nrow(inv_init)
    ind_cp = inv_init[k, :cp] == "na" ? 0 : indexin([inv_init[k, :cp]], counter_party[:cp])[1]
    if ind_cp == 0
      for col in cp_cols
        counter_party_row[1, col] =  inv_init[k, col]
      end
      append!(counter_party, counter_party_row)
    else
      counter_party[ind_cp, :mv_init] =
        (counter_party[ind_cp, :mv_init] * counter_party[ind_cp, :lgd_rel] +
           inv_init[k, :mv_init] * inv_init[k, :lgd_rel]
         ) / (counter_party[ind_cp, :mv_init] + inv_init[k, :mv_init])
      counter_party[ind_cp, :mv_init] +=  inv_init[k, :mv_init]
      if counter_party[ind_cp, :rating] !=  inv_init[k, :rating]
        warn("counterparty $(inv_init[k, :cp]): inconsistent rating")
      end
    end
  end
  return counter_party
end
