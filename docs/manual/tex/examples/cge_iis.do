* Examples of [CGE] cge_iis. The SAM is SYNTHETIC.
*>> iis_setup
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
*<<

*>> iis_bounds
cge_shock tm, value(0)
cge_bound QM(com_man), upper(1) relative
cge_bound QM(com_agr), lower(0.5) relative
cge_bound PQ, lower(0.5) upper(2) relative
cge_iis, trace
cge_bound, clear
*<<

*>> iis_quota
cge_equation quota: QM(com_man) =l= 0.98 * base(QM(com_man)), perp(RM(com_man))
cge_solve, name(quota)
cge_bound RM(com_man), upper(0.0487)
cge_bound QM(com_agr), lower(0.5) relative
cge_iis
cge_bound, clear
cge_equation, clear
*<<
