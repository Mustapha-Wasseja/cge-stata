* test_foresight.do -- dynamic runs with perfect foresight (version 0.10.2;
* docs/model_spec.md, Section 10.6). Without leads the stacked solve gives the
* recursive run, from a recursive start and from the base: capital mobile and
* specific, growth, population, government and foreign flows, efficiency,
* growth targets, public debt, deaths, lags and shocks, those on capital and
* debt included. The Jacobian of the stacked system against central
* differences; leads against a backward recursion, with each terminal
* condition; a model with forward-looking investment, each period against a
* solve of its own; the period in user equations; errors.

version 13.0
quietly do helpers_reference.do

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local instmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)             ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local hltmap activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)
local common capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02) population(0.02) ///
    govgrowth(0.03) foreigngrowth(0.01)

_cge_load
capture mata: mata drop _tf_runs() _tf_jaccheck() _tf_own() _tf_leads() _tf_lamdiff() _tf_count()
mata:
// The largest difference between the periods of runs a and b, relative to
// the scale of each variable
real scalar _tf_runs(string scalar a, string scalar b)
{
    struct cge_model scalar M
    real colvector sa, sb
    M = _cge_load()
    sa = select((1::rows(M.simname)), M.simrun :== a)
    sb = select((1::rows(M.simname)), M.simrun :== b)
    sa = sa[order(M.simper[sa], 1)]
    sb = sb[order(M.simper[sb], 1)]
    if (rows(sa) != rows(sb) | !rows(sa)) return(.)
    if (M.simper[sa] != M.simper[sb]) return(.)
    return(max(abs(M.simx[., sa'] - M.simx[., sb']) :/ M.xscale))
}

// The largest difference between the efficiency factors of the periods of
// runs a and b, missing if one has a factor where the other has none; and the
// number of periods stored for run a
real scalar _tf_lamdiff(string scalar a, string scalar b)
{
    struct cge_model scalar M
    real colvector sa, sb, la, lb
    M = _cge_load()
    sa = select((1::rows(M.simname)), M.simrun :== a)
    sb = select((1::rows(M.simname)), M.simrun :== b)
    la = M.simlam[sa[order(M.simper[sa], 1)]]
    lb = M.simlam[sb[order(M.simper[sb], 1)]]
    if ((la :>= .) != (lb :>= .)) return(.)
    return(max(abs(select(la - lb, la :< .))))
}

real scalar _tf_count(string scalar a)
{
    struct cge_model scalar M
    M = _cge_load()
    return(sum(M.simrun :== a))
}

// Each period of run a solved on its own, from the base, with its parameters,
// fixed values and the values of the periods around it as stored: the largest
// difference from the stored solution (scalar tf_d); and the largest
// difference between the values of later periods it was given and the
// solutions of those periods (tf_e)
void _tf_own(string scalar a)
{
    struct cge_model scalar M
    struct cge_par scalar p
    real colvector s, x
    real scalar k, conv, iter, err, d1, d2
    string scalar method
    M = _cge_load()
    s = select((1::rows(M.simname)), M.simrun :== a)
    s = s[order(M.simper[s], 1)]
    d1 = d2 = 0
    for (k = 1; k <= rows(s); k++) {
        p = M.simp[s[k]]
        x = _cge_solve_point(M, p, M.simx[., s[k]], M.x0, 1e-12, 100, 0, conv, iter, err, method)
        if (!conv) d1 = .
        d1 = max((d1, max(abs(x - M.simx[., s[k]]) :/ M.xscale)))
        if (k < rows(s) & cols(p.xlead)) d2 = max((d2, max(abs(p.xlead[., 1] - M.simx[., s[k + 1]]) :/ M.xscale)))
    }
    st_numscalar("tf_d", d1)
    st_numscalar("tf_e", d2)
}

// The values of user variable q in the periods of run a, and those of the
// backward recursion q(t) = (d(t) + q(t + 1)) / (1 + r) from the values of d,
// with the terminal condition: the largest relative difference
real scalar _tf_leads(string scalar a, string scalar qn, string scalar dn, real scalar r, real scalar term)
{
    struct cge_model scalar M
    real colvector s, q, d, b
    real scalar k, N, pq, pd, g
    M = _cge_load()
    s = select((1::rows(M.simname)), M.simrun :== a)
    s = s[order(M.simper[s], 1)]
    pq = _cge_vpos(M, _cge_vidx(M, qn))
    pd = _cge_vpos(M, _cge_vidx(M, dn))
    q = M.simx[pq, s']'
    d = M.simx[pd, s']'
    N = rows(s)
    b = J(N, 1, .)
    // the last period: q = (d + q) / (1 + r) with the value of the last
    // period beyond it, or (d + q g) / (1 + r) with its growth g
    if (term == 1) b[N] = d[N] / r
    else {
        g = q[N] / q[N - 1]
        b[N] = d[N] / (1 + r - g)
    }
    for (k = N - 1; k >= 1; k--) b[k] = (d[k] + (k + 1 == N ? q[N] : q[k + 1])) / (1 + r)
    return(max(abs(b - q) :/ abs(q)))
}

// The Jacobian of the stacked system of the run set up but not yet solved,
// at a point near the start, against central differences of its residuals:
// the largest difference relative to the largest entry of its column
real scalar _tf_jaccheck()
{
    struct cge_model scalar M
    struct cge_dyn scalar D
    struct cge_fs scalar FS
    struct cge_sys scalar S
    struct cge_fsw scalar W
    real colvector u, ri, ci, v, du, Rp, Rm, col
    real matrix A
    real scalar n, j, h, worst, nw
    M = _cge_load()
    D = _cge_dyn_load()
    FS = _cge_fs_load()
    S = _cge_sys_make(M, 0)
    nw = _cge_fs_warm(M, D, FS, S, W)
    u = _cge_fs_pack(FS, W)
    rseed(5)
    u = u :* (1 :+ 1e-3 :* rnormal(rows(u), 1, 0, 1))
    if (!_cge_fs_jac(M, D, FS, S, u, ri, ci, v)) return(.)
    n = rows(u)
    A = J(n, n, 0)
    for (j = 1; j <= rows(v); j++) A[ri[j], ci[j]] = A[ri[j], ci[j]] + v[j]
    worst = 0
    for (j = 1; j <= n; j++) {
        h = 1e-6 * max((1, abs(u[j])))
        du = J(n, 1, 0)
        du[j] = h
        Rp = _cge_fs_resid(M, D, FS, S, u + du)
        Rm = _cge_fs_resid(M, D, FS, S, u - du)
        col = (Rp - Rm) / (2 * h)
        if (hasmissing(col)) return(.)
        worst = max((worst, max(abs(A[., j] - col)) / max((1, max(abs(col))))))
    }
    st_numscalar("tf_n", n)
    return(worst)
}
end

capture program drop _tf_check
program define _tf_check
    args a b tol what
    mata: st_numscalar("tf_d", _tf_runs("`a'", "`b'"))
    display as text "`what': " as result %9.2e scalar(tf_d)
    assert scalar(tf_d) < `tol'
end

* ---------------------------------------------------------------------
* 1. Without leads, the recursive run
* ---------------------------------------------------------------------
capture program drop _tf_tariff
program define _tf_tariff
    args t
    if `t' == 2 cge_shock tm, elements(com_man) value(0)
end
* mobile capital, efficiency growth, a tariff cut in period 2
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
quietly cge_dynamic, name(r1) periods(0/4) `common' tfp(0.01) shocks(_tf_tariff)
cge_dynamic, name(f1) periods(0/4) `common' tfp(0.01) shocks(_tf_tariff) foresight
assert "`r(sims)'" == "f10 f11 f12 f13 f14" & "`r(foresight)'" == "foresight"
_tf_check r1 f1 1e-9 "mobile capital, foresight against recursive"
quietly cge_dynamic, name(f1b) periods(0/4) `common' tfp(0.01) shocks(_tf_tariff) foresight start(base)
_tf_check r1 f1b 1e-9 "mobile capital, from the base"
* the model is left as it was
quietly cge_solve, name(after)
assert r(iterations) == 0

* capital specific to each activity, rents shared with sensitivity 2, and a
* shock to the capital stocks (a fifth destroyed in period 3)
capture program drop _tf_quake
program define _tf_quake
    args t
    if `t' == 3 cge_shock QF, elements(cap) scale(0.8)
end
quietly cge_closure, factors(cap:specific)
quietly cge_dynamic, name(r2) periods(0/5) `common' tfp(0.01) sensitivity(2) shocks(_tf_quake)
quietly cge_dynamic, name(f2) periods(0/5) `common' tfp(0.01) sensitivity(2) shocks(_tf_quake) foresight
_tf_check r2 f2 1e-9 "specific capital and its shock, foresight against recursive"
quietly cge_dynamic, name(f2b) periods(0/5) `common' tfp(0.01) sensitivity(2) shocks(_tf_quake) foresight start(base)
_tf_check r2 f2b 1e-9 "specific capital, from the base"

* growth targets: the efficiency factors as well
quietly cge_dynamic, name(r3) periods(0/3) `common' gdpgrowth(0.04 0.03 0.05)
quietly cge_dynamic, name(f3) periods(0/3) `common' gdpgrowth(0.04 0.03 0.05) foresight start(base)
_tf_check r3 f3 1e-9 "growth targets"
mata: st_numscalar("tf_d", _tf_lamdiff("r3", "f3"))
display as text "efficiency factors: " as result %9.2e scalar(tf_d)
assert scalar(tf_d) < 1e-10
* a baseline's efficiency path
quietly cge_dynamic, name(r3b) periods(0/3) `common' baseline(r3)
quietly cge_dynamic, name(f3b) periods(0/3) `common' baseline(r3) foresight
_tf_check r3b f3b 1e-9 "a baseline's efficiency"
quietly cge_closure, factors(cap:mobile)

* public debt, with relief of half the foreign debt in period 2
capture program drop _tf_relief
program define _tf_relief
    args t
    if `t' == 2 cge_shock fdebt, scale(0.5)
end
local debt debt(domestic:100 foreign:40) interest(domestic:0.05 foreign:0.03)
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, `instmap'
quietly cge_calibrate, `sigmas' `debt'
quietly cge_closure, factors(cap:specific)
quietly cge_dynamic, name(r4) periods(0/4) `common' tfp(0.01) shocks(_tf_relief)
quietly cge_dynamic, name(f4) periods(0/4) `common' tfp(0.01) shocks(_tf_relief) foresight
_tf_check r4 f4 1e-9 "public debt and its relief"
quietly cge_dynamic, name(f4b) periods(0/4) `common' tfp(0.01) shocks(_tf_relief) foresight start(base)
_tf_check r4 f4b 1e-9 "public debt, from the base"

* deaths at working ages, with more health services from period 1
capture program drop _tf_health
program define _tf_health
    args t
    if `t' == 1 cge_shock qg, elements(com_hlt) scale(1.2)
end
quietly cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, `hltmap'
quietly cge_calibrate, `sigmas' healthcom(com_hlt) sickdays(lab:0.05) sickelas(lab:-0.4) mortality(0.01) mortelas(-0.3)
quietly cge_closure, factors(cap:specific)
local deaths deathfactors(lab) deathshare(0.3) workingage(0.55)
quietly cge_dynamic, name(r5) periods(0/4) `common' tfp(0.01) `deaths' shocks(_tf_health)
quietly cge_dynamic, name(f5) periods(0/4) `common' tfp(0.01) `deaths' shocks(_tf_health) foresight start(base)
_tf_check r5 f5 1e-9 "deaths and population, foresight against recursive"

* lags in user equations: partial adjustment that feeds back on government
* consumption
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
cge_variable GPATH, value(1)
cge_equation gpa: GPATH = 0.6 * lag(GPATH) + 0.4 * QA(act_man) / base(QA(act_man))
cge_variable GRULE = QG(com_ser) / (base(QG(com_ser)) * GPATH)
quietly cge_closure, swap(GRULE GADJ)
quietly cge_dynamic, name(r6) periods(0/4) `common' tfp(0.01) shocks(_tf_tariff)
quietly cge_dynamic, name(f6) periods(0/4) `common' tfp(0.01) shocks(_tf_tariff) foresight start(base)
_tf_check r6 f6 1e-9 "lags, foresight against recursive"
quietly cge_closure, swap(none)
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 2. The Jacobian of the stacked system against central differences, with
* lags and leads and both terminal conditions: specific capital, debt and
* growth targets; then deaths and population
* ---------------------------------------------------------------------
capture program drop _tf_jac
program define _tf_jac
    args what gdp deaths
    foreach term in constant growth {
        mata: _cge_dyn_start("fj", "0 1 2 3", "cap", "0.05", "0.15", 1.5, "lab:0.02", "`=cond("`gdp'" == "", "0.01", "")'", ///
            "`gdp'", "", 0.02, 0.03, 0.01, 1e-12, 100, "`deaths'", `=cond("`deaths'" == "", 0, 0.3)', ///
            `=cond("`deaths'" == "", 1, 0.55)', 1)
        mata: _cge_fs_start("`term'", "")
        forvalues t = 1/3 {
            mata: _cge_fs_advance()
            mata: _cge_fs_record()
        }
        mata: st_numscalar("tf_d", _tf_jaccheck())
        mata: _cge_dyn_abort()
        display as text "Jacobian of the stacked system, `what' (`term'), " scalar(tf_n) " unknowns: largest difference " ///
            as result %9.2e scalar(tf_d)
        assert scalar(tf_d) < 1e-6
    }
end
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, `instmap'
quietly cge_calibrate, `sigmas' `debt'
quietly cge_closure, factors(cap:specific)
cge_variable GPATH, value(1)
cge_equation gpa: GPATH = 0.5 * lag(GPATH) + 0.5 * lead(GPATH) * QA(act_man) / base(QA(act_man))
cge_variable GRULE = QG(com_ser) / (base(QG(com_ser)) * GPATH)
quietly cge_closure, swap(GRULE GADJ)
_tf_jac "debt and growth targets" "0.03 0.04 0.02"
quietly cge_closure, swap(none)
quietly cge_equation, clear
quietly cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, `hltmap'
quietly cge_calibrate, `sigmas' healthcom(com_hlt) sickdays(lab:0.05) mortality(0.01) mortelas(-0.3)
quietly cge_closure, factors(cap:specific)
cge_variable GPATH, value(1)
cge_equation gpa: GPATH = 0.5 * lag(GPATH) + 0.5 * lead(GPATH) * QA(act_man) / base(QA(act_man))
cge_variable GRULE = QG(com_ser) / (base(QG(com_ser)) * GPATH)
quietly cge_closure, swap(GRULE GADJ)
_tf_jac "deaths and population" "" lab
quietly cge_closure, swap(none)
quietly cge_equation, clear
program drop _tf_jac

* ---------------------------------------------------------------------
* 3. Leads against a backward recursion, and the terminal conditions
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
cge_variable DIV = YF(cap) / CPI
quietly cge_solve, name(b0)
quietly cge_results, sim(b0) clear nodisplay
quietly summarize value if variable == "DIV"
local q0 = r(mean) / 0.05
cge_variable QK, value(`q0')
cge_equation qk: QK = (DIV + lead(QK)) / 1.05
foreach term in constant growth {
    quietly cge_dynamic, name(l`term') periods(0/5) `common' tfp(0.01) shocks(_tf_tariff) foresight terminal(`term')
    mata: st_numscalar("tf_d", _tf_leads("l`term'", "QK", "DIV", 0.05, ("`term'" == "constant" ? 1 : 2)))
    display as text "leads against the backward recursion (`term'): " as result %9.2e scalar(tf_d)
    assert scalar(tf_d) < 1e-10
}
* the leads do not feed back: the other variables are those of the run
* without them
quietly cge_equation, clear
quietly cge_dynamic, name(lnone) periods(0/5) `common' tfp(0.01) shocks(_tf_tariff)
quietly cge_results, sim(lconstant3) clear nodisplay
rename value v_l
tempfile lc
quietly save `lc'
quietly cge_results, sim(lnone3) clear nodisplay
quietly merge 1:1 variable element1 element2 using `lc', nogenerate keep(match)
quietly generate double rel = abs(value - v_l) / max(1, abs(value)) if !inlist(variable, "QK", "DIV")
quietly summarize rel
assert r(max) < 1e-9

* ---------------------------------------------------------------------
* 4. Forward-looking investment: Tobin's q, with a tariff cut in period 3
* known from period 0
* ---------------------------------------------------------------------
capture program drop _tf_later
program define _tf_later
    args t
    if `t' == 3 cge_shock tm, value(0)
end
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
quietly cge_closure, savinv(investment)
cge_parameter rint = 0.05
cge_parameter delta = 0.05
cge_variable RK = W(cap) / CPI
quietly cge_solve, name(b0)
quietly cge_results, sim(b0) clear nodisplay
quietly summarize value if variable == "RK"
local q0 = r(mean) / 0.10
cge_variable Q, value(`q0')
cge_equation qeq: Q = (lead(RK) + (1 - delta) * lead(Q)) / (1 + rint)
cge_variable IRULE = IADJ / (Q / base(Q))^2
quietly cge_closure, swap(IRULE IADJ)
cge_dynamic, name(tq) periods(0/8) capital(cap) depreciation(0.05) rental(0.10) growth(lab:0.02) shocks(_tf_later) foresight
* each period solves its own model, given the periods around it
mata: _tf_own("tq")
display as text "each period on its own: " as result %9.2e scalar(tf_d) as text "; leads against the next period: " ///
    as result %9.2e scalar(tf_e)
assert scalar(tf_d) < 1e-9 & scalar(tf_e) < 1e-12
* from the base, the same solution
quietly cge_dynamic, name(tqb) periods(0/8) capital(cap) depreciation(0.05) rental(0.10) growth(lab:0.02) shocks(_tf_later) ///
    foresight start(base)
_tf_check tq tqb 1e-9 "Tobin's q from the base"
* investment moves before the tariff cut, which a recursive run cannot see
quietly cge_results, sim(tq1) clear nodisplay
quietly summarize value if variable == "IADJ"
local i1 = r(mean)
quietly cge_results, sim(tq2) clear nodisplay
quietly summarize value if variable == "IADJ"
assert abs(`i1' - 1) > 1e-6 | abs(r(mean) - 1) > 1e-6

* ---------------------------------------------------------------------
* 5. The period in user equations
* ---------------------------------------------------------------------
quietly cge_closure, swap(none)
quietly cge_equation, clear
cge_variable TP = tperiod + 10 * tfirst + 100 * tlast
quietly cge_dynamic, name(tpr) periods(3/6) `common'
quietly cge_dynamic, name(tpf) periods(3/6) `common' foresight
foreach r in tpr tpf {
    forvalues t = 3/6 {
        quietly cge_results, sim(`r'`t') clear nodisplay
        quietly summarize value if variable == "TP"
        assert r(mean) == `t' + 10 * (`t' == 3) + 100 * (`t' == 6)
    }
}
quietly cge_shock, reset
quietly cge_solve, name(tps)
quietly cge_results, sim(tps) clear nodisplay
quietly summarize value if variable == "TP"
assert r(mean) == 0
* ifthen() on the period: a different equation in the last period
quietly cge_equation, clear
cge_variable Z, value(1)
cge_equation zeq: Z = ifthen(tlast, 2, 1 + 0 * lead(Z))
quietly cge_dynamic, name(tz) periods(0/2) `common' foresight
forvalues t = 0/2 {
    quietly cge_results, sim(tz`t') clear nodisplay
    quietly summarize value if variable == "Z"
    assert reldif(r(mean), 1 + (`t' == 2)) < 1e-12
}

* ---------------------------------------------------------------------
* 6. Errors
* ---------------------------------------------------------------------
quietly cge_equation, clear
cge_variable Z, value(1)
cge_equation zeq: Z = 0.5 + 0.5 * lead(Z)
capture noisily cge_dynamic, name(bad) periods(0/2) `common'
assert _rc == 198
capture noisily cge_dynamic, name(bad) periods(0/2) `common' foresight terminal(flat)
assert _rc == 198
capture noisily cge_dynamic, name(bad) periods(0/2) `common' foresight start(nowhere)
assert _rc == 198
capture noisily cge_dynamic, name(bad) periods(0/2) `common' terminal(growth)
assert _rc == 198
capture noisily cge_equation zz: Z = lead(Z, 5)
assert _rc == 198
capture noisily cge_variable tlast, value(1)
assert _rc == 198
capture noisily cge_variable W2 = lead(W2)
assert _rc != 0
capture noisily cge_equation zz(c)$(tlast): Z = 1
assert _rc == 198
* runs that fail are not stored, and leave the model as it was
mata: st_numscalar("tf_n", _tf_count("bad"))
assert scalar(tf_n) == 0
quietly cge_equation, clear
* shocks that a run with foresight cannot follow
capture program drop _tf_badshock
program define _tf_badshock
    args t
    if `t' == 1 cge_shock ad, scale(1.1)
end
capture noisily cge_dynamic, name(bad) periods(0/2) `common' gdpgrowth(0.03 0.03) shocks(_tf_badshock) foresight
assert _rc == 198
capture program drop _tf_badclosure
program define _tf_badclosure
    args t
    if `t' == 1 cge_closure, swap(GSAV GADJ)
end
capture noisily cge_dynamic, name(bad) periods(0/2) `common' shocks(_tf_badclosure) foresight
assert _rc == 198
quietly cge_closure, swap(none)
mata: mata drop _tf_runs() _tf_jaccheck() _tf_own() _tf_leads() _tf_lamdiff() _tf_count()
