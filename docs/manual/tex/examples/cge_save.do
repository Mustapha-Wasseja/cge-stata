* Examples of [CGE] cge_save. The SAM is SYNTHETIC.
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)             ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
quietly cge_shock tm, value(0)
quietly cge_solve, name(notariff)

*>> save_model
cge_save using mymodel, replace
return list
*<<

*>> save_exists
capture noisily cge_save using mymodel
di as err "r(" _rc ");"
*<<

*>> save_sam
cge_synthetic, clear
cge_sam, labels(account)
cge_save using samonly, replace
*<<
