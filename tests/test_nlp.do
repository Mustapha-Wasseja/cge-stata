* test_nlp.do -- nonlinear programmes of standalone models (version 0.15.0;
* docs/model_spec.md, Section 24): Hock and Schittkowski's problem 71 against
* its published optimum, with the marginals of its equations against
* differences of their right sides; Rosenbrock's function; a frontier with
* and without a binding bound against its closed form; balancing a matrix by
* cross entropy against the RAS method; multi-start (from version 0.24.0)
* against the roots of a cubic; errors.

version 13.0

capture mata: mata drop _tn_val()
capture mata: mata drop _tn_ras()
_cge_load
mata:
// The value of element el of variable v in simulation s
real scalar _tn_val(string scalar v, string scalar el, real scalar s)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.simx[_cge_u_vpos(M, v, el), s])
}

// The RAS (biproportional) balance of prior A to row sums u and column sums
// v: r_i A_ij s_j
real matrix _tn_ras(real matrix A, real colvector u, real rowvector v)
{
    real colvector r
    real rowvector s
    real scalar it
    r = J(rows(A), 1, 1)
    s = J(1, cols(A), 1)
    for (it = 1; it <= 10000; it++) {
        r = u :/ (A * s')
        s = v :/ (r' * A)
        if (max(abs(rowsum(r :* A :* s) - u)) < 1e-14 * max(u)) break
    }
    return(r :* A :* s)
}
end

* ---------------------------------------------------------------------
* 1. Hock and Schittkowski (1981), problem 71: min x1 x4 (x1 + x2 + x3) + x3
*    with x1 x2 x3 x4 >= 25 (an equation with a slack), sum x^2 = 40 and
*    1 <= x <= 5; the optimum 17.0140173 at (1, 4.7429994, 3.8211503,
*    1.3794082)
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
cge_solve, name(hs071) minimize(`f71')
assert r(converged) == 1 & "`r(method)'" == "nlp" & r(N_dof) == 3
assert abs(r(objective) - 17.0140173) < 1e-7
matrix mg = r(marginals)
assert colsof(mg) == 2
local d = 0
local k = 0
foreach v in 1 4.7429994 3.8211503 1.3794082 {
    local ++k
    mata: st_local("x", strofreal(_tn_val("X", "x`k'", 1), "%21.15g"))
    local d = max(`d', abs(`x' - `v'))
}
display as text "HS071: distance from the published optimum " as result %9.2e `d'
assert `d' < 1e-6
* the marginals: central differences of the optimum in the right sides
local k = 0
foreach b in b1 b2 {
    local ++k
    local base = cond("`b'" == "b1", 25, 40)
    quietly cge_shock `b', value(`=`base' + 1e-4')
    quietly cge_solve, name(up`b') minimize(`f71')
    local fu = r(objective)
    quietly cge_shock `b', value(`=`base' - 1e-4')
    quietly cge_solve, name(dn`b') minimize(`f71')
    local fd = r(objective)
    quietly cge_shock, reset
    local dfd = (`fu' - `fd') / 2e-4
    display as text "marginal of G`k': " as result %12.8f mg[1, `k'] as text ", by differences " as result %12.8f `dfd'
    assert abs(mg[1, `k'] - `dfd') < 1e-5
}
cge_results, sim(hs071)
* maximising the negative gives the same point
cge_solve, name(hs071max) maximize(-(`f71'))
assert abs(r(objective) + 17.0140173) < 1e-7
* the sixth simulation, after the four for the differences
mata: st_numscalar("tn_d", abs(_tn_val("X", "x3", 1) - _tn_val("X", "x3", 6)))
assert scalar(tn_d) < 1e-7

* ---------------------------------------------------------------------
* 2. Rosenbrock's function from (-1.2, 1): the minimum 0 at (1, 1)
* ---------------------------------------------------------------------
cge_model new
cge_variable A, value(-1.2)
cge_variable B, value(1)
cge_solve, name(rb) minimize((1 - A)^2 + 100 * (B - A^2)^2)
assert r(converged) == 1 & r(N_dof) == 2
assert r(objective) < 1e-14
mata: st_numscalar("tn_d", max((abs(_tn_val("A", "", 1) - 1), abs(_tn_val("B", "", 1) - 1))))
assert scalar(tn_d) < 1e-7

* ---------------------------------------------------------------------
* 3. A frontier sum_g X(g)^2 = 100 and the utility sum_g alpha(g) ln X(g):
*    X(g) = 10 sqrt(alpha(g)); with X(g1) <= 3, the others share the
*    remaining 91 in proportion to their alpha. The bound is added after the
*    start, which lies outside it
* ---------------------------------------------------------------------
cge_model new
cge_set g = g1 g2 g3
cge_parameter alpha(g) = ord(g) / 6
cge_variable X(g), value(5)
cge_equation FR: sum(g, X(g)^2) = 100
cge_bound X, lower(0)
local u sum(g, alpha(g) * ln(X(g)))
cge_solve, name(fr) maximize(`u')
assert r(converged) == 1
local d = 0
forvalues k = 1/3 {
    mata: st_local("x", strofreal(_tn_val("X", "g`k'", 1), "%21.15g"))
    local d = max(`d', abs(`x' - 10 * sqrt(`k' / 6)))
}
display as text "frontier: distance from the closed form " as result %9.2e `d'
assert `d' < 1e-7
* the marginal of the frontier: dU/dR^2 = sum alpha / (2 R^2) = 1/200
matrix mg = r(marginals)
assert abs(mg[1, 1] - 1/200) < 1e-7
cge_bound X(g1), upper(3)
cge_solve, name(fr3) maximize(`u')
assert r(converged) == 1
mata: st_numscalar("tn_d", max((abs(_tn_val("X", "g1", 2) - 3), abs(_tn_val("X", "g2", 2) - sqrt(2/5) * sqrt(91)), ///
    abs(_tn_val("X", "g3", 2) - sqrt(3/5) * sqrt(91)))))
display as text "frontier at a bound: distance from the closed form " as result %9.2e scalar(tn_d)
assert scalar(tn_d) < 1e-7
local uexact = (1/6) * ln(3) + (2/6) * ln(sqrt(2/5) * sqrt(91)) + (3/6) * ln(sqrt(3/5) * sqrt(91))
assert abs(r(objective) - `uexact') < 1e-9

* ---------------------------------------------------------------------
* 4. Balancing a 3 x 4 matrix by cross entropy, min sum X ln(X / A), to new
*    row and column sums: the solution is the RAS balance. One column
*    equation is left out, as the sums of the rows and of the columns agree
* ---------------------------------------------------------------------
cge_model new
cge_set r = r1 r2 r3
cge_set c = c1 c2 c3 c4
cge_parameter a(r,c), values(r1.c1:10 r1.c2:5 r1.c3:2 r1.c4:8 r2.c1:3 r2.c2:12 r2.c3:6 r2.c4:1 r3.c1:4 r3.c2:2 r3.c3:9 r3.c4:7)
cge_parameter u(r), values(r1:30 r2:20 r3:19)
cge_parameter v(c), values(c1:20 c2:21 c3:16 c4:12)
cge_variable X(r,c), value(a(r,c))
cge_equation ROW(r): sum(c, X(r,c)) = u(r)
cge_equation COL(c)$(ord(c) < card(c)): sum(r, X(r,c)) = v(c)
cge_bound X, lower(0)
cge_solve, name(ce) minimize(sum((r,c), X(r,c) * ln(X(r,c) / a(r,c))))
assert r(converged) == 1 & r(N_dof) == 12 - 6
mata:
st_numscalar("tn_d", 0)
tn_A = (10, 5, 2, 8 \ 3, 12, 6, 1 \ 4, 2, 9, 7)
tn_X = _tn_ras(tn_A, (30 \ 20 \ 19), (20, 21, 16, 12))
for (tn_i = 1; tn_i <= 3; tn_i++) {
    for (tn_j = 1; tn_j <= 4; tn_j++) {
        st_numscalar("tn_d", max((st_numscalar("tn_d"), abs(_tn_val("X", "r" + strofreal(tn_i) + ".c" + strofreal(tn_j), 1) - tn_X[tn_i, tn_j]))))
    }
}
mata drop tn_A tn_X tn_i tn_j
end
display as text "cross entropy against RAS: largest difference " as result %9.2e scalar(tn_d)
assert scalar(tn_d) < 1e-7

* ---------------------------------------------------------------------
* 5. Errors
* ---------------------------------------------------------------------
* no degrees of freedom: a square system
cge_model new
cge_variable Y, value(1)
cge_equation EY: Y^2 = 4
capture noisily cge_solve, minimize(Y)
assert _rc == 459
* an inequality paired with a variable is a complementarity condition
cge_variable Z, value(1)
cge_variable MU, value(0) fixed
cge_equation EZ: Z =l= 3, perp(MU)
capture noisily cge_solve, minimize(-Z)
assert _rc == 459
* equal bounds
cge_model new
cge_variable Y, value(1)
cge_variable W, value(1)
cge_equation EY: Y + W = 4
cge_bound Y, lower(2) upper(2)
capture noisily cge_solve, minimize(Y^2 + W^2)
assert _rc == 459
* both senses
capture noisily cge_solve, minimize(Y) maximize(W)
assert _rc == 198
* a model from a SAM
quietly do setup_synthetic.do
capture noisily cge_solve, maximize(QH(com_agr, hhd))
assert _rc == 198

* ---------------------------------------------------------------------
* Multi-start (from version 0.24.0): f(x) = (x^2 - 1)^2 + 0.3 x, with x =
* k / 2 and k in [-4, 4], has a local minimum at x = 0.96, which the
* interior point reaches from k = 2, and its global minimum at x = -1.036,
* the root of f'(x) = 4x^3 - 4x + 0.3 with the least f, which five starts
* find
* ---------------------------------------------------------------------
cge_model new
cge_variable x, value(1)
cge_variable k, value(2)
cge_equation E: x = 0.5 * k
cge_bound k, lower(-4) upper(4)
cge_solve, name(n1) minimize((x^2 - 1)^2 + 0.3 * x)
assert r(converged) == 1 & r(starts) == 1
mata: st_numscalar("tn_d", _tn_val("x", "", 1))
assert scalar(tn_d) > 0.9
cge_solve, name(n5) minimize((x^2 - 1)^2 + 0.3 * x) starts(5)
assert r(converged) == 1 & r(starts) == 5 & r(best_start) > 1 & r(N_starts_converged) >= 2
mata: tn_r = Re(polyroots((0.3, -4, 0, 4))); tn_f = (tn_r :^ 2 :- 1) :^ 2 + 0.3 * tn_r
mata: st_numscalar("tn_d", abs(_tn_val("x", "", 2) - select(tn_r, tn_f :== min(tn_f))))
assert scalar(tn_d) < 1e-8
mata: st_numscalar("tn_d", abs(st_numscalar("r(objective)") - min(tn_f)))
assert scalar(tn_d) < 1e-10
mata: mata drop tn_r tn_f
capture noisily cge_solve, name(e1) minimize(x^2) starts(0)
assert _rc == 198
capture noisily cge_solve, name(e2) starts(3)
assert _rc == 198

mata: mata drop _tn_val() _tn_ras()
scalar drop tn_d
