* test_condsolve.do -- conditions ($) of user definitions evaluated at each
* solve (version 0.43.0; docs/model_spec.md, Section 53). cge_options,
* conditions(solve): a conditional domain, sum and term switched by a shock,
* against the model whose base meets the condition; an element that leaves
* its domain; the default, at the base; a pair of a conditional variable and
* equation; a nonlinear programme; cge_loop; cge_listing at each
* simulation; conditions(base) again; save and use; a model from a SAM;
* errors.

version 13.0

capture mata: mata drop _tcs_val()
capture mata: mata drop _tcs_cond()
_cge_load
mata:
// The value of element el of user variable v in simulation s
real scalar _tcs_val(string scalar s, string scalar v, string scalar el)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.simx[_cge_u_vpos(M, v, el), _cge_find(M.simname, s)])
}
// 1 if simulation s was solved with conditions(solve)
real scalar _tcs_cond(string scalar s)
{
    struct cge_model scalar M
    M = _cge_load()
    return(_cge_simcond(M, _cge_find(M.simname, s)))
}
end

* ---------------------------------------------------------------------
* 1. A conditional domain and sum: X(i) = w(i) Y where on(i), T the sum of
*    X over on(i); on(c) switched on by a shock
* ---------------------------------------------------------------------
program define _tcs_model1
    args onc ona
    cge_model new
    cge_set i = a b c
    cge_parameter on(i), values(a:`ona' b:1 c:`onc')
    cge_parameter w(i), values(a:1 b:2 c:3)
    cge_variable Y, value(10) fixed
    cge_variable X(i)$(on(i)) = w(i) * Y
    cge_variable T = sum(i$(on(i)), X(i))
end
quietly _tcs_model1 0 1
* the default: the conditions at the base
cge_options
assert "`r(conditions)'" == "base"
cge_shock on, elements(c) value(1)
cge_solve, name(atbase)
mata: st_numscalar("tcs_t", _tcs_val("atbase", "T", ""))
mata: st_numscalar("tcs_x", _tcs_val("atbase", "X", "c"))
assert abs(scalar(tcs_t) - 30) < 1e-10 & scalar(tcs_x) == 0
mata: assert(_tcs_cond("atbase") == 0)
* at the solve
cge_options, conditions(solve)
assert "`r(conditions)'" == "solve"
cge_solve, name(atsolve)
mata: st_numscalar("tcs_t", _tcs_val("atsolve", "T", ""))
mata: st_numscalar("tcs_x", _tcs_val("atsolve", "X", "c"))
assert abs(scalar(tcs_t) - 60) < 1e-10 & abs(scalar(tcs_x) - 30) < 1e-10
mata: assert(_tcs_cond("atsolve") == 1)
* the results show the element that the solve brought in, and only there
cge_results, sim(atsolve) clear
count if variable == "X" & element1 == "c"
assert r(N) == 1
cge_results, sim(atbase) clear
count if variable == "X" & element1 == "c"
assert r(N) == 0
* an element that leaves its domain is 0
cge_shock on, elements(a) value(0)
cge_solve, name(leave)
mata: st_numscalar("tcs_t", _tcs_val("leave", "T", ""))
mata: st_numscalar("tcs_x", _tcs_val("leave", "X", "a"))
assert abs(scalar(tcs_t) - 50) < 1e-10 & scalar(tcs_x) == 0
* the scenario against the model whose base meets the conditions
mata: st_numscalar("tcs_b", _tcs_val("leave", "X", "b"))
quietly cge_save using "tcs_model1", replace
quietly _tcs_model1 1 0
cge_solve, name(direct)
foreach el in a b c {
    mata: st_numscalar("tcs_d", abs(_tcs_val("direct", "X", "`el'")))
    if "`el'" == "a" assert scalar(tcs_d) == 0
    else assert scalar(tcs_d) > 0
}
mata: st_numscalar("tcs_d", _tcs_val("direct", "T", ""))
assert abs(scalar(tcs_d) - 50) < 1e-10
cge_use using "tcs_model1"
* the options and the flags are kept by save and use
cge_options
assert "`r(conditions)'" == "solve"
mata: assert(_tcs_cond("atsolve") == 1 & _tcs_cond("atbase") == 0)
* cge_listing at each simulation: its own equation elements, which defined
* variables bring (X(a), X(b) and T at the base; X(b), X(c) and T after
* leave)
cge_listing, sim(atbase)
assert r(N_equations) == 3
cge_listing, sim(atsolve)
assert r(N_equations) == 4
cge_listing, sim(leave)
assert r(N_equations) == 3
cge_listing, base
assert r(N_equations) == 3
* back to the base: the default again, and the structure of the base
cge_shock, reset
cge_options, conditions(base)
assert "`r(conditions)'" == "base"
cge_shock on, elements(c) value(1)
cge_solve, name(base2)
mata: st_numscalar("tcs_t", _tcs_val("base2", "T", ""))
assert abs(scalar(tcs_t) - 30) < 1e-10
cge_options, conditions(solve)
cge_options, reset
assert "`r(conditions)'" == "base"
erase "tcs_model1.cgem"

* ---------------------------------------------------------------------
* 2. A conditional variable and equation, a conditional term and a
*    conditional sum: a subsidy S(i) = sub(i) Q(i) where sub(i) > 0, a
*    price P(i) = 1 - 0.1$(sub(i) > 0) and their total G
* ---------------------------------------------------------------------
program define _tcs_model2
    args suba
    cge_model new
    * before the definitions: S and sdef have no element at the base
    cge_options, conditions(solve)
    cge_set i = a b
    cge_parameter sub(i), values(a:`suba' b:0)
    cge_parameter d0(i), values(a:5 b:8)
    cge_variable P(i), value(1)
    cge_variable Q(i), value(d0(i))
    cge_variable S(i)$(sub(i) > 0), value(sub(i) * d0(i))
    cge_equation price(i): P(i) = 1 - 0.1$(sub(i) > 0)
    cge_equation dem(i): Q(i) = d0(i) / P(i)
    cge_equation sdef(i)$(sub(i) > 0): S(i) = sub(i) * Q(i)
    cge_variable G = sum(i$(sub(i) > 0), S(i))
end
quietly _tcs_model2 0
cge_shock sub, elements(a) value(0.2)
cge_solve, name(subs)
assert r(converged) == 1
mata: st_numscalar("tcs_p", _tcs_val("subs", "P", "a"))
mata: st_numscalar("tcs_q", _tcs_val("subs", "Q", "a"))
mata: st_numscalar("tcs_s", _tcs_val("subs", "S", "a"))
mata: st_numscalar("tcs_g", _tcs_val("subs", "G", ""))
assert abs(scalar(tcs_p) - 0.9) < 1e-10 & abs(scalar(tcs_q) - 5 / 0.9) < 1e-9
assert abs(scalar(tcs_s) - 0.2 * 5 / 0.9) < 1e-9 & abs(scalar(tcs_g) - scalar(tcs_s)) < 1e-10
* at the base, none of it: the shock changes nothing that the base did not
* already have
cge_options, conditions(base)
cge_solve, name(subbase)
mata: st_numscalar("tcs_p", _tcs_val("subbase", "P", "a"))
mata: st_numscalar("tcs_g", _tcs_val("subbase", "G", ""))
assert abs(scalar(tcs_p) - 1) < 1e-10 & scalar(tcs_g) == 0
* the model whose base has the subsidy, every variable
local els "P.a P.b Q.a Q.b S.a G."
local vals
foreach v of local els {
    gettoken nm el : v, parse(".")
    local el = substr("`el'", 2, .)
    mata: st_local("x", strofreal(_tcs_val("subs", "`nm'", "`el'"), "%21.15g"))
    local vals `vals' `x'
}
quietly _tcs_model2 0.2
cge_solve, name(direct)
local d = 0
local j = 0
foreach v of local els {
    local ++j
    gettoken nm el : v, parse(".")
    local el = substr("`el'", 2, .)
    mata: st_local("x", strofreal(_tcs_val("direct", "`nm'", "`el'"), "%21.15g"))
    local d = max(`d', abs(`x' - `: word `j' of `vals''))
}
display as text "conditions at the solve against the model with them at the base: " as result %9.2e `d'
assert `d' < 1e-10

* ---------------------------------------------------------------------
* 3. A nonlinear programme: technology t3 becomes available; min
*    sum(k$(avail(k)), cost(k) Z(k)^2) subject to the sum of Z = 10 has the
*    minimum 100 / sum(1 / cost(k)) over the technologies available, 600/9
*    with t1 and t2, 1400/49 with t3, where Z(t3) = 40/7
* ---------------------------------------------------------------------
cge_model new
cge_set k = t1 t2 t3
cge_parameter avail(k), values(t1:1 t2:1 t3:0)
cge_parameter cost(k), values(t1:2 t2:1 t3:0.5)
cge_variable Z(k)$(avail(k)), value(5)
cge_equation dem: sum(k$(avail(k)), Z(k)) = 10
cge_options, conditions(solve)
cge_solve, name(two) minimize(sum(k$(avail(k)), cost(k) * Z(k)^2))
assert r(converged) == 1 & abs(r(objective) - 600 / 9) < 1e-8
cge_shock avail, elements(t3) value(1)
cge_solve, name(three) minimize(sum(k$(avail(k)), cost(k) * Z(k)^2))
assert r(converged) == 1 & abs(r(objective) - 1400 / 49) < 1e-8
mata: st_numscalar("tcs_z", _tcs_val("three", "Z", "t3"))
assert abs(scalar(tcs_z) - 40 / 7) < 1e-8
mata: assert(_tcs_cond("three") == 1)
* at the base, t3 stays out
cge_options, conditions(base)
cge_solve, name(twob) minimize(sum(k$(avail(k)), cost(k) * Z(k)^2))
assert r(converged) == 1 & abs(r(objective) - 600 / 9) < 1e-8

* ---------------------------------------------------------------------
* 4. cge_loop: each scenario's conditions
* ---------------------------------------------------------------------
quietly _tcs_model1 0 1
cge_options, conditions(solve)
cge_loop, name(lp) values(on(c) = 0 1 0)
mata: st_numscalar("tcs_t", _tcs_val("lp1", "T", ""))
assert abs(scalar(tcs_t) - 30) < 1e-10
mata: st_numscalar("tcs_t", _tcs_val("lp2", "T", ""))
assert abs(scalar(tcs_t) - 60) < 1e-10
mata: st_numscalar("tcs_t", _tcs_val("lp3", "T", ""))
assert abs(scalar(tcs_t) - 30) < 1e-10
mata: assert(_tcs_cond("lp2") == 1)
* a scenario's dataset has the element it brought in
cge_loop, name(lq) values(on(c) = 0 1) keep(X) clear
count if variable == "X" & element1 == "c"
assert r(N) == 2
* the loop leaves the model's structure as it was
cge_listing, current
assert r(N_equations) == 3

* ---------------------------------------------------------------------
* 5. A model from a SAM: a user variable defined where flag(c)
* ---------------------------------------------------------------------
quietly {
    cge_synthetic, clear
    cge_sam, labels(account)
    cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) ///
        households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
    cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
}
cge_parameter flag(c), values(com_agr:1 com_man:0 com_ser:0)
cge_variable XV(c)$(flag(c)) = PQ(c) * QQ(c)
cge_options, conditions(solve)
cge_shock tm, value(0)
cge_shock flag, elements(com_man) value(1)
cge_solve, name(samsolve)
assert r(converged) == 1
mata: st_numscalar("tcs_x", _tcs_val("samsolve", "XV", "com_man"))
assert scalar(tcs_x) > 0
cge_options, conditions(base)
cge_solve, name(sambase)
mata: st_numscalar("tcs_x", _tcs_val("sambase", "XV", "com_man"))
assert scalar(tcs_x) == 0

* ---------------------------------------------------------------------
* 6. Errors
* ---------------------------------------------------------------------
capture noisily cge_options, conditions(sometimes)
assert _rc == 198
cge_model new
cge_set i = a b
cge_parameter rr(i), values(a:1 b:2)
cge_variable Y, value(1) fixed
cge_variable X(i)$(1 / rr(i) > 0) = Y
cge_options, conditions(solve)
cge_shock rr, elements(a) value(0)
capture noisily cge_solve, name(miss)
assert _rc == 459
* the next command evaluates its conditions at its own parameters, not
* those of the solve that stopped
cge_model new
cge_set i = a b
cge_parameter v(i), values(a:2 b:0)
cge_parameter s(i)$(v(i) > 0) = 1 / v(i)
cge_variable X(i)$(v(i) > 0), value(s(i))
cge_listing, base
assert r(N_equations) == 0
capture mata: mata drop _tcs_val()
capture mata: mata drop _tcs_cond()
capture program drop _tcs_model1
capture program drop _tcs_model2
capture scalar drop tcs_t tcs_x tcs_b tcs_d tcs_p tcs_q tcs_s tcs_g tcs_z
