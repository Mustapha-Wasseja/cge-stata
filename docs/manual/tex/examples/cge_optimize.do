* Examples of [CGE] cge_optimize. The SAM is SYNTHETIC and the elasticities
* are illustrative.
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> opt_base
cge_solve, name(base)
cge_report, sims(base) tables(government)
cge_closure, government(fixgsav)
*<<

*>> opt_max
cge_optimize, instruments(tm(com_man)) maximize(welfare equivalent_variation hhd) ///
    lower(tm(com_man):-0.5) upper(tm(com_man):1) trace
*<<

*>> opt_return
display r(converged), r(N_evaluations), r(iterations), r(objective)
matrix list r(instruments)
cge_report, sims(optimum) tables(government welfare)
*<<

*>> opt_revenue
cge_shock, reset
cge_optimize, instruments(tm(com_agr) tm(com_man)) maximize(welfare equivalent_variation hhd) ///
    targets(government tax_import = 8) name(two_tariffs)
*<<

*>> opt_targets
cge_shock, reset
cge_closure, government(flexgsav)
cge_shock tm, value(0)
cge_optimize, instruments(TINSADJ) targets(government savings = 3) name(tins) trace
*<<

*>> opt_fixgsav
cge_shock, reset
cge_closure, government(fixgsav)
cge_shock tm, value(0)
cge_solve, name(fixgsav)
cge_results, sim(fixgsav) clear nodisplay
list variable value if variable == "TINSADJ", noobs
*<<
