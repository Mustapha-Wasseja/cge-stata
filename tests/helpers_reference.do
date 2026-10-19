* helpers_reference.do -- programs that compare Stata results with the Python
* reference (expected files in tests/expected); used by several test files

version 13.0

* Simulation results of the current model are compared with expected/<name>.csv
capture program drop _compare_reference
program define _compare_reference
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
    quietly generate double basediff = abs(base - ref_base) / max(1, abs(ref_base))
    quietly summarize basediff
    assert r(max) < 1e-9
    quietly summarize reldiff
    display as text "`sim': " as result _N as text " values, largest relative difference " ///
        as result %9.2e r(max)
    assert r(max) < 1e-6
end

* The five standard simulations on the calibrated model in memory
* (an optional prefix selects the expected files, e.g. inst_ for inst_<name>.csv)
capture program drop _standard_simulations
program define _standard_simulations
    args prefix
    cge_shock, reset
    cge_shock tm, value(0)
    cge_solve, name(`prefix'tariff_removal) tolerance(1e-12)
    cge_shock, reset
    cge_shock pwm, scale(1.1)
    cge_solve, name(`prefix'import_price_up10) tolerance(1e-12)
    cge_shock, reset
    cge_shock QFS, elements(lab) scale(1.05)
    cge_solve, name(`prefix'labour_supply_up5) tolerance(1e-12)
    cge_shock, reset
    cge_shock FSAV, scale(0.8)
    cge_solve, name(`prefix'foreign_savings_down20) tolerance(1e-12)
    cge_shock, reset
    cge_shock ad, elements(act_agr) scale(1.05)
    cge_solve, name(`prefix'agri_productivity_up5) tolerance(1e-12)
    foreach sim in tariff_removal import_price_up10 labour_supply_up5 ///
        foreign_savings_down20 agri_productivity_up5 {
        _compare_reference `prefix'`sim'
    }
end

* Report measures of a simulation are compared with expected/report_<name>.csv
* (or another file named in the second argument)
capture program drop _compare_report
program define _compare_report
    args sim file
    if "`file'" == "" local file report_`sim'
    tempfile stata
    quietly cge_report, sims(`sim') clear nodisplay
    keep table measure element base value
    quietly save `stata'
    quietly import delimited using "expected/`file'.csv", varnames(1) case(preserve) ///
        stringcols(1 2 3) asdouble clear
    rename (base value) (ref_base ref_value)
    quietly merge 1:1 table measure element using `stata'
    assert _merge == 3
    quietly generate double rel = abs(value - ref_value) / max(1, abs(ref_value))
    quietly generate double relb = abs(base - ref_base) / max(1, abs(ref_base))
    quietly summarize relb
    assert r(max) < 1e-9
    quietly summarize rel
    display as text "report `sim': " as result _N as text " measures, largest relative difference " ///
        as result %9.2e r(max)
    assert r(max) < 1e-6
end

* Results of one period of a dynamic run compared with expected/<file>.csv
capture program drop _compare_period
program define _compare_period
    args sim file
    tempfile stata
    quietly cge_results, sim(`sim') clear nodisplay
    quietly save `stata'
    quietly import delimited using "expected/`file'.csv", varnames(1) case(preserve) ///
        stringcols(1 2 3) asdouble clear
    rename (base value) (ref_base ref_value)
    quietly merge 1:1 variable element1 element2 using `stata'
    assert _merge == 3
    quietly generate double reldiff = abs(value - ref_value) / max(1, abs(ref_value)) if variable != "WALRAS"
    quietly summarize reldiff
    local worst = r(max)
    quietly summarize value if variable == "WALRAS"
    assert abs(r(mean)) < 1e-8
    display as text "`sim' (`file'): " as result _N as text " values, largest relative difference " ///
        as result %9.2e `worst'
    assert `worst' < 1e-8
end
