* Examples of [CGE] cge_nest. The SAM is SYNTHETIC.
*>> nest_setup
cge_synthetic, clear nests
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser act_ene) commodities(com_agr com_man com_ser com_ene) ///
    factors(lab_hi lab_lo cap) households(hhd) government(gov) savinv(sav) row(row)             ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) factortax(tax_pay:lab_hi)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
*<<

*>> nest_declare
cge_nest begin va(a), output(QVA(a)) price(PVA(a)) s(0.8) efficiency(ad(a) / base(ad(a))) replace(Q3)
cge_nest nest labour, s(1.5)
cge_nest input QF(lab_hi, a), price(W(lab_hi) * WFDIST(lab_hi, a) * (1 + tf(lab_hi, a))) ///
    units(af(lab_hi)) in(labour) replace(Q4(lab_hi, a))
cge_nest input QF(lab_lo, a), price(W(lab_lo) * WFDIST(lab_lo, a) * (1 + tf(lab_lo, a))) ///
    units(af(lab_lo)) in(labour) replace(Q4(lab_lo, a))
cge_nest input QF(cap, a), price(W(cap) * WFDIST(cap, a) * (1 + tf(cap, a))) ///
    units(af(cap)) replace(Q4(cap, a))
cge_nest end
cge_nest, list
*<<

*>> nest_solve
cge_shock QFS, elements(lab_hi) scale(1.1)
cge_solve, name(skilled)
quietly cge_results, sim(skilled) clear nodisplay
format base value %9.4f
list variable element1 element2 base value if inlist(variable, "QF", "W") & ///
    inlist(element1, "lab_hi", "lab_lo") & inlist(element2, "", "act_man"), noobs sepby(variable)
*<<

*>> nest_builtin
quietly cge_equation, clear
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) nests(labour: lab_hi lab_lo) sigmanest(labour:1.5)
quietly cge_shock QFS, elements(lab_hi) scale(1.1)
quietly cge_solve, name(builtin)
quietly cge_results, sim(builtin) clear nodisplay
format value %9.4f
list variable element1 element2 value if inlist(variable, "QF", "W") & ///
    inlist(element1, "lab_hi", "lab_lo") & inlist(element2, "", "act_man"), noobs sepby(variable)
*<<
