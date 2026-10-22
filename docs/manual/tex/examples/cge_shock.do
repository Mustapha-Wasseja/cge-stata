* Examples of [CGE] cge_shock. The SAMs are SYNTHETIC.
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)             ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> shock_par
cge_shock tm, value(0)
cge_shock pwm, elements(com_man) scale(1.1)
cge_shock ad, elements(act_agr) scale(1.05)
*<<

*>> shock_accum
cge_shock qg, elements(com_ser) scale(1.1)
cge_shock qg, elements(com_ser) scale(1.1)
quietly cge_parameters, clear current
list parameter element1 value if parameter == "qg", noobs abbreviate(9)
*<<

*>> shock_reset
cge_shock, reset
*<<

*>> shock_var
cge_shock QFS, elements(lab) scale(1.05)
cge_shock FSAV, scale(0.8)
capture noisily cge_shock EXR, scale(1.1)
di as err "r(" _rc ");"
*<<

*>> shock_solve
cge_solve, name(lab_up)
quietly cge_results, sim(lab_up) clear nodisplay
list variable element1 base value if inlist(variable, "QFS", "FSAV", "EXR"), noobs
*<<

*>> shock_need
cge_shock, reset
capture noisily cge_shock tshi, scale(1.1)
di as err "r(" _rc ");"
capture noisily cge_shock trgr, elements(hhd) scale(2)
di as err "r(" _rc ");"
*<<

* A SAM with a social health insurance fund
quietly cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                              ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> shock_health
cge_shock qg, elements(com_hlt) scale(1.2)
cge_shock tshi, elements(lab) scale(1.5)
cge_shock af, elements(lab) scale(0.98)
cge_solve, name(health)
cge_report, sims(health) tables(health)
*<<
