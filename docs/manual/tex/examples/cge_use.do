* Examples of [CGE] cge_use. The SAM is SYNTHETIC.
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)             ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
quietly cge_shock tm, value(0)
quietly cge_solve, name(notariff)
quietly cge_closure, government(fixgsav sales)
quietly cge_solve, name(nt_sales)
quietly cge_save using mymodel, replace

*>> use_load
clear all
cge_use using mymodel
return list
*<<

*>> use_state
cge_closure
cge_report, sims(_all) tables(welfare)
quietly cge_parameters, clear current
list parameter element1 value if parameter == "tm", noobs abbreviate(9)
*<<

*>> use_err
cge_synthetic, clear
save notamodel, replace
capture noisily cge_use using notamodel.dta
di as err "r(" _rc ");"
*<<
