* health_outcomes.do -- worked example: days lost to illness, the death rate,
* and population and labour in a dynamic run (docs/model_spec.md, Section 15)
*
* The synthetic SAM is constructed for testing and describes no country; the
* shares, rates and elasticities are illustrative, not estimates.

version 13.0
clear all

cge_synthetic, clear health
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)

* 1. Workers lose 5 per cent of their working time to illness, and 10 people in
*    1,000 die each period; both fall as health services per head rise
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) healthcom(com_hlt) ///
    sickdays(lab:0.05) sickelas(-0.4) mortality(0.01) mortelas(-0.3)

* 20 per cent more government health services, and an epidemic that doubles
* the time lost to illness
cge_shock qg, elements(com_hlt) scale(1.2)
cge_solve, name(health)
cge_shock, reset
cge_shock sick, elements(lab) scale(2)
cge_solve, name(epidemic)
cge_shock, reset
cge_report, sims(health epidemic) tables(macro health)

* 2. A baseline in which 30 per cent of deaths are at working ages, where 55
*    per cent of the population lives, and a scenario with 20 per cent more
*    government health services from period 1
capture program drop more_health
program define more_health
    args t
    if `t' == 1 cge_shock qg, elements(com_hlt) scale(1.2)
end
cge_closure, factors(cap:specific)
local settings capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02) population(0.02) ///
    govgrowth(0.03) tfp(0.01) deathfactors(lab) deathshare(0.3) workingage(0.55)
cge_dynamic, name(base) periods(0/4) `settings'
cge_dynamic, name(more) periods(0/4) `settings' shocks(more_health)
cge_report, run(more) tables(health)
* Labour supply and days worked against the baseline
cge_dynresults, run(more) baseline(base) clear
list period variable value baseline dev_pct if inlist(variable, "QFS", "DW") & element1 == "lab", ///
    noobs sepby(variable)
