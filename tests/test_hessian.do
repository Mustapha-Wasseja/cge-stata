* test_hessian.do -- exact second derivatives of nonlinear programmes
* (version 0.28.0; docs/model_spec.md, Section 38): the Hessians of
* expressions against closed forms and against central differences of their
* exact gradients, over every operation and function of the language; the
* Hessian of the Lagrangian of test programmes against differences; the
* solutions with exact Hessians against those with differences, with the
* iterations; the setting, saved with the model; errors.

version 13.0

capture mata: mata drop _th_hess()
capture mata: mata drop _th_fd()
capture mata: mata drop _th_x()
capture mata: mata drop _th_simdiff()
_cge_load
mata:
// Element i of the solution of simulation s
real scalar _th_x(real scalar i, real scalar s)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.simx[i, s])
}

// The largest difference between the solutions of simulations a and b
real scalar _th_simdiff(real scalar a, real scalar b)
{
    struct cge_model scalar M
    M = _cge_load()
    return(max(abs(M.simx[., a] - M.simx[., b])))
}

// The exact Hessian of expression ex at the starting levels, over the
// variables of the model in their order (dense), by _cge_u_hvalue
real matrix _th_hess(string scalar ex)
{
    struct cge_model scalar M
    real matrix tok
    real colvector gi, gv, hi, hj, hv
    real scalar sgn, f
    string scalar g
    M = _cge_load()
    tok = _cge_nlp_tok(M, "min:" + ex, sgn, g)
    f = _cge_u_hvalue(M, M.p, M.x0, tok, gi, gv, hi, hj, hv)
    st_numscalar("th_f", f)
    _cge_hd_hsum(hi, hj, hv, rows(M.x0))
    return(_cge_trip_dense(hi, hj, hv, rows(M.x0), rows(M.x0)))
}

// The Hessian of ex by central differences of its exact gradient (step h)
real matrix _th_fd(string scalar ex, real scalar h)
{
    struct cge_model scalar M
    real matrix tok, D
    real colvector x, vpos
    real rowvector gp, gm
    real scalar sgn, n, i, f
    string scalar g
    M = _cge_load()
    tok = _cge_nlp_tok(M, "min:" + ex, sgn, g)
    n = rows(M.x0)
    vpos = (1::n)
    D = J(n, n, .)
    for (i = 1; i <= n; i++) {
        x = M.x0
        x[i] = x[i] + h
        f = _cge_u_dvalue(M, M.p, x, tok, vpos, gp)
        x[i] = x[i] - 2 * h
        f = _cge_u_dvalue(M, M.p, x, tok, vpos, gm)
        D[., i] = (gp - gm)' / (2 * h)
    }
    return((D + D') / 2)
}
end

* ---------------------------------------------------------------------
* 1. Closed forms: x^2 y, Rosenbrock's function and exp(x y)
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(1.3)
cge_variable Y, value(0.7)
cge_variable W, value(2)
mata: H = _th_hess("X^2 * Y"); st_numscalar("th_d", max(abs(H[|1, 1 \ 2, 2|] - (2 * 0.7, 2 * 1.3 \ 2 * 1.3, 0))))
assert scalar(th_d) < 1e-14
mata: H = _th_hess("(1 - X)^2 + 100 * (Y - X^2)^2"); st_numscalar("th_d", max(abs(H[|1, 1 \ 2, 2|] - (2 - 400 * 0.7 + 1200 * 1.3^2, -400 * 1.3 \ -400 * 1.3, 200))))
assert scalar(th_d) < 1e-11
mata: H = _th_hess("exp(X * Y)"); e = exp(1.3 * 0.7); st_numscalar("th_d", max(abs(H[|1, 1 \ 2, 2|] - (0.49 * e, e * (1 + 0.91) \ e * (1 + 0.91), 1.69 * e))))
assert scalar(th_d) < 1e-13

* ---------------------------------------------------------------------
* 2. Every operation and function against central differences of the exact
*    gradient: + - * / ^ (constant and variable exponents), negation, exp,
*    ln, sqrt, abs, sqr, log10, min, max and ifthen
* ---------------------------------------------------------------------
local ex1 X^2 * Y + exp(X * Y) + ln(Y) / X + sqrt(X + Y * W) + X^Y + Y^3 - W^(-1.5)
local ex2 abs(X - 2 * Y) * W + sqr(X * W) + log10(W * Y) + max(X, Y) * W - min(X * W, Y)
cge_parameter kk = 2
local ex3 ifthen(kk > 1, X * Y * W, 0) + (X + Y) / (W - Y)^2 - 2^(X * W) + W^X / Y
foreach k in 1 2 3 {
    mata: H = _th_hess(st_local("ex`k'")); D = _th_fd(st_local("ex`k'"), 1e-5)
    mata: st_numscalar("th_d", max(abs(H - D)) / max((1, max(abs(H)))))
    display as text "expression `k': exact against differences " as result %9.2e scalar(th_d)
    assert scalar(th_d) < 1e-8
}
mata: mata drop H D e

* ---------------------------------------------------------------------
* 3. The Hessian of the Lagrangian of test programmes against differences
* ---------------------------------------------------------------------
* problem 71 of Hock and Schittkowski, from a start within the bounds (the
* differences step to either side)
cge_model new
cge_set i = x1 x2 x3 x4
cge_parameter x0(i), values(x1:1.5 x2:4.5 x3:3.5 x4:1.5)
cge_variable X(i), value(x0(i))
cge_variable S, value(10)
cge_equation G1: X(x1) * X(x2) * X(x3) * X(x4) - S = 25
cge_equation G2: sum(i, X(i)^2) = 40
cge_bound X, lower(1) upper(5)
cge_bound S, lower(0)
local f71 X(x1) * X(x4) * (X(x1) + X(x2) + X(x3)) + X(x3)
mata: st_numscalar("th_d", _cge_hesscheck("min:" + st_local("f71")))
display as text "HS071: exact against differences " as result %9.2e scalar(th_d)
assert scalar(th_d) < 1e-7
* the optimum with exact Hessians and with differences
cge_solve, name(ex) minimize(`f71')
assert r(converged) == 1 & "`r(hessian)'" == "exact" & r(N_hessian_differences) == 0
local ie = r(iterations)
assert abs(r(objective) - 17.0140173) < 1e-7
quietly cge_options, hessian(differences)
assert "`r(hessian)'" == "differences"
cge_solve, name(fd) minimize(`f71')
assert r(converged) == 1 & "`r(hessian)'" == "differences" & r(N_hessian_exact) == 0
local id = r(iterations)
display as text "HS071: " as result `ie' as text " iterations with exact Hessians, " as result `id' as text " with differences"
mata: st_numscalar("th_d", _th_simdiff(1, 2))
assert scalar(th_d) < 1e-7
quietly cge_options, hessian(exact)

* a frontier with logarithms, and Rosenbrock's function
cge_model new
cge_set g = g1 g2 g3
cge_parameter alpha(g) = ord(g) / 6
cge_variable X(g), value(5)
cge_equation FR: sum(g, X(g)^2) = 100
cge_bound X, lower(0)
mata: st_numscalar("th_d", _cge_hesscheck("max:sum(g, alpha(g) * ln(X(g)))"))
assert scalar(th_d) < 1e-7
cge_model new
cge_variable A, value(-1.2)
cge_variable B, value(1)
mata: st_numscalar("th_d", _cge_hesscheck("min:(1 - A)^2 + 100 * (B - A^2)^2"))
assert scalar(th_d) < 1e-7
cge_solve, name(rb) minimize((1 - A)^2 + 100 * (B - A^2)^2)
assert r(converged) == 1 & r(objective) < 1e-14 & "`r(hessian)'" == "exact"

* the library's Ramsey model: 60 variables, the Euler equation, and the
* same path with differences
quietly cge_modlib run ramsey
local obj sum(t, beta^(ord(t) - 1) * ln(C(t)))
mata: st_numscalar("th_d", _cge_hesscheck("max:" + st_local("obj")))
display as text "Ramsey: exact against differences " as result %9.2e scalar(th_d) as text " over " as result r(N) as text " variables"
assert scalar(th_d) < 1e-6
timer clear 1
timer on 1
cge_solve, name(rex) maximize(`obj')
timer off 1
assert r(converged) == 1 & "`r(hessian)'" == "exact"
local fe = r(objective)
local ie = r(iterations)
quietly cge_options, hessian(differences)
timer clear 2
timer on 2
cge_solve, name(rfd) maximize(`obj')
timer off 2
assert r(converged) == 1
quietly timer list
display as text "Ramsey: " as result `ie' as text " iterations, " as result r(t1) as text " s with exact Hessians; " ///
    as result r(iterations) as text " iterations, " as result r(t2) as text " s with differences"
assert reldif(r(objective), `fe') < 1e-10
quietly cge_options, hessian(exact)

* ---------------------------------------------------------------------
* 4. Branch and bound with exact Hessians: integer least squares
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(1)
cge_variable Y, value(1)
cge_bound X, lower(0) upper(10)
cge_bound Y, lower(0) upper(10)
cge_bound X, integer
cge_bound Y, integer
cge_solve, name(ils) minimize((X - 2.4)^2 + (Y - 1.6)^2)
assert r(converged) == 1 & "`r(hessian)'" == "exact"
mata: st_numscalar("th_d", abs(_th_x(1, 1) - 2) + abs(_th_x(2, 1) - 2))
assert scalar(th_d) < 1e-9

* ---------------------------------------------------------------------
* 5. The setting is saved with the model; errors
* ---------------------------------------------------------------------
quietly cge_options, hessian(differences)
tempfile mf
quietly cge_save using "`mf'", replace
quietly cge_options, reset
assert "`r(hessian)'" == "exact"
quietly cge_use using "`mf'"
quietly cge_options
assert "`r(hessian)'" == "differences"
capture noisily cge_options, hessian(newton)
assert _rc == 198
quietly cge_options, reset

mata: mata drop _th_hess() _th_fd() _th_x() _th_simdiff()
scalar drop th_d th_f
