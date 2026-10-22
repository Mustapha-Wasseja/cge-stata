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
