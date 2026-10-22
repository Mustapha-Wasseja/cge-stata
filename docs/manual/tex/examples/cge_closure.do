* Examples of [CGE] cge_closure. The SAM is SYNTHETIC.
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)             ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> clos_default
cge_closure
return list
*<<

*>> clos_alt
cge_closure, external(fixexr) savinv(investment) factors(cap:specific)
*<<

*>> clos_fixgsav
cge_closure, external(flexexr) savinv(savings) factors(cap:mobile) government(fixgsav sales)
cge_shock tm, value(0)
cge_solve, name(notariff_sales)
*<<

*>> clos_fixgsav_res
quietly cge_results, sim(notariff_sales) clear nodisplay
list variable base value if inlist(variable, "GSAV", "TQADJ", "TINSADJ", "GADJ"), noobs
*<<

*>> clos_swap
cge_shock, reset
cge_closure, government(flexgsav) swap(QG(com_ser) GADJ)
cge_shock QG, elements(com_ser) scale(1.1)
cge_solve, name(qgser)
*<<

*>> clos_swap_res
quietly cge_results, sim(qgser) clear nodisplay
list variable element1 base value if inlist(variable, "QG", "GADJ"), noobs
*<<

*>> clos_singular
cge_shock, reset
capture noisily cge_closure, swap(QG(com_ser) TINSADJ)
di as err "r(" _rc ");"
*<<

*>> clos_fixed
capture noisily cge_closure, swap(FSAV EXR)
di as err "r(" _rc ");"
cge_closure, swap(none)
*<<
