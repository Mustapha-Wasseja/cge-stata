* test_tape.do -- the user equations as one tape (version 0.48.0;
* docs/model_spec.md, Section 58): values and derivatives against reading
* every element row by row, and derivatives against central differences, over
* every operation on the tape; elements that stay off it among those on it;
* derivatives that are not defined; a model of one equation; variables
* repeated in an equation; parameters read at each solve; a tape made again
* when the equations change, kept for models that take turns; a long sum; a
* dense model; and a model from a SAM with user equations.

version 13.0

capture mata: mata drop _ttp_cmp()
capture mata: mata drop _ttp_count()
capture mata: mata drop _ttp_simdiff()
capture mata: mata drop _ttp_ent()
capture mata: mata drop _ttp_nrows()
capture mata: mata drop _ttp_kept()
_cge_load
mata:
// The largest difference between the two sides of the elements and between
// the entries of the Jacobian, on the tape and row by row, at the start of
// the model with the free variables moved by up to +-spread; then 1 if the
// entries are in the same places, and the elements on and off the tape
real rowvector _ttp_cmp(real scalar spread)
{
    struct cge_model scalar M
    struct cge_sys scalar S
    pointer(struct cge_tape scalar) scalar t
    real colvector z, x, l0, r0, l1, r1, ri0, ci0, v0, ri1, ci1, v1
    real scalar ok0, ok1
    M = _cge_load()
    S = _cge_sys_make(M, 0)
    z = M.x0[S.free] :/ M.xscale[S.free]
    if (spread > 0) z = z :* (1 :+ spread :* (2 :* runiform(rows(z), 1) :- 1))
    x = M.x0
    x[S.free] = z :* M.xscale[S.free]
    (void) _cge_dmode(0)
    _cge_u_eval(M, M.p, x, l0, r0)
    ok0 = _cge_jac_trip(M, M.p, x, S, z, ri0, ci0, v0)
    t = _cge_tp(M)
    (void) _cge_dmode(2)
    _cge_u_eval(M, M.p, x, l1, r1)
    ok1 = _cge_jac_trip(M, M.p, x, S, z, ri1, ci1, v1)
    (void) _cge_dmode(0)
    if (ok0 != ok1) return((., ., 0, rows(t->elt), rows(t->rest)))
    return((max((max(abs(l0 - l1) :/ (1 :+ abs(l1))), max(abs(r0 - r1) :/ (1 :+ abs(r1))))),
            (rows(v0) ? max(abs(v0 - v1) :/ (1 :+ abs(v1))) : 0),
            (ri0 == ri1) & (ci0 == ci1), rows(t->elt), rows(t->rest)))
}

// The rows on the tape of model M
real scalar _ttp_nrows(struct cge_model scalar M)
{
    pointer(struct cge_tape scalar) scalar t
    t = _cge_tp(M)
    return(rows(t->tok))
}

// 1 if the tapes of models A and B, which differ, are both kept
real scalar _ttp_kept(struct cge_model scalar A, struct cge_model scalar B)
{
    pointer(struct cge_tape scalar) scalar a, b, a2, b2
    a = _cge_tp(A)
    b = _cge_tp(B)
    a2 = _cge_tp(A)
    b2 = _cge_tp(B)
    return(a == a2 & b == b2 & a != b)
}

// The number of tapes kept
real scalar _ttp_count()
{
    pointer() scalar q
    q = findexternal("cge__tape")
    return(q == NULL ? 0 : rows(*q))
}

// The largest difference between the solutions of simulations a and b,
// relative to the scale of each variable
real scalar _ttp_simdiff(string scalar a, string scalar b)
{
    struct cge_model scalar M
    real scalar ia, ib
    M = _cge_load()
    ia = _cge_find(M.simname, a)
    ib = _cge_find(M.simname, b)
    return(max(abs(M.simx[., ia] - M.simx[., ib]) :/ M.xscale))
}

// The Jacobian entries of element e of the user equations at the start, by the tape:
// returns whether they could be evaluated, with the entries in v, by variable
real scalar _ttp_ent(real scalar e, real colvector c, real colvector v)
{
    struct cge_model scalar M
    struct cge_sys scalar S
    real colvector x, z, ri, ci, va, sel
    real scalar ok
    M = _cge_load()
    S = _cge_sys_make(M, 0)
    x = M.x0
    z = x[S.free] :/ M.xscale[S.free]
    (void) _cge_dmode(0)
    ok = _cge_jac_trip(M, M.p, x, S, z, ri, ci, va)
    c = v = J(0, 1, .)
    if (!ok) return(0)
    sel = select((1::rows(ri)), ri :== e)
    c = S.free[ci[sel]]
    v = va[sel] :* M.escale[e] :/ M.xscale[c]
    return(1)
}
end

* ---------------------------------------------------------------------
* 1. Every operation on the tape, against row by row and differences
* ---------------------------------------------------------------------
cge_model new
cge_set i = e1 e2 e3 e4 e5
cge_parameter a(i) = 0.5 + 0.3 * ord(i)
cge_parameter q = 2
cge_variable X, value(1.3)
cge_variable Y, value(0.7)
cge_variable Z, value(2.1)
cge_variable V(i), value(0.8 + 0.2 * ord(i))
cge_variable R1, value(1)
cge_variable R2, value(1)
cge_variable R3, value(1)
cge_variable R4, value(1)
cge_variable R5(i), value(1)
cge_equation FX: X = 1.3
cge_equation FY: Y = 0.7
cge_equation FZ: Z = 2.1
cge_equation FV(i): V(i) = 0.8 + 0.2 * ord(i)
cge_equation E1: X * Y + X / Z - Y^2 + X^Y + exp(0.1 * X * Z) - ln(Y) + sqrt(Z) = R1
cge_equation E2: (X + Y)^Z + Z^(X - Y) + 2^X + X^0 + X^1 + X^(-2) - X^q + q^X = R2
cge_equation E3: -X^3 * Z - (-Y) + -(Y - Z) / (X * Z) + log(X + Y) = R3
cge_equation E4: exp(-sum(i, a(i) * (V(i) - X)^2)) / sqrt(1 + sum(i, V(i)^2)) + prod(i, 1 + 0.1 * V(i) * a(i)) = R4
cge_equation E5(i): a(i) * V(i)^2 / (1 + V(i)) + X * V(i) - sum(i2$(ord(i2) <= ord(i)), a(i2) * ln(V(i2) + X)) = R5(i)
quietly cge_solve, name(ops0) tolerance(1e-12)
assert r(converged) == 1
foreach s in 0 0.05 0.3 {
    mata: r = _ttp_cmp(`s'); st_numscalar("tt_v", r[1]); st_numscalar("tt_j", r[2]); st_numscalar("tt_p", r[3])
    mata: st_numscalar("tt_e", r[4]); st_numscalar("tt_r", r[5])
    display as text "spread `s': values " as result %9.2e scalar(tt_v) as text ", Jacobian " as result %9.2e scalar(tt_j)
    assert scalar(tt_v) < 1e-14
    assert scalar(tt_j) < 1e-13
    assert scalar(tt_p) == 1
    assert scalar(tt_r) == 0
}
mata: _cge_jexall()
display as text "against central differences: " as result %9.2e r(maxdiff)
assert r(maxdiff) < 1e-5
mata: (void) _cge_dmode(2)
quietly cge_solve, name(ops2) tolerance(1e-12)
assert r(converged) == 1
mata: (void) _cge_dmode(0)
mata: st_numscalar("tt_d", _ttp_simdiff("ops0", "ops2"))
assert scalar(tt_d) < 1e-13

* ---------------------------------------------------------------------
* 2. Elements that stay off the tape, between those on it
* ---------------------------------------------------------------------
cge_model new
cge_set i = e1 e2 e3 e4 e5 e6
cge_parameter a(i) = ord(i) / 3
cge_parameter sw = 1
cge_variable V(i), value(1 + ord(i) / 5)
cge_variable W, value(1.5)
cge_set r = r1 r2 r3 r4 r5 r6 r7
cge_variable R(r), value(1)
cge_equation P1: V(e1)^2 + W = R(r1)
cge_equation Q1: abs(V(e2) - 3) + min(V(e2), W) = R(r2)
cge_equation P2: V(e3) * W - a(e3) = R(r3)
cge_equation Q2: ifthen(sw > 0.5, V(e4)^2, W) + max(V(e4), V(e1)) = R(r4)
cge_equation P3: sum(i, a(i) * V(i)) - V(e5) = R(r5)
cge_equation Q3: sqr(V(e6)) + log10(W) = R(r6)
cge_equation P4: exp(W / 10) = R(r7) - 1
cge_equation FV(i): V(i) = 1 + ord(i) / 4
cge_equation FW: W = 1.25
quietly cge_solve, name(mix0) tolerance(1e-12)
assert r(converged) == 1
foreach s in 0 0.1 {
    mata: r = _ttp_cmp(`s'); st_numscalar("tt_v", r[1]); st_numscalar("tt_j", r[2]); st_numscalar("tt_p", r[3])
    mata: st_numscalar("tt_e", r[4]); st_numscalar("tt_r", r[5])
    assert scalar(tt_v) < 1e-14 & scalar(tt_j) < 1e-13 & scalar(tt_p) == 1
    assert scalar(tt_e) == 11 & scalar(tt_r) == 3
}
mata: _cge_jexall()
assert r(maxdiff) < 1e-5
mata: (void) _cge_dmode(1)
quietly cge_solve, name(mix1) tolerance(1e-12)
mata: (void) _cge_dmode(0)
mata: st_numscalar("tt_d", _ttp_simdiff("mix0", "mix1"))
assert scalar(tt_d) < 1e-12

* ---------------------------------------------------------------------
* 3. Derivatives that are not defined: nothing passes back where the
*    adjoint is zero; a variable's own undefined derivative stops the
*    Jacobian, and a value that is missing too
* ---------------------------------------------------------------------
cge_model new
cge_parameter q = 0
cge_parameter e0 = 0
cge_variable X, value(0)
cge_variable Y, value(1)
cge_equation A1: q * sqrt(X) + Y = 1
cge_equation A2: q * X^0.5 + X^e0 * Y = 1
mata: c = v = J(0, 1, .)
mata: st_numscalar("tt_ok", _ttp_ent(1, c, v))
assert scalar(tt_ok) == 1
mata: st_numscalar("tt_m", hasmissing(v))
assert scalar(tt_m) == 0
mata: st_numscalar("tt_ok", _ttp_ent(2, c, v))
assert scalar(tt_ok) == 1
mata: st_numscalar("tt_m", hasmissing(v))
assert scalar(tt_m) == 0
quietly cge_equation, clear
cge_variable X, value(0)
cge_variable Y, value(1)
cge_equation B1: sqrt(X) + Y = 1
cge_equation B2: Y = 1
mata: st_numscalar("tt_ok", _ttp_ent(1, c, v))
assert scalar(tt_ok) == 0
quietly cge_equation, clear
cge_variable X, value(0)
cge_variable Y, value(1)
cge_equation C1: ln(X) + Y = 1
cge_equation C2: Y = 1
mata: st_numscalar("tt_ok", _ttp_ent(1, c, v))
assert scalar(tt_ok) == 0

* ---------------------------------------------------------------------
* 4. One equation; a variable repeated in an element and on both sides
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(2)
cge_equation E1: X^2 = 9
quietly cge_solve, name(one) tolerance(1e-12)
assert r(converged) == 1 & reldif(r(max_residual) + 3, 3) < 1e-10
quietly cge_results, sim(one) clear nodisplay
quietly summarize value if variable == "X"
assert reldif(r(mean), 3) < 1e-10
cge_equation, clear
cge_variable X, value(2)
cge_equation E2: X = 5
quietly cge_solve, name(onel) tolerance(1e-12)
assert r(converged) == 1
quietly cge_results, sim(onel) clear nodisplay
quietly summarize value if variable == "X"
assert reldif(r(mean), 5) < 1e-10
cge_equation, clear
cge_variable X, value(2)
cge_equation E3: X + X * X - 3 * X = 8 - X + X^3 - X^3
mata: st_numscalar("tt_ok", _ttp_ent(1, c, v))
assert scalar(tt_ok) == 1
mata: st_numscalar("tt_g", v[1]); st_numscalar("tt_n", rows(v))
* d/dX of X + X^2 - 3X - (8 - X + X^3 - X^3) at 2: 1 + 4 - 3 + 1
assert scalar(tt_n) == 1 & reldif(scalar(tt_g), 3) < 1e-13
quietly cge_solve, name(rep) tolerance(1e-12)
assert r(converged) == 1
quietly cge_results, sim(rep) clear nodisplay
quietly summarize value if variable == "X"
assert reldif(r(mean)^2 - r(mean) - 8, 0) < 1e-9 | abs(r(mean)^2 - r(mean) - 8) < 1e-9

* ---------------------------------------------------------------------
* 5. Parameters are read at each solve
* ---------------------------------------------------------------------
cge_model new
cge_set i = e1 e2 e3
cge_parameter a(i) = 1 + ord(i)
cge_variable X(i), value(1)
cge_equation EX(i): X(i)^2 = a(i)
quietly cge_solve, name(base0)
assert r(converged) == 1
cge_shock a, elements(e2) value(16)
quietly cge_solve, name(shock0)
assert r(converged) == 1
quietly cge_results, sim(shock0) clear nodisplay
quietly summarize value if variable == "X" & element1 == "e2"
assert reldif(r(mean), 4) < 1e-10
quietly summarize value if variable == "X" & element1 == "e3"
assert reldif(r(mean), 2) < 1e-10

* ---------------------------------------------------------------------
* 6. A tape made again when the equations change; those of models that
*    take turns kept; a model saved and read back
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(1)
cge_equation E1: X^2 = 4
quietly cge_solve, name(c1)
assert r(converged) == 1
mata: M1 = _cge_load()
mata: st_numscalar("tt_n", _ttp_nrows(M1))
assert scalar(tt_n) == 4
cge_model new
cge_variable X, value(1)
cge_equation E1: X^3 = 27
quietly cge_solve, name(c2)
assert r(converged) == 1
quietly cge_results, sim(c2) clear nodisplay
quietly summarize value if variable == "X"
assert reldif(r(mean), 3) < 1e-10
mata: M2 = _cge_load()
mata: st_numscalar("tt_same", _ttp_kept(M1, M2))
assert scalar(tt_same) == 1
* replaced by another equation of the same shape
cge_equation, clear
cge_variable X, value(1)
cge_equation E1: X^3 = 8
quietly cge_solve, name(c3)
assert r(converged) == 1
quietly cge_results, sim(c3) clear nodisplay
quietly summarize value if variable == "X"
assert reldif(r(mean), 2) < 1e-10
* no more than eight are kept, the oldest going first
forvalues k = 1/10 {
    cge_model new
    cge_variable X, value(1)
    cge_equation E1: X^2 = `= `k' + 100'
    quietly cge_solve, name(c)
    assert r(converged) == 1
}
mata: st_numscalar("tt_n", _ttp_count())
assert scalar(tt_n) == 8
mata: mata drop M1 M2
tempfile f
quietly cge_save using `f', replace
quietly cge_use using `f'
quietly cge_solve, name(d)
assert r(converged) == 1
quietly cge_results, sim(d) clear nodisplay
quietly summarize value if variable == "X"
assert reldif(r(mean), sqrt(110)) < 1e-10

* ---------------------------------------------------------------------
* 7. A long sum in one element: a tree thousands of rows high
* ---------------------------------------------------------------------
cge_model new
local labs
forvalues j = 1/3000 {
    local labs `labs' v`j'
}
quietly cge_set j = `labs'
cge_parameter b(j) = 1 + ord(j) / 3000
cge_variable V(j), value(1)
cge_variable T, value(1)
cge_equation FV(j): V(j) = b(j)
cge_equation TOT: T = sum(j, b(j) * ln(V(j)) + V(j)^2)
quietly cge_solve, name(long) tolerance(1e-11)
assert r(converged) == 1
mata: r = _ttp_cmp(0.1); st_numscalar("tt_v", r[1]); st_numscalar("tt_j", r[2]); st_numscalar("tt_p", r[3]); st_numscalar("tt_r", r[5])
display as text "a sum of 3,000 terms: values " as result %9.2e scalar(tt_v) as text ", Jacobian " as result %9.2e scalar(tt_j)
assert scalar(tt_v) < 1e-13 & scalar(tt_j) < 1e-13 & scalar(tt_p) == 1 & scalar(tt_r) == 0

* ---------------------------------------------------------------------
* 8. A dense model, solved on the tape and row by row
* ---------------------------------------------------------------------
cge_model new
local labs
forvalues j = 1/30 {
    local labs `labs' g`j'
}
quietly cge_set g = `labs'
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
quietly cge_solve, name(dense0) tolerance(1e-11)
assert r(converged) == 1
local nrev0 = r(jacobians)
mata: (void) _cge_dmode(2)
quietly cge_solve, name(dense2) tolerance(1e-11)
assert r(converged) == 1
mata: (void) _cge_dmode(0)
mata: st_numscalar("tt_d", _ttp_simdiff("dense0", "dense2"))
display as text "dense model of 30 sectors, solutions on the tape and row by row: " as result %9.2e scalar(tt_d)
assert scalar(tt_d) < 1e-9

* ---------------------------------------------------------------------
* 9. A model from a SAM with user equations
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
mata: _cge_jexall()
display as text "SAM model with user equations, against differences: " as result %9.2e r(maxdiff)
assert r(maxdiff) < 1e-6
quietly cge_solve, name(sam0) tolerance(1e-12)
assert r(converged) == 1
mata: (void) _cge_dmode(2)
quietly cge_solve, name(sam2) tolerance(1e-12)
assert r(converged) == 1
mata: (void) _cge_dmode(0)
mata: st_numscalar("tt_d", _ttp_simdiff("sam0", "sam2"))
assert scalar(tt_d) < 1e-12
quietly cge_closure, swap(none)
quietly cge_equation, clear
mata: (void) _cge_dmode(0)
mata: mata drop c v r
mata: mata drop _ttp_cmp() _ttp_count() _ttp_simdiff() _ttp_ent() _ttp_nrows() _ttp_kept()
scalar drop _all
