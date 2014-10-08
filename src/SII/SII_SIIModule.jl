## Private ---------------------------------------------------------------------

## calculate shocked balance sheet

function balance_det_init(me::SIIModule,
                          scen::Symbol,     # name of scenario
                          capmkt::CapMkt,
                          invest_dfs::Any,
                          buckets::Buckets,
                          asset_other::AssetOther,
                          liab_other::LiabOther,
                          dyn::Dynamic,
                          shock!!::Any)

  fluct = Fluct(capmkt.tf, capmkt.n_mc, 1.0)
  cpm = deepcopy(capmkt)
  bkts = deepcopy(buckets)
  asset_oth = deepcopy(asset_other)
  liab_oth = deepcopy(liab_other)
  if (shock!! == nothing)
    inv = Invest([:sii_inv, cpm, invest_dfs]..., bkts.n_c)
    fixed = Fixed(inv, bkts)
    cfl = CFlow(bkts, inv, asset_oth, liab_oth, fixed, fluct, dyn)
    bal = balance_det_init(cfl,
                           inv.ig[inv.id[:cash]].cost.rel_c,
                           scen)
  else
    if me.shock_type == :CapMkt   shock!!(me, cpm) end
    inv = Invest([:sii_inv, cpm, invest_dfs]..., bkts.n_c)
    fixed = Fixed(inv, bkts)
    if me.shock_type == :Invest   shock!!(me, inv) end
    if me.shock_type == :Buckets  shock!!(me, bkts) end
    if me.shock_type == :InvestBuckets  shock!!(me, inv, bkts) end
    cfl = CFlow(bkts, inv, asset_oth, liab_oth, fixed, fluct, dyn)
    bal = balance_det_init(cfl,
                           inv.ig[inv.id[:cash]].cost.rel_c,
                           scen)
  end


  return bal
end

## add scenario
function add!(me::SIIModule,
              scen::Symbol,     # name of scenario / submodule
              capmkt::CapMkt,
              invest_dfs::Any,
              buckets::Buckets,
              asset_oth::AssetOther,
              liab_oth::LiabOther,
              dyn::Dynamic,
              shock!!::Any)
  append!(me.balance,
          balance_det_init(me,  scen, capmkt, invest_dfs,  buckets,
                           asset_oth, liab_oth, dyn, shock!!))
end

## basic own funds
bof(me::SIIModule, scen::Symbol) =
  me.balance[me.balance[:SCEN] .== scen, :INVEST_EOC][1,1] +
  me.balance[me.balance[:SCEN] .== scen, :TPG_EOC][1,1] +
  me.balance[me.balance[:SCEN] .== scen, :L_OTHER_EOC][1,1] +
  me.balance[me.balance[:SCEN] .== scen, :BONUS_EOC][1,1]

## future discretionary benefits
fdb(me::SIIModule, scen::Symbol) =
  me.balance[me.balance[:SCEN] .== scen, :BONUS_EOC][1,1]

