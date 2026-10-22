* Examples of [CGE] cge_check. The SAM is SYNTHETIC.
cge_synthetic, clear
cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                 ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> check_base
cge_check
*<<

*>> check_sim
quietly cge_shock tm, value(0)
quietly cge_solve, name(notariff)
cge_check, homogeneity perturb(0.1)
*<<

*>> check_closure
cge_closure, external(fixexr) savinv(investment) factors(cap:specific)
cge_check, homogeneity perturb(0.2) seed(2026)
*<<
