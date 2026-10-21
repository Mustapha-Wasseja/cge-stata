* test_output_ces.do -- output of a commodity from several activities,
* combined by a CES or Cobb-Douglas function (version 0.5.2;
* docs/model_spec.md, Section 17.3), against the Python reference

version 13.0
quietly do helpers_reference.do

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

* ---------------------------------------------------------------------
* 1. Calibration: act_agr and act_man both produce com_man
* ---------------------------------------------------------------------
cge_synthetic, clear multiproduct
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) sigmaac(com_man:2)
assert r(max_residual) < 1e-12
quietly cge_solve, name(base) tolerance(1e-12)
quietly cge_results, sim(base) clear nodisplay
quietly count if variable == "QXAC"
assert r(N) == 2
quietly summarize base if variable == "QXAC" & element1 == "act_agr" & element2 == "com_man"
assert reldif(r(mean), 10) < 1e-13
quietly cge_parameters, clear
quietly summarize value if parameter == "dac" & element1 == "act_agr" & element2 == "com_man"
assert reldif(r(mean), 10^0.5 / (10^0.5 + 140^0.5)) < 1e-13

* ---------------------------------------------------------------------
* 2. Against the reference
* ---------------------------------------------------------------------
cge_synthetic, clear multiproduct
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) sigmaac(com_man:2)
_standard_simulations xac_
_compare_report xac_agri_productivity_up5
cge_check, sim(xac_agri_productivity_up5) homogeneity perturb(0.1)
assert r(failures) == 0
* imperfect substitutes: agriculture's manufactures become cheaper than act_man's
quietly cge_results, sim(xac_agri_productivity_up5) clear nodisplay
quietly summarize value if variable == "PXAC" & element1 == "act_agr"
local pa = r(mean)
quietly summarize value if variable == "PXAC" & element1 == "act_man"
assert `pa' < r(mean)
* Cobb-Douglas
cge_synthetic, clear multiproduct
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) sigmaac(com_man:1)
cge_shock ad, elements(act_agr) scale(1.05)
cge_solve, name(xac_cd_agri_productivity_up5) tolerance(1e-12)
_compare_reference xac_cd_agri_productivity_up5
* mixed elasticities
cge_synthetic, clear multiproduct
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.5 1 1.5) sigmaq(0.6 3 1.2) sigmat(0.7 4 1) sigmaac(com_man:2)
cge_shock ad, elements(act_agr) scale(1.05)
cge_solve, name(xac_mixed_agri_productivity_up5) tolerance(1e-12)
_compare_reference xac_mixed_agri_productivity_up5
cge_check, sim(xac_mixed_agri_productivity_up5) homogeneity
assert r(failures) == 0

* ---------------------------------------------------------------------
* 3. With a very large elasticity the activities' outputs are almost
*    perfect substitutes, as without sigmaac()
* ---------------------------------------------------------------------
cge_synthetic, clear multiproduct
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock ad, elements(act_agr) scale(1.05)
quietly cge_solve, name(flat) tolerance(1e-12)
tempfile flat
quietly cge_results, sim(flat) clear nodisplay
rename value flat
quietly save `flat'
cge_synthetic, clear multiproduct
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) sigmaac(1e8)
cge_shock ad, elements(act_agr) scale(1.05)
quietly cge_solve, name(near) tolerance(1e-12)
quietly cge_results, sim(near) clear nodisplay
quietly drop if inlist(variable, "PXAC", "QXAC")
quietly merge 1:1 variable element1 element2 using `flat'
assert _merge == 3
quietly generate double rel = abs(value - flat) / max(1, abs(flat))
quietly summarize rel
display as text "sigmaac(1e8) and perfect substitutes differ by at most " as result %9.2e r(max)
assert r(max) < 1e-6

* ---------------------------------------------------------------------
* 4. Saved models, the GAMS export and errors
* ---------------------------------------------------------------------
cge_synthetic, clear multiproduct
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) sigmaac(com_man:2)
cge_shock ad, elements(act_agr) scale(1.05)
quietly cge_solve, name(xac_agri_productivity_up5) tolerance(1e-12)
tempfile saved
quietly cge_save using "`saved'", replace
quietly cge_use using "`saved'"
quietly cge_solve, name(again) tolerance(1e-12)
_compare_reference xac_agri_productivity_up5
tempfile gdir
cge_gams using "`gdir'_gams", sim(xac_agri_productivity_up5) replace
mata: st_numscalar("okg", sum(cat(st_local("gdir") + "_gams/cge_data.inc") :== "    'com_man' 2"))
assert scalar(okg) == 1
local e sigmava(0.8) sigmaq(2) sigmat(2)
capture noisily cge_calibrate, `e' sigmaac(com_agr:2)
assert _rc == 459
capture noisily cge_calibrate, `e' sigmaac(com_man:0)
assert _rc == 198
capture noisily cge_calibrate, `e' sigmaac(xyz:2)
assert _rc == 111
capture noisily cge_calibrate, `e' sigmaac(0)
assert _rc == 198
