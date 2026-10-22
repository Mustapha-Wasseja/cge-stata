* Examples of [CGE] cge_dynamic. The SAMs are SYNTHETIC; the rates, shares
* and elasticities are illustrative, not estimates.
*>> dyn_setup
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_closure, factors(cap:specific)
*<<

*>> dyn_base
cge_dynamic, name(base) periods(0/4) capital(cap) depreciation(0.05) rental(0.15) ///
    growth(lab:0.025) population(0.025) govgrowth(0.03) foreigngrowth(0.02)      ///
    gdpgrowth(0.04)
*<<

*>> dyn_return
return list
*<<

*>> dyn_basereport
cge_report, run(base) tables(macro)
*<<

*>> dyn_scenario
program define tariff_from2
    args t
    if `t' == 2 cge_shock tm, value(0)
end
cge_dynamic, name(lib) periods(0/4) capital(cap) depreciation(0.05) rental(0.15) ///
    growth(lab:0.025) population(0.025) govgrowth(0.03) foreigngrowth(0.02)      ///
    baseline(base) shocks(tariff_from2)
*<<

*>> dyn_compare
cge_report, sims(base4 lib4) tables(macro welfare)
*<<

*>> dyn_deaths
cge_synthetic, clear health
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser act_hlt)                       ///
    commodities(com_agr com_man com_ser com_hlt) factors(lab cap)          ///
    households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir)   ///
    saltax(tax_sal) imptax(tax_imp) insurance(shi)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) healthcom(com_hlt) ///
    mortality(0.01) mortelas(-0.3)
cge_closure, factors(cap:specific)
local settings capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02) ///
    population(0.02) govgrowth(0.03) tfp(0.01) deathfactors(lab)           ///
    deathshare(0.3) workingage(0.55)
cge_dynamic, name(hbase) periods(0/4) `settings'
*<<

*>> dyn_health
cge_report, run(hbase) tables(factors health)
*<<
