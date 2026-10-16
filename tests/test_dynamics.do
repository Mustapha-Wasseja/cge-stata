* test_dynamics.do -- recursive dynamics (version 0.2.0; docs/model_spec.md,
* Section 10): every period of each run agrees with the Python reference
* (expected/dyn_<run>_p<period>.csv and dyn_<run>_tfp.csv)

version 13.0

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

* Efficiency factors of a run compared with expected/dyn_<run>_tfp.csv
capture program drop _compare_tfp
program define _compare_tfp
    args run file
    preserve
    quietly import delimited using "expected/`file'_tfp.csv", varnames(1) asdouble clear
    forvalues t = 1/`=_N' {
        local ref = lambda[`t']
        mata: st_numscalar("cge_test_lam", _cge_test_lam("`run'", `t'))
        assert abs(scalar(cge_test_lam) - `ref') < 1e-10
    }
    restore
    display as text "efficiency factors of `run' agree with `file'"
end

* The Mata library defines the model structure that the helper below uses
_cge_load
mata:
real scalar _cge_test_lam(string scalar run, real scalar period)
{
    struct cge_model scalar M
    real colvector s
    M = _cge_load()
    s = select((1::rows(M.simname)), (M.simrun :== run) :* (M.simper :== period))
    return(M.simlam[s[1]])
}
end

local common capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02) population(0.02) ///
    govgrowth(0.03) foreigngrowth(0.01)

* Standard layout, capital specific to each activity, efficiency growth of 1 per cent
quietly do setup_synthetic.do
quietly cge_closure, factors(cap:specific)
cge_dynamic, name(std) periods(0/4) `common' tfp(0.01)
assert "`r(sims)'" == "std0 std1 std2 std3 std4"
forvalues t = 0/4 {
    _compare_period std`t' dyn_std_p`t'
}

* Efficiency calibrated to real growth of 4 per cent
cge_dynamic, name(target) periods(0/4) `common' gdpgrowth(0.04)
forvalues t = 0/4 {
    _compare_period target`t' dyn_target_p`t'
}
_compare_tfp target dyn_target
* The model is left as it was: base parameters and closure
quietly cge_solve, name(after)
assert r(iterations) == 0

* Institutions layout with LES demand, mobile capital, efficiency growth by activity
cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)                ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1 1.4) frisch(-2 -3)
cge_dynamic, name(inst) periods(0/4) capital(cap) depreciation(0.06) rental(0.12) growth(lab:0.025) ///
    population(0.025) govgrowth(0.03) foreigngrowth(0.02) tfp(0.02 0.01 0)
forvalues t = 0/4 {
    _compare_period inst`t' dyn_inst_p`t'
}

* Health layout: a baseline calibrated to 3 per cent growth, and a donor exit
* from the insurance fund from period 2 that keeps the baseline's efficiency
capture program drop _donor_exit
program define _donor_exit
    args t
    if `t' >= 2 cge_shock trshir, value(0)
end
cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                            ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) healthcom(com_hlt) healthfac(lab) healthelas(0.3)
quietly cge_closure, factors(cap:specific)
cge_dynamic, name(health) periods(0/4) `common' gdpgrowth(0.03)
cge_dynamic, name(exit) periods(0/4) `common' baseline(health) shocks(_donor_exit)
forvalues t = 0/4 {
    _compare_period health`t' dyn_health_p`t'
    _compare_period exit`t' dyn_health_exit_p`t'
}
_compare_tfp health dyn_health

* Results of a run against its baseline, and the report of a run
cge_dynresults, run(exit) baseline(health) clear
assert abs(dev_pct) < 1e-10 if period <= 1 & !missing(dev_pct)
quietly summarize dev_pct if variable == "SHIADJ" & period == 4
assert r(mean) < 0
cge_report, run(exit) tables(health) nodisplay
assert r(N_sims) == 5

* The runs are saved and loaded with the model
tempfile fn
local fn "`fn'.cgem"
cge_save using "`fn'", replace
mata: rmexternal("cge__model")
cge_use using "`fn'"
cge_dynresults, run(exit) baseline(health) clear
assert _N > 0

* Errors
capture cge_dynamic, name(bad) periods(0/2) capital(cap)
assert _rc == 198
capture cge_dynamic, name(bad) periods(0/2) growth(cap:0.01) capital(cap) depreciation(0.05) rental(0.15)
assert _rc == 198
capture cge_dynamic, name(bad) periods(0/2) tfp(0.01) gdpgrowth(0.03)
assert _rc == 198
capture cge_dynamic, name(bad) periods(0/2) baseline(nosuchrun)
assert _rc == 111
capture cge_dynamic, name(bad) periods(0/2) growth(land:0.01)
assert _rc == 111
capture cge_dynresults, run(nosuchrun) clear
assert _rc == 111

program drop _compare_period _compare_tfp _donor_exit
