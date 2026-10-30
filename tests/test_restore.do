* test_restore.do -- feasibility restoration of the interior point and the
* infeasibility finder (version 0.36.0; docs/model_spec.md, Section 46):
* the counterexample of Wachter and Biegler (2000) solved to its solution; a
* locally infeasible programme reported as such; the nonlinear programmes of
* the tests solved as before; irreducible infeasible sets of bounds and
* constraints of a SAM-based model, one bound among others that do not bind
* and a quota whose rent is capped; errors.

version 13.0

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)

_cge_load
capture mata: mata drop _tre_off()
capture mata: mata drop _tre_val()
mata:
// Restoration off (1) or on (0)
void _tre_off(real scalar off)
{
    pointer() scalar q
    if ((q = findexternal("cge__norest")) == NULL) q = crexternal("cge__norest")
    *q = off
}

// The value of variable v, element el ("" for a scalar), in simulation s
real scalar _tre_val(string scalar s, string scalar v, string scalar el)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.simx[_cge_u_vpos(M, v, el), _cge_find(M.simname, s)])
}
end

* ---------------------------------------------------------------------
* 1. Wachter and Biegler's example: min x1 subject to x1^2 = x2 + 1, x1 =
*    x3 + 1/2, x2 >= 0, x3 >= 0, from (-2, 3, 1), where the linearised
*    equations and the bounds cannot hold together; the solution is
*    (1, 0, 1/2). Without restoration the interior point stops; with it, it
*    reaches the solution
* ---------------------------------------------------------------------
capture program drop _tre_wb
program define _tre_wb
    args form x1 x2 x3
    quietly cge_model new
    quietly cge_variable X1, value(`x1')
    quietly cge_variable X2, value(`x2')
    quietly cge_variable X3, value(`x3')
    if `form' == 1 {
        quietly cge_equation c1: X1^2 = X2 + 1
        quietly cge_equation c2: X1 = X3 + 0.5
    }
    else {
        quietly cge_equation c1: X1^2 - X2 - 1 = 0
        quietly cge_equation c2: X1 - X3 - 0.5 = 0
    }
    quietly cge_bound X2, lower(0)
    quietly cge_bound X3, lower(0)
end
_tre_wb 1 -2 3 1
cge_solve, name(wb) minimize(X1)
assert r(converged) == 1 & r(modelstat) == 2 & r(N_restorations) >= 1
local nrest = r(N_restorations)
foreach v in X1 X2 X3 {
    mata: st_local("`v'", strofreal(_tre_val("wb", "`v'", ""), "%21.15g"))
}
display as text "Wachter-Biegler: (" `X1' ", " `X2' ", " `X3' "), " `nrest' " restoration(s)"
assert abs(`X1' - 1) < 1e-6 & abs(`X2') < 1e-6 & abs(`X3' - 0.5) < 1e-6
* without restoration
mata: _tre_off(1)
capture noisily cge_solve, name(wb0) minimize(X1)
local rc0 = _rc
local conv0 = r(converged)
local nr0 = r(N_restorations)
mata: _tre_off(0)
assert `rc0' == 430 & `conv0' == 0 & `nr0' == 0
* the other starts that the interior point could not solve alone
foreach st in "-2 1 1" "-3 8 1" {
    _tre_wb 1 `st'
    quietly cge_solve, name(wbs) minimize(X1)
    mata: st_local("X1", strofreal(_tre_val("wbs", "X1", ""), "%21.15g"))
    assert r(converged) == 1 & r(N_restorations) >= 1 & abs(`X1' - 1) < 1e-6
    mata: _tre_off(1)
    capture quietly cge_solve, name(wbs0) minimize(X1)
    local rc0 = _rc
    mata: _tre_off(0)
    assert `rc0' == 430
}

* ---------------------------------------------------------------------
* 2. Stationary points of the infeasibility. Written as x1^2 - x2 - 1 = 0
*    and x1 - x3 - 1/2 = 0, the scaled residuals have a local minimum near
*    x1 = -1, toward which the iterates from (-2, 3, 1) go: without
*    restoration the interior point takes every iteration it is given, with
*    it, it stops there, locally infeasible. x + y = 5 with x, y <= 1 has no
*    solution at all
* ---------------------------------------------------------------------
_tre_wb 2 -2 3 1
mata: _tre_off(1)
capture noisily cge_solve, name(st0) minimize(X1)
assert _rc == 430 & r(modelstat) == 6 & r(solvestat) == 2
mata: _tre_off(0)
capture noisily cge_solve, name(st1) minimize(X1)
assert _rc == 430 & r(modelstat) == 5 & r(iterations) < 20
mata: st_local("X1", strofreal(_tre_val("st1", "X1", ""), "%21.15g"))
assert `X1' < -0.9 & `X1' > -1.1
cge_model new
cge_variable X, value(0.5)
cge_variable Y, value(0.5)
cge_equation e: X + Y = 5
cge_bound X, upper(1)
cge_bound Y, upper(1)
capture noisily cge_solve, name(inf) minimize(X^2 + Y^2)
assert _rc == 430 & r(converged) == 0 & r(modelstat) == 5
* the nonlinear programmes that solve without restoration solve as before:
* a start in the region of the solution
_tre_wb 2 0.6 0.1 0.1
cge_solve, name(near) minimize(X1)
assert r(converged) == 1 & r(N_restorations) == 0 & r(iterations) == 9

* ---------------------------------------------------------------------
* 3. Irreducible infeasible sets of a SAM-based model: a tariff removal
*    with imports of manufactures held below their base, among bounds that
*    do not bind
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
quietly cge_shock tm, value(0)
cge_bound QM(com_man), upper(1) relative
cge_bound QM(com_agr), lower(0.5) relative
cge_bound PQ, lower(0.5) upper(2) relative
cge_iis, trace
assert r(N_iis) == 1 & r(N_candidates) == 8 & r(N_solves) == 10
assert strpos("`r(iis)'", "upper bound of QM(com_man)") == 1
quietly cge_bound, clear
* nothing to find when the scenario solves
cge_bound PQ, lower(0.5) upper(2) relative
cge_iis
assert r(N_iis) == 0
quietly cge_bound, clear
* a quota on imports of manufactures whose rent is capped below what the
* quota needs: the inequality and the cap together, either alone solves
cge_equation quota: QM(com_man) =l= 0.98 * base(QM(com_man)), perp(RM(com_man))
quietly cge_solve, name(q)
mata: st_local("rent", strofreal(_tre_val("q", "RM", "com_man"), "%21.15g"))
assert `rent' > 0
cge_bound RM(com_man), upper(`=`rent' / 2')
cge_bound QM(com_agr), lower(0.5) relative
cge_iis, trace
assert r(N_iis) == 2 & r(N_candidates) == 3
assert strpos("`r(iis)'", "upper bound of RM(com_man)") > 0 & strpos("`r(iis)'", "inequality quota") > 0
quietly cge_bound, clear
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 4. Errors
* ---------------------------------------------------------------------
capture noisily cge_iis
assert _rc == 459
capture noisily cge_iis, iterate(0)
assert _rc == 198
capture noisily cge_iis, tolerance(0)
assert _rc == 198
capture mata: mata drop _tre_off()
capture mata: mata drop _tre_val()
