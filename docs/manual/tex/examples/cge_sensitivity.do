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

*>> sens_standalone
cge_model new
cge_set c = g1 g2 g3
cge_set h = h1 h2
cge_parameter alpha(c,h), values(g1.h1:0.5 g2.h1:0.3 g3.h1:0.2 g1.h2:0.2 g2.h2:0.3 g3.h2:0.5)
cge_parameter ybar(h), values(h1:100 h2:50)
cge_parameter eta(c), values(g1:1 g2:1 g3:0.5)
cge_parameter A(c) = sum(h, alpha(c,h) * ybar(h))
cge_variable P(c), value(1)
cge_variable Y(h) = ybar(h)
cge_variable X(c) = A(c) * P(c)^eta(c)
cge_variable Q(c,h) = alpha(c,h) * Y(h) / P(c)
cge_equation MKT(c): sum(h, Q(c,h)) = X(c)
cge_model roles, groups(h) goods(c) prices(P) consumption(Q) income(Y)
program define supply_cut
    cge_shock A, elements(g2) scale(0.8)
end
cge_sensitivity, scenario(supply_cut) draws(20) seed(2026) vary(eta) items(pg2 = P(g2))
*<<
