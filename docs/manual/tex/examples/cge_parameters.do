* Examples of [CGE] cge_parameters. The SAM is SYNTHETIC.
cge_synthetic, clear
cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                 ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> param_base
cge_parameters, clear
display r(N)
list if inlist(parameter, "tm", "tq"), noobs sepby(parameter) abbreviate(9)
*<<

*>> param_matrix
list element1 element2 value if parameter == "dva", noobs
*<<

*>> param_sim
quietly cge_shock tm, value(0)
quietly cge_solve, name(notariff)
cge_parameters, clear sim(notariff)
list if parameter == "tm", noobs abbreviate(9)
*<<

*>> param_current
quietly cge_shock tq, elements(com_ser) scale(1.5)
cge_parameters, clear current
list if parameter == "tq", noobs abbreviate(9)
*<<
