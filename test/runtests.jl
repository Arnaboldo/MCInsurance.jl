tests = ["load_data",  
         "dynamic_behavior",  
         "setup_objects",  
         "TimeFrame",
         "StochProcess",
         "Invest",
         "LC",
         "Bucket",
         "Fluct",
         "CFlow"]
for t in tests
    println("* running $(t).jl ...")
    include("$(t).jl")
end
    println("* end of test run")
