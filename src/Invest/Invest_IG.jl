function show(io::IO, me::IG)
    println(io,"Type      : $(string(typeof(me)))")
    println(io,"name      : $(me.name)")
    println(io,"labels    : $(transpose(me.labels))")
    println(io,"n         : $(me.n)")
    print(io,  "port_start:\n$(me.port_start)")
end
