* test_sparse.do -- the sparse LU of Newton's steps (version 0.10.1). The
* factorisation against dense solves, with pivoting, refactorisation and
* singular matrices; and solutions with the sparse LU against those with the
* dense one, for the reduced and the full system, constraints, user
* equations, a dynamic run, the optimiser and a loop

version 13.0
quietly do helpers_reference.do

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local instmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)             ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)

quietly cge_synthetic, clear
quietly cge_sam, labels(account)

* ---------------------------------------------------------------------
* 1. The factorisation
* ---------------------------------------------------------------------
capture mata: mata drop _ts_case() _ts_diff()
mata:
// a random sparse matrix, its rows shuffled so that pivoting is needed, some
// diagonal entries zero; the largest error of the solution against a dense
// solve, before and after a refactorisation with new values
real rowvector _ts_case(real scalar n, real scalar dens, real scalar seed, real scalar zdiag)
{
    struct cge_slu scalar F
    real matrix A
    real colvector r, c, v, b, x, xd, t
    real scalar i, e1, e2, ok
    rseed(seed)
    A = (runiform(n, n) :< dens) :* rnormal(n, n, 0, 1)
    for (i = 1; i <= n; i++) A[i, i] = (runiform(1, 1) < zdiag ? 0 : 1 + runiform(1, 1))
    // entries on a random permutation make the matrix structurally nonsingular
    t = order(runiform(n, 1), 1)
    for (i = 1; i <= n; i++) A[i, t[i]] = A[i, t[i]] + 3
    A = A[order(runiform(n, 1), 1), .]
    t = selectindex(vec(A') :!= 0)
    r = floor((t :- 1) :/ n) :+ 1
    c = mod(t :- 1, n) :+ 1
    v = vec(A')[t]
    b = rnormal(n, 1, 0, 1)
    F.ok = 0
    ok = _cge_slu_update(F, r, c, v, n)
    if (!ok) return((., ., rank(A)))
    x = _cge_slu_solve(F, b)
    xd = lusolve(A, b)
    e1 = max(abs(x - xd)) / max(abs(xd))
    // the same pattern, new values
    v = v :* (1 :+ 0.01 :* rnormal(rows(v), 1, 0, 1))
    A = J(n, n, 0)
    for (i = 1; i <= rows(r); i++) A[r[i], c[i]] = v[i]
    ok = _cge_slu_update(F, r, c, v, n)
    x = _cge_slu_solve(F, b)
    e2 = max(abs(x - lusolve(A, b))) / max(abs(lusolve(A, b)))
    return((e1, e2, rank(A)))
}
end
foreach c in "30 0.15 1 0" "120 0.04 2 0.2" "300 0.015 3 0.3" "600 0.006 4 0.4" {
    tokenize `c'
    mata: E = _ts_case(`1', `2', `3', `4'); st_numscalar("e1", E[1]); st_numscalar("e2", E[2]); st_numscalar("rk", E[3])
    display as text "n = `1': against the dense solve " as result %9.2e scalar(e1) as text ", refactorised " as result %9.2e scalar(e2)
    assert scalar(rk) == `1'
    assert scalar(e1) < 1e-9 & scalar(e2) < 1e-9
}
* rows with many entries, set apart in the dense block, and pairs of rows
* that cancel: the second row of each pair is 0.7 times the first, with an
* entry of its own on the diagonal, so that after the elimination a column of
* the pair keeps only entries lost to rounding, and its pivot must come from
* the dense rows
capture mata: mata drop _ts_dense()
mata:
real rowvector _ts_dense(real scalar seed)
{
    struct cge_slu scalar F
    real matrix A
    real colvector r, c, v, b, x, xd, t, own
    real scalar n, i, k, e1, e2, ok, nd
    n = 200
    rseed(seed)
    A = (runiform(n, n) :< 0.02) :* rnormal(n, n, 0, 1)
    for (i = 1; i <= n; i++) A[i, i] = A[i, i] + 2 + runiform(1, 1)
    own = (191::198)
    A[|15, 191 \ n, 198|] = J(n - 14, 8, 0)
    A[|191, 1 \ 198, n|] = J(8, n, 0)
    for (i = 191; i <= 198; i++) A[i, i - 170] = 2.5
    // six dense rows, with entries in the columns of the pairs
    for (i = 1; i <= 6; i++) {
        A[i, .] = (runiform(1, n) :< 0.6) :* rnormal(1, n, 0, 1)
        A[i, own'] = rnormal(1, 8, 0, 1)
    }
    // four pairs of rows, each with two columns of its own
    for (k = 1; k <= 4; k++) {
        i = 5 + 2 * k
        A[i, .] = (runiform(1, n) :< 0.03) :* rnormal(1, n, 0, 1)
        A[|i, 191 \ i, 198|] = J(1, 8, 0)
        A[|i, 189 + 2 * k \ i, 190 + 2 * k|] = (0.1 + runiform(1, 1), 0.7 + runiform(1, 1))
        A[i, i] = A[i, i] + 2
        A[i + 1, .] = 0.7 :* A[i, .]
        A[i + 1, i + 1] = A[i + 1, i + 1] + 2
    }
    t = selectindex(vec(A') :!= 0)
    r = floor((t :- 1) :/ n) :+ 1
    c = mod(t :- 1, n) :+ 1
    v = vec(A')[t]
    b = rnormal(n, 1, 0, 1)
    F.ok = 0
    ok = _cge_slu_update(F, r, c, v, n)
    if (!ok) return((., ., rank(A), .))
    nd = n - F.ns
    x = _cge_slu_solve(F, b)
    xd = lusolve(A, b)
    e1 = max(abs(x - xd)) / max(abs(xd))
    // new values on the same pattern, factorised in the same order
    v = v :* (1 :+ 0.01 :* rnormal(rows(v), 1, 0, 1))
    A = J(n, n, 0)
    for (i = 1; i <= rows(r); i++) A[r[i], c[i]] = v[i]
    ok = _cge_slu_update(F, r, c, v, n)
    x = _cge_slu_solve(F, b)
    xd = lusolve(A, b)
    e2 = max(abs(x - xd)) / max(abs(xd))
    return((e1, e2, rank(A), nd))
}
E = _ts_dense(7)
st_numscalar("e1", E[1])
st_numscalar("e2", E[2])
st_numscalar("rk", E[3])
st_numscalar("nd", E[4])
end
display as text "dense rows and rows that cancel: against the dense solve " as result %9.2e scalar(e1) ///
    as text ", refactorised " as result %9.2e scalar(e2) as text "; dense block of " as result scalar(nd)
assert scalar(rk) == 200
assert scalar(e1) < 1e-10 & scalar(e2) < 1e-10
assert scalar(nd) >= 6
* a singular matrix, a zero column, is found
mata:
real scalar _ts_sing()
{
    struct cge_slu scalar F
    F.ok = 0
    return(_cge_slu_update(F, (1 \ 2 \ 2), (1 \ 1 \ 3), (1 \ 2 \ 1), 3))
}
st_numscalar("sg", _ts_sing())
end
assert scalar(sg) == 0
* a pivot that falls below the threshold: the order is chosen again
mata:
real scalar _ts_reorder()
{
    struct cge_slu scalar F
    real colvector r, c, v, x
    r = (1 \ 1 \ 2 \ 2)
    c = (1 \ 2 \ 1 \ 2)
    F.ok = 0
    (void) _cge_slu_update(F, r, c, (4 \ 1 \ 1 \ 3), 2)
    // the first pivot of the first order becomes tiny
    (void) _cge_slu_update(F, r, c, (1e-14 \ 1 \ 1 \ 3), 2)
    x = _cge_slu_solve(F, (1 \ 2))
    return(max(abs((1e-14, 1 \ 1, 3) * x - (1 \ 2))))
}
st_numscalar("ro", _ts_reorder())
end
assert scalar(ro) < 1e-14

* ---------------------------------------------------------------------
* 2. Solutions with the sparse LU against the dense one
* ---------------------------------------------------------------------
mata:
real scalar _ts_diff(string scalar a, string scalar b)
{
    struct cge_model scalar M
    M = _cge_load()
    return(max(abs(M.simx[., _cge_sim_index(M, a)] - M.simx[., _cge_sim_index(M, b)]) :/ M.xscale))
}
end
* the standard model, reduced and full
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
cge_options
assert "`r(linsolver)'" == "dense"
cge_shock tm, value(0)
quietly cge_solve, name(d1) tolerance(1e-12)
assert "`r(linsolver)'" == "dense"
cge_solve, name(s1) tolerance(1e-12) sparse
assert r(converged) == 1 & "`r(linsolver)'" == "sparse"
mata: st_numscalar("d", _ts_diff("d1", "s1"))
display as text "reduced system, sparse against dense: " as result %9.2e scalar(d)
assert scalar(d) < 1e-10
cge_solve, name(s2) tolerance(1e-12) sparse full
mata: st_numscalar("d", _ts_diff("d1", "s2"))
display as text "full system, sparse against the reduced one, dense: " as result %9.2e scalar(d)
assert scalar(d) < 1e-10
* Newton's fallbacks, central (mode 1) and one-sided (mode 2) differences,
* with the sparse LU against the dense one
capture mata: mata drop _ts_cd()
mata:
real scalar _ts_cd(real scalar mode, real scalar full)
{
    struct cge_model scalar M
    real colvector x1, x2
    real scalar conv, iter, err
    string scalar method
    M = _cge_load()
    M.linsolver = 0
    x1 = _cge_solve_point(M, M.p, M.xcur, M.xcur, 1e-12, 100, 0, conv, iter, err, method, full, mode)
    if (!conv) return(.)
    M.linsolver = 1
    x2 = _cge_solve_point(M, M.p, M.xcur, M.xcur, 1e-12, 100, 0, conv, iter, err, method, full, mode)
    if (!conv) return(.)
    return(max(abs(x1 - x2) :/ M.xscale))
}
end
foreach c in "1 0" "2 0" "1 1" "2 1" {
    tokenize `c'
    mata: st_numscalar("d", _ts_cd(`1', `2'))
    display as text "differences (mode `1', full `2'), sparse against dense: " as result %9.2e scalar(d)
    assert scalar(d) < 1e-9
}
* the setting stays for later solves, and is saved with the model
cge_options, linsolver(sparse)
assert "`r(linsolver)'" == "sparse"
quietly cge_solve, name(s3) tolerance(1e-12)
assert "`r(linsolver)'" == "sparse"
tempfile sv
quietly cge_save using "`sv'", replace
quietly cge_use using "`sv'"
cge_options
assert "`r(linsolver)'" == "sparse"
quietly cge_solve, name(s4) tolerance(1e-12) dense
assert "`r(linsolver)'" == "dense"
cge_options
assert "`r(linsolver)'" == "sparse"
cge_options, linsolver(auto)
assert "`r(linsolver)'" == "auto"
quietly cge_solve, name(s5) tolerance(1e-12)
mata: st_numscalar("d", _ts_diff("d1", "s5"))
assert scalar(d) < 1e-10
cge_options, linsolver(dense)
quietly cge_shock, reset
* institutions, a quota, a user inequality and a dynamic run
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, `instmap'
quietly cge_calibrate, `sigmas'
cge_variable RGSAV = GSAV / CPI
cge_equation lim: QE(com_agr) =l= 1.01 * base(QE(com_agr)), perp(RE(com_agr))
cge_constraint QM, elements(com_man) upper(1.02) scale
cge_shock tm, value(0)
quietly cge_solve, name(d6) tolerance(1e-12)
quietly cge_solve, name(s6) tolerance(1e-12) sparse
mata: st_numscalar("d", _ts_diff("d6", "s6"))
display as text "constraints and user equations: " as result %9.2e scalar(d)
assert scalar(d) < 1e-10
quietly cge_constraint, clear
quietly cge_equation, clear
quietly cge_shock, reset
quietly cge_dynamic, name(dd) periods(0/2) capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02)
cge_options, linsolver(sparse)
quietly cge_dynamic, name(ds) periods(0/2) capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02)
forvalues t = 0/2 {
    mata: st_numscalar("d", _ts_diff("dd`t'", "ds`t'"))
    assert scalar(d) < 1e-10
}
* the optimiser and a loop
cge_options, linsolver(dense)
quietly cge_optimize, instruments(tm(com_man)) maximize(YG) lower(tm(com_man):0) upper(tm(com_man):2) name(od)
local fd = r(objective)
cge_options, linsolver(sparse)
quietly cge_shock, reset
quietly cge_optimize, instruments(tm(com_man)) maximize(YG) lower(tm(com_man):0) upper(tm(com_man):2) name(os)
assert reldif(r(objective), `fd') < 1e-10
quietly cge_shock, reset
quietly cge_loop, name(ls) values(tm(com_man) = 0 0.2)
cge_options, linsolver(dense)
quietly cge_loop, name(ld) values(tm(com_man) = 0 0.2)
forvalues k = 1/2 {
    mata: st_numscalar("d", _ts_diff("ld`k'", "ls`k'"))
    assert scalar(d) < 1e-10
}
* errors
capture noisily cge_solve, sparse dense
assert _rc == 198
capture noisily cge_options, linsolver(fast)
assert _rc == 198
mata: mata drop _ts_case() _ts_diff() _ts_sing() _ts_reorder() _ts_dense() _ts_cd()
