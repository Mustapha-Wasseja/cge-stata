* Examples of [CGE] cge_gams. The SAM is SYNTHETIC and the elasticities are
* illustrative. GAMS is not run: Stata for Windows cannot start it in batch
* mode, so the examples show the export and the files written.
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> gams_sim
cge_closure, government(fixgsav sales)
cge_shock tm, value(0)
cge_solve, name(notariff)
*<<

*>> gams_export
cge_gams using gams_notariff, sim(notariff)
return list
*<<

*>> gams_par
type gams_notariff/cge_shock_par.inc
*<<

*>> gams_driver
type gams_notariff/cge_run.gms
*<<

*>> gams_again
capture noisily cge_gams using gams_notariff, sim(notariff)
di as err "r(" _rc ");"
*<<

*>> gams_batch
capture noisily cge_gams using gams_notariff, sim(notariff) noexport run
di as err "r(" _rc ");"
*<<

*>> gams_quota
cge_shock tm, value(0)
cge_constraint QM, elements(com_man) upper(1.02) scale
cge_solve, name(quota)
cge_gams using gams_quota, sim(quota)
type gams_quota/cge_constraints.inc
*<<

*>> gams_dyn
cge_constraint, clear
cge_shock, reset
cge_closure, government(flexgsav) factors(cap:specific)
cge_dynamic, name(dn) periods(0/2) capital(cap) depreciation(0.05) rental(0.15) ///
    growth(lab:0.02) population(0.02) govgrowth(0.03)
cge_gams using gams_dn, dynamic(dn)
*<<

*>> gams_dynfiles
return list
type gams_dn/cge_dn1_par.inc
type gams_dn/cge_dn1_var.inc
*<<
