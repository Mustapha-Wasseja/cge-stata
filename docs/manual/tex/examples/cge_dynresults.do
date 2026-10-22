* Examples of [CGE] cge_dynresults. The SAM is SYNTHETIC; the rates are
* illustrative, not estimates.
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_closure, factors(cap:specific)
local settings capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.025) ///
    population(0.025) govgrowth(0.03) foreigngrowth(0.02)
cge_dynamic, name(base) periods(0/4) `settings' gdpgrowth(0.04)
program define tariff_from2
    args t
    if `t' == 2 cge_shock tm, value(0)
end
cge_dynamic, name(lib) periods(0/4) `settings' baseline(base) shocks(tariff_from2)

*>> dynr_load
cge_dynresults, run(lib) baseline(base) clear
describe
*<<

*>> dynr_capital
list period element2 value baseline dev_pct if variable == "QF" & element1 == "cap", ///
    noobs sepby(period)
*<<

*>> dynr_output
list period element1 base value baseline dev_pct if variable == "QA", noobs sepby(period)
*<<

*>> dynr_nobase
cge_dynresults, run(base) clear
list period variable element1 base value if variable == "EXR", noobs
*<<
