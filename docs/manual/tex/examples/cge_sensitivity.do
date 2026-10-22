* Examples of [CGE] cge_sensitivity. The SAM is SYNTHETIC and the central
* elasticities are illustrative.
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> sens_program
program define tariff_cut
    cge_shock tm, value(0)
end
*<<

*>> sens_draws
cge_sensitivity, scenario(tariff_cut) draws(20) seed(2026)
*<<

*>> sens_common
cge_sensitivity, scenario(tariff_cut) draws(20) seed(2026) vary(q t) common ///
    distribution(triangular) tables(welfare) clear
*<<

*>> sens_data
tabulate table
list draw measure element value if table == "elasticity" & draw <= 2 & measure == "sigmaq", ///
    noobs sepby(draw)
summarize pct if measure == "equivalent_variation" & draw > 0
*<<
