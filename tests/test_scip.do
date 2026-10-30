* test_scip.do -- programmes by SCIP through PySCIPOpt (version 0.42.0;
* docs/model_spec.md, Section 52). On Stata 16 and later with Python and
* PySCIPOpt: Hock and Schittkowski's problem 71 against its published
* optimum; the global minimum of a nonconvex polynomial where the interior
* point finds a local one, with and without an equation; a linear objective
* on a circle; each function against its closed form; parameters and fixed
* variables; a mixed-integer programme against branch and bound; a binary
* choice; the gap; the node limit; an infeasible programme; errors; the
* log. Without them, solver(scip) stops with an error.

version 13.0

local ok 0
if c(stata_version) >= 16 {
    * found without importing it into Stata's process
    capture python: import importlib.util; assert importlib.util.find_spec("pyscipopt") is not None
    if !_rc local ok 1
}
if !`ok' {
    display as text "Stata " c(stata_version) ": no Python with PySCIPOpt; solver(scip) stops with an error"
    cge_model new
    cge_variable x, value(1)
    cge_variable y, value(1)
    cge_equation E: x + y = 2
    capture noisily cge_solve, name(s) minimize(x^2 + y^2) solver(scip)
    assert _rc == 198
    exit
}

capture mata: mata drop _tsc_val()
_cge_load
mata:
// The value of element el of variable v in simulation s
real scalar _tsc_val(string scalar s, string scalar v, string scalar el)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.simx[_cge_u_vpos(M, v, el), _cge_find(M.simname, s)])
}
end

* ---------------------------------------------------------------------
* 1. Hock and Schittkowski (1981), problem 71: the optimum 17.0140173 at
*    (1, 4.7429994, 3.8211503, 1.3794082), with its best bound
* ---------------------------------------------------------------------
cge_model new
cge_set i = x1 x2 x3 x4
cge_parameter x0(i), values(x1:1 x2:5 x3:5 x4:1)
cge_parameter b1 = 25
cge_parameter b2 = 40
cge_variable X(i), value(x0(i))
cge_variable S, value(0)
cge_equation G1: X(x1) * X(x2) * X(x3) * X(x4) - S = b1
cge_equation G2: sum(i, X(i)^2) = b2
cge_bound X, lower(1) upper(5)
cge_bound S, lower(0)
local f71 X(x1) * X(x4) * (X(x1) + X(x2) + X(x3)) + X(x3)
cge_solve, name(sc) minimize(`f71') solver(scip)
assert r(converged) == 1 & "`r(solver)'" == "scip" & r(modelstat) == 1 & r(solvestat) == 1
assert abs(r(objective) - 17.0140173) < 1e-6
assert r(nodes) > 0 & r(N_integer) == 0
assert abs(r(bestbound) - r(objective)) < 1e-6 & r(gap) < 1e-6
local k = 0
local d = 0
foreach v in 1 4.7429994 3.8211503 1.3794082 {
    local ++k
    mata: st_local("x", strofreal(_tsc_val("sc", "X", "x`k'"), "%21.15g"))
    local d = max(`d', abs(`x' - `v'))
}
* SCIP's point is as accurate as its tolerances allow
display as text "HS071 by SCIP: distance from the published optimum " as result %9.2e `d'
assert `d' < 1e-4
* polished by the interior point from SCIP's solution
cge_solve, name(pol) minimize(`f71') from(sc)
assert r(converged) == 1 & abs(r(objective) - 17.0140173) < 1e-7
local k = 0
local d = 0
foreach v in 1 4.7429994 3.8211503 1.3794082 {
    local ++k
    mata: st_local("x", strofreal(_tsc_val("pol", "X", "x`k'"), "%21.15g"))
    local d = max(`d', abs(`x' - `v'))
}
display as text "polished by the interior point: distance " as result %9.2e `d'
assert `d' < 1e-6
* maximising the negative
cge_solve, name(scmax) maximize(-(`f71')) solver(scip)
assert r(converged) == 1 & abs(r(objective) + 17.0140173) < 1e-6
assert abs(r(bestbound) - r(objective)) < 1e-6

* ---------------------------------------------------------------------
* 2. A nonconvex polynomial, x^4 - 3x^2 + x on [-2, 2]: from x = 1 the
*    interior point reaches the local minimum at 1.1309011 (-1.0702302),
*    SCIP the global one at -1.3008396 (-3.5139050); then with y = x^2 as
*    an equation
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(1)
cge_bound X, lower(-2) upper(2)
cge_solve, name(loc) minimize(X^4 - 3 * X^2 + X)
assert r(converged) == 1 & abs(r(objective) + 1.0702302) < 1e-6
cge_solve, name(glo) minimize(X^4 - 3 * X^2 + X) solver(scip)
assert r(converged) == 1 & r(modelstat) == 1 & abs(r(objective) + 3.5139050) < 1e-6
mata: st_numscalar("tsc_x", _tsc_val("glo", "X", ""))
assert abs(scalar(tsc_x) + 1.3008396) < 1e-5
cge_model new
cge_variable X, value(1)
cge_variable Y, value(1)
cge_equation sq: Y = X^2
cge_bound X, lower(-2) upper(2)
cge_solve, name(gloeq) minimize(Y^2 - 3 * Y + X) solver(scip)
assert r(converged) == 1 & abs(r(objective) + 3.5139050) < 1e-6
mata: st_numscalar("tsc_x", _tsc_val("gloeq", "X", ""))
assert abs(scalar(tsc_x) + 1.3008396) < 1e-5

* ---------------------------------------------------------------------
* 3. A linear objective on a circle, its radius a parameter and a fixed
*    variable: max x + y subject to x^2 + y^2 = r * K, r = 0.5 and K = 2
*    fixed, at x = y = 1/sqrt(2)
* ---------------------------------------------------------------------
cge_model new
cge_parameter r = 0.5
cge_variable K, value(2) fixed
cge_variable x, value(-0.5)
cge_variable y, value(0.5)
cge_equation circle: x^2 + y^2 = r * K
cge_bound x, lower(-2) upper(2)
cge_bound y, lower(-2) upper(2)
cge_solve, name(circ) maximize(x + y) solver(scip)
assert r(converged) == 1 & abs(r(objective) - sqrt(2)) < 1e-6
mata: st_numscalar("tsc_x", _tsc_val("circ", "x", ""))
mata: st_numscalar("tsc_y", _tsc_val("circ", "y", ""))
assert abs(scalar(tsc_x) - sqrt(0.5)) < 1e-4 & abs(scalar(tsc_y) - sqrt(0.5)) < 1e-4
mata: st_numscalar("tsc_x", _tsc_val("circ", "K", ""))
assert scalar(tsc_x) == 2

* ---------------------------------------------------------------------
* 4. Each function against its closed form: exp, ln, sqrt, log10, sqr and
*    abs in the objective, a number to the power of a variable (2^q = 8)
*    and a variable to the power of a variable (P^q = 27): x = ln 2, y = e,
*    z = 9, w = 100, v = 1, u = 1/2, q = 3, P = 3. The objective is 1 at
*    the optimum, where a relative gap of 1e-7 is defined, as it is not at 0
* ---------------------------------------------------------------------
cge_model new
foreach v in x y z w v u q P {
    cge_variable `v', value(2)
}
cge_bound x, lower(-3) upper(3)
cge_bound y, lower(0.1) upper(10)
cge_bound z, lower(0.01) upper(20)
cge_bound w, lower(1) upper(1000)
cge_bound v, lower(-3) upper(3)
cge_bound u, lower(-2) upper(2)
cge_bound q, lower(0) upper(5)
cge_bound P, lower(1) upper(5)
cge_equation pw: 2^q = 8
cge_equation vv: P^q = 27
cge_solve, name(fns) solver(scip) optcr(1e-7) ///
    minimize(1 + (exp(x) - 2)^2 + (ln(y) - 1)^2 + (sqrt(z) - 3)^2 + (log10(w) - 2)^2 + sqr(v - 1) + abs(u - 0.5))
assert r(converged) == 1 & r(modelstat) == 1 & abs(r(objective) - 1) < 1e-6 & r(gap) <= 1e-7
local d = 0
foreach p in "x ln(2)" "y exp(1)" "z 9" "w 100" "v 1" "u 0.5" "q 3" "P 3" {
    gettoken nm val : p
    mata: st_local("x", strofreal(_tsc_val("fns", "`nm'", ""), "%21.15g"))
    local d = max(`d', abs(`x' - `val') / max(1, abs(`val')))
}
display as text "functions by SCIP: largest relative distance " as result %9.2e `d'
assert `d' < 1e-3

* ---------------------------------------------------------------------
* 5. Integer and binary variables
* ---------------------------------------------------------------------
* a mixed-integer programme against branch and bound: min (x - 2.6)^2 +
* (y - 1.4)^2 + (z - 0.3)^2 with x and y integers and x + y + z = 4
cge_model new
cge_variable x, value(1)
cge_variable y, value(1)
cge_variable z, value(2)
cge_equation tot: x + y + z = 4
cge_bound x, lower(0) upper(5)
cge_bound y, lower(0) upper(5)
cge_bound z, lower(-5) upper(5)
cge_bound x, integer
cge_bound y, integer
cge_solve, name(bb) minimize((x - 2.6)^2 + (y - 1.4)^2 + (z - 0.3)^2)
local obb = r(objective)
cge_solve, name(mi) minimize((x - 2.6)^2 + (y - 1.4)^2 + (z - 0.3)^2) solver(scip)
assert r(converged) == 1 & r(modelstat) == 1 & r(N_integer) == 2
assert abs(r(objective) - `obb') < 1e-6
foreach v in x y z {
    mata: st_numscalar("tsc_x", abs(_tsc_val("mi", "`v'", "") - _tsc_val("bb", "`v'", "")))
    assert scalar(tsc_x) < 1e-5
}
mata: st_numscalar("tsc_x", _tsc_val("mi", "x", ""))
assert scalar(tsc_x) == round(scalar(tsc_x))
* a binary choice: a fixed cost of 3 opens capacity 10, x + s = 10 b with
* s >= 0, and (x - 4)^2 is the cost of being away from 4: b = 1, x = 4
cge_model new
cge_variable b, value(0)
cge_variable x, value(0)
cge_variable s, value(0)
cge_equation cap: x + s = 10 * b
cge_bound x, lower(0)
cge_bound s, lower(0)
cge_bound b, binary
cge_solve, name(bin) minimize(3 * b + (x - 4)^2) solver(scip)
assert r(converged) == 1 & abs(r(objective) - 3) < 1e-6
mata: st_numscalar("tsc_x", _tsc_val("bin", "b", ""))
mata: st_numscalar("tsc_y", _tsc_val("bin", "x", ""))
assert scalar(tsc_x) == 1 & abs(scalar(tsc_y) - 4) < 1e-5

* ---------------------------------------------------------------------
* 6. The gap, the node limit and an infeasible programme
* ---------------------------------------------------------------------
cge_model new
cge_set i = x1 x2 x3 x4
cge_parameter x0(i), values(x1:1 x2:5 x3:5 x4:1)
cge_variable X(i), value(x0(i))
cge_variable S, value(0)
cge_equation G1: X(x1) * X(x2) * X(x3) * X(x4) - S = 25
cge_equation G2: sum(i, X(i)^2) = 40
cge_bound X, lower(1) upper(5)
cge_bound S, lower(0)
cge_solve, name(gap) minimize(`f71') solver(scip) optcr(0.05)
assert r(converged) == 1 & r(modelstat) == 1 & r(gap) <= 0.05
assert r(objective) >= 17.0140173 - 1e-6
capture noisily cge_solve, name(lim) minimize(`f71') solver(scip) nodes(1)
assert _rc == 430 & r(solvestat) == 2 & inlist(r(modelstat), 6, 7)
cge_model new
cge_variable X, value(0.5)
cge_variable Y, value(0.5)
cge_equation e: X + Y = 5
cge_bound X, upper(1)
cge_bound Y, upper(1)
capture noisily cge_solve, name(inf) minimize(X^2 + Y^2) solver(scip)
assert _rc == 430 & r(converged) == 0 & r(modelstat) == 4 & r(solvestat) == 1

* ---------------------------------------------------------------------
* 7. Errors: functions without a form in SCIP, starts()
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(1)
cge_variable Y, value(1)
cge_equation e: X + Y = 2
capture noisily cge_solve, name(e1) minimize(max(X, Y)) solver(scip)
assert _rc == 459
capture noisily cge_solve, name(e2) minimize(X^2 + Y^2) solver(scip) starts(3)
assert _rc == 198
capture noisily cge_solve, name(e3) minimize(X^2 + Y^2) solver(nosuch)
assert _rc == 198
cge_solve, name(ok) minimize(X^2 + Y^2) solver(scip)
assert r(converged) == 1 & abs(r(objective) - 2) < 1e-6
* SCIP's log, displayed when its process ends
cge_solve, name(tr) minimize(X^2 + Y^2) solver(scip) trace
assert r(converged) == 1 & abs(r(objective) - 2) < 1e-6
capture mata: mata drop _tsc_val()
scalar drop tsc_x tsc_y
