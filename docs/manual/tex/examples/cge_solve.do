* Examples of [CGE] cge_solve. The SAM is SYNTHETIC.
*>> solve_setup
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
*<<

*>> solve_notariff
cge_shock tm, value(0)
cge_solve, name(notariff)
*<<

*>> solve_trace
cge_solve, name(notariff) tolerance(1e-12) trace
*<<

*>> solve_return
return list
*<<

*>> solve_collapse
cge_shock, reset
cge_shock qg, scale(10)
cge_solve, name(qg10)
*<<

*>> solve_fail
cge_closure, savinv(investment)
capture noisily cge_solve, name(qg10fixed)
di as err "r(" _rc ");"
*<<
