* test_optimize.do -- policy optimisation (version 0.6.0; docs/model_spec.md,
* Section 18), against the Python reference (scipy's SLSQP and least squares)

version 13.0
quietly do helpers_reference.do

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local ev welfare equivalent_variation hhd

* The instruments and objective of a case, against expected/opt_instruments.csv
capture program drop _compare_optimum _compare_solution
program define _compare_optimum
    args case tol
    tempname r
    matrix `r' = r(instruments)
    local obj = r(objective)
    preserve
    quietly import delimited using "expected/opt_instruments.csv", varnames(1) stringcols(1 2) asdouble clear
    quietly keep if case == "`case'"
    forvalues k = 1/`=colsof(`r')' {
        quietly summarize value if item == "instrument`k'"
        display as text "`case' instrument `k': " as result %14.10f `r'[1, `k'] as text ", reference " as result %14.10f r(mean)
        assert abs(`r'[1, `k'] - r(mean)) < `tol' * max(1, abs(r(mean)))
    }
    quietly count if item == "objective"
    if r(N) {
        quietly summarize value if item == "objective"
        assert reldif(`obj', r(mean)) < 1e-9
    }
    restore
end

* The solution at an optimum against expected/<case>.csv. A smooth objective
* is flat at its optimum, so an optimum is located to about 1e-6, the square
* root of the objective's precision, and the solution agrees to about 1e-6
capture program drop _compare_solution
program define _compare_solution
    args sim
    tempfile stata
    quietly cge_results, sim(`sim') clear nodisplay
    quietly save `stata'
    quietly import delimited using "expected/`sim'.csv", varnames(1) case(preserve) ///
        stringcols(1 2 3) asdouble clear
    rename (base value) (ref_base ref_value)
    quietly merge 1:1 variable element1 element2 using `stata'
    assert _merge == 3
    quietly generate double reldiff = abs(value - ref_value) / max(1, abs(ref_value))
    quietly summarize reldiff
    display as text "`sim': " as result _N as text " values, largest relative difference " ///
        as result %9.2e r(max)
    assert r(max) < 1e-5
end

* ---------------------------------------------------------------------
* 1. A target: the direct tax rate that keeps government savings at the
*    base after tariffs are removed is the closure fixgsav
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
cge_optimize, instruments(TINSADJ) targets(government savings = 3) name(opt_target_gsav)
assert r(converged) == 1
tempname tins
matrix `tins' = r(instruments)
_compare_optimum opt_target_gsav 1e-10
_compare_reference opt_target_gsav
quietly cge_closure, government(fixgsav)
quietly cge_shock, reset
cge_shock tm, value(0)
quietly cge_solve, name(fixgsav) tolerance(1e-12)
quietly cge_results, sim(fixgsav) clear nodisplay
quietly summarize value if variable == "TINSADJ"
assert reldif(r(mean), `tins'[1, 1]) < 1e-10

* ---------------------------------------------------------------------
* 2. Welfare-maximising tariffs, revenue-neutral
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
quietly cge_closure, government(fixgsav)
cge_optimize, instruments(tm(com_man)) maximize(`ev') lower(tm(com_man):-0.5) upper(tm(com_man):1) name(opt_tariff_man)
assert r(converged) == 1
_compare_optimum opt_tariff_man 1e-5
_compare_solution opt_tariff_man
* the optimum is left as the current shock: solving again reproduces it
quietly cge_solve, name(opt_tariff_man) tolerance(1e-12)
_compare_solution opt_tariff_man
quietly cge_shock, reset
cge_optimize, instruments(tm(com_agr) tm(com_man)) maximize(`ev') name(opt_two_tariffs)
assert r(converged) == 1
_compare_optimum opt_two_tariffs 1e-5
_compare_solution opt_two_tariffs
* a bound that binds: the optimum of 0.30 is above 0.2
quietly cge_shock, reset
cge_optimize, instruments(tm(com_man)) maximize(`ev') lower(tm(com_man):0) upper(tm(com_man):0.2) name(opt_bound)
_compare_optimum opt_bound 1e-8
* an objective with a target: tariff revenue at its base value
quietly cge_shock, reset
cge_optimize, instruments(tm(com_agr) tm(com_man)) maximize(`ev') targets(government tax_import = 8) name(opt_revenue)
assert r(converged) == 1
assert reldif(el(r(targets), 1, 1), 8) < 1e-9
_compare_optimum opt_revenue 1e-5
_compare_solution opt_revenue

* ---------------------------------------------------------------------
* 3. Errors
* ---------------------------------------------------------------------
quietly cge_shock, reset
capture noisily cge_optimize, instruments(W(lab)) maximize(`ev')
assert _rc == 459
capture noisily cge_optimize, instruments(tm(com_man))
assert _rc == 198
capture noisily cge_optimize, instruments(tm(xyz)) maximize(`ev')
assert _rc == 111
capture noisily cge_optimize, instruments(tm(com_man)) maximize(macro nothing)
assert _rc == 111
capture noisily cge_optimize, instruments(tm(com_man)) maximize(`ev') lower(tm(com_man):0.5)
assert _rc == 459
capture noisily cge_optimize, instruments(tm(com_man) tm(com_man)) maximize(`ev')
assert _rc == 198
capture noisily cge_optimize, instruments(tm(com_man)) maximize(`ev') minimize(`ev')
assert _rc == 198
program drop _compare_optimum _compare_solution
