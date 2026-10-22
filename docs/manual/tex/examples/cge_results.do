* Examples of [CGE] cge_results. The SAM is SYNTHETIC.
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)             ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
quietly cge_shock tm, value(0)
quietly cge_solve, name(notariff)

*>> res_show
cge_results, sim(notariff)
*<<

*>> res_return
return list
matrix list r(ev)
*<<

*>> res_data
cge_results, sim(notariff) clear nodisplay
describe, short
list if variable == "QA", noobs
*<<

*>> res_pct
generate double pct = 100 * (value - base) / abs(base)
list variable element1 base value pct if inlist(variable, "PQ", "QM"), noobs
*<<

*>> res_saving
cge_results, sim(notariff) saving(notariff_results, replace) nodisplay
*<<
