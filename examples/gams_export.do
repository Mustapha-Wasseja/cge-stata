* gams_export.do -- worked example: the model written as a GAMS program,
* solved in GAMS and compared with Stata (docs/gams.md)
*
* The synthetic SAM is constructed for testing and describes no country; the
* elasticities are illustrative. GAMS is needed only for the last step.

version 13.0
clear all

cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

* 1. A tariff removal, with the sales tax replacing the lost revenue
cge_closure, government(fixgsav sales)
cge_shock tm, value(0)
cge_solve, name(notariff)

* 2. The model and the scenario as a GAMS program, in a folder next to the
*    temporary files: the SAM, the calibration settings, the equations, the
*    closure and the shocks (as ratios to the base)
tempfile tmp
local folder "`tmp'_gams_notariff"
cge_gams using "`folder'", sim(notariff) replace
type "`folder'/cge_shock_par.inc"

* 3. With GAMS installed, solve the model with PATH, then with IPOPT, and
*    compare with Stata (interactive Stata; in batch mode run cge_run.gms with
*    GAMS, then use cge_gams ..., sim(notariff) compare noexport)
local gams "C:/GAMS/54/gams.exe"
capture confirm file "`gams'"
if !_rc & "`c(mode)'" != "batch" {
    cge_gams using "`folder'", sim(notariff) noexport run compare gams(`gams')
    cge_gams using "`folder'", sim(notariff) noexport run compare gams(`gams') solver(ipopt)
}
