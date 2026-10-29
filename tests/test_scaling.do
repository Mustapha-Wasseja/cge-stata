* test_scaling.do -- Ruiz's equilibration of Newton's linear systems
* (version 0.33.0; docs/model_spec.md, Section 43): the scaled rows and
* columns of the Jacobian and its condition number, dense and from its
* entries; the same solutions and iterations with and without scaling, with
* the dense and the sparse LU, for a SAM-based model, a badly scaled
* standalone model, constraints by the semismooth method, a run with
* foresight and linked regions; the setting saved with the model; errors.

version 13.0

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local instmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)             ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)

_cge_load
capture mata: mata drop _ts_diff()
capture mata: mata drop _ts_runs()
mata:
// The largest difference between simulations a and b, relative to the
// scale of each variable
real scalar _ts_diff(string scalar a, string scalar b)
{
    struct cge_model scalar M
    M = _cge_load()
    return(max(abs(M.simx[., _cge_find(M.simname, a)] - M.simx[., _cge_find(M.simname, b)]) :/ M.xscale))
}

// The same for the periods of dynamic runs a and b
real scalar _ts_runs(string scalar a, string scalar b)
{
    struct cge_model scalar M
    real colvector sa, sb
    M = _cge_load()
    sa = select((1::rows(M.simname)), M.simrun :== a)
    sb = select((1::rows(M.simname)), M.simrun :== b)
    sa = sa[order(M.simper[sa], 1)]
    sb = sb[order(M.simper[sb], 1)]
    if (rows(sa) != rows(sb) | !rows(sa)) return(.)
    return(max(abs(M.simx[., sa'] - M.simx[., sb']) :/ M.xscale))
}
end

* A solve with each scaling: the same solution and iterations
capture program drop _ts_both
program define _ts_both
    args what lin
    foreach sc in none ruiz {
        quietly cge_options, scaling(`sc') linsolver(`lin')
        quietly cge_solve, name(`sc') tolerance(1e-12)
        assert r(converged) == 1
        local it_`sc' = r(iterations)
    }
    mata: st_numscalar("ts_d", _ts_diff("none", "ruiz"))
    display as text "`what' (`lin'): iterations `it_none' and `it_ruiz'; solutions " as result %9.2e scalar(ts_d)
    assert scalar(ts_d) < 1e-10
    quietly cge_options, reset
end

* ---------------------------------------------------------------------
* 1. The Jacobian of a SAM-based model, equilibrated
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
mata: _cge_ruizcheck()
display as text "SAM model, " r(N) " columns: condition " as result %9.2e r(cond) as text ", equilibrated " ///
    as result %9.2e r(cond_ruiz) as text "; row norms " r(rmin) " to " r(rmax) ", columns " r(cmin) " to " r(cmax)
assert r(rmin) > 0.8 & r(rmax) < 1.25 & r(cmin) > 0.8 & r(cmax) < 1.25
assert r(sparse_dense) < 1e-12
cge_shock tm, value(0)
_ts_both "tariff removal" dense
_ts_both "tariff removal" sparse
* the setting, saved with the model and reset
cge_options, scaling(ruiz)
assert "`r(scaling)'" == "ruiz"
tempfile mf
quietly cge_save using "`mf'", replace
quietly cge_use using "`mf'"
cge_options
assert "`r(scaling)'" == "ruiz"
cge_options, reset
assert "`r(scaling)'" == "none"
capture noisily cge_options, scaling(other)
assert _rc == 198

* ---------------------------------------------------------------------
* 2. A badly scaled standalone model: each variable enters every equation
*    with a coefficient from 1e-5 to 1e5, so that its column is badly
*    scaled whatever the scales of the rows; both settings find the same
*    root
* ---------------------------------------------------------------------
cge_model new
local labs
forvalues j = 1/40 {
    local labs `labs' g`j'
}
cge_set i = `labs'
cge_parameter b(i) = 10^(ord(i) / 4 - 5)
cge_parameter rhs(i) = sum(i2, b(i2)) * 2 / 40 + 4 * b(i)
cge_variable X(i), value(1)
cge_equation EX(i): sum(i2, b(i2) * X(i2)) / 40 + b(i) * X(i)^2 = rhs(i)
mata: _cge_ruizcheck()
display as text "badly scaled model: condition " as result %9.2e r(cond) as text ", equilibrated " as result %9.2e r(cond_ruiz)
assert r(cond_ruiz) < r(cond) / 10
_ts_both "badly scaled model" dense
_ts_both "badly scaled model" sparse

* ---------------------------------------------------------------------
* 3. Constraints by the semismooth method: a quota on imports
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
cge_constraint QM, elements(com_man) upper(1.01) scale rents(gov)
cge_shock tm, value(0)
_ts_both "import quota" dense
_ts_both "import quota" sparse
quietly cge_constraint, clear

* ---------------------------------------------------------------------
* 4. A run with foresight (the sparse LU of the stacked system)
* ---------------------------------------------------------------------
quietly cge_shock, reset
quietly cge_closure, factors(cap:specific)
foreach sc in none ruiz {
    quietly cge_options, scaling(`sc')
    quietly cge_dynamic, name(fs_`sc') periods(0/3) capital(cap) depreciation(0.05) rental(0.15) ///
        growth(lab:0.02) population(0.02) govgrowth(0.03) foreigngrowth(0.01) tfp(0.01) foresight
}
quietly cge_options, reset
mata: st_numscalar("ts_d", _ts_runs("fs_none", "fs_ruiz"))
display as text "foresight: runs " as result %9.2e scalar(ts_d)
assert scalar(ts_d) < 1e-10

* ---------------------------------------------------------------------
* 5. Linked regions (the first region's setting)
* ---------------------------------------------------------------------
clear
input str4 exporter str4 importer str8 commodity double value double tariff
A B com_agr 8 .
A B com_man 24 0.08
B A com_man 30 .
end
tempfile trade
quietly save `trade'
foreach sc in none ruiz {
    capture noisily cge_region clear
    quietly cge_synthetic, clear
    quietly cge_sam, labels(account)
    quietly cge_map, `stdmap'
    quietly cge_calibrate, `sigmas'
    quietly cge_options, scaling(`sc')
    quietly cge_region add A
    quietly cge_synthetic, clear institutions
    quietly cge_sam, labels(account)
    quietly cge_map, `instmap'
    quietly cge_calibrate, `sigmas'
    quietly cge_region add B, units(2)
    use `trade', clear
    quietly cge_region trade, exporter(exporter) importer(importer) commodity(commodity) value(value) tariff(tariff)
    quietly cge_region tariff, from(A B) to(A B) value(0)
    quietly cge_region solve, name(fta)
    local it_`sc' = r(iterations)
    quietly cge_region select B
    quietly cge_results, sim(fta) clear nodisplay
    tempfile r_`sc'
    quietly save `r_`sc''
}
use `r_none', clear
rename value v_none
quietly merge 1:1 variable element1 element2 using `r_ruiz', keepusing(value)
assert _merge == 3
generate double rel = abs(value - v_none) / max(1, abs(v_none))
quietly summarize rel
display as text "linked regions: iterations `it_none' and `it_ruiz'; region B " as result %9.2e r(max)
assert r(max) < 1e-10
capture noisily cge_region clear
program drop _ts_both
