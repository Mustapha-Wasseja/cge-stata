* test_mip.do -- integer and binary variables, by branch and bound (version
* 0.18.0; docs/model_spec.md, Section 27): a knapsack problem and an integer
* least-squares problem against enumeration of every integer point; an
* equation among integers, whose nodes are square systems; a mixed problem
* with continuous variables; node limits, integer infeasibility and the
* statuses; saving and loading; errors.

version 13.0

capture mata: mata drop _ti_val()
capture mata: mata drop _ti_knap()
_cge_load
mata:
// The value of element el of user variable v in the last simulation
real scalar _ti_val(string scalar v, string scalar el)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.simx[_cge_u_vpos(M, v, el), rows(M.simname)])
}

// The best value of a knapsack by enumeration of every choice
real scalar _ti_knap(real colvector val, real colvector w, real scalar cap)
{
    real scalar n, k, j, best, tv, tw, b
    n = rows(val)
    best = 0
    for (k = 0; k < 2^n; k++) {
        tv = tw = 0
        b = k
        for (j = 1; j <= n; j++) {
            if (mod(b, 2)) {
                tv = tv + val[j]
                tw = tw + w[j]
            }
            b = floor(b / 2)
        }
        if (tw <= cap + 1e-12 & tv > best) best = tv
    }
    return(best)
}
end

* ---------------------------------------------------------------------
* 1. A knapsack of eight items: binary choices, a capacity written as an
*    equation with a slack; a mixed-integer linear programme
* ---------------------------------------------------------------------
cge_model new
cge_set i = i1 i2 i3 i4 i5 i6 i7 i8
cge_parameter v(i), values(i1:15 i2:10 i3:9 i4:5 i5:12 i6:7 i7:11 i8:4)
cge_parameter w(i), values(i1:8 i2:5 i3:6 i4:3 i5:7 i6:4 i7:6 i8:2)
cge_parameter cap = 20
cge_variable X(i), value(0.5)
cge_variable S, value(1)
cge_equation CAP: sum(i, w(i) * X(i)) + S = cap
cge_bound X, binary
assert r(N_integer) == 8
cge_bound S, lower(0)
cge_solve, name(knap) maximize(sum(i, v(i) * X(i)))
assert r(converged) == 1 & r(modelstat) == 1 & r(solvestat) == 1 & "`r(method)'" == "minlp"
local fk = r(objective)
mata: st_numscalar("ti_best", _ti_knap((15, 10, 9, 5, 12, 7, 11, 4)', (8, 5, 6, 3, 7, 4, 6, 2)', 20))
display as text "knapsack: branch and bound " as result `fk' as text ", enumeration " as result scalar(ti_best) ///
    as text ", " as result r(nodes) as text " node(s)"
assert abs(`fk' - scalar(ti_best)) < 1e-6
assert r(gap) < 1e-6 & r(N_integer) == 8
* every choice is 0 or 1 and the capacity holds
local used = 0
forvalues k = 1/8 {
    mata: st_local("xk", strofreal(_ti_val("X", "i`k'"), "%21.15g"))
    assert abs(`xk') < 1e-9 | abs(`xk' - 1) < 1e-9
}
mata: st_numscalar("ti_s", _ti_val("S", ""))
assert scalar(ti_s) >= -1e-9
cge_results, sim(knap) nodisplay
assert r(modelstat) == 1

* a node limit of 1: the root's relaxation is fractional, so no integer
* solution: model status 14 (no solution returned), solver status 2
capture noisily cge_solve, name(knap1) maximize(sum(i, v(i) * X(i))) nodes(1)
assert _rc == 430 & r(modelstat) == 14 & r(solvestat) == 2

* ---------------------------------------------------------------------
* 2. Integer least squares: min (X - 2.4)^2 + (Y - 1.6)^2 with X + Y <= 3.5,
*    X and Y integers in [0, 10]: (2, 1), 0.52, by enumeration
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(1)
cge_variable Y, value(1)
cge_variable S, value(1.5)
cge_equation CAP: X + Y + S = 3.5
cge_bound X, lower(0) upper(10)
cge_bound Y, lower(0) upper(10)
cge_bound X, integer
cge_bound Y, integer
cge_bound S, lower(0)
cge_solve, name(ils) minimize((X - 2.4)^2 + (Y - 1.6)^2)
assert r(converged) == 1 & r(modelstat) == 1
local best = .
forvalues a = 0/10 {
    forvalues b = 0/10 {
        if `a' + `b' <= 3.5 {
            local f = (`a' - 2.4)^2 + (`b' - 1.6)^2
            if `f' < `best' local best = `f'
        }
    }
}
display as text "integer least squares: " as result r(objective) as text ", enumeration " as result `best'
assert abs(r(objective) - `best') < 1e-8
mata: st_numscalar("ti_d", abs(_ti_val("X", "") - 2) + abs(_ti_val("Y", "") - 1))
assert scalar(ti_d) < 1e-9

* ---------------------------------------------------------------------
* 3. An equation among integers, X + 2Y = 7 with X, Y >= 0 integers, and a
*    continuous Z: min (X - 3)^2 + Y^2 + (Z - X)^2. Leaves with X fixed are
*    square systems in Y
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(1)
cge_variable Y, value(1)
cge_variable Z, value(0)
cge_equation E: X + 2 * Y = 7
cge_bound X, lower(0) upper(7)
cge_bound Y, lower(0) upper(7)
cge_bound X, integer
cge_bound Y, integer
cge_solve, name(eq) minimize((X - 3)^2 + Y^2 + (Z - X)^2)
assert r(converged) == 1 & r(modelstat) == 1
* candidates (7,0): 16; (5,1): 5; (3,2): 4; (1,3): 13; Z = X
display as text "equation among integers: " as result r(objective)
assert abs(r(objective) - 4) < 1e-8
mata: st_numscalar("ti_d", abs(_ti_val("X", "") - 3) + abs(_ti_val("Y", "") - 2) + abs(_ti_val("Z", "") - 3))
assert scalar(ti_d) < 1e-7

* ---------------------------------------------------------------------
* 4. Integer infeasibility: an integer variable within [0.2, 0.8]
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(0.5)
cge_variable Y, value(0)
cge_bound X, lower(0.2) upper(0.8)
cge_bound X, integer
capture noisily cge_solve, name(inf) minimize((X - 0.5)^2 + Y^2)
assert _rc == 430 & r(modelstat) == 10 & r(solvestat) == 1

* ---------------------------------------------------------------------
* 5. Types: continuous removes integrality; clear removes every attribute;
*    saving and loading keep them
* ---------------------------------------------------------------------
cge_model new
cge_set i = a b
cge_variable X(i), value(0.5)
cge_variable S, value(0)
cge_equation E: sum(i, X(i)) + S = 1.5
cge_bound S, lower(0)
cge_bound X, binary
cge_bound X(b), continuous
assert r(N_integer) == 1
tempfile mf
quietly cge_save using "`mf'", replace
cge_model new
quietly cge_use using "`mf'"
cge_solve, name(mix) maximize(2 * X(a) + X(b))
assert r(converged) == 1 & r(N_integer) == 1
* X(a) = 1, X(b) = 0.5 (continuous within [0, 1])
assert abs(r(objective) - 2.5) < 1e-7
cge_bound X, clear
cge_bound X, lower(0) upper(1)
cge_solve, name(cont) maximize(2 * X(a) + X(b))
assert r(N_integer) == 0
assert "`r(method)'" == "nlp"

* ---------------------------------------------------------------------
* 6. Errors
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(1)
cge_variable Y, value(1)
cge_equation E: X + Y = 3
cge_bound X, integer
capture noisily cge_solve, name(sys)
assert _rc == 459
capture noisily cge_bound X, integer binary
assert _rc == 198
capture noisily cge_bound X, integer lower(1)
assert _rc == 198
quietly do setup_synthetic.do
capture noisily cge_bound QA, integer
assert _rc == 198

mata: mata drop _ti_val() _ti_knap()
scalar drop ti_best ti_s ti_d
