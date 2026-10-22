* test_nests.do -- nests of value added (version 0.5.1; docs/model_spec.md,
* Section 17.2), against the Python reference

version 13.0
quietly do helpers_reference.do

local nmap activities(act_agr act_man act_ser act_ene) commodities(com_agr com_man com_ser com_ene) ///
    factors(lab_hi lab_lo cap) households(hhd) government(gov) savinv(sav) row(row)             ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) factortax(tax_pay:lab_hi)
local nests nests(labour: lab_hi lab_lo, ke: cap com_ene) sigmanest(labour:1.5 ke:0.4)

* The shocks of the nest cases (reference: scenarios.nest_shocks)
capture program drop _nest_simulations
program define _nest_simulations
    args prefix
    cge_shock, reset
    cge_shock tm, value(0)
    cge_solve, name(`prefix'tariff_removal) tolerance(1e-12)
    cge_shock, reset
    cge_shock pwm, scale(1.1)
    cge_solve, name(`prefix'import_price_up10) tolerance(1e-12)
    cge_shock, reset
    cge_shock QFS, elements(lab_hi) scale(1.1)
    cge_solve, name(`prefix'skilled_supply_up10) tolerance(1e-12)
    cge_shock, reset
    cge_shock pwm, elements(com_ene) scale(1.5)
    cge_solve, name(`prefix'energy_price_up50) tolerance(1e-12)
    cge_shock, reset
    cge_shock ad, elements(act_agr) scale(1.05)
    cge_solve, name(`prefix'agri_productivity_up5) tolerance(1e-12)
    cge_shock, reset
    cge_shock tf, elements(lab_hi) scale(0.5)
    cge_solve, name(`prefix'payroll_cut) tolerance(1e-12)
end

* ---------------------------------------------------------------------
* 1. Calibration
* ---------------------------------------------------------------------
cge_synthetic, clear nests
quietly cge_sam, labels(account)
cge_map, `nmap'
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) `nests'
assert r(max_residual) < 1e-12
* the exact Jacobian (version 0.7.0)
mata: _cge_jexall()
assert r(maxdiff) < 1e-6
quietly cge_solve, name(base) tolerance(1e-12)
quietly cge_results, sim(base) clear nodisplay
* each nest at its members' costs: labour types with the payroll tax, capital and energy
quietly summarize base if variable == "QNA" & element1 == "labour" & element2 == "act_man"
assert reldif(r(mean), 35) < 1e-13
quietly summarize base if variable == "QNA" & element1 == "ke" & element2 == "act_man"
assert reldif(r(mean), 40) < 1e-13
quietly summarize base if variable == "QVA" & element1 == "act_man"
assert reldif(r(mean), 75) < 1e-13
* act_ene buys no energy: its capital nest holds capital only
quietly count if variable == "QNA" & element2 == "act_ene"
assert r(N) == 2
quietly cge_parameters, clear
quietly count if parameter == "ica" & element1 == "com_ene" & value != 0
assert r(N) == 0
quietly count if parameter == "dce" & element1 == "com_ene" & value != 0
assert r(N) == 3
* real value added excludes energy
quietly cge_report, sims(base) tables(macro activities) clear nodisplay
quietly summarize base if measure == "value_added_real"
assert reldif(r(mean), 53 + 83 + 132 + 4) < 1e-12
quietly summarize base if measure == "value_added" & element == "act_man"
assert reldif(r(mean), 65) < 1e-12

* ---------------------------------------------------------------------
* 2. Against the reference
* ---------------------------------------------------------------------
cge_synthetic, clear nests
quietly cge_sam, labels(account)
quietly cge_map, `nmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) `nests'
_nest_simulations vnest_
foreach sim in tariff_removal import_price_up10 skilled_supply_up10 energy_price_up50 ///
    agri_productivity_up5 payroll_cut {
    _compare_reference vnest_`sim'
}
_compare_report vnest_energy_price_up50
cge_check, sim(vnest_energy_price_up50) homogeneity perturb(0.1)
assert r(failures) == 0
* capital specific to each activity
cge_closure, factors(cap:specific)
cge_shock, reset
cge_shock pwm, elements(com_ene) scale(1.5)
cge_solve, name(vnest_specific_energy_price_up50) tolerance(1e-12)
_compare_reference vnest_specific_energy_price_up50
* mixed elasticities: Cobb-Douglas value added in act_man and a Cobb-Douglas labour nest
cge_synthetic, clear nests
quietly cge_sam, labels(account)
quietly cge_map, `nmap'
quietly cge_calibrate, sigmava(0.5 1 1.5 0.8) sigmaq(2) sigmat(2) nests(labour: lab_hi lab_lo, ke: cap com_ene) ///
    sigmanest(labour:1 ke:0.25)
cge_shock pwm, elements(com_ene) scale(1.5)
cge_solve, name(vnest_mixed_energy_price_up50) tolerance(1e-12)
_compare_reference vnest_mixed_energy_price_up50
cge_shock, reset
cge_shock QFS, elements(lab_hi) scale(1.1)
cge_solve, name(vnest_mixed_skilled_supply_up10) tolerance(1e-12)
_compare_reference vnest_mixed_skilled_supply_up10
cge_check, sim(vnest_mixed_skilled_supply_up10) homogeneity
assert r(failures) == 0

* VAT that not every activity recovers: manufactures and capital in one nest
cge_synthetic, clear vat
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) ///
    households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) vattax(tax_vat)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) vatcredit(act_agr:0 act_ser:0.5) nests(km: cap com_man) sigmanest(0.5)
cge_shock tv, scale(1.2)
cge_solve, name(vnest_vat_rate_up20) tolerance(1e-12)
_compare_reference vnest_vat_rate_up20
cge_check, sim(vnest_vat_rate_up20)
assert r(failures) == 0

* ---------------------------------------------------------------------
* 3. A nest of factors with the elasticity of value added is the flat
*    function of value added
* ---------------------------------------------------------------------
foreach s in 0.8 1 {
    cge_synthetic, clear nests
    quietly cge_sam, labels(account)
    quietly cge_map, `nmap'
    quietly cge_calibrate, sigmava(`s') sigmaq(2) sigmat(2)
    cge_shock QFS, elements(lab_hi) scale(1.1)
    quietly cge_solve, name(flat) tolerance(1e-12)
    tempfile flat
    quietly cge_results, sim(flat) clear nodisplay
    rename value flat
    quietly save `flat'
    cge_synthetic, clear nests
    quietly cge_sam, labels(account)
    quietly cge_map, `nmap'
    quietly cge_calibrate, sigmava(`s') sigmaq(2) sigmat(2) nests(labour: lab_hi lab_lo) sigmanest(`s')
    cge_shock QFS, elements(lab_hi) scale(1.1)
    quietly cge_solve, name(nested) tolerance(1e-12)
    quietly cge_results, sim(nested) clear nodisplay
    quietly drop if inlist(variable, "QNA", "PNA")
    quietly merge 1:1 variable element1 element2 using `flat'
    assert _merge == 3
    quietly generate double rel = abs(value - flat) / max(1, abs(flat))
    quietly summarize rel
    display as text "sigma `s': nested and flat value added differ by at most " as result %9.2e r(max)
    assert r(max) < 1e-10
}

* ---------------------------------------------------------------------
* 4. Saved models, sensitivity analysis, dynamic runs and the GAMS export
* ---------------------------------------------------------------------
cge_synthetic, clear nests
quietly cge_sam, labels(account)
quietly cge_map, `nmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) `nests'
cge_shock pwm, elements(com_ene) scale(1.5)
quietly cge_solve, name(vnest_energy_price_up50) tolerance(1e-12)
tempfile saved
quietly cge_save using "`saved'", replace
quietly cge_use using "`saved'"
quietly cge_solve, name(again) tolerance(1e-12)
_compare_reference vnest_energy_price_up50
capture program drop _dear_energy
program define _dear_energy
    cge_shock pwm, elements(com_ene) scale(1.5)
end
cge_sensitivity, scenario(_dear_energy) draws(2) seed(5) tables(macro) nodisplay
assert r(N_converged) == 2
program drop _dear_energy
* the nests survive the calibrations of the sensitivity analysis
quietly cge_parameters, clear
quietly count if parameter == "sgn"
assert r(N) == 2
* a dynamic run with a target for real value added, which excludes energy
cge_synthetic, clear nests
quietly cge_sam, labels(account)
quietly cge_map, `nmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) `nests'
quietly cge_dynamic, name(dn) periods(0/2) capital(cap) depreciation(0.05) rental(0.15) growth(lab_lo:0.02) gdpgrowth(0.03)
quietly cge_report, sims(dn1 dn2) tables(macro) clear nodisplay
quietly summarize value if measure == "value_added_real" & sim == "dn1"
local v1 = r(mean)
quietly summarize value if measure == "value_added_real" & sim == "dn2"
assert reldif(r(mean) / `v1', 1.03) < 1e-8
cge_synthetic, clear nests
quietly cge_sam, labels(account)
quietly cge_map, `nmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) `nests'
cge_shock pwm, elements(com_ene) scale(1.5)
quietly cge_solve, name(vnest_energy_price_up50) tolerance(1e-12)
tempfile gdir
cge_gams using "`gdir'_gams", sim(vnest_energy_price_up50) replace
mata: st_numscalar("okg", sum(cat(st_local("gdir") + "_gams/cge_data.inc") :== "set NST(*) 'nests of value added' / 'labour', 'ke' /;") + ///
    sum(cat(st_local("gdir") + "_gams/cge_data.inc") :== "parameter signest(NST) / 'labour' 1.5, 'ke' 0.4 /;"))
assert scalar(okg) == 2

* ---------------------------------------------------------------------
* 5. Errors
* ---------------------------------------------------------------------
cge_synthetic, clear nests
quietly cge_sam, labels(account)
quietly cge_map, `nmap'
local e sigmava(0.8) sigmaq(2) sigmat(2)
capture noisily cge_calibrate, `e' nests(a: lab_hi, b: lab_hi cap) sigmanest(0.5)
assert _rc == 198
capture noisily cge_calibrate, `e' nests(a: xyz) sigmanest(0.5)
assert _rc == 198
capture noisily cge_calibrate, `e' nests(cap: lab_hi lab_lo) sigmanest(0.5)
assert _rc == 198
capture noisily cge_calibrate, `e' nests(a lab_hi lab_lo) sigmanest(0.5)
assert _rc == 198
capture noisily cge_calibrate, `e' nests(a: lab_hi lab_lo)
assert _rc == 198
capture noisily cge_calibrate, `e' sigmanest(0.5)
assert _rc == 198
capture noisily cge_calibrate, `e' nests(a: lab_hi lab_lo) sigmanest(b:0.5)
assert _rc == 111
capture noisily cge_calibrate, `e' nests(a: lab_hi lab_lo) sigmanest(0)
assert _rc == 198
