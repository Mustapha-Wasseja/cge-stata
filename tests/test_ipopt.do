* test_ipopt.do -- nonlinear programmes by IPOPT through cyipopt (version
* 0.41.0; docs/model_spec.md, Section 51). On Stata 16 and later with
* Python, SciPy and cyipopt: Hock and Schittkowski's problem 71 against its
* published optimum and the package's interior point, with the marginals of
* its equations; a programme maximised; a closed form; the limited-memory
* Hessian; Waechter and Biegler's example; a programme without equations;
* the statuses of an infeasible programme and of the iteration limit;
* errors. Without them, solver(ipopt) stops with an error.

version 13.0

local ok 0
if c(stata_version) >= 16 {
    capture python: import cyipopt
    if !_rc local ok 1
}
if !`ok' {
    display as text "Stata " c(stata_version) ": no Python with cyipopt; solver(ipopt) stops with an error"
    cge_model new
    cge_variable x, value(1)
    cge_variable y, value(1)
    cge_equation E: x + y = 2
    capture noisily cge_solve, name(i) minimize(x^2 + y^2) solver(ipopt)
    assert _rc == 198
    exit
}

capture mata: mata drop _tip_val()
_cge_load
mata:
// The value of element el of variable v in simulation s
real scalar _tip_val(string scalar s, string scalar v, string scalar el)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.simx[_cge_u_vpos(M, v, el), _cge_find(M.simname, s)])
}
end

* ---------------------------------------------------------------------
* 1. Hock and Schittkowski (1981), problem 71: the optimum 17.0140173 at
*    (1, 4.7429994, 3.8211503, 1.3794082)
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
cge_solve, name(ip) minimize(`f71') solver(ipopt)
assert r(converged) == 1 & "`r(solver)'" == "ipopt" & r(modelstat) == 2 & r(solvestat) == 1
assert abs(r(objective) - 17.0140173) < 1e-7
assert r(iterations) > 0 & r(iterations) < 100
matrix mi = r(marginals)
local k = 0
local d = 0
foreach v in 1 4.7429994 3.8211503 1.3794082 {
    local ++k
    mata: st_local("x", strofreal(_tip_val("ip", "X", "x`k'"), "%21.15g"))
    local d = max(`d', abs(`x' - `v'))
}
display as text "HS071 by IPOPT: distance from the published optimum " as result %9.2e `d'
assert `d' < 1e-6
* against the package's interior point, solution and marginals
cge_solve, name(pm) minimize(`f71')
matrix mp = r(marginals)
local d = 0
forvalues k = 1/4 {
    mata: st_local("x", strofreal(abs(_tip_val("ip", "X", "x`k'") - _tip_val("pm", "X", "x`k'")), "%21.15g"))
    local d = max(`d', `x')
}
assert `d' < 1e-6
forvalues k = 1/2 {
    display as text "marginal of G`k': IPOPT " as result %12.8f mi[1, `k'] as text ", interior point " as result %12.8f mp[1, `k']
    assert abs(mi[1, `k'] - mp[1, `k']) < 1e-5
}
* maximising the negative
cge_solve, name(ipmax) maximize(-(`f71')) solver(ipopt)
assert r(converged) == 1 & abs(r(objective) + 17.0140173) < 1e-7
matrix mx = r(marginals)
assert abs(mx[1, 1] + mi[1, 1]) < 1e-5
* the limited-memory Hessian
quietly cge_options, hessian(differences)
cge_solve, name(iplm) minimize(`f71') solver(ipopt) iterate(1000)
assert r(converged) == 1 & abs(r(objective) - 17.0140173) < 1e-6
quietly cge_options, reset
* the iteration limit
capture noisily cge_solve, name(iplim) minimize(`f71') solver(ipopt) iterate(2)
assert _rc == 430 & r(solvestat) == 2 & inlist(r(modelstat), 6, 7)

* ---------------------------------------------------------------------
* 2. A closed form: a Cobb-Douglas utility maximised on a budget, x = 3,
*    y = 7 at prices 1, with the marginal utility of income as marginal
* ---------------------------------------------------------------------
cge_model new
cge_variable x, value(5)
cge_variable y, value(5)
cge_equation budget: x + y = 10
cge_bound x, lower(1e-6)
cge_bound y, lower(1e-6)
cge_solve, name(cd) maximize(x^0.3 * y^0.7) solver(ipopt)
assert r(converged) == 1
mata: st_numscalar("tip_x", _tip_val("cd", "x", ""))
mata: st_numscalar("tip_y", _tip_val("cd", "y", ""))
assert abs(scalar(tip_x) - 3) < 1e-7 & abs(scalar(tip_y) - 7) < 1e-7
matrix mc = r(marginals)
assert abs(mc[1, 1] - 0.3 * 3^(-0.7) * 7^0.7) < 1e-6

* ---------------------------------------------------------------------
* 3. Waechter and Biegler's example, from (-2, 3, 1), written as GAMS
*    writes it: IPOPT reaches (1, 0, 1/2)
* ---------------------------------------------------------------------
cge_model new
cge_variable X1, value(-2)
cge_variable X2, value(3)
cge_variable X3, value(1)
cge_equation c1: X1^2 = X2 + 1
cge_equation c2: X1 = X3 + 0.5
cge_bound X2, lower(0)
cge_bound X3, lower(0)
cge_solve, name(wb) minimize(X1) solver(ipopt)
assert r(converged) == 1
mata: st_numscalar("tip_x", _tip_val("wb", "X1", ""))
assert abs(scalar(tip_x) - 1) < 1e-6

* ---------------------------------------------------------------------
* 4. A programme without equations, and one without a solution
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(-1.2)
cge_variable Y, value(1)
cge_solve, name(rb) minimize(100 * (Y - X^2)^2 + (1 - X)^2) solver(ipopt)
assert r(converged) == 1 & abs(r(objective)) < 1e-10
cge_model new
cge_variable X, value(0.5)
cge_variable Y, value(0.5)
cge_equation e: X + Y = 5
cge_bound X, upper(1)
cge_bound Y, upper(1)
capture noisily cge_solve, name(inf) minimize(X^2 + Y^2) solver(ipopt)
assert _rc == 430 & r(converged) == 0 & r(modelstat) == 5

* ---------------------------------------------------------------------
* 5. Errors
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(1)
cge_variable Y, value(1)
cge_equation e: X + Y = 2
cge_bound X, lower(0) upper(2)
cge_bound X, integer
capture noisily cge_solve, name(e1) minimize(X^2 + Y^2) solver(ipopt)
assert _rc == 198
cge_bound X, continuous
capture noisily cge_solve, name(e2) minimize(X^2 + Y^2) solver(ipopt) starts(3)
assert _rc == 198
capture noisily cge_solve, name(e3) solver(ipopt)
assert _rc == 198
capture noisily cge_solve, name(e4) minimize(X^2 + Y^2) solver(nosuch)
assert _rc == 198
cge_solve, name(ok) minimize(X^2 + Y^2) solver(ipopt)
assert r(converged) == 1 & abs(r(objective) - 2) < 1e-8
capture mata: mata drop _tip_val()
scalar drop tip_x tip_y
