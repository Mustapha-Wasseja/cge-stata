* Chapter 2, A first model. The SAM is SYNTHETIC.
*>> gs_sam
cge_synthetic, clear
list account act_agr act_man act_ser com_agr com_man com_ser in 1/6, noobs abbreviate(8)
cge_sam, labels(account)
*<<

*>> gs_map
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
*<<

*>> gs_calibrate
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_check, homogeneity perturb(0.1)
*<<

*>> gs_solve
cge_shock tm, value(0)
cge_solve, name(notariff)
*<<

*>> gs_results
cge_results, sim(notariff)
*<<

*>> gs_closure
cge_closure, government(fixgsav direct)
cge_solve, name(notariff_direct)
*<<

*>> gs_report
cge_report, sims(notariff notariff_direct) tables(macro government welfare)
*<<
