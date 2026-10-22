* Examples of [CGE] cge_constraint. The SAM is SYNTHETIC; the limits are illustrative.
quietly cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                              ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> cons_cap
cge_shock qg, elements(com_hlt) scale(1.2)
quietly cge_solve, name(hlt20)
cge_constraint QA, elements(act_hlt) upper(1.03) scale rents(hhd)
cge_solve, name(hlt20_cap)
cge_constraint, list
return list
*<<

*>> cons_cap_res
cge_report, sims(hlt20 hlt20_cap) tables(activities)
*<<

*>> cons_deficit
quietly cge_results, sim(hlt20) clear nodisplay
quietly summarize base if variable == "GSAV"
local gsav0 = r(mean)
cge_constraint, clear
cge_constraint GSAV, lower(`gsav0') adjust(GADJ) down
quietly cge_solve, name(hlt20_rule)
cge_constraint, list
quietly cge_results, sim(hlt20_rule) clear nodisplay
list variable base value if inlist(variable, "GSAV", "GADJ"), noobs
*<<

*>> cons_quota
cge_constraint, clear
cge_shock, reset
cge_constraint QM, elements(com_man) upper(1.02) scale
quietly cge_solve, name(quota_base)
cge_constraint, list
cge_shock tm, value(0)
quietly cge_solve, name(quota)
cge_constraint, list
*<<

*>> cons_quota_res
quietly cge_results, sim(quota) clear nodisplay
list variable element1 base value if inlist(variable, "QM", "RM") & element1 == "com_man", noobs
*<<

*>> cons_peg
cge_constraint, clear
capture noisily cge_constraint FSAV, upper(1.05) scale adjust(EXR) up
di as err "r(" _rc ");"
cge_closure, external(fixexr)
cge_constraint FSAV, upper(1.05) scale adjust(EXR) up
quietly cge_solve, name(peg)
cge_constraint, list
quietly cge_results, sim(peg) clear nodisplay
list variable base value if inlist(variable, "FSAV", "EXR"), noobs
*<<
