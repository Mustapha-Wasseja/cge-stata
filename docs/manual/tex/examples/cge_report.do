* Examples of [CGE] cge_report. The SAM is SYNTHETIC.
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)             ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> rep_sims
cge_shock tm, value(0)
quietly cge_solve, name(notariff)
cge_closure, government(fixgsav sales)
quietly cge_solve, name(nt_sales)
*<<

*>> rep_macro
cge_report, sims(notariff nt_sales) tables(macro government welfare)
*<<

*>> rep_return
return list
*<<

*>> rep_data
cge_report, sims(_all) clear nodisplay
describe, short
list sim measure element value pct if table == "welfare", noobs sepby(sim)
*<<

*>> rep_excel
cge_report, sims(_all) tables(all) saving(report.xlsx, replace) nodisplay
*<<

*>> rep_items
cge_report, sims(_all) items(absorption = sum(c, PQ(c) * QQ(c)); pman = PQ(com_man)) variables(QA) tables(macro items variables)
*<<

*>> rep_standalone
cge_model new
cge_set c = g1 g2 g3
cge_set h = h1 h2
cge_parameter alpha(c,h), values(g1.h1:0.5 g2.h1:0.3 g3.h1:0.2 g1.h2:0.2 g2.h2:0.3 g3.h2:0.5)
cge_parameter ybar(h), values(h1:100 h2:50)
cge_parameter A(c) = sum(h, alpha(c,h) * ybar(h))
cge_variable P(c), value(1)
cge_variable Y(h) = ybar(h)
cge_variable X(c) = A(c) * P(c)
cge_variable Q(c,h) = alpha(c,h) * Y(h) / P(c)
cge_equation MKT(c): sum(h, Q(c,h)) = X(c)
cge_shock A, elements(g2) scale(0.8)
cge_solve, name(supply)
cge_model roles, groups(h) goods(c) prices(P) consumption(Q) income(Y)
cge_report, items(revenue = sum(c, P(c) * X(c)))
*<<
