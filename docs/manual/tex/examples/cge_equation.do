* Examples of [CGE] cge_equation. The SAM is SYNTHETIC.
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)             ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> eq_lam
cge_variable LAM, value(1)
cge_equation lam: QG(com_ser) = LAM * base(QG(com_ser))
cge_closure, swap(LAM GADJ)
cge_shock LAM, value(1.1)
cge_solve, name(qgser)
*<<

*>> eq_lam_res
quietly cge_results, sim(qgser) clear nodisplay
list variable element1 base value if inlist(variable, "LAM", "GADJ", "QG"), noobs
*<<

*>> eq_index
cge_variable PIX(c), value(1)
cge_equation pix(c): ln(PIX(c)) = ln(PQ(c)) - ln(CPI)
cge_variable CVOL, value(1)
cge_equation cvol: sum(c, PQ(c) * QH(c, hhd)) = CVOL * sum(c, PQ(c) * base(QH(c, hhd)))
quietly cge_solve, name(qgser)
quietly cge_results, sim(qgser) clear nodisplay
list variable element1 base value if inlist(variable, "PIX", "CVOL"), noobs
*<<

*>> eq_list
cge_equation, list
return list
*<<

*>> eq_err
capture noisily cge_equation bad: QG(com_xxx) = 1
di as err "r(" _rc ");"
capture noisily cge_equation, clear
di as err "r(" _rc ");"
cge_closure, swap(none)
cge_equation, clear
*<<
