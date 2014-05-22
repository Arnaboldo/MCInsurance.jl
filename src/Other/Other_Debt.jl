function pveoc(me::Debt, t::Int, discount::Vector{Float64})
    dur = me.t_final - t
    if dur == 0
        return 0.0
    else
        cf_remaining = ones(Float64, dur) * me.nominal * (exp(me.interest) - 1)
        cf_remaining[dur] += me.nominal
        return sum(cumprod(discount[2:(dur+1)]) .* cf_remaining)
    end
end

function paydebt(me::Debt, t::Int)
    payment = 0.0
    if t <= me.t_final && t >= me.t_init
        payment += me.nominal * me.interest
    end
    if t == me.t_final
        payment += me.nominal
    end
    return payment
end

  
