* test_scipy.do -- links to SciPy through Stata's Python (version 0.27.0,
* an experimental prototype; docs/model_spec.md, Section 36). On Stata 16
* and later with Python and SciPy: Newton's steps with SuperLU against the
* package's sparse LU, reduced and full systems; linear programmes by HiGHS
* against the interior point, with their marginals and against a closed
* form; mixed-integer programmes against enumeration; infeasible, unbounded
* and nonlinear programmes. On Stata 13 to 15, or without Python and SciPy,
* the options stop with an error.

version 13.0

local py 0
if c(stata_version) >= 16 {
    capture python: import scipy.sparse.linalg
    if !_rc local py 1
}

quietly do setup_synthetic.do
if !`py' {
    display as text "Stata " c(stata_version) ": no Python with SciPy; the links stop with an error"
    capture noisily cge_options, linsolver(python)
    assert _rc == 198
    cge_model new
    cge_variable x, value(1)
    cge_variable y, value(1)
    cge_equation E: x + y = 2
    cge_bound x, lower(0) upper(2)
    capture noisily cge_solve, name(h) maximize(x) solver(highs)
    assert _rc == 198
    exit
}

capture mata: mata drop _tp_cmp()
capture mata: mata drop _tp_assign()
mata:
// The largest relative difference between the solutions of two simulations
real scalar _tp_cmp(string scalar a, string scalar b)
{
    struct cge_model scalar M
    real colvector x, y
    M = _cge_load()
    x = M.simx[., _cge_sim_index(M, a)]
    y = M.simx[., _cge_sim_index(M, b)]
    return(max(abs(x - y) :/ rowmax((J(rows(x), 1, 1), abs(x)))))
}

// The least cost of an assignment of n workers to n tasks, by enumeration of
// every permutation (Heap's algorithm)
real scalar _tp_assign(real matrix C)
{
    real rowvector p, c
    real scalar n, i, best, s, j, t
    n = rows(C)
    p = 1..n
    c = J(1, n, 1)
    best = 0
    for (j = 1; j <= n; j++) best = best + C[j, p[j]]
    i = 1
    while (i <= n) {
        if (c[i] < i) {
            if (mod(i, 2)) {
                t = p[1]
                p[1] = p[i]
                p[i] = t
            }
            else {
                t = p[c[i]]
                p[c[i]] = p[i]
                p[i] = t
            }
            s = 0
            for (j = 1; j <= n; j++) s = s + C[j, p[j]]
            if (s < best) best = s
            c[i] = c[i] + 1
            i = 1
        }
        else {
            c[i] = 1
            i++
        }
    }
    return(best)
}
end

* ---------------------------------------------------------------------
* 1. Newton's steps with SciPy's SuperLU give the solutions of the package's
*    sparse LU, reduced and full systems
* ---------------------------------------------------------------------
quietly cge_options, linsolver(sparse)
cge_shock tm, value(0)
cge_solve, name(mata)
cge_solve, name(matafull) full
cge_options, linsolver(python)
assert "`r(linsolver)'" == "python"
mata: st_numscalar("tp_n", _cge_py_count())
cge_solve, name(py)
assert r(converged) == 1
cge_solve, name(pyfull) full
assert r(converged) == 1
mata: st_numscalar("tp_d", max((_tp_cmp("mata", "py"), _tp_cmp("matafull", "pyfull"), _tp_cmp("py", "pyfull"))))
display as text "SuperLU against the package's sparse LU: " as result %9.2e scalar(tp_d)
assert scalar(tp_d) < 1e-9
* SuperLU made the factorisations
mata: st_numscalar("tp_n", _cge_py_count() - st_numscalar("tp_n"))
display as text "SuperLU factorisations: " as result scalar(tp_n)
assert scalar(tp_n) >= 2
quietly cge_shock, reset
quietly cge_options, linsolver(auto)

* ---------------------------------------------------------------------
* 2. A linear programme with a closed form: maximise 3x + 2y with
*    x + y + s = 4, x <= 3, y <= 3, s >= 0; x = 3, y = 1, 11, and the
*    marginal of the equation is 2
* ---------------------------------------------------------------------
cge_model new
cge_variable x, value(1)
cge_variable y, value(1)
cge_variable s, value(1)
cge_equation E: x + y + s = 4
cge_bound x, lower(0) upper(3)
cge_bound y, lower(0) upper(3)
cge_bound s, lower(0)
cge_solve, name(lp) maximize(3 * x + 2 * y) solver(highs)
assert r(converged) == 1 & r(modelstat) == 1 & "`r(solver)'" == "highs"
assert abs(r(objective) - 11) < 1e-9
matrix mg = r(marginals)
assert abs(mg[1, 1] - 2) < 1e-9
cge_solve, name(lpip) maximize(3 * x + 2 * y)
matrix mi = r(marginals)
assert abs(mi[1, 1] - 2) < 1e-6
mata: st_numscalar("tp_d", _tp_cmp("lp", "lpip"))
assert scalar(tp_d) < 1e-6

* ---------------------------------------------------------------------
* 3. Dantzig's transportation problem (the library's model): HiGHS gives
*    the interior point's optimum, 153.675, and its marginals
* ---------------------------------------------------------------------
quietly cge_modlib run transport
cge_solve, name(trip) minimize(sum((i,j), c(i,j) * X(i,j)))
matrix mi = r(marginals)
local fi = r(objective)
cge_solve, name(trh) minimize(sum((i,j), c(i,j) * X(i,j))) solver(highs)
assert r(converged) == 1
assert abs(r(objective) - 153.675) < 1e-9 & abs(`fi' - 153.675) < 1e-6
matrix mg = r(marginals)
assert colsof(mg) == colsof(mi)
assert mreldif(mg, mi) < 1e-5

* ---------------------------------------------------------------------
* 4. Mixed-integer programmes: a knapsack and an assignment of six workers
*    to six tasks, against enumeration and against branch and bound
* ---------------------------------------------------------------------
cge_model new
cge_set i = i1 i2 i3 i4 i5 i6 i7 i8
cge_parameter v(i), values(i1:15 i2:10 i3:9 i4:5 i5:12 i6:7 i7:11 i8:4)
cge_parameter w(i), values(i1:8 i2:5 i3:6 i4:3 i5:7 i6:4 i7:6 i8:2)
cge_variable X(i), value(0)
cge_variable S, value(1)
cge_equation CAP: sum(i, w(i) * X(i)) + S = 20
cge_bound X, binary
cge_bound S, lower(0)
cge_solve, name(kh) maximize(sum(i, v(i) * X(i))) solver(highs)
assert r(converged) == 1 & r(modelstat) == 1
local fk = r(objective)
cge_solve, name(kb) maximize(sum(i, v(i) * X(i)))
assert abs(r(objective) - `fk') < 1e-9
* the best value by enumeration of the 256 choices
mata: vv = (15, 10, 9, 5, 12, 7, 11, 4); ww = (8, 5, 6, 3, 7, 4, 6, 2); bb = 0
mata: for (q = 0; q < 256; q++) { ch = mod(floor(q :/ (2 :^ (0..7))), 2); if (ch * ww' <= 20) bb = max((bb, ch * vv')); }
mata: st_numscalar("tp_d", abs(bb - st_numscalar("r(objective)")))
assert scalar(tp_d) < 1e-9
mata: mata drop vv ww bb q ch

cge_model new
cge_set w = w1 w2 w3 w4 w5 w6
cge_set k = k1 k2 k3 k4 k5 k6
cge_parameter cost(w,k) = abs(3 * ord(w) - 2 * ord(k)) + 0.1 * ord(w) * ord(k)
cge_variable Y(w,k), value(0)
cge_bound Y, binary
cge_equation RW(w): sum(k, Y(w,k)) = 1
cge_equation RK(k): sum(w, Y(w,k)) = 1
cge_solve, name(as) minimize(sum((w,k), cost(w,k) * Y(w,k))) solver(highs)
assert r(converged) == 1 & r(modelstat) == 1
local fa = r(objective)
mata: C = J(6, 6, .); for (a = 1; a <= 6; a++) for (b = 1; b <= 6; b++) C[a, b] = abs(3 * a - 2 * b) + 0.1 * a * b
mata: st_numscalar("tp_d", abs(_tp_assign(C) - st_numscalar("r(objective)")))
display as text "assignment: " as result `fa' as text " against enumeration, gap " as result %9.2e scalar(tp_d)
assert scalar(tp_d) < 1e-9
mata: mata drop C a b

* ---------------------------------------------------------------------
* 5. An infeasible and an unbounded programme, and a nonlinear one
* ---------------------------------------------------------------------
cge_model new
cge_variable x, value(1)
cge_variable y, value(1)
cge_equation E: x + y = 10
cge_bound x, lower(0) upper(3)
cge_bound y, lower(0) upper(3)
capture noisily cge_solve, name(inf) maximize(x) solver(highs)
assert _rc == 430
cge_results, sim(inf) nodisplay
assert r(modelstat) == 4
cge_model new
cge_variable x, value(1)
cge_variable y, value(1)
cge_equation E: x - y = 0
cge_bound y, lower(0)
capture noisily cge_solve, name(unb) maximize(x) solver(highs)
assert _rc == 430
cge_results, sim(unb) nodisplay
assert r(modelstat) == 3
capture noisily cge_solve, name(nl) maximize(x - y^2) solver(highs)
assert _rc == 459
capture noisily cge_solve, name(nl) maximize(x) solver(cplex)
assert _rc == 198

mata: mata drop _tp_cmp() _tp_assign()
scalar drop tp_d tp_n
