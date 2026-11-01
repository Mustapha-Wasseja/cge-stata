* test_mpsge.do -- models in the form of MPSGE (version 0.44.0;
* docs/model_spec.md, Section 54). cge_mpsge against GAMS/MPSGE: the three
* models of tests/data/mpsge, read from the GAMS programs with cge_mpsge
* using, against the levels that GAMS/MPSGE gave for their scenarios
* (tests/expected/mpsge_gams.csv, from tools/gams/run_mpsge_check.py); the
* same models written in commands; a model written by hand in user variables
* and equations; MPSGE's numeraire; a free good, a sector that shuts down
* and one that starts; an elasticity given by a parameter, switched to
* Cobb-Douglas under conditions(solve); save and use; errors. The data are
* SYNTHETIC.

version 13.0

capture mata: mata drop _tmp_gams()
capture mata: mata drop _tmp_val()
capture mata: mata drop _tmp_diff()
_cge_load
mata:
// The largest relative difference between simulation sim and the levels
// that GAMS/MPSGE gave for scenario scen of model mdl, whose numeraire is
// the price of labour; the levels of the variables in sc (prices and
// incomes) are divided by rel, the price of labour in sim
real scalar _tmp_gams(string scalar mdl, string scalar scen, string scalar sim, real scalar rel, | string scalar sc)
{
    struct cge_model scalar M
    string colvector L
    string rowvector f
    real scalar k, s, p, d, n, g
    M = _cge_load()
    s = _cge_find(M.simname, sim)
    L = cat("expected/mpsge_gams.csv")
    d = n = 0
    for (k = 2; k <= rows(L); k++) {
        f = tokens(L[k], ",")
        f = select(f, f :!= ",")
        if (f[1] != mdl | f[2] != scen) continue
        // a scalar's element is empty: four fields
        p = _cge_u_varpos(M, f[3], (cols(f) == 5 ? f[4] : J(1, 0, "")))
        if (!p) _error(3498, "no level " + f[3] + " in the model")
        g = strtoreal(f[cols(f)])
        d = max((d, abs(M.simx[p, s] / (anyof(tokens(sc), f[3]) ? rel : 1) - g) / max((1, abs(g)))))
        n++
    }
    if (!n) _error(3498, "no levels of " + mdl + " " + scen)
    return(d)
}
// The value of variable v (element el, or "") in simulation sim
real scalar _tmp_val(string scalar sim, string scalar v, string scalar el)
{
    struct cge_model scalar M
    string rowvector a
    M = _cge_load()
    a = (el != "" ? tokens(el, ",") : J(1, 0, ""))
    if (cols(a)) a = select(a, a :!= ",")
    return(M.simx[_cge_u_varpos(M, v, a), _cge_find(M.simname, sim)])
}
// The largest relative difference between the variables of two simulations
// that exist in both, the second scaled by rel
real scalar _tmp_diff(string scalar a, string scalar b, real scalar rel)
{
    struct cge_model scalar M
    real colvector xa, xb, k
    M = _cge_load()
    xa = M.simx[., _cge_find(M.simname, a)]
    xb = M.simx[., _cge_find(M.simname, b)]
    k = _cge_which(M.exists)
    return(max(abs(xa[k] - rel :* xb[k]) :/ rowmax((J(rows(k), 1, 1), abs(xa[k])))))
}
end

* ---------------------------------------------------------------------
* 1. A tax on labour in sector X: the model read from the GAMS program,
*    against GAMS/MPSGE; the same model in commands; and by hand
* ---------------------------------------------------------------------
program define _tmp_tax
    cge_model new
    cge_parameter tx = 0.25
end
_tmp_tax
cge_mpsge using "data/mpsge/mp_tax.gms", numeraire(PL)
assert r(N_sectors) == 3 & r(N_commodities) == 5 & r(N_consumers) == 1 & r(N_blocks) == 4
assert "`r(name)'" == "mp_tax" & "`r(numeraire)'" == "PL" & r(numeraire_value) == 1
* the reference point is the benchmark: no iteration
assert r(gap) < 1e-12
cge_solve, name(bench)
assert r(converged) == 1 & r(iterations) == 0
cge_shock tx, value(0)
cge_solve, name(notax)
cge_shock tx, value(0.5)
cge_solve, name(hitax)
foreach sc in notax hitax {
    mata: st_numscalar("tmp_d", _tmp_gams("mp_tax", "`sc'", "`sc'", 1))
    display as text "mp_tax `sc': largest relative difference from GAMS/MPSGE " as result %9.2e scalar(tmp_d)
    assert scalar(tmp_d) < 1e-9
}
* the tax revenue goes to the consumer: X_tx2 = tx PL X_i2
mata: st_numscalar("tmp_d", abs(_tmp_val("hitax", "X_tx2", "") - 0.5 * _tmp_val("hitax", "X_i2", "")))
assert scalar(tmp_d) < 1e-12
cge_mpsge, list
assert r(N_models) == 1 & "`r(models)'" == "mp_tax"
quietly cge_save using "tmp_mpsge", replace

* the same model in commands, several records to a statement
_tmp_tax
cge_mpsge model:mp_tax
cge_mpsge sectors: X Y W
cge_mpsge commodities: PX PY PL PK PW
cge_mpsge consumers: CONS
cge_mpsge prod:X s:0.5  o:PX q:100  i:PL q:40 p:1.25 a:CONS t:tx  i:PK q:50
cge_mpsge prod:Y s:1.5  o:PY q:100  i:PL q:60  i:PK q:40
cge_mpsge prod:W s:1
cge_mpsge    o:PW q:200
cge_mpsge    i:PX q: 100  i:PY q: 100
cge_mpsge demand:CONS   d:PW q:200  e:PL q:100  e:PK q:90
cge_mpsge end, numeraire(PL)
cge_shock tx, value(0.5)
cge_solve, name(hitax)
mata: st_numscalar("tmp_d", _tmp_gams("mp_tax", "hitax", "hitax", 1))
assert scalar(tmp_d) < 1e-9

* by hand: the zero profits, markets and income of MPSGE's calibrated
* functions, written apart from cge_mpsge
cge_model new
cge_parameter tx = 0.5
foreach v in X Y W PX PY PK PW {
    cge_variable `v', value(1) fixed
}
cge_variable PL, value(1) fixed
cge_variable cx = ((50 * (PL * (1 + tx) / 1.25)^0.5 + 50 * PK^0.5) / 100)^2
cge_variable cy = ((60 * PL^(-0.5) + 40 * PK^(-0.5)) / 100)^(-2)
cge_variable cw = sqrt(PX * PY)
cge_variable lx = X * 40 * (cx / (PL * (1 + tx) / 1.25))^0.5
cge_variable kx = X * 50 * (cx / PK)^0.5
cge_variable ly = Y * 60 * (cy / PL)^1.5
cge_variable ky = Y * 40 * (cy / PK)^1.5
cge_variable CONS, value(200) fixed
cge_equation zx: 100 * cx - 100 * PX = 0, perp(X) lower(0)
cge_equation zy: 100 * cy - 100 * PY = 0, perp(Y) lower(0)
cge_equation zw: 200 * cw - 200 * PW = 0, perp(W) lower(0)
cge_equation mx: 100 * X - 100 * W * cw / PX = 0, perp(PX) lower(0)
cge_equation my: 100 * Y - 100 * W * cw / PY = 0, perp(PY) lower(0)
cge_equation mk: 90 - kx - ky = 0, perp(PK) lower(0)
cge_equation mw: 200 * W - CONS / PW = 0, perp(PW) lower(0)
cge_equation inc: CONS = 100 * PL + 90 * PK + tx * PL * lx, perp(CONS) lower(0)
cge_solve, name(hand)
assert r(converged) == 1
mata: st_numscalar("tmp_d", _tmp_gams("mp_tax", "hitax", "hand", 1))
display as text "the same functions by hand: largest relative difference from GAMS/MPSGE " as result %9.2e scalar(tmp_d)
assert scalar(tmp_d) < 1e-9

* MPSGE's numeraire: the income of the consumer with the largest income,
* fixed at its value at the reference point; quantities as with labour, and
* prices in proportion
_tmp_tax
cge_mpsge using "data/mpsge/mp_tax.gms"
assert "`r(numeraire)'" == "CONS" & r(numeraire_value) == 200
cge_shock tx, value(0.5)
cge_solve, name(hitax)
mata: st_numscalar("tmp_r", _tmp_val("hitax", "PL", ""))
assert abs(scalar(tmp_r) - 1) > 1e-3
mata: st_numscalar("tmp_d", _tmp_gams("mp_tax", "hitax", "hitax", st_numscalar("tmp_r"), "PX PY PK PW CONS"))
assert scalar(tmp_d) < 1e-9

* save and use keep the declarations
cge_use using "tmp_mpsge"
cge_mpsge, list generated
assert r(N_models) == 1
cge_solve, name(again)
mata: st_numscalar("tmp_d", _tmp_diff("again", "hitax", 1))
assert scalar(tmp_d) < 1e-12
cge_equation, clear
cge_mpsge, list
assert r(N_models) == 0

* ---------------------------------------------------------------------
* 2. Three sectors over sets: intermediate inputs, a nest of factors with an
*    elasticity of each sector, taxes paid to the government, households of
*    their own elasticities
* ---------------------------------------------------------------------
program define _tmp_sam3
    args ea
    if "`ea'" == "" local ea 0.5
    cge_model new
    cge_set s = agr man ser
    cge_set g = s
    cge_set f = lab cap
    cge_set h = rich poor
    cge_parameter id0(g,s), values(agr.agr:10 agr.man:20 agr.ser:5 man.agr:15 man.man:30 man.ser:20 ser.agr:5 ser.man:15 ser.ser:25)
    cge_parameter fd0(f,s), values(lab.agr:30 lab.man:25 lab.ser:40 cap.agr:20 cap.man:30 cap.ser:35)
    cge_parameter tf0(f,s), values(lab.man:0.2)
    cge_parameter tf(f,s), values(lab.man:0.2)
    cge_parameter y0(s), values(agr:80 man:156.25 ser:125)
    cge_parameter ty0(s), values(man:0.2)
    cge_parameter ty(s), values(man:0.2)
    cge_parameter esub(s), values(agr:`ea' man:1 ser:1.5)
    cge_parameter sh(h), values(rich:1.5 poor:0.8)
    cge_parameter g0(g), values(agr:5 man:11.25 ser:20)
    cge_parameter c0(g,h), values(agr.rich:15 agr.poor:25 man.rich:50 man.poor:30 ser.rich:40 ser.poor:20)
    cge_parameter e0(f,h), values(lab.rich:45 lab.poor:50 cap.rich:60 cap.poor:25)
end
program define _tmp_sam3run
    cge_solve, name(bench)
    assert r(converged) == 1 & r(iterations) == 0
    cge_shock ty, elements(man) value(0)
    cge_solve, name(notax)
    cge_shock ty, elements(man) value(0.2)
    cge_shock tf, elements(lab.man) value(0.5)
    cge_solve, name(labtax)
    cge_shock tf, elements(lab.man) value(0.2)
    cge_shock e0, elements(cap.rich) value(72)
    cge_solve, name(capital)
end
_tmp_sam3
cge_mpsge using "data/mpsge/mp_sam3.gms", numeraire(PF(lab))
assert r(N_sectors) == 3 & r(N_commodities) == 5 & r(N_consumers) == 3 & r(gap) < 1e-12
_tmp_sam3run
foreach sc in notax labtax capital {
    mata: st_numscalar("tmp_d", _tmp_gams("mp_sam3", "`sc'", "`sc'", 1))
    display as text "mp_sam3 `sc': largest relative difference from GAMS/MPSGE " as result %9.2e scalar(tmp_d)
    assert scalar(tmp_d) < 1e-9
}
* the government's income is the revenue of its taxes
mata: st_numscalar("tmp_d", _tmp_val("labtax", "GOV", "") - _tmp_val("labtax", "Y_tx3", "man,lab") - _tmp_val("labtax", "Y_tx1", "man"))
assert abs(scalar(tmp_d)) < 1e-10
quietly cge_save using "tmp_mpsge", replace

* the same model in commands, with conditions written as in Stata
_tmp_sam3
cge_mpsge sectors: Y(s)
cge_mpsge commodities: P(s) PF(f)
cge_mpsge consumers: HH(h) GOV
cge_mpsge prod:Y(s) s:0 va:esub(s)
cge_mpsge    o:P(s)  q:y0(s) p:(1-ty0(s)) a:GOV t:ty(s)
cge_mpsge    i:P(g)$(id0(g,s)) q:id0(g,s)
cge_mpsge    i:PF(f) q:fd0(f,s) p:(1+tf0(f,s)) va: a:GOV t:tf(f,s)
cge_mpsge demand:HH(h) s:sh(h)  d:P(g) q:c0(g,h)  e:PF(f) q:e0(f,h)
cge_mpsge demand:GOV s:0  d:P(g) q:g0(g)
cge_mpsge end, numeraire(PF(lab))
assert "`r(name)'" == "mpsge"
_tmp_sam3run
foreach sc in notax labtax capital {
    mata: st_numscalar("tmp_d", _tmp_gams("mp_sam3", "`sc'", "`sc'", 1))
    assert scalar(tmp_d) < 1e-9
}

* ---------------------------------------------------------------------
* 3. Joint products, two levels of nests, a Leontief resource that becomes
*    a free good, a technology that starts when it pays while another shuts
*    down, nested demand, and the default elasticity of demand (0)
* ---------------------------------------------------------------------
cge_model new
cge_parameter te0 = 0.1
cge_parameter te = 0.1
cge_parameter tl0 = 0.2
cge_parameter tl = 0.2
cge_parameter zq = 6
cge_parameter nend = 20
cge_mpsge using "data/mpsge/mp_nest.gms", numeraire(PL)
* technology Z does not pay at the reference prices: it starts at 0, as
* GAMS's Z.l = 0
cge_bound Z, level(0)
cge_solve, name(base)
assert r(converged) == 1
mata: st_numscalar("tmp_d", _tmp_val("base", "Z", "") + abs(_tmp_val("base", "X", "") - 1) + abs(_tmp_val("base", "PN", "") - 1))
assert scalar(tmp_d) < 1e-10
cge_shock te, value(0.3)
cge_solve, name(extax)
cge_shock te, value(0.1)
cge_shock nend, value(25)
cge_solve, name(freegood)
cge_shock nend, value(20)
cge_shock zq, value(4.5)
cge_solve, name(newtech)
foreach sc in extax freegood newtech {
    mata: st_numscalar("tmp_d", _tmp_gams("mp_nest", "`sc'", "`sc'", 1))
    display as text "mp_nest `sc': largest relative difference from GAMS/MPSGE " as result %9.2e scalar(tmp_d)
    assert scalar(tmp_d) < 1e-9
}
* the free good: no price, and more of it than is used
mata: st_numscalar("tmp_d", _tmp_val("freegood", "PN", ""))
assert abs(scalar(tmp_d)) < 1e-10
mata: st_numscalar("tmp_d", 25 - _tmp_val("freegood", "X_i3", ""))
assert scalar(tmp_d) > 1
* Y shuts down when Z pays
mata: st_numscalar("tmp_d", _tmp_val("newtech", "Y", ""))
assert abs(scalar(tmp_d)) < 1e-10
mata: st_numscalar("tmp_d", _tmp_val("newtech", "Z", ""))
assert scalar(tmp_d) > 5

* ---------------------------------------------------------------------
* 4. An elasticity given by a parameter that a shock makes 1: under
*    conditions(solve) the nest becomes Cobb-Douglas, as in the model whose
*    base has it
* ---------------------------------------------------------------------
_tmp_sam3 1
quietly cge_mpsge using "data/mpsge/mp_sam3.gms", numeraire(PF(lab))
cge_shock ty, elements(man) value(0)
cge_solve, name(cdbase)
mata: st_numscalar("tmp_a", _tmp_val("cdbase", "Y", "agr"))
mata: st_numscalar("tmp_c", _tmp_val("cdbase", "PF", "cap"))
_tmp_sam3
cge_options, conditions(solve)
quietly cge_mpsge using "data/mpsge/mp_sam3.gms", numeraire(PF(lab))
cge_shock esub, elements(agr) value(1)
cge_shock ty, elements(man) value(0)
cge_solve, name(cdshock)
mata: st_numscalar("tmp_b", abs(_tmp_val("cdshock", "Y", "agr") - st_numscalar("tmp_a")) + abs(_tmp_val("cdshock", "PF", "cap") - st_numscalar("tmp_c")))
display as text "Cobb-Douglas at the base and by a shock: " as result %9.2e scalar(tmp_b)
assert scalar(tmp_b) < 1e-12
* the shock took effect: Cobb-Douglas keeps the value shares of the factors
* in agriculture at their reference values, 20 and 30
mata: st_numscalar("tmp_d", _tmp_val("cdshock", "PF", "cap") * _tmp_val("cdshock", "Y_i3", "agr,cap") / (_tmp_val("cdshock", "Y_i3", "agr,lab")) - 20 / 30)
assert abs(scalar(tmp_d)) < 1e-12
mata: st_numscalar("tmp_d", _tmp_val("cdshock", "PF", "cap") - 1)
assert abs(scalar(tmp_d)) > 1e-3
cge_options, conditions(base)

* ---------------------------------------------------------------------
* 5. Errors: the model is not added, and the statements are kept until
*    they are dropped
* ---------------------------------------------------------------------
program define _tmp_err
    args rc
    capture noisily cge_mpsge end
    assert _rc == `rc'
    cge_mpsge, drop
end
_tmp_tax
cge_mpsge sectors: X
cge_mpsge commodities: PX PL
cge_mpsge consumers: CONS
cge_mpsge prod:X o:PX q:10 i:PQ q:10
cge_mpsge demand:CONS d:PX q:10 e:PL q:10
_tmp_err 111
* a sector without a block
cge_mpsge sectors: X Y
cge_mpsge commodities: PX PL
cge_mpsge consumers: CONS
cge_mpsge prod:X o:PX q:10 i:PL q:10
cge_mpsge demand:CONS d:PX q:10 e:PL q:10
_tmp_err 198
* a nest that is not declared
cge_mpsge sectors: X
cge_mpsge commodities: PX PL
cge_mpsge consumers: CONS
cge_mpsge prod:X o:PX q:10 i:PL q:10 va:
cge_mpsge demand:CONS d:PX q:10 e:PL q:10
_tmp_err 111
* an input in a nest of outputs
cge_mpsge sectors: X
cge_mpsge commodities: PX PL
cge_mpsge consumers: CONS
cge_mpsge prod:X t:1 ot(t):2 o:PX q:10 i:PL q:10 ot:
cge_mpsge demand:CONS d:PX q:10 e:PL q:10
_tmp_err 198
* an agent who is not a consumer, a numeraire that is not a price or income
cge_mpsge sectors: X
cge_mpsge commodities: PX PL
cge_mpsge consumers: CONS
cge_mpsge prod:X o:PX q:10 a:X t:0.1 i:PL q:10
cge_mpsge demand:CONS d:PX q:10 e:PL q:10
_tmp_err 198
cge_mpsge sectors: X
cge_mpsge commodities: PX PL
cge_mpsge consumers: CONS
cge_mpsge prod:X o:PX q:10 i:PL q:10
cge_mpsge demand:CONS d:PX q:10 e:PL q:10
capture noisily cge_mpsge end, numeraire(X)
assert _rc == 198
* the statements are kept: the model is added with a numeraire
cge_mpsge end, numeraire(PL)
assert r(N_sectors) == 1
* errors of the statements themselves
_tmp_tax
foreach st in "o:PX q:10" "prod:X i:PL q:10 t:0.1" "demand:C o:PX" "commodities: P(nosuch)" "prod:X s:1 s:2" {
    if "`st'" == "o:PX q:10" capture noisily cge_mpsge `st'
    else {
        cge_mpsge sectors: X
        capture noisily cge_mpsge `st'
    }
    assert _rc == 198
    cge_mpsge, drop
}
capture noisily cge_mpsge using "data/mpsge/nosuch.gms"
assert _rc == 601
* a model from a SAM takes no model in the form of MPSGE
quietly do setup_synthetic.do
capture noisily cge_mpsge sectors: X
assert _rc == 198

capture erase "tmp_mpsge.cgem"
capture mata: mata drop _tmp_gams()
capture mata: mata drop _tmp_val()
capture mata: mata drop _tmp_diff()
capture program drop _tmp_tax _tmp_sam3 _tmp_sam3run _tmp_err
capture scalar drop tmp_d tmp_r tmp_a tmp_b tmp_c
