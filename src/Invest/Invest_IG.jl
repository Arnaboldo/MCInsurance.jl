function show(io::IO, me::IG)
    println(io,"Type      : $(string(typeof(me)))")
    println(io,"name      : $(me.name)")
    println(io,"asset     : $(transpose(me.asset))")
    println(io,"n         : $(me.n)")
end
