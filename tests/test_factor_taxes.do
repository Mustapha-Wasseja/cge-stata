* test_factor_taxes.do -- taxes on factor use and on factor income (version
* 0.5.0; docs/model_spec.md, Section 17.1), against the Python reference

version 13.0
quietly do helpers_reference.do

local ftmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)         ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) factortax(tax_pay:lab) factorincometax(tax_fy)

* ---------------------------------------------------------------------
* 1. Calibration
* ---------------------------------------------------------------------
cge_synthetic, clear factortax
quietly cge_sam, labels(account)
cge_map, `ftmap'
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
assert r(max_residual) < 1e-12
quietly cge_parameters, clear
* payroll taxes of 4, 3 and 6 on labour payments of 36, 32 and 54
quietly summarize value if parameter == "tf" & element1 == "lab" & element2 == "act_man"
assert reldif(r(mean), 3 / 32) < 1e-14
quietly summarize value if parameter == "tfy" & element1 == "cap"
assert reldif(r(mean), 7 / 127) < 1e-14

* ---------------------------------------------------------------------
* 2. Against the reference
* ---------------------------------------------------------------------
cge_synthetic, clear factortax
quietly cge_sam, labels(account)
quietly cge_map, `ftmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
_standard_simulations ftax_
cge_shock, reset
cge_shock tf, elements(lab) scale(0.5)
* the exact Jacobian (version 0.7.0)
mata: _cge_jexall()
assert r(maxdiff) < 1e-6
cge_solve, name(ftax_payroll_cut) tolerance(1e-12)
_compare_reference ftax_payroll_cut
_compare_report ftax_payroll_cut
cge_shock, reset
cge_shock tfy, scale(2)
cge_solve, name(ftax_income_tax_up) tolerance(1e-12)
_compare_reference ftax_income_tax_up
cge_check, sim(ftax_payroll_cut) homogeneity perturb(0.1)
assert r(failures) == 0
* Workers bear the payroll tax when labour supply is fixed: halving it raises
* the net wage by about 5 per cent
quietly cge_results, sim(ftax_payroll_cut) clear nodisplay
quietly summarize value if variable == "W" & element1 == "lab"
assert r(mean) > 1.04

cge_synthetic, clear factortax
quietly cge_sam, labels(account)
quietly cge_map, `ftmap'
quietly cge_calibrate, sigmava(0.5 1 1.5) sigmaq(0.6 3 1.2) sigmat(0.7 4 1)
cge_shock tf, elements(lab) scale(0.5)
cge_solve, name(ftax_mixed_payroll_cut) tolerance(1e-12)
_compare_reference ftax_mixed_payroll_cut

* A tax introduced where the SAM has none: a payroll tax of 10 per cent on capital
cge_shock, reset
cge_shock tf, elements(cap) value(0.1)
quietly cge_solve, name(captax) tolerance(1e-12)
quietly cge_report, sims(captax) tables(government) clear nodisplay
quietly summarize value if measure == "tax_factor_use"
assert r(mean) > 13

* ---------------------------------------------------------------------
* 3. Templates, saved models and the GAMS export keep the factor taxes
* ---------------------------------------------------------------------
tempfile tmpl
cge_template using "`tmpl'.csv", replace
preserve
quietly import delimited using "`tmpl'.csv", varnames(1) stringcols(_all) clear
quietly count if account == "tax_pay" & role == "factortax" & pair == "lab"
assert r(N) == 1
quietly count if account == "tax_fy" & role == "factorincometax"
assert r(N) == 1
restore
cge_synthetic, clear factortax
quietly cge_sam, labels(account)
cge_map using "`tmpl'.csv"
assert strpos("`r(command)'", "factortax(tax_pay:lab)") & strpos("`r(command)'", "factorincometax(tax_fy)")
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tf, elements(lab) scale(0.5)
quietly cge_solve, name(ftax_payroll_cut) tolerance(1e-12)
_compare_reference ftax_payroll_cut
tempfile saved
quietly cge_save using "`saved'", replace
quietly cge_use using "`saved'"
quietly cge_solve, name(again) tolerance(1e-12)
quietly cge_results, sim(again) clear nodisplay
quietly summarize value if variable == "W" & element1 == "lab"
assert r(mean) > 1.04
cge_gams using "`tmpl'_gams", sim(ftax_payroll_cut) replace
mata: st_numscalar("okg", sum(cat(st_local("tmpl") + "_gams/cge_shock_par.inc") :== "tf('lab', 'act_agr') = 0.5 * tf('lab', 'act_agr');") + ///
    sum(cat(st_local("tmpl") + "_gams/cge_data.inc") :== "set FTAXS(AC) /"))
assert scalar(okg) == 2

* ---------------------------------------------------------------------
* 4. Errors
* ---------------------------------------------------------------------
cge_synthetic, clear factortax
quietly cge_sam, labels(account)
local base activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
capture noisily cge_map, `base' factortax(tax_pay) factorincometax(tax_fy)
assert _rc == 198
capture noisily cge_map, `base' factortax(tax_pay:xyz) factorincometax(tax_fy)
assert _rc == 198
capture noisily cge_map, `base' factortax(tax_pay:lab tax_pay:cap) factorincometax(tax_fy)
assert _rc == 198
* the accounts left unmapped
capture noisily cge_map, `base'
assert _rc == 459
