## Private ---------------------------------------------------------------------

## calculate shocked balance sheet

function balance_det_init(me::SIIModule,
                 scen::Symbol,     # name of scenario
                 capmkt::CapMkt,
                 invest_dfs::Any,
                 buckets::Buckets,
                 other::Other,
                 dyn::Dynamic,
                 shock!!::Any)

  fluct = Fluct(capmkt.tf, capmkt.n_mc, 1.0)
  cpm = deepcopy(capmkt)
  bkts = deepcopy(buckets)
  oth = deepcopy(other)
  if (shock!! == nothing)
    inv = Invest([:sii_inv, cpm, invest_dfs]..., bkts.n_c)
  else
    if me.shock_type == :CapMkt   shock!!(me, cpm) end
    inv = Invest([:sii_inv, cpm, invest_dfs]..., bkts.n_c
                 )
    if me.shock_type == :Invest   shock!!(me, inv) end
    if me.shock_type == :Buckets  shock!!(me, bkts) end
    if me.shock_type == :InvestBuckets  shock!!(me, inv, bkts) end
  end

  cfl = CFlow(bkts, inv, oth, fluct, dyn)

  return balance_det_init(cfl, scen)
end

## add scenario
function add!(me::SIIModule,
              scen::Symbol,     # name of scenario / submodule
              capmkt::CapMkt,
              invest_dfs::Any,
              buckets::Buckets,
              oth::Other,
              dyn::Dynamic,
              shock!!::Any)
  append!(me.balance,
          balance_det_init(me,  scen, capmkt, invest_dfs,  buckets, oth, dyn, shock!!))
end

## basic own funds
bof(me::SIIModule, scen::Symbol) =
  me.balance[me.balance[:SCEN] .== scen, :ASSET_EOC][1,1] +
            me.balance[me.balance[:SCEN] .== scen, :TPG_EOC][1,1] +
              me.balance[me.balance[:SCEN] .== scen, :OTHER_EOC][1,1] +
                me.balance[me.balance[:SCEN] .== scen, :BONUS_EOC][1,1]

## future discretionary benefits
fdb(me::SIIModule, scen::Symbol) =
  me.balance[me.balance[:SCEN] .== scen, :BONUS_EOC][1,1]

