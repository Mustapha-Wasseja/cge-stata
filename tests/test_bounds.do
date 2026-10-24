* test_bounds.do -- attributes of variables, cge_bound (version 0.9.8), the
* solution listing with its marginals, and the marginals of the optimiser.
* Checked against the solutions without the attributes, the constraints'
* own variables and, for the optimiser, the change in the optimum when a bound
* or target moves; tools/gams checks the GAMS program and GAMS's marginals

version 13.0
quietly do helpers_reference.do

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local ev welfare equivalent_variation hhd


* ---------------------------------------------------------------------
* 1. Bounds that do not bind, scales and starting levels leave the
*    solution as it was
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
* the largest difference between two simulations, relative to the scales
capture mata: mata drop _tb_diff() _tb_scale()
mata:
real scalar _tb_diff(string scalar a, string scalar b)
{
    struct cge_model scalar M
    M = _cge_load()
    return(max(abs(M.simx[., _cge_sim_index(M, a)] - M.simx[., _cge_sim_index(M, b)]) :/ M.xscale))
}
// the solver's scale of an element
real scalar _tb_scale(string scalar spec)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.xscale[_cge_specpos(M, spec, "test")])
}
end
cge_shock tm, value(0)
quietly cge_solve, name(plain) tolerance(1e-12)
local it0 = r(iterations)
cge_bound QM, lower(0.5) upper(2) relative
assert r(N_elements) == 3 & r(N_lower) == 3 & r(N_upper) == 3
cge_bound PQ(com_man), lower(0.5)
assert r(N_elements) == 1 & r(N_lower) == 4
cge_bound QF, elements(lab.act_agr cap.act_man) lower(1)
assert r(N_elements) == 2
cge_bound QA(act_man), scale(1000)
cge_bound EXR, level(1.3)
cge_bound QE, level(1.2) relative
cge_bound, list
assert r(N_definitions) == 6 & r(N_lower) == 6 & r(N_upper) == 3 & r(N_scales) == 1 & r(N_levels) == 4
mata: st_numscalar("sc", _tb_scale("QA(act_man)"))
assert scalar(sc) == 1000
cge_solve, name(bounded) tolerance(1e-12)
assert r(converged) == 1 & r(N_atbound) == 0
mata: st_numscalar("d1", _tb_diff("plain", "bounded"))
display as text "with bounds, a scale and starting levels: " as result %9.2e d1
assert d1 < 1e-10
* the listing gives the bounds: QM within half and twice its base
quietly cge_listing, sim(bounded) solution clear
quietly count if kind == "VAR"
local nvar = r(N)
foreach c in com_agr com_man com_ser {
    quietly cge_results, sim(bounded) clear nodisplay
    quietly summarize base if variable == "QM" & element1 == "`c'"
    local b = r(mean)
    quietly summarize value if variable == "QM" & element1 == "`c'"
    local v = r(mean)
    quietly cge_listing, sim(bounded) solution clear
    quietly summarize lower if kind == "VAR" & name == "QM" & element == "`c'"
    assert reldif(r(mean), 0.5 * `b') < 1e-14
    quietly summarize upper if kind == "VAR" & name == "QM" & element == "`c'"
    assert reldif(r(mean), 2 * `b') < 1e-14
    quietly summarize level if kind == "VAR" & name == "QM" & element == "`c'"
    assert reldif(r(mean), `v') < 1e-14
}
* a later definition replaces an earlier one; inf removes a bound
cge_bound QM(com_man), upper(inf)
cge_bound, list
assert r(N_upper) == 2
* clearing a variable's attributes gives back the automatic scale
quietly cge_results, sim(plain) clear nodisplay
quietly summarize base if variable == "QA" & element1 == "act_man"
local qa0 = r(mean)
cge_bound QA, clear
mata: st_numscalar("sc", _tb_scale("QA(act_man)"))
assert reldif(scalar(sc), `qa0') < 1e-14

* ---------------------------------------------------------------------
* 2. Bounds at and beyond the solution
* ---------------------------------------------------------------------
quietly cge_results, sim(plain) clear nodisplay
quietly summarize value if variable == "QM" & element1 == "com_man"
local qm1 = r(mean)
* a bound just above the solution: solved, with a note that it is active
cge_bound QM(com_man), upper(`=`qm1' * (1 + 1e-11)')
cge_solve, name(atbound) tolerance(1e-12)
assert r(converged) == 1 & r(N_atbound) == 1
mata: st_numscalar("d2", _tb_diff("plain", "atbound"))
assert d2 < 1e-9
* a bound below the solution: the solve fails, against the bound
cge_bound QM(com_man), upper(61)
capture noisily cge_solve, name(beyond)
assert _rc == 430
cge_bound QM(com_man), upper(inf)
* the starting levels must lie within the bounds, the base too
capture noisily cge_bound QM(com_man), lower(70)
assert _rc == 459
capture noisily cge_bound QA(act_man), level(5) lower(10)
assert _rc == 459
capture noisily cge_bound PQ(com_agr), level(-1)
assert _rc == 459
capture noisily cge_bound QM(com_man), lower(2) upper(1)
assert _rc == 198
cge_bound, list
assert r(N_definitions) == 9

* ---------------------------------------------------------------------
* 3. fix(): the value of an exogenous variable, as cge_shock sets it
* ---------------------------------------------------------------------
cge_bound, clear
quietly cge_shock, reset
cge_bound FSAV, fix(12)
quietly cge_solve, name(fix1) tolerance(1e-12)
quietly cge_shock, reset
cge_shock FSAV, value(12)
quietly cge_solve, name(fix2) tolerance(1e-12)
mata: st_numscalar("d3", _tb_diff("fix1", "fix2"))
assert d3 == 0
cge_bound FSAV, fix(1.5) relative
quietly cge_results, clear nodisplay
quietly cge_solve, name(fix3) tolerance(1e-12)
quietly cge_results, sim(fix3) clear nodisplay
quietly summarize value if variable == "FSAV"
local f3 = r(mean)
quietly summarize base if variable == "FSAV"
assert reldif(`f3', 1.5 * r(mean)) < 1e-14
* fixed outside its bounds: the solve stops
cge_bound FSAV, lower(0.9) relative
capture noisily cge_bound FSAV, fix(0.5) relative
assert _rc == 0
capture noisily cge_solve, name(fixout)
assert _rc == 459
* fixing an endogenous variable, or a level for a fixed one, is an error
capture noisily cge_bound QA(act_man), fix(100)
assert _rc == 459
capture noisily cge_bound FSAV, level(10)
assert _rc == 459
capture noisily cge_bound FSAV, fix(10) lower(1)
assert _rc == 198
cge_bound, clear
quietly cge_shock, reset

* ---------------------------------------------------------------------
* 4. Errors
* ---------------------------------------------------------------------
capture noisily cge_bound pwm, lower(0)
assert _rc == 198
capture noisily cge_bound QM(com_xyz), lower(0)
assert _rc == 111
capture noisily cge_bound QF(lab), lower(0)
assert _rc == 111
capture noisily cge_bound QM, scale(-1)
assert _rc == 198
capture noisily cge_bound QM, lower(abc)
assert _rc == 198
capture noisily cge_bound QM, lower(inf)
assert _rc == 198
capture noisily cge_bound QM
assert _rc == 198
capture noisily cge_bound QM(com_man), elements(com_agr) lower(0)
assert _rc == 198
capture noisily cge_bound EXR(com_agr), lower(0)
assert _rc == 198
capture noisily cge_bound, list clear
assert _rc == 198

* ---------------------------------------------------------------------
* 5. Saved, loaded and calibrated again; the attributes of user variables
*    go with them
* ---------------------------------------------------------------------
cge_variable RP(c) = PQ(c) / CPI
cge_bound RP, lower(0.8) upper(1.25)
cge_bound QM, lower(0.5) relative
cge_bound QA(act_agr), scale(10)
tempfile sv
quietly cge_save using "`sv'", replace
quietly cge_use using "`sv'"
cge_bound, list
assert r(N_definitions) == 3 & r(N_lower) == 6 & r(N_upper) == 3 & r(N_scales) == 1
mata: st_numscalar("sc", _tb_scale("QA(act_agr)"))
assert scalar(sc) == 10
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_bound, list
assert r(N_definitions) == 3 & r(N_lower) == 6 & r(N_scales) == 1
mata: st_numscalar("sc", _tb_scale("QA(act_agr)"))
assert scalar(sc) == 10
cge_shock tm, value(0)
quietly cge_solve, name(kept) tolerance(1e-12)
assert r(converged) == 1 & r(N_atbound) == 0
cge_equation, clear
cge_bound, list
assert r(N_definitions) == 2 & r(N_lower) == 3 & r(N_upper) == 0

* ---------------------------------------------------------------------
* 6. The GAMS program: bounds of free variables, scales and levels
* ---------------------------------------------------------------------
cge_bound EXR, level(1.1)
cge_bound PQ(com_man), lower(0.5) upper(2)
cge_bound FSAV, lower(0)
quietly cge_solve, name(gb) tolerance(1e-12)
tempfile gd
quietly cge_gams using "`gd'_b", sim(gb) replace
mata:
u = cat(st_local("gd") + "_b/cge_bounds.inc")
st_numscalar("okg", (sum(u :== "QM.lo('com_man') = 30;") == 1) + (sum(u :== "PQ.up('com_man') = 2;") == 1) +
             (sum(u :== "QA.scale('act_agr') = 10;") == 1) + (sum(strpos(u, "scaleopt = 1") :> 0) == 1) +
             (sum(u :== "EXR.l = 1.1;") == 1) + (sum(strpos(u, "FSAV.") :> 0) == 0))
d = cat(st_local("gd") + "_b/cge_run.gms")
st_numscalar("okd", sum(d :== char(36) + "include cge_bounds.inc"))
end
assert scalar(okg) == 6
assert scalar(okd) == 1
cge_bound, clear
quietly cge_shock, reset

* ---------------------------------------------------------------------
* 7. The solution listing: levels, bounds and the marginals of constraints
* ---------------------------------------------------------------------
cge_shock tm, value(0)
cge_constraint QM, elements(com_man) upper(1.02) scale
cge_constraint QM, elements(com_agr) upper(2) scale
cge_solve, name(quota) tolerance(1e-12)
cge_listing, sim(quota) solution
assert r(N_constraints) == 2 & r(N_binding) == 1
matrix mg = r(marginals)
matrix rm = r(room)
quietly cge_results, sim(quota) clear nodisplay
quietly summarize value if variable == "RM" & element1 == "com_man"
local rm = r(mean)
quietly summarize value if variable == "QM" & element1 == "com_agr"
local qa = r(mean)
quietly summarize base if variable == "QM" & element1 == "com_agr"
local qa0 = r(mean)
* the quota binds: no room, and its marginal is the premium
assert abs(rm[1, 1]) < 1e-9 & reldif(mg[1, 1], `rm') < 1e-14 & `rm' > 0
* the other limit does not: its room is the gap, and its marginal zero
assert reldif(rm[1, 2], 2 * `qa0' - `qa') < 1e-12 & mg[1, 2] == 0
* the dataset: every variable and equation element; fixed variables at their
* level, free ones unbounded; equation residuals that are zero at a solution
cge_listing, sim(quota) solution clear
assert _N == r(N_variables) + r(N_equations)
quietly count if kind == "VAR"
assert r(N) == `nvar'
assert lower == upper & lower == level if kind == "VAR" & name == "GADJ"
assert missing(lower) & missing(upper) if kind == "VAR" & name == "QA"
assert missing(lower) & missing(upper) if kind == "VAR" & name == "RM" & element == "com_man"
quietly summarize level if kind == "EQU" & name != "B1"
assert max(abs(r(min)), abs(r(max))) < 1e-8
quietly summarize marginal if kind == "EQU" & name == "B1" & element == "QM(com_man)"
assert reldif(r(mean), `rm') < 1e-14
quietly count if !missing(marginal)
assert r(N) == 2
* a lower limit with its variable moving down: GSAV at least its base, with
* GADJ falling; the marginal is the fall
quietly cge_constraint, clear
quietly cge_shock, reset
cge_shock tm, value(0)
cge_constraint GSAV, lower(1) scale adjust(GADJ) down
quietly cge_solve, name(ceiling) tolerance(1e-12)
quietly cge_listing, sim(ceiling) solution
matrix mg = r(marginals)
quietly cge_results, sim(ceiling) clear nodisplay
quietly summarize value if variable == "GADJ"
assert reldif(mg[1, 1], 1 - r(mean)) < 1e-12 & mg[1, 1] > 0
* blocks and variables listed on request
cge_listing, sim(ceiling) solution variables(GADJ GSAV) blocks(T5 B1)
capture noisily cge_listing, solution variables(QXX)
assert _rc == 198
capture noisily cge_listing, solution blocks(ZZ9)
assert _rc == 198
capture noisily cge_listing, variables(QM)
assert _rc == 198
quietly cge_constraint, clear
quietly cge_shock, reset

* ---------------------------------------------------------------------
* 8. The optimiser's marginals: the change in the optimum per unit of a
*    constraint's bound, a target and an instrument's bound, against the
*    optima when they move
* ---------------------------------------------------------------------
* a constraint that binds: imports of manufactures at least 98 per cent of
* the base, government revenue maximised
quietly cge_results, sim(ceiling) clear nodisplay
quietly summarize base if variable == "QM" & element1 == "com_man"
local b = 0.98 * r(mean)
local h = 1e-3 * `b'
cge_optimize, instruments(tm(com_man)) maximize(YG) constraints(QM(com_man) >= `b') ///
    lower(tm(com_man):0) upper(tm(com_man):2) name(om0)
assert r(converged) == 1 & r(N_binding) == 1
local m0 = el(r(constraint_marginals), 1, 1)
assert el(r(instrument_marginals), 1, 1) == 0
foreach s in 1 -1 {
    quietly cge_shock, reset
    quietly cge_optimize, instruments(tm(com_man)) maximize(YG) constraints(QM(com_man) >= `=`b' + `s' * `h'') ///
        lower(tm(com_man):0) upper(tm(com_man):2) name(om`=`s' + 1')
    local f`=`s' + 1' = r(objective)
}
local fd = (`f2' - `f0') / (2 * `h')
display as text "constraint marginal " as result %12.8f `m0' as text ", from the optima " as result %12.8f `fd'
assert reldif(`m0', `fd') < 1e-4 & `m0' < 0
* minimised, the marginal changes sign
quietly cge_shock, reset
cge_optimize, instruments(tm(com_man)) minimize(-YG) constraints(QM(com_man) >= `b') ///
    lower(tm(com_man):0) upper(tm(com_man):2) name(om3)
assert reldif(el(r(constraint_marginals), 1, 1), -`m0') < 1e-4
* a target: tariff revenue held at 8, welfare maximised over two tariffs
quietly cge_shock, reset
quietly cge_closure, government(fixgsav)
cge_optimize, instruments(tm(com_agr) tm(com_man)) maximize(`ev') targets(government tax_import = 8) name(ot0)
assert r(converged) == 1
local m0 = el(r(target_marginals), 1, 1)
foreach s in 1 -1 {
    quietly cge_shock, reset
    quietly cge_optimize, instruments(tm(com_agr) tm(com_man)) maximize(`ev') targets(government tax_import = `=8 + `s' * 0.01') ///
        name(ot`=`s' + 1')
    local f`=`s' + 1' = r(objective)
}
local fd = (`f2' - `f0') / 0.02
display as text "target marginal " as result %12.8f `m0' as text ", from the optima " as result %12.8f `fd'
assert reldif(`m0', `fd') < 1e-4
* an instrument at its upper bound: its reduced cost is the gain from
* raising the bound; the instruments within their bounds have none
quietly cge_shock, reset
cge_optimize, instruments(tm(com_man)) maximize(`ev') lower(tm(com_man):0) upper(tm(com_man):0.2) name(ob0)
local m0 = el(r(instrument_marginals), 1, 1)
foreach s in 1 -1 {
    quietly cge_shock, reset
    quietly cge_optimize, instruments(tm(com_man)) maximize(`ev') lower(tm(com_man):0) upper(tm(com_man):`=0.2 + `s' * 1e-4') ///
        name(ob`=`s' + 1')
    local f`=`s' + 1' = r(objective)
}
local fd = (`f2' - `f0') / 2e-4
display as text "reduced cost " as result %12.8f `m0' as text ", from the optima " as result %12.8f `fd'
assert reldif(`m0', `fd') < 1e-4 & `m0' > 0
quietly cge_shock, reset
cge_optimize, instruments(tm(com_man)) maximize(`ev') lower(tm(com_man):-0.5) upper(tm(com_man):1) name(oi)
assert el(r(instrument_marginals), 1, 1) == 0
* targets alone have no objective, so no marginals
quietly cge_shock, reset
quietly cge_closure, government(flexgsav)
cge_optimize, instruments(TINSADJ) targets(government savings = 3) name(onone)
capture confirm matrix r(target_marginals)
assert _rc
quietly cge_shock, reset
mata: mata drop _tb_diff() _tb_scale()
