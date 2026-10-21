* test_gams.do -- the model written as a GAMS program (version 0.4.3;
* docs/gams.md). GAMS is not needed: the comparison is checked against
* results that GAMS (PATH) wrote for the same model, kept in data/gams.
* tools/gams/run_export_check.py solves every exported case in GAMS.

version 13.0

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
tempfile tmp
local dir "`tmp'_gams"

* ---------------------------------------------------------------------
* 1. What is written
* ---------------------------------------------------------------------
cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
quietly cge_closure, external(fixexr) government(fixgsav sales) savinv(investment) numeraire(dpi) ///
    factors(cap:specific)
cge_shock pwm, scale(1.1)
cge_shock QFS, elements(lab) scale(1.05)
quietly cge_solve, name(closures) tolerance(1e-12)
cge_gams using "`dir'", sim(closures) replace
assert r(N_accounts) == 15 & r(N_changes) == 4 & "`r(name)'" == "closures"
assert "`r(closure)'" == "fixexr fixgsav:sales investment dpi lab:mobile cap:specific"
foreach f in cge_model.gms cge_closure.gms cge_write.gms cge_solve.gms cge_data.inc ///
    cge_shock_par.inc cge_shock_var.inc cge_run.gms {
    confirm file "`dir'/`f'"
}
* The data: the SAM's non-zero cells at full precision and the roles
mata:
lines = cat(st_local("dir") + "/cge_data.inc")
st_numscalar("nsam", sum(strpos(lines, "'.'") :> 0))
st_numscalar("hasA", sum(lines :== "set A(AC) /"))
st_numscalar("hasgov", sum(strpos(lines, "'gov'") :> 0))
end
capture mata: mata drop _test_gams_nz()
mata:
real scalar _test_gams_nz()
{
    struct cge_model scalar M
    M = _cge_load()
    return(sum(M.S :!= 0))
}
st_numscalar("nz", _test_gams_nz())
end
assert scalar(nsam) == scalar(nz)
assert scalar(hasA) == 1 & scalar(hasgov) >= 2
* The scenario: world import prices as ratios to GAMS's own base values,
* the closure, and labour supply as a ratio to its base level
mata:
p = cat(st_local("dir") + "/cge_shock_par.inc")
v = cat(st_local("dir") + "/cge_shock_var.inc")
st_numscalar("npwm", sum(strpos(p, "pwm('com_") :> 0))
st_numscalar("okpwm", sum(p :== "pwm('com_man') = 1.1 * pwm('com_man');"))
st_numscalar("okcl", sum(p :== "clext = 2;") + sum(p :== "clgov = 3;") + sum(p :== "clsi = 2;") +
             sum(p :== "clnum = 2;") + sum(p :== "fclo('cap') = 2;") + sum(p :== "fclo('lab') = 1;"))
st_numscalar("okqfs", sum(v :== "QFS.fx('lab') = 1.05 * QFS.l('lab');"))
end
assert scalar(npwm) == 3 & scalar(okpwm) == 1 & scalar(okcl) == 6 & scalar(okqfs) == 1
* An existing export needs replace
capture noisily cge_gams using "`dir'", sim(closures)
assert _rc == 602
cge_gams using "`dir'", sim(closures) replace

* ---------------------------------------------------------------------
* 2. Comparison with the results of GAMS (PATH) for this model
* ---------------------------------------------------------------------
copy "data/gams/cge_base.csv" "`dir'/cge_base.csv", replace
copy "data/gams/cge_closures.csv" "`dir'/cge_closures.csv", replace
cge_gams using "`dir'", sim(closures) compare noexport
assert r(modelstat) == 16 & r(base_modelstat) == 16
assert r(base_maxdiff) < 1e-14
assert r(maxdiff) < 1e-10
assert r(N_compared) == 108
assert abs(r(walras)) < 1e-9
* A different simulation does not match these results
cge_shock, reset
cge_shock pwm, scale(1.2)
quietly cge_solve, name(closures) tolerance(1e-12)
cge_gams using "`dir'", sim(closures) compare noexport
assert r(maxdiff) > 1e-3

* ---------------------------------------------------------------------
* 3. Current shocks, and errors
* ---------------------------------------------------------------------
cge_gams using "`dir'_cur", replace
assert "`r(name)'" == "current" & r(N_changes) == 3
confirm file "`dir'_cur/cge_run.gms"
capture noisily cge_gams using "`dir'", compare noexport
assert _rc == 198
capture noisily cge_gams using "`dir'", sim(closures) noexport
assert _rc == 198
capture noisily cge_gams using "`dir'", sim(closures) replace type(lp)
assert _rc == 198
capture noisily cge_gams using "`dir'", sim(nosuch) replace
assert _rc == 111
capture noisily cge_gams using "`dir'_none", sim(closures) compare noexport
assert _rc == 601
if "`c(mode)'" == "batch" & "`c(os)'" == "Windows" {
    capture noisily cge_gams using "`dir'", sim(closures) replace run
    assert _rc == 198
}
* A period of a dynamic run is not a static simulation
quietly cge_shock, reset
quietly cge_closure, external(flexexr) government(flexgsav) savinv(savings) numeraire(cpi) factors(cap:mobile)
quietly cge_dynamic, name(dyn) periods(0/1) capital(cap) depreciation(0.05) rental(0.1)
capture noisily cge_gams using "`dir'", sim(dyn1) replace
assert _rc == 198
