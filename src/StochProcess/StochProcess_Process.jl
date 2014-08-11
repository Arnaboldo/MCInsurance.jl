## Interface  ------------------------------------------------------------------
isstoch(me::Process) = true

## Private ---------------------------------------------------------------------
function infoskeleton(proc::Process)
  init = (typeof(proc.init) == Float64 ? [proc.init] : proc.init)
  StochProcessInfo(symbol(string(typeof(proc).name)),
                   proc.name,
                   deepcopy(proc.cpnt),
                   deepcopy(init),
                   Array(Float64, 0, 0),
                   false)
end
