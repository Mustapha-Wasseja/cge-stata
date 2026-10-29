* test_fsjac.do -- exact state derivatives in runs with foresight (version
* 0.32.0; docs/model_spec.md, Section 42): the Jacobian of the stacked
* system, with the derivatives of each period in its states other than
* capital exact, against central differences of its residuals and against
* the differences used before: debt and growth targets; deaths with a labour
* force and a wage curve, health efficiency and days lost to illness; user
* equations that use debt, the efficiency parameter, the health services of
* the base and the labour force. The solutions of runs agree in each mode.

version 13.0

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
capture mata: mata drop _tj_check()
capture mata: mata drop _tj_runs()
capture mata: mata drop _tj_mode()
mata:
// The Jacobian of the stacked system of the run set up, near its start,
// with the states' derivatives exact (fd 0) or by differences (fd 1),
// against central differences of the residuals: the largest difference
// relative to the largest entry of its column; tj_n the unknowns, tj_t the
// seconds for the Jacobian
real scalar _tj_check(real scalar fd)
{
    struct cge_model scalar M
    struct cge_dyn scalar D
    struct cge_fs scalar FS
    struct cge_sys scalar S
    struct cge_fsw scalar W
    real colvector u, ri, ci, v, du, Rp, Rm, col
    real matrix A
    real scalar n, j, h, worst, nw
    pointer() scalar q
    M = _cge_load()
    D = _cge_dyn_load()
    FS = _cge_fs_load()
    S = _cge_sys_make(M, 0)
    nw = _cge_fs_warm(M, D, FS, S, W)
    u = _cge_fs_pack(FS, W)
    rseed(7)
    u = u :* (1 :+ 1e-3 :* rnormal(rows(u), 1, 0, 1))
    if ((q = findexternal("cge__fsfd")) == NULL) q = crexternal("cge__fsfd")
    *q = fd
    stata("timer clear 97")
    stata("timer on 97")
    j = _cge_fs_jac(M, D, FS, S, u, ri, ci, v)
    stata("timer off 97")
    *q = 0
    if (!j) return(.)
    stata("quietly timer list 97")
    st_numscalar("tj_t", st_numscalar("r(t97)"))
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
    st_numscalar("tj_n", n)
    return(worst)
}

// Sets the mode of the states' derivatives: 0 exact, 1 differences
void _tj_mode(real scalar fd)
{
    pointer() scalar q
    if ((q = findexternal("cge__fsfd")) == NULL) q = crexternal("cge__fsfd")
    *q = fd
}

// The largest difference between the periods of runs a and b, relative to
// the scale of each variable
real scalar _tj_runs(string scalar a, string scalar b)
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

* The stacked Jacobian set up for three periods, in each mode
capture program drop _tj_jac
program define _tj_jac
    args what gdp deaths
    foreach fd in 0 1 {
        mata: _cge_dyn_start("fj", "0 1 2 3", "cap", "0.05", "0.15", 1.5, "lab:0.02", "`=cond("`gdp'" == "", "0.01", "")'", ///
            "`gdp'", "", 0.02, 0.03, 0.01, 1e-12, 100, "`deaths'", `=cond("`deaths'" == "", 0, 0.3)', ///
            `=cond("`deaths'" == "", 1, 0.55)', 1)
        mata: _cge_fs_start("constant", "")
        forvalues t = 1/3 {
            mata: _cge_fs_advance()
            mata: _cge_fs_record()
        }
        mata: st_numscalar("tj_d`fd'", _tj_check(`fd'))
        mata: _cge_dyn_abort()
        local t`fd' = scalar(tj_t)
    }
    display as text "`what', " scalar(tj_n) " unknowns: exact against differences " as result %9.2e scalar(tj_d0) ///
        as text ", before " as result %9.2e scalar(tj_d1) as text "; seconds `t0' and `t1'"
    assert scalar(tj_d0) < 1e-6 & scalar(tj_d1) < 1e-6
end

* ---------------------------------------------------------------------
* 1. Debt and growth targets, with user equations that use the debt and
*    the efficiency parameter
* ---------------------------------------------------------------------
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, `instmap'
quietly cge_calibrate, `sigmas' debt(domestic:100 foreign:40) interest(domestic:0.05 foreign:0.03)
quietly cge_closure, factors(cap:specific)
cge_variable DEBTR = (ddebt + fdebt * EXR) / (0.01 + sum(a, ad(a) * QA(a)))
cge_variable ADX(a) = ad(a) * QVA(a) / base(QVA(a))
_tj_jac "debt and growth targets" "0.03 0.04 0.02"
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 2. Deaths with a labour force and a wage curve, health efficiency and
*    days lost to illness; user equations that use the health services of
*    the base and the labour force
* ---------------------------------------------------------------------
quietly cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, `hltmap'
quietly cge_calibrate, `sigmas' healthcom(com_hlt) healthfac(lab) healthelas(0.3) sickdays(lab:0.05) sickelas(-0.2) ///
    mortality(0.01) mortelas(-0.3) unemployment(lab:0.1) wagecurve(lab:0.1)
quietly cge_closure, factors(cap:specific lab:wagecurve)
cge_variable HSR = HS / hs0
cge_variable LFR = QFS(lab) / qlf(lab)
_tj_jac "deaths, a wage curve and health efficiency" "" lab
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 3. The runs in each mode: the same solutions
* ---------------------------------------------------------------------
cge_variable HSR = HS / hs0
foreach fd in 0 1 {
    mata: _tj_mode(`fd')
    timer clear 1
    timer on 1
    quietly cge_dynamic, name(run`fd') periods(0/4) `common' tfp(0.01) foresight deathfactors(lab) deathshare(0.3) workingage(0.55)
    timer off 1
    quietly timer list 1
    local s`fd' = r(t1)
}
mata: _tj_mode(0)
mata: st_numscalar("tj_d", _tj_runs("run0", "run1"))
display as text "runs with foresight, exact and differences: " as result %9.2e scalar(tj_d) as text "; seconds `s0' and `s1'"
assert scalar(tj_d) < 1e-10
quietly cge_closure, swap(none)
quietly cge_equation, clear
program drop _tj_jac
