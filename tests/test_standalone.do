* test_standalone.do -- standalone models and parameter assignments (version
* 0.13.0; docs/model_spec.md, Section 22): an exchange economy against its
* closed form; assignments, conditions and data against direct
* computations; the standard model written in the user language against the
* built-in model, at the base and in four scenarios; the statistics of
* cge_model describe; saving and loading; errors.

version 13.0

capture mata: mata drop _ts_val()
capture mata: mata drop _ts_upval()
_cge_load
mata:
// The value of element el of variable v in simulation s (0 the base)
real scalar _ts_val(string scalar v, string scalar el, real scalar s)
{
    struct cge_model scalar M
    M = _cge_load()
    if (s == 0) return(M.x0[_cge_u_vpos(M, v, el)])
    return(M.simx[_cge_u_vpos(M, v, el), s])
}

// The base values of user parameter name, in storage order
real colvector _ts_upval(string scalar name)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.p0.upval[_cge_up_pos(M, _cge_up_find(M, name))])
}
end

* ---------------------------------------------------------------------
* 1. An exchange economy: two goods, two consumers, Cobb-Douglas utility.
*    With good 1 the numeraire, P2 = sum_h a(h,2) e(h,1) / sum_h a(h,1) e(h,2)
* ---------------------------------------------------------------------
cge_model new
assert r(standalone) == 1
cge_set g = g1 g2
cge_set h = h1 h2
cge_parameter alpha(h,g), values(h1.g1:0.3 h1.g2:0.7 h2.g1:0.6 h2.g2:0.4)
cge_parameter e(h,g), values(h1.g1:10 h1.g2:2 h2.g1:3 h2.g2:8)
cge_variable P(g), value(1)
cge_variable Y(h) = sum(g, P(g) * e(h,g))
cge_variable X(h,g) = alpha(h,g) * Y(h) / P(g)
cge_variable WALRAS, value(0)
cge_equation NUM: P(g1) = 1
cge_equation MKT(g): sum(h, X(h,g)) = sum(h, e(h,g)) + WALRAS
cge_model describe
assert r(N_eq_blocks) == 4 & r(N_equations) == 9 & r(N_var_blocks) == 4 & r(N_variables) == 9
assert r(N_fixed) == 0 & r(N_free) == 9 & r(square) == 1 & r(N_sets) == 2 & r(N_parameters) == 2
* nonzeros: NUM 1, MKT 2 x 3, Y 2 x 3, X 4 x 3
assert r(N_nonzeros) == 1 + 6 + 6 + 12
cge_solve, name(eq)
assert r(converged) == 1
mata: st_numscalar("ts_d", abs(_ts_val("P", "g2", 1) - (0.7 * 10 + 0.4 * 3) / (0.3 * 2 + 0.6 * 8)))
display as text "exchange economy: P(g2) against the closed form " as result %9.2e scalar(ts_d)
assert scalar(ts_d) < 1e-12
mata: st_numscalar("ts_w", abs(_ts_val("WALRAS", "", 1)))
assert scalar(ts_w) < 1e-10
* a larger endowment of good 1 for consumer 1
cge_shock e, elements(h1.g1) value(15)
cge_solve, name(more)
mata: st_numscalar("ts_d", abs(_ts_val("P", "g2", 2) - (0.7 * 15 + 0.4 * 3) / (0.3 * 2 + 0.6 * 8)))
assert scalar(ts_d) < 1e-12
cge_results, sim(more)
* a swap needs a fixed variable to free: WALRAS is not fixed
cge_shock, reset
capture noisily cge_closure, swap(P(g2) WALRAS)
assert _rc == 459

* ---------------------------------------------------------------------
* 2. Parameter assignments: expressions, conditions, assignment again, data
* ---------------------------------------------------------------------
cge_model new
cge_set i = r1 r2 r3
cge_set j = i
cge_parameter v(i), values(r1:2 r2:0 r3:5)
cge_parameter w(i,j) = v(i) * 10 + ord(j)
mata: assert(_ts_upval("w") == (21 \ 22 \ 23 \ 1 \ 2 \ 3 \ 51 \ 52 \ 53))
* a condition: the elements that meet it, others zero (or the default)
cge_parameter s(i)$(v(i) > 0) = 1 / v(i)
mata: assert(_ts_upval("s") == (0.5 \ 0 \ 0.2))
cge_parameter s2(i)$(v(i) > 0) = 1 / v(i), default(-1)
mata: assert(_ts_upval("s2") == (0.5 \ -1 \ 0.2))
* assigned again, over the elements that meet the condition
cge_parameter s(i)$(v(i) == 0) = 7
mata: assert(_ts_upval("s") == (0.5 \ 7 \ 0.2))
cge_parameter s(i) = s(i) * 2
mata: assert(_ts_upval("s") == (1 \ 14 \ 0.4))
* sums over two indexes and the functions of the language
cge_parameter tot = sum((i,j), w(i,j))
mata: assert(_ts_upval("tot") == 228)
cge_parameter big = smax(i, v(i)) + card(i) + abs(-2) + max(1, 4)
mata: assert(_ts_upval("big") == 5 + 3 + 2 + 4)
* a base value of a variable
cge_variable Z(i), value(v(i) + 1)
cge_parameter zb(i) = base(Z(i)) * 3
mata: assert(_ts_upval("zb") == (9 \ 3 \ 18))
* from the data: long and wide
clear
input str4 row str4 col double val
r1 r1 1
r1 r3 4
r2 r2 9
end
cge_parameter lg(i,j), from(val) labels(row col)
mata: assert(_ts_upval("lg") == (1 \ 0 \ 4 \ 0 \ 9 \ 0 \ 0 \ 0 \ 0))
clear
input str4 lab double r1 double r2 double r3
r1 1 2 3
r3 7 8 9
end
cge_parameter wd(i,j), from(r1-r3) labels(lab)
mata: assert(_ts_upval("wd") == (1 \ 2 \ 3 \ 0 \ 0 \ 0 \ 7 \ 8 \ 9))
* a set from the data, with labels of its own
clear
input str6 name
alpha
beta
alpha
gamma
end
cge_set k, from(name)
assert "`r(elements)'" == "alpha beta gamma"
* errors
capture noisily cge_parameter s(i) = v(i) / 0
assert _rc == 459
capture noisily cge_parameter q2(i) = Z(i) * 2
assert _rc == 198
capture noisily cge_parameter v(i), values(r1:1)
assert _rc == 110
capture noisily cge_parameter v(j) = 1
assert _rc == 198
cge_equation ZE(i): Z(i) = v(i) + 1
capture noisily cge_parameter v(i) = 3
assert _rc == 459
capture noisily cge_set bad = x-y
assert _rc == 198
capture noisily cge_set bad2 = sum
assert _rc == 198
capture noisily cge_set bad3 = i
* a set of the same labels as i, which is an alias
assert _rc == 0

* ---------------------------------------------------------------------
* 3. Assignments and value() expressions in a model from a SAM
* ---------------------------------------------------------------------
quietly do setup_synthetic.do
cge_parameter tm2(c) = tm(c) * 2 + 1
mata: assert(max(reldif(_ts_upval("tm2"), (1.2 \ 1.2 \ 1))) < 1e-15)
cge_variable QX2(c), value(base(QX(c)) / 2) fixed
mata: assert(_ts_val("QX2", "com_man", 0) == 70)
cge_equation, clear
cge_parameter, clear

* ---------------------------------------------------------------------
* 4. The standard model in the user language against the built-in model
* ---------------------------------------------------------------------
local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) ///
    households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
foreach s in base notariff labour prod invest {
    tempfile b_`s'
}
quietly cge_solve, name(base)
quietly cge_results, sim(base) clear
quietly save `b_base'
quietly cge_shock tm, value(0)
quietly cge_solve, name(notariff)
quietly cge_results, sim(notariff) clear
quietly save `b_notariff'
quietly cge_shock, reset
quietly cge_shock QFS, elements(lab) scale(1.1)
quietly cge_solve, name(labour)
quietly cge_results, sim(labour) clear
quietly save `b_labour'
quietly cge_shock, reset
quietly cge_shock ad, elements(act_agr) scale(1.05)
quietly cge_solve, name(prod)
quietly cge_results, sim(prod) clear
quietly save `b_prod'
quietly cge_shock, reset
quietly cge_closure, savinv(investment)
quietly cge_shock GADJ, scale(1.2)
quietly cge_solve, name(invest)
quietly cge_results, sim(invest) clear
quietly save `b_invest'

* the standalone model, from examples/standard_model.do, which solves the
* base and the removal of tariffs
quietly do ../examples/standard_model.do
cge_model describe
assert r(standalone) == 1 & r(N_equations) == 93 & r(N_variables) == 106 & r(N_fixed) == 13 & r(N_free) == 93
assert r(square) == 1
quietly cge_shock, reset
quietly cge_shock QFS, elements(lab) scale(1.1)
quietly cge_solve, name(labour)
quietly cge_shock, reset
quietly cge_shock ad, elements(act_agr) scale(1.05)
quietly cge_solve, name(prod)
quietly cge_shock, reset
* investment-driven savings: IADJ fixed, MPSADJ free
cge_closure, swap(IADJ MPSADJ)
quietly cge_shock GADJ, scale(1.2)
quietly cge_solve, name(invest)
foreach s in base notariff labour prod invest {
    quietly cge_results, sim(`s') clear
    rename value sa_value
    quietly merge 1:1 variable element1 element2 using `b_`s'', keep(master match)
    assert _merge == 3
    quietly generate double d = abs(sa_value - value) / max(1, abs(value))
    quietly summarize d
    display as text "`s': " as result _N as text " values, largest relative difference from the built-in model " ///
        as result %9.2e r(max)
    assert r(max) < 1e-9
}
* the starting values solve the base
cge_listing, sim(base)
assert r(max_residual) < 1e-12

* saved and loaded, then solved again
tempfile f
quietly cge_save using `f', replace
quietly cge_use using `f'
cge_model describe
assert r(standalone) == 1 & r(N_equations) == 93
quietly cge_closure, swap(none)
quietly cge_shock, reset
quietly cge_shock tm, value(0)
quietly cge_solve, name(again)
quietly cge_results, sim(again) clear
rename value v2
quietly merge 1:1 variable element1 element2 using `b_notariff', keep(master match)
quietly generate double d = abs(v2 - value) / max(1, abs(value))
quietly summarize d
assert r(max) < 1e-9

* ---------------------------------------------------------------------
* 5. Errors: commands that need a SAM, closure options, shocks, export
* ---------------------------------------------------------------------
foreach cmd in "cge_calibrate, sigmava(1) sigmaq(1) sigmat(1)" "cge_report" "cge_check" "cge_multiplier" ///
    "cge_dynamic, name(x) periods(1 2)" "cge_map, activities(a)" "cge_samexport, clear" {
    capture noisily `cmd'
    assert _rc == 459
}
capture noisily cge_closure, external(fixexr)
assert _rc == 198
capture noisily cge_shock tm2, value(1)
assert _rc == 198
capture noisily cge_shock QA, elements(act_agr) scale(2)
assert _rc == 459
capture noisily cge_variable PQ2(c), value(1) lower(0)
assert _rc == 198
cge_variable PQ2(c), value(1)
cge_model describe
* a variable without an equation: the system is no longer square
assert r(square) == 0
capture noisily cge_solve, name(nosq)
assert _rc == 459
* a sum over an index of the domain (GAMS: set already under control)
capture noisily cge_equation BAD(f,a): W(f) = sum(f, QF(f,a))
assert _rc == 198
capture noisily cge_model nothing
assert _rc == 198
* from version 0.17.0 describe takes a named model: one not defined is 111
capture noisily cge_model describe extra
assert _rc == 111
capture noisily cge_model describe extra more
assert _rc == 198

mata: mata drop _ts_val() _ts_upval()
