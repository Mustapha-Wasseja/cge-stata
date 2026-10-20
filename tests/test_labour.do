* test_labour.do -- labour-market regimes (version 0.3.3; docs/model_spec.md,
* Section 14): labour force, wage curve and minimum wage, against the Python
* reference, and the smoothed minimum-wage condition against the exact regimes

version 13.0

quietly do helpers_reference.do

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)

* The standard simulations, with a larger labour force in place of more labour
* supply, under the closure in memory; prefix selects the expected files
capture program drop _labour_simulations
program define _labour_simulations
    args prefix
    cge_shock, reset
    cge_shock tm, value(0)
    cge_solve, name(`prefix'tariff_removal) tolerance(1e-12)
    cge_shock, reset
    cge_shock pwm, scale(1.1)
    cge_solve, name(`prefix'import_price_up10) tolerance(1e-12)
    cge_shock, reset
    cge_shock qlf, elements(lab) scale(1.05)
    cge_solve, name(`prefix'labour_force_up5) tolerance(1e-12)
    cge_shock, reset
    cge_shock FSAV, scale(0.8)
    cge_solve, name(`prefix'foreign_savings_down20) tolerance(1e-12)
    cge_shock, reset
    cge_shock ad, elements(act_agr) scale(1.05)
    cge_solve, name(`prefix'agri_productivity_up5) tolerance(1e-12)
    cge_shock, reset
    foreach sim in tariff_removal import_price_up10 labour_force_up5 ///
        foreign_savings_down20 agri_productivity_up5 {
        _compare_reference `prefix'`sim'
    }
end

* Unemployment rate of lab in a stored simulation, in per cent
capture program drop _urate
program define _urate, rclass
    args sim
    preserve
    quietly cge_report, sims(`sim') tables(factors) clear nodisplay
    quietly summarize value if measure == "unemployment_rate" & element == "lab"
    return scalar u = r(mean)
    quietly summarize value if measure == "real_wage" & element == "lab"
    return scalar rw = r(mean)
    restore
end

* ---------------------------------------------------------------------
* 1. A wage curve with 15 per cent unemployment
* ---------------------------------------------------------------------
cge_synthetic, clear
quietly cge_sam, labels(account)
cge_map, `stdmap'
cge_calibrate, `sigmas' unemployment(lab:0.15) wagecurve(lab:0.1)
assert r(max_residual) < 1e-12
quietly cge_parameters, clear
quietly summarize value if parameter == "u0" & element1 == "lab"
assert r(mean) == 0.15
quietly summarize value if parameter == "inlf" & element1 == "cap"
assert r(mean) == 0
cge_closure, factors(lab:wagecurve)
quietly cge_solve, name(wc_base) tolerance(1e-12)
assert r(iterations) == 0
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
mata: _cge_jaccheck(1)
assert r(maxdiff) < 1e-6
_labour_simulations wc_
_compare_report wc_tariff_removal
cge_closure, numeraire(dpi)
cge_shock tm, value(0)
cge_solve, name(wc_dpi_tariff_removal) tolerance(1e-12)
_compare_reference wc_dpi_tariff_removal
cge_shock, reset
* The full system gives the same solution, which is homogeneous of degree zero
cge_closure, numeraire(cpi)
cge_shock pwm, scale(1.1)
cge_solve, name(wc_full) tolerance(1e-12) full
_compare_reference wc_import_price_up10
cge_check, sim(wc_full) homogeneity
cge_shock, reset
* Higher import prices: more unemployment and lower real wages
_urate wc_import_price_up10
assert r(u) > 15 & r(rw) < 1

* A dynamic run in which the labour force grows with lab
quietly cge_closure, factors(cap:specific lab:wagecurve)
local common capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02) population(0.02) ///
    govgrowth(0.03) foreigngrowth(0.01)
cge_dynamic, name(wc) periods(0/4) `common' tfp(0.01)
forvalues t = 0/4 {
    _compare_period wc`t' dyn_wc_p`t'
}
quietly cge_parameters, sim(wc4) clear
quietly summarize value if parameter == "qlf" & element1 == "lab"
local q4 = r(mean)
quietly cge_parameters, clear
quietly summarize value if parameter == "qlf" & element1 == "lab"
assert reldif(`q4', r(mean) * 1.02^4) < 1e-14

* ---------------------------------------------------------------------
* 2. A binding minimum wage with 15 per cent unemployment
* ---------------------------------------------------------------------
cge_calibrate, `sigmas' unemployment(lab:0.15)
quietly cge_closure, factors(lab:minwage)
_labour_simulations mw_
* Against the exact regime: unemployment at the fixed wage wmin
quietly cge_parameters, clear
quietly summarize value if parameter == "wmin" & element1 == "lab"
local wmin = r(mean)
quietly cge_closure, factors(lab:unemployed)
cge_shock W, elements(lab) value(`wmin')
cge_shock pwm, scale(1.1)
quietly cge_solve, name(exact) tolerance(1e-12)
cge_shock, reset
preserve
quietly cge_results, sim(exact) clear nodisplay
rename value exact
keep if inlist(variable, "QA", "QFS", "PQ", "W")
tempfile ex
quietly save `ex'
quietly cge_results, sim(mw_import_price_up10) clear nodisplay
quietly merge 1:1 variable element1 element2 using `ex', keep(match)
generate double rel = abs(value - exact) / abs(exact)
summarize rel
assert r(max) < 1e-8
restore

* ---------------------------------------------------------------------
* 3. Regime switches: full employment above a floor at 95 per cent of the
*    base wage; 2 per cent unemployment at the floor
* ---------------------------------------------------------------------
cge_calibrate, `sigmas' minwage(lab:0.95)
quietly cge_closure, factors(lab:minwage)
cge_shock FSAV, scale(0.8)
cge_solve, name(mwnb_foreign_savings_down20) tolerance(1e-12)
_compare_reference mwnb_foreign_savings_down20
cge_shock, reset
_urate mwnb_foreign_savings_down20
assert r(u) < 1e-6 & r(rw) > 0.95
cge_shock pwm, scale(1.5)
cge_solve, name(mwnb_pwm_up50) tolerance(1e-12)
_compare_reference mwnb_pwm_up50
_compare_report mwnb_pwm_up50
cge_shock, reset
_urate mwnb_pwm_up50
assert r(u) > 5 & reldif(r(rw), 0.95) < 1e-8

cge_calibrate, `sigmas' unemployment(lab:0.02)
quietly cge_closure, factors(lab:minwage)
cge_shock ad, scale(1.05)
cge_solve, name(mwlo_productivity_up5) tolerance(1e-12)
_compare_reference mwlo_productivity_up5
cge_shock, reset
_urate mwlo_productivity_up5
assert r(u) < 1e-6 & r(rw) > 1.01

* A saved model keeps its labour force and closure
tempfile saved
quietly cge_save using "`saved'", replace
cge_synthetic, clear
quietly cge_sam, labels(account)
cge_use using "`saved'"
quietly cge_closure
assert strpos(r(closure), "lab:minwage")
cge_shock ad, scale(1.05)
quietly cge_solve, name(mwlo_productivity_up5) tolerance(1e-12)
_compare_reference mwlo_productivity_up5
cge_shock, reset

* ---------------------------------------------------------------------
* 4. Errors
* ---------------------------------------------------------------------
cge_calibrate, `sigmas'
capture noisily cge_closure, factors(lab:minwage)
assert _rc == 459
capture noisily cge_shock qlf, elements(lab) scale(1.1)
assert _rc == 459
capture noisily cge_closure, factors(lab:fixed)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' unemployment(lab:0.15) wagecurve(cap:0.1)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' wagecurve(lab:0.1)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' unemployment(lab:1)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' unemployment(lab:0.1) minwage(lab:0.9)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' minwage(lab:1)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' unemployment(lab:0.1) wagecurve(lab:-1)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' unemployment(lab:0.1) smoothing(0)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' unemployment(xyz:0.1)
assert _rc == 111
cge_calibrate, `sigmas' unemployment(lab:0.15) wagecurve(lab:0.1)
quietly cge_closure, factors(cap:mobile lab:wagecurve)
capture noisily cge_dynamic, name(bad) periods(0/1) capital(lab) depreciation(0.05) rental(0.15)
assert _rc == 198
