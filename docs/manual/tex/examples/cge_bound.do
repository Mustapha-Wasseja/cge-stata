* Examples of [CGE] cge_bound. The SAM is SYNTHETIC.
*>> bnd_setup
cge_synthetic, clear
cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                 ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
cge_solve, name(plain)
*<<

*>> bnd_define
cge_bound QM, lower(0.5) upper(2) relative
cge_bound PQ(com_man), lower(0.5)
cge_bound QA(act_man), scale(1000)
cge_bound EXR, level(1.05)
cge_bound QE, level(1.1) relative
cge_bound, list
cge_solve, name(bounded)
quietly cge_results, sim(plain) clear nodisplay
quietly summarize value if variable == "QM" & element1 == "com_man"
local q1 = r(mean)
quietly cge_results, sim(bounded) clear nodisplay
quietly summarize value if variable == "QM" & element1 == "com_man"
display "QM(com_man): " %12.8f `q1' " without the attributes, " %12.8f r(mean) " with them"
*<<

*>> bnd_listing
cge_listing, sim(bounded) solution variables(QM PQ)
*<<

*>> bnd_beyond
cge_bound QM(com_man), upper(61)
capture noisily cge_solve, name(beyond)
cge_bound QM(com_man), upper(inf)
cge_constraint QM, elements(com_man) upper(61)
cge_solve, name(quota)
*<<

*>> bnd_fix
cge_constraint, clear
cge_bound, clear
cge_shock, reset
cge_bound FSAV, fix(1.2) relative
cge_solve, name(fsav)
capture noisily cge_bound QA(act_man), fix(100)
*<<
