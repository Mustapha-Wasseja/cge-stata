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

*>> dyn_fs_setup
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_closure, savinv(investment)
cge_variable RK = W(cap) / CPI
cge_variable Q, value(10)
cge_equation qeq: Q = (lead(RK) + 0.95 * lead(Q)) / 1.05
cge_variable IRULE = IADJ / (Q / base(Q))^2
cge_closure, swap(IRULE IADJ)
*<<

*>> dyn_fs_run
program define tariff_from4
    args t
    if `t' == 4 cge_shock tm, value(0)
end
local settings capital(cap) depreciation(0.05) rental(0.10) growth(lab:0.02) foresight
quietly cge_dynamic, name(fsbase) periods(0/10) `settings'
cge_dynamic, name(fscut) periods(0/10) `settings' shocks(tariff_from4)
*<<

*>> dyn_fs_compare
cge_dynresults, run(fscut) baseline(fsbase) clear
format value baseline %9.4f
format dev_pct %9.3f
list period value baseline dev_pct if variable == "IADJ", noobs sep(0)
*<<
