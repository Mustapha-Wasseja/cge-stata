* test_template.do -- sums compiled from one term, and the values of the
* user equations kept at the base (version 0.49.0; docs/model_spec.md,
* Section 59): models built with every sum written out, as before, and with
* sums compiled from one term give the same rows, GAMS text, scales and base
* values; references to subsets, to parameters of three and four indexes
* and to variables of two; products; conditions; sums that stay written out
* (a condition in the body, ord(), base(), lags, smax()); sums within
* conditions, functions and other sums; sets of pairs; the errors of a
* reference written out; the values at the base as equations are added; a
* model from a SAM; and a dense model, solved both ways.

version 13.0

capture mata: mata drop _ttm_keep()
capture mata: mata drop _ttm_same()
capture mata: mata drop _ttm_forget()
capture mata: mata drop _ttm_unkeep()
capture mata: mata drop _ttm_base()
capture mata: mata drop _ttm_simdiff()
_cge_load
mata:
// The model in memory kept in external nm
void _ttm_keep(string scalar nm)
{
    struct cge_model scalar M
    pointer() scalar q
    M = _cge_load()
    if ((q = findexternal(nm)) == NULL) q = crexternal(nm)
    *q = M
}

// 1 if the models kept in a and b have the same user equations, row for
// row, with the same GAMS text, labels, masks and base values, and scales
// that agree to rounding (from the tape in one, row by row in the other)
real scalar _ttm_same(string scalar a, string scalar b)
{
    struct cge_model scalar A, B
    A = *findexternal(a)
    B = *findexternal(b)
    if (rows(A.escale) != rows(B.escale)) return(0)
    if (rows(A.escale)) if (max(abs(A.escale - B.escale) :/ B.escale) > 1e-14) return(0)
    return(A.utok == B.utok & A.uegams == B.uegams & A.uelab == B.uelab & A.ustart == B.ustart &
           A.ulen == B.ulen & A.ulen2 == B.ulen2 & A.upar == B.upar & A.emask == B.emask &
           A.x0 == B.x0 & A.exists == B.exists)
}

// The elements kept from one build to the next, and the values kept at the
// base, forgotten
void _ttm_forget()
{
    if (findexternal("cge__ubmemo") != NULL) rmexternal("cge__ubmemo")
    if (findexternal("cge__ubv") != NULL) rmexternal("cge__ubv")
}

// The models kept, removed
void _ttm_unkeep()
{
    if (findexternal("ttm_a") != NULL) rmexternal("ttm_a")
    if (findexternal("ttm_b") != NULL) rmexternal("ttm_b")
}

// The largest relative difference between the two sides of the user
// equations at the base with the values kept and read row by row, and the
// number of elements whose values were kept
real rowvector _ttm_base()
{
    struct cge_model scalar M
    real colvector l0, r0, l1, r1
    real scalar n0
    M = _cge_load()
    (void) _cge_dmode(0)
    _cge_u_eval(M, M.p0, M.x0, l0, r0)
    l1 = r1 = J(rows(M.uelab), 1, .)
    n0 = _cge_u_bvhit(M, M.p0, M.x0, l1, r1)
    (void) _cge_dmode(2)
    _cge_u_eval(M, M.p0, M.x0, l1, r1)
    (void) _cge_dmode(0)
    return((max((max(abs(l0 - l1) :/ (1 :+ abs(l1))), max(abs(r0 - r1) :/ (1 :+ abs(r1))))), n0))
}

// The largest difference between the solutions of simulations a and b,
// relative to the scale of each variable
real scalar _ttm_simdiff(string scalar a, string scalar b)
{
    struct cge_model scalar M
    real scalar ia, ib
    M = _cge_load()
    ia = _cge_find(M.simname, a)
    ib = _cge_find(M.simname, b)
    return(max(abs(M.simx[., ia] - M.simx[., ib]) :/ M.xscale))
}
end

* A model built with every sum written out (kept as ttm_a) and with sums
* compiled from one term (ttm_b); tt_same 1 if they agree, tt_n1 and tt_n0
* the sums compiled from one term in each
capture program drop _ttm_both
program define _ttm_both
    args model
    mata: (void) _cge_u_tploff(1)
    mata: _ttm_forget()
    mata: (void) _cge_u_ntpl(0)
    quietly `model'
    mata: st_numscalar("tt_n1", _cge_u_ntpl())
    mata: _ttm_keep("ttm_a")
    mata: (void) _cge_u_tploff(0)
    mata: _ttm_forget()
    mata: (void) _cge_u_ntpl(0)
    quietly `model'
    mata: st_numscalar("tt_n0", _cge_u_ntpl())
    mata: _ttm_keep("ttm_b")
    mata: st_numscalar("tt_same", _ttm_same("ttm_a", "ttm_b"))
end

* ---------------------------------------------------------------------
* 1. Subsets, parameters of three and four indexes, a variable of two,
*    products, negation, powers and sums within functions
* ---------------------------------------------------------------------
capture program drop _ttm_m1
program define _ttm_m1
    cge_model new
    cge_set i = r1 r2 r3 r4
    cge_set j = i
    cge_set k = k1 k2 k3
    cge_set s(i) = r2 r4
    cge_parameter a(i) = 0.4 + 0.1 * ord(i)
    cge_parameter b(i,j) = 0.05 * ord(i) + 0.02 * ord(j)
    cge_parameter c(i,j,k) = 0.01 * ord(i) + 0.003 * ord(j) + 0.002 * ord(k)
    cge_parameter d(i,j,k,i2) = 0.001 * ord(i) * ord(i2) + 0.0005 * ord(k)
    cge_parameter e(k) = 1 + 0.5 * ord(k)
    cge_variable X(i), value(1)
    cge_variable V(i,k), value(1)
    cge_variable T, value(1)
    cge_variable Y = sum(i, a(i) * X(i)) + sum(s, X(s)^2)
    cge_equation EX(i): X(i) = 1 + sum(j, b(j,i) * ln(X(j) / b(j,i))) / 10 + sum(k, c(i,i,k) * V(i,k)) - sum(i2, d(i,r1,k1,i2) * X(i2))
    cge_equation EV(i,k): V(i,k) = e(k) * (1 + sum(j, c(i,j,k) * X(j)^2)) + sum(j, -d(i,j,k,r2) / X(j))
    cge_equation ET: T = prod(s, X(s)) + sum(s, -X(s) / a(s)) + exp(sum(j, a(j) * 0.1)) + Y / 10 + sqrt(sum(k, e(k) * V(r3,k)))
end
_ttm_both _ttm_m1
display as text "subsets and parameters of several indexes: the same " as result scalar(tt_same) ///
    as text ", sums from one term " as result scalar(tt_n0) as text " (" as result scalar(tt_n1) as text " written out)"
assert scalar(tt_same) == 1
assert scalar(tt_n1) == 0
assert scalar(tt_n0) >= 9
quietly cge_solve, name(m1b) tolerance(1e-12)
assert r(converged) == 1
mata: st_matrix("tt_b", _ttm_base())
assert tt_b[1, 1] < 1e-14
mata: (void) _cge_u_tploff(1)
quietly cge_solve, name(m1a) tolerance(1e-12)
assert r(converged) == 1
mata: (void) _cge_u_tploff(0)
mata: st_numscalar("tt_d", _ttm_simdiff("m1a", "m1b"))
assert scalar(tt_d) < 1e-12

* ---------------------------------------------------------------------
* 2. Conditions; sums that stay written out; sums within conditions,
*    functions and other sums; sets of pairs; an empty sum
* ---------------------------------------------------------------------
capture program drop _ttm_m2
program define _ttm_m2
    cge_model new
    cge_set t = t1 t2 t3 t4 t5
    cge_set j = t
    cge_set m(t,j) = t1.t2 t2.t3 t3.t4 t4.t5 t5.t1
    cge_parameter w(t) = ord(t)
    cge_parameter z(t,j) = 0.1 * ord(t) * ord(j)
    cge_variable Q(t), value(1)
    cge_variable R, value(0)
    cge_variable G(t)$(w(t) > 1), value(1)
    cge_equation EQ(t): Q(t) = 1 + sum(j$(w(j) > 2), z(t,j) * Q(j)) / 100 + sum(j, z(j,t)$(w(j) > 3) * Q(j)) / 100 + sum(j, ord(j) * Q(j)) / 1000 + sum(j, base(Q(j)) * z(t,j)) / 1000 + max(0, sum(j, z(t,j)) - 1) + sum(j, z(t,j) * Q(j-1)) / 100
    cge_equation EG(t)$(w(t) > 1): G(t) = sum(j$(sum(t2, z(t2,j)) > 1), z(t,j) * Q(j)) / 10 + 1
    cge_equation ER: R = sum(m(t,j), z(t,j) * Q(j)) + sum((t,j), z(t,j)) / 100 - sum(t, smax(j, z(t,j) * Q(j))) + sum(t, sum(j, z(t,j) * Q(t) * Q(j))) / 1000 + sum(t$(w(t) > 10), Q(t)) + ifthen(w(t1) > 0, sum(j, Q(j)), 0)
end
_ttm_both _ttm_m2
display as text "conditions and sums written out: the same " as result scalar(tt_same) ///
    as text ", sums from one term " as result scalar(tt_n0)
assert scalar(tt_same) == 1
assert scalar(tt_n0) >= 10
quietly cge_solve, name(m2b) tolerance(1e-12)
assert r(converged) == 1
mata: st_matrix("tt_b", _ttm_base())
assert tt_b[1, 1] < 1e-14

* ---------------------------------------------------------------------
* 3. The errors of a reference written out, with either
* ---------------------------------------------------------------------
cge_model new
cge_set i = r1 r2 r3
cge_set j = i
cge_set s(i) = r1 r3
cge_set k = k1 k2
cge_parameter a(i) = ord(i)
cge_parameter av(s) = ord(s)
cge_parameter ak(i,k) = ord(i) * ord(k)
cge_variable X(i), value(1)
cge_variable XS(s), value(1)
local bad1 "sum(j, X(j, j))"
local rc1 198
local bad2 "sum(i, av(i))"
local rc2 111
local bad3 "sum(i, XS(i))"
local rc3 111
local bad4 "sum(j, a(k))"
local rc4 198
local bad5 "sum(j, a(j, k1))"
local rc5 198
local bad6 "sum(j, nosuch(j))"
local rc6 111
local bad7 "sum(i, ak(i, k3))"
local rc7 198
local bad8 "sum(k, ak(r4, k))"
local rc8 111
forvalues b = 1/8 {
    foreach mode in 1 0 {
        mata: (void) _cge_u_tploff(`mode')
        capture cge_equation BAD: X(r1) = `bad`b''
        if _rc != `rc`b'' {
            display as error "error `b' (`bad`b''), mode `mode': rc " _rc ", expected `rc`b''"
            exit 9
        }
    }
}
mata: (void) _cge_u_tploff(0)
display as text "the errors of references in sums: as written out"

* ---------------------------------------------------------------------
* 4. The values at the base kept as equations are added: those found
*    before, and the values row by row
* ---------------------------------------------------------------------
mata: _ttm_forget()
cge_model new
cge_set i = r1 r2 r3 r4 r5
cge_set j = i
cge_parameter b(i,j) = 0.02 * ord(i) + 0.01 * ord(j)
cge_variable X(i), value(1 + ord(i) / 10)
cge_variable Z(i), value(2)
cge_variable U, value(1)
cge_equation EX(i): X(i) = 1 + ord(i) / 10 + sum(j, b(i,j) * (X(j) - 1 - ord(j) / 10))
mata: st_matrix("tt_b", _ttm_base())
assert tt_b[1, 1] < 1e-14
cge_equation EZ(i): Z(i) = 2 + sum(j, b(j,i) * ln(Z(j) / 2))
mata: st_matrix("tt_b", _ttm_base())
assert tt_b[1, 1] < 1e-14
assert tt_b[1, 2] == 10
cge_equation EU: U = sum(i, X(i) * Z(i)) / sum(i, 2 + 2 * ord(i) / 10)
mata: st_matrix("tt_b", _ttm_base())
assert tt_b[1, 1] < 1e-14
assert tt_b[1, 2] == 11
* the equations changed: their values found again
quietly cge_equation, clear
cge_variable X(i), value(1)
cge_equation EX(i): X(i)^2 = ord(i)
mata: st_matrix("tt_b", _ttm_base())
assert tt_b[1, 1] < 1e-14
quietly cge_solve, name(m4)
assert r(converged) == 1
mata: st_matrix("tt_b", _ttm_base())
assert tt_b[1, 1] < 1e-14
display as text "values at the base kept as equations are added: the same as row by row"

* ---------------------------------------------------------------------
* 5. A model from a SAM with user variables and equations
* ---------------------------------------------------------------------
capture program drop _ttm_m5
program define _ttm_m5
    cge_synthetic, clear
    cge_sam, labels(account)
    cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
        factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)        ///
        dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
    cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
    cge_variable GEXP = sum(c, PQ(c) * QG(c)) / CPI + max(0, sum(c, QM(c)) - 1e6), nominal
    cge_variable PREL(c) = PQ(c)^0.5 * exp(0.01 * QQ(c) / base(QQ(c))) / CPI
    cge_variable VSH(a) = PA(a) * QA(a) / sum(a2, PA(a2) * QA(a2))
end
_ttm_both _ttm_m5
display as text "a model from a SAM: the same " as result scalar(tt_same) as text ", sums from one term " as result scalar(tt_n0)
assert scalar(tt_same) == 1
assert scalar(tt_n0) >= 3

* ---------------------------------------------------------------------
* 6. A dense model of 25 sectors, built and solved both ways
* ---------------------------------------------------------------------
capture program drop _ttm_m6
program define _ttm_m6
    cge_model new
    local labs
    forvalues k = 1/25 {
        local labs `labs' g`k'
    }
    cge_set g = `labs'
    cge_set f = lab cap
    cge_parameter bg(g,g2) = 0.25 / card(g) * (1 + ord(g) * ord(g2) / (card(g) * card(g)))
    cge_parameter sh(f), values(lab:0.6 cap:0.4)
    cge_parameter bf(f,g) = sh(f) * (1 - sum(g2, bg(g2,g)))
    cge_parameter gam(g) = 1 / card(g)
    cge_parameter endow(f), values(lab:100 cap:50)
    cge_variable P(g), value(1)
    cge_variable W(f), value(1)
    cge_variable Z(g), value(100)
    cge_variable WALRAS, value(0)
    cge_variable Y = sum(f, W(f) * endow(f))
    cge_equation NUM: W(lab) = 1
    cge_equation ZP(g): ln(P(g)) = sum(g2, bg(g2,g) * ln(P(g2) / bg(g2,g))) + sum(f, bf(f,g) * ln(W(f) / bf(f,g)))
    cge_equation MKT(g): P(g) * Z(g) = sum(g2, bg(g,g2) * P(g2) * Z(g2)) + gam(g) * Y
    cge_equation FAC(f): W(f) * endow(f) = sum(g, bf(f,g) * P(g) * Z(g)) + WALRAS
end
_ttm_both _ttm_m6
display as text "dense model of 25 sectors: the same " as result scalar(tt_same) as text ", sums from one term " as result scalar(tt_n0)
assert scalar(tt_same) == 1
assert scalar(tt_n0) >= 77
quietly cge_solve, name(m6b)
assert r(converged) == 1
mata: (void) _cge_u_tploff(1)
quietly cge_solve, name(m6a)
assert r(converged) == 1
mata: (void) _cge_u_tploff(0)
mata: st_numscalar("tt_d", _ttm_simdiff("m6a", "m6b"))
assert scalar(tt_d) < 1e-12

mata: (void) _cge_u_tploff(0)
mata: _ttm_forget()
mata: _ttm_unkeep()
capture program drop _ttm_both
capture program drop _ttm_m1
capture program drop _ttm_m2
capture program drop _ttm_m5
capture program drop _ttm_m6
mata: mata drop _ttm_keep() _ttm_same() _ttm_forget() _ttm_unkeep() _ttm_base() _ttm_simdiff()
scalar drop _all
capture matrix drop tt_b
