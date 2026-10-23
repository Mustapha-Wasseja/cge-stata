* Examples of [CGE] cge_listing. The SAM is SYNTHETIC.
*>> list_setup
cge_synthetic, clear
cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                 ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
*<<

*>> list_base
cge_listing, base
*<<

*>> list_current
cge_shock tm, value(0)
cge_listing, current blocks(P1 I8)
*<<

*>> list_fail
capture noisily cge_solve, name(stopped) iterate(1) steps(1) tolerance(1e-30)
cge_listing, sim(stopped) top(8)
*<<

*>> list_clear
quietly cge_solve, name(notariff)
quietly cge_listing, sim(notariff) clear
describe, simple
list block element lhs rhs scaled if inlist(block, "Q4", "I8"), noobs
*<<
