## Private ---------------------------------------------------------------------

## calculate balance sheet
function balance(me::SIIModule,
                 scen::Symbol,     # name of scenario
                 capmkt::CapMkt,
                 invest_dfs::Any,
                 buckets::Buckets,
                 oth::Other,
                 dyn::Dynamic,
                 shock!!::Any)

  fluct = Fluct(capmkt.tf, capmkt.n_mc, 1.0)
  cpm = deepcopy(capmkt)
  bkts = deepcopy(buckets)
  if (shock!! == nothing)
    inv = Invest([:sii_inv, cpm, invest_dfs]...)
  else
    if me.shock_type == :CapMkt   shock!!(me, cpm) end
    inv = Invest([:sii_inv, cpm, invest_dfs]...)
    if me.shock_type == :Invest   shock!!(me, inv) end
    if me.shock_type == :Buckets  shock!!(me, bkts) end
  end
  cfl = CFlow(bkts, inv, oth, fluct, dyn)
  discount = meancumdiscrf(inv.c, inv.c.yield_rf_init, bkts.n_c)
  bonus_eoc =  dot(discount[1:capmkt.tf.n_c], dfcf(cfl,1)[:BONUS])

  return hcat(dfv0(cfl, SII_DIGITS),
              DataFrame(BONUS_EOC = bonus_eoc, SCEN = scen))
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
          balance(me,  scen, capmkt, invest_dfs,  buckets, oth, dyn, shock!!))
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

