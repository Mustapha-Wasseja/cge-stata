* test_reverse.do -- reverse differentiation (version 0.30.0;
* docs/model_spec.md, Section 40): the gradients of expressions by reverse
* and by forward differentiation and by central differences, over every
* operation and function of the language; constants whose derivative is
* undefined; a row of many variables; the choice between the two by the
* number of variables; the same solutions and iterations of a standalone
* model with a dense row, a nonlinear programme, a SAM-based model with user
* equations (its exact Jacobian against differences) and a run with
* foresight with lags and leads, in each mode.

version 13.0

capture mata: mata drop _tr_cmp()
capture mata: mata drop _tr_grad()
capture mata: mata drop _tr_simdiff()
capture mata: mata drop _tr_runs()
capture mata: mata drop _tr_count()
_cge_load
mata:
// For expression ex at the starting levels: the difference between its
// values by the two modes, the largest difference between their gradients
// relative to 1 + |forward|, the largest difference between the reverse
// gradient and central differences relative to 1 + |reverse|, and the
// number of variables
real rowvector _tr_cmp(string scalar ex)
{
    struct cge_model scalar M
    real matrix tok
    real colvector vpos, x
    real rowvector gf, gr, gd
    real scalar sgn, f1, f2, j, h, fp, fm
    string scalar g
    M = _cge_load()
    tok = _cge_nlp_tok(M, "min:" + ex, sgn, g)
    vpos = uniqrows(select(tok[., 2], tok[., 1] :== 2))
    f1 = _cge_u_fvalue(M, M.p, M.x0, tok, vpos, gf)
    f2 = _cge_u_rvalue(M, M.p, M.x0, tok, vpos, gr)
    gd = J(1, rows(vpos), .)
    for (j = 1; j <= rows(vpos); j++) {
        x = M.x0
        h = 1e-6 * max((1, abs(x[vpos[j]])))
        x[vpos[j]] = M.x0[vpos[j]] + h
        fp = _cge_u_value(M, M.p, x, tok)
        x[vpos[j]] = M.x0[vpos[j]] - h
        fm = _cge_u_value(M, M.p, x, tok)
        gd[j] = (fp - fm) / (2 * h)
    }
    return((abs(f1 - f2), max(abs(gf - gr) :/ (1 :+ abs(gf))), max(abs(gd - gr) :/ (1 :+ abs(gr))), rows(vpos)))
}

// The gradient of ex at the starting levels in mode m (1 forward, 2
// reverse), over its variables in the order of the model
real rowvector _tr_grad(string scalar ex, real scalar m)
{
    struct cge_model scalar M
    real matrix tok
    real colvector vpos
    real rowvector gr
    real scalar sgn
    string scalar g
    M = _cge_load()
    tok = _cge_nlp_tok(M, "min:" + ex, sgn, g)
    vpos = uniqrows(select(tok[., 2], tok[., 1] :== 2))
    if (m == 1) (void) _cge_u_fvalue(M, M.p, M.x0, tok, vpos, gr)
    else (void) _cge_u_rvalue(M, M.p, M.x0, tok, vpos, gr)
    return(gr)
}

// The number of reverse passes that _cge_u_dvalue takes for expression ex,
// in mode 0 (by the number of variables)
real scalar _tr_count(string scalar ex)
{
    struct cge_model scalar M
    real matrix tok
    real colvector vpos
    real rowvector gr
    real scalar sgn
    string scalar g
    M = _cge_load()
    tok = _cge_nlp_tok(M, "min:" + ex, sgn, g)
    vpos = uniqrows(select(tok[., 2], tok[., 1] :== 2))
    (void) _cge_dmode(0)
    (void) _cge_u_dvalue(M, M.p, M.x0, tok, vpos, gr)
    return(_cge_dmode(0))
}

// The largest difference between the solutions of simulations a and b,
// relative to the scale of each variable
real scalar _tr_simdiff(string scalar a, string scalar b)
{
    struct cge_model scalar M
    real scalar ia, ib
    M = _cge_load()
    ia = _cge_find(M.simname, a)
    ib = _cge_find(M.simname, b)
    return(max(abs(M.simx[., ia] - M.simx[., ib]) :/ M.xscale))
}

// The largest difference between the periods of dynamic runs a and b,
// relative to the scale of each variable
real scalar _tr_runs(string scalar a, string scalar b)
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

* ---------------------------------------------------------------------
* 1. Every operation and function: reverse against forward and against
*    central differences
* ---------------------------------------------------------------------
cge_model new
cge_set i = e1 e2 e3 e4 e5
cge_parameter a(i) = 0.5 + 0.3 * ord(i)
cge_parameter q = 0
cge_variable X, value(1.3)
cge_variable Y, value(0.7)
cge_variable Z, value(2.1)
cge_variable W(i), value(0.8 + 0.2 * ord(i))
local k 0
foreach ex in "X * Y + X / Z - Y^2 + X^Y + exp(X * Z) - ln(Y) + sqrt(Z)"                  ///
              "-X^3 * abs(Y - 2) + sqr(Z) + log10(X + Y) - (X - Y) / (X * Z)"             ///
              "min(X, Y, Z) + max(X * Y, Z) + ifthen(q > 0.5, X^2, Y^3) + abs(Z - X)"      ///
              "ifthen(q < 1, X, Y * Z) + ifthen(!(q > 1) & a(e1) >= 0.5 | q < -1, Y, Z) * X" ///
              "(X + Y)^Z + Z^(X - Y) + 2^X + X^0 + X^1"                                     ///
              "sum(i, a(i) * W(i)^2 / (1 + W(i))) * sum(i, W(i)) - sum(i, ln(W(i) + X))"    ///
              "prod(i, 1 + 0.1 * W(i) * a(i)) + smax(i, W(i) * a(i)) + smin(i, W(i) + Y)"   ///
              "exp(-sum(i, a(i) * (W(i) - X)^2)) / sqrt(1 + sum(i, W(i)^2))" {
    local ++k
    mata: r = _tr_cmp("`ex'")
    mata: st_numscalar("tr_v", r[1]); st_numscalar("tr_g", r[2]); st_numscalar("tr_d", r[3])
    display as text "expression `k': values " as result %9.2e scalar(tr_v) as text ", reverse - forward " ///
        as result %9.2e scalar(tr_g) as text ", reverse - differences " as result %9.2e scalar(tr_d)
    assert scalar(tr_v) == 0
    assert scalar(tr_g) < 1e-13
    assert scalar(tr_d) < 1e-7
}

* ---------------------------------------------------------------------
* 2. Constants whose derivative is undefined: sqrt(q) and q^0.5 at q = 0
*    have no derivative in the variables, which before version 0.30.0
*    made forward derivatives missing
* ---------------------------------------------------------------------
foreach m in 1 2 {
    mata: g = _tr_grad("X^2 + sqrt(q) + q^0.5 * Y + ln(1 + q) * Z + abs(q) * X", `m')
    mata: st_numscalar("tr_ok", !hasmissing(g) & reldif(g[1], 2.6) < 1e-14 & g[2] == 0 & g[3] == 0)
    assert scalar(tr_ok) == 1
}
* a variable's own undefined derivative is still missing
foreach m in 1 2 {
    mata: g = _tr_grad("sqrt(X - 1.3) + Y", `m')
    mata: st_numscalar("tr_ok", g[1] >= .)
    assert scalar(tr_ok) == 1
}

* ---------------------------------------------------------------------
* 3. A row of many variables: the mode chosen by their number
* ---------------------------------------------------------------------
local labs
forvalues j = 1/300 {
    local labs `labs' v`j'
}
cge_set j = `labs'
cge_parameter b(j) = 1 + ord(j) / 300
cge_variable V(j), value(1)
mata: r = _tr_cmp("sum(j, b(j) * V(j)^2 + ln(V(j)) * exp(0.1 * V(j))) * (1 + sum(j, V(j)) / 1000)")
mata: st_numscalar("tr_g", r[2]); st_numscalar("tr_d", r[3]); st_numscalar("tr_n", r[4])
display as text "300 variables: reverse - forward " as result %9.2e scalar(tr_g) as text ", reverse - differences " as result %9.2e scalar(tr_d)
assert scalar(tr_n) == 300 & scalar(tr_g) < 1e-13 & scalar(tr_d) < 1e-6
* the choice: reverse from _cge_u_rmin() variables on
mata: st_numscalar("tr_rmin", _cge_u_rmin())
assert scalar(tr_rmin) >= 2 & scalar(tr_rmin) < 300
mata: st_numscalar("tr_nrev", _tr_count("sum(j, V(j)^2)"))
assert scalar(tr_nrev) == 1
mata: st_numscalar("tr_nrev", _tr_count("X * Y + sum(i, W(i))"))
assert scalar(tr_nrev) == 0
cge_equation, clear

* ---------------------------------------------------------------------
* 4. A standalone model with a dense row, solved in each mode
* ---------------------------------------------------------------------
cge_model new
local labs
forvalues j = 1/250 {
    local labs `labs' g`j'
}
cge_set i = `labs'
cge_parameter a(i) = 1 + ord(i) / 250
cge_parameter p(i) = 2 - ord(i) / 250
cge_variable X(i), value(1)
cge_variable TOT = sum(i, p(i) * X(i)) / card(i)
cge_equation EX(i): X(i) * (1 + 0.1 * X(i)) = a(i) * TOT^0.5
local it
foreach m in 1 2 0 {
    mata: (void) _cge_dmode(`m')
    quietly cge_solve, name(dense`m') tolerance(1e-12)
    assert r(converged) == 1
    local it `it' `r(iterations)'
    mata: st_numscalar("tr_nrev`m'", _cge_dmode(0))
}
display as text "iterations by mode 1, 2, 0: `it'; reverse passes " scalar(tr_nrev1) ", " scalar(tr_nrev2) ", " scalar(tr_nrev0)
assert scalar(tr_nrev1) == 0 & scalar(tr_nrev2) > 0 & scalar(tr_nrev0) > 0
assert word("`it'", 1) == word("`it'", 2) & word("`it'", 1) == word("`it'", 3)
mata: st_numscalar("tr_d", max((_tr_simdiff("dense1", "dense2"), _tr_simdiff("dense1", "dense0"))))
display as text "dense row, solutions by mode: " as result %9.2e scalar(tr_d)
assert scalar(tr_d) < 1e-12

* ---------------------------------------------------------------------
* 5. A nonlinear programme of 250 variables: cross entropy with given
*    totals, in each mode
* ---------------------------------------------------------------------
cge_model new
cge_set i = `labs'
cge_parameter x0(i) = 1 + ord(i) / 100
cge_parameter w(i) = 1 + ord(i) / 125
cge_variable X(i), value(1)
cge_bound X, lower(1e-6)
cge_equation TA: sum(i, X(i)) = 1.1 * sum(i, x0(i))
cge_equation TB: sum(i, w(i) * X(i)) = sum(i, w(i) * x0(i))
foreach m in 1 0 {
    mata: (void) _cge_dmode(`m')
    timer clear 1
    timer on 1
    quietly cge_solve, name(ce`m') minimize(sum(i, X(i) * ln(X(i) / x0(i)))) tolerance(1e-10)
    timer off 1
    assert r(converged) == 1
    local obj`m' = r(objective)
    local it`m' = r(iterations)
    quietly timer list 1
    local t`m' = r(t1)
    mata: st_numscalar("tr_nrev`m'", _cge_dmode(0))
}
display as text "cross entropy: objective " as result %18.12g `obj1' " " %18.12g `obj0' as text ", iterations `it1' and `it0', seconds `t1' and `t0'"
assert scalar(tr_nrev0) > 0
assert `it1' == `it0' & reldif(`obj1', `obj0') < 1e-12
mata: st_numscalar("tr_d", _tr_simdiff("ce1", "ce0"))
assert scalar(tr_d) < 1e-10

* ---------------------------------------------------------------------
* 6. A SAM-based model with user equations: the exact Jacobian against
*    differences in reverse mode
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                  ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_variable GEXP = sum(c, PQ(c) * QG(c)) / CPI + max(0, sum(c, QM(c)) - 1e6), nominal
cge_variable PREL(c) = PQ(c)^0.5 * exp(0.01 * QQ(c) / base(QQ(c))) / CPI
quietly cge_closure, swap(GEXP GADJ)
quietly cge_shock tm, value(0)
foreach m in 1 2 {
    mata: (void) _cge_dmode(`m')
    mata: _cge_jexall()
    scalar tr_j`m' = r(maxdiff)
    quietly cge_solve, name(sam`m') tolerance(1e-12)
    assert r(converged) == 1
    local it`m' = r(iterations)
}
mata: (void) _cge_dmode(0)
display as text "SAM model: Jacobian against differences " as result %9.2e scalar(tr_j1) " " %9.2e scalar(tr_j2) ///
    as text "; iterations `it1' and `it2'"
assert scalar(tr_j2) < 1e-6 & abs(scalar(tr_j1) - scalar(tr_j2)) < 1e-9
assert `it1' == `it2'
mata: st_numscalar("tr_d", _tr_simdiff("sam1", "sam2"))
assert scalar(tr_d) < 1e-12
quietly cge_closure, swap(none)
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 7. Perfect foresight with lags and leads, in each mode
* ---------------------------------------------------------------------
quietly cge_closure, factors(cap:specific)
cge_variable GPATH, value(1)
cge_equation gpa: GPATH = 0.5 * lag(GPATH) + 0.5 * lead(GPATH) * QA(act_man) / base(QA(act_man))
cge_variable GRULE = QG(com_ser) / (base(QG(com_ser)) * GPATH)
quietly cge_closure, swap(GRULE GADJ)
foreach m in 1 2 {
    mata: (void) _cge_dmode(`m')
    quietly cge_dynamic, name(fs`m') periods(0/3) capital(cap) depreciation(0.05) rental(0.15) ///
        growth(lab:0.02) population(0.02) govgrowth(0.03) foreigngrowth(0.01) tfp(0.01) foresight
    mata: st_numscalar("tr_nrev`m'", _cge_dmode(0))
}
mata: st_numscalar("tr_d", _tr_runs("fs1", "fs2"))
display as text "foresight with lags and leads, the runs by mode: " as result %9.2e scalar(tr_d)
assert scalar(tr_nrev1) == 0 & scalar(tr_nrev2) > 0
assert scalar(tr_d) < 1e-10
quietly cge_closure, swap(none)
quietly cge_equation, clear
mata: (void) _cge_dmode(0)
