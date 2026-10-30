* test_addterm.do -- variables added to built-in equations, cge_variable,
* add() (version 0.40.0; docs/model_spec.md, Section 50): a variable added
* to an element gives the same solution as the element replaced by its own
* equation with the variable on its right side (I7, S4, and P1, a definition
* the reduced system leaves out otherwise); rows with exact derivatives of
* their own (I8, I9, S2) against models that move the same amount elsewhere;
* the exact Jacobian against central differences; a solve with differences;
* two variables on one element; a defined variable; save and use; clear;
* errors.

version 13.0

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)

_cge_load
capture mata: mata drop _tad_keep()
capture mata: mata drop _tad_cmp()
capture mata: mata drop _tad_val()
capture mata: mata drop _tad_nadd()
mata:
// Keep the built-in variables of simulation s as external cge__tad_<tag>
void _tad_keep(string scalar tag, string scalar s)
{
    struct cge_model scalar M
    pointer() scalar q
    real scalar n
    M = _cge_load()
    n = (M.nuv ? M.voff[rows(M.vname) - M.nuv + 1] : rows(M.x0))
    if ((q = findexternal("cge__tad_" + tag)) == NULL) q = crexternal("cge__tad_" + tag)
    *q = M.simx[|1, _cge_find(M.simname, s) \ n, _cge_find(M.simname, s)|]
}

// The largest difference, relative to the scale, between the built-in
// variables of simulation s and those kept as tag, the elements of variable
// v (with element el, or all) left out; st_numscalar tad_d
void _tad_cmp(string scalar tag, string scalar s, string scalar v, string scalar el)
{
    struct cge_model scalar M
    real colvector a, b, keep, pos
    real scalar n
    M = _cge_load()
    n = (M.nuv ? M.voff[rows(M.vname) - M.nuv + 1] : rows(M.x0))
    a = *findexternal("cge__tad_" + tag)
    b = M.simx[|1, _cge_find(M.simname, s) \ n, _cge_find(M.simname, s)|]
    keep = J(n, 1, 1)
    if (v != "") {
        pos = (el == "" ? _cge_vpos(M, _cge_vidx(M, v)) : _cge_u_vpos(M, v, el))
        keep[pos] = J(rows(pos), 1, 0)
    }
    st_numscalar("tad_d", max(select(abs(a - b) :/ M.xscale[|1 \ n|], keep)))
}

// The value of variable v, element el, in simulation s, or kept as tag
real scalar _tad_val(string scalar s, string scalar v, string scalar el, | string scalar tag)
{
    struct cge_model scalar M
    real colvector a
    M = _cge_load()
    if (args() == 4) {
        a = *findexternal("cge__tad_" + tag)
        return(a[_cge_u_vpos(M, v, el)])
    }
    return(M.simx[_cge_u_vpos(M, v, el), _cge_find(M.simname, s)])
}

// The variables added, and their elements
void _tad_nadd()
{
    struct cge_model scalar M
    M = _cge_load()
    st_numscalar("tad_nadd", rows(M.uadd))
    st_numscalar("tad_nel", rows(M.uaddp))
}
end

quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'

* ---------------------------------------------------------------------
* 1. I7: government purchases of services, and a variable on their right
*    side, against the element replaced by its own equation
* ---------------------------------------------------------------------
cge_variable W7, value(0) fixed add(I7(com_ser))
mata: _tad_nadd()
assert scalar(tad_nadd) == 1 & scalar(tad_nel) == 1
cge_shock W7, value(2)
cge_solve, name(a7)
assert r(converged) == 1
mata: _tad_keep("a7", "a7")
quietly cge_shock, reset
quietly cge_equation, clear
cge_variable W7, value(0) fixed
cge_equation g7: QG(com_ser) = qg(com_ser) * GADJ + W7, replace(I7(com_ser))
cge_shock W7, value(2)
quietly cge_solve, name(b7)
mata: _tad_cmp("a7", "b7", "", "")
display as text "I7: largest difference " as result scalar(tad_d)
assert scalar(tad_d) < 1e-10
quietly cge_shock, reset
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 2. S4: the government balance
* ---------------------------------------------------------------------
cge_variable W4, value(0) fixed add(S4)
cge_shock W4, value(1)
quietly cge_solve, name(a4)
mata: _tad_keep("a4", "a4")
quietly cge_shock, reset
quietly cge_equation, clear
cge_variable W4, value(0) fixed
cge_equation s4: YG = EG + GSAV + W4, replace(S4)
cge_shock W4, value(1)
quietly cge_solve, name(b4)
mata: _tad_cmp("a4", "b4", "", "")
display as text "S4: largest difference " as result scalar(tad_d)
assert scalar(tad_d) < 1e-10
quietly cge_shock, reset
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 3. P1: the import price of manufactures, a definition that the reduced
*    system leaves out unless something is added to it (the synthetic SAM
*    has no margins, so that ici is 0)
* ---------------------------------------------------------------------
cge_variable W1, value(0) fixed add(P1(com_man))
cge_shock W1, value(0.05)
quietly cge_solve, name(a1)
assert r(converged) == 1
mata: _tad_keep("a1", "a1")
quietly cge_shock, reset
quietly cge_equation, clear
cge_variable W1, value(0) fixed
cge_equation p1: PM(com_man) = pwm(com_man) * (1 + tm(com_man) * TMADJ + RM(com_man)) * EXR + W1, replace(P1(com_man))
cge_shock W1, value(0.05)
quietly cge_solve, name(b1)
mata: _tad_cmp("a1", "b1", "", "")
display as text "P1: largest difference " as result scalar(tad_d)
assert scalar(tad_d) < 1e-10
mata: st_numscalar("tad_pm", _tad_val("b1", "PM", "com_man"))
assert scalar(tad_pm) > 1.04
quietly cge_shock, reset
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 4. Rows with exact derivatives. I8: revenue W added to government income
*    is the same as W less spending in the balance S4, apart from YG itself
* ---------------------------------------------------------------------
cge_variable W8, value(0) fixed add(I8)
cge_shock W8, value(1.5)
quietly cge_solve, name(a8)
assert r(converged) == 1
mata: _tad_keep("a8", "a8")
mata: _cge_jexall()
display as text "I8: exact Jacobian against differences " as result r(maxdiff)
assert r(maxdiff) < 1e-6
quietly cge_shock, reset
quietly cge_equation, clear
cge_variable W8B, value(0) fixed
cge_variable V8 = -W8B, add(S4)
cge_shock W8B, value(1.5)
quietly cge_solve, name(b8)
mata: _tad_cmp("a8", "b8", "YG", "")
display as text "I8: largest difference apart from YG " as result scalar(tad_d)
assert scalar(tad_d) < 1e-10
mata: st_numscalar("tad_yg", _tad_val("", "YG", "", "a8") - _tad_val("b8", "YG", ""))
assert abs(scalar(tad_yg) - 1.5) < 1e-9
quietly cge_shock, reset
quietly cge_equation, clear

* S2 and I9: W more of manufactures absorbed in market clearing, against W
* more government purchases (I7) that the government does not pay for (I9),
* apart from QG(com_man) itself
cge_variable W2, value(0) fixed add(S2(com_man))
cge_shock W2, value(3)
quietly cge_solve, name(a2)
assert r(converged) == 1
mata: _tad_keep("a2", "a2")
mata: _cge_jexall()
display as text "S2: exact Jacobian against differences " as result r(maxdiff)
assert r(maxdiff) < 1e-6
* the same with Jacobians from central differences
quietly cge_options, jacobian(differences)
quietly cge_solve, name(a2c)
quietly cge_options, reset
mata: _tad_cmp("a2", "a2c", "", "")
display as text "S2: exact against central differences " as result scalar(tad_d)
assert scalar(tad_d) < 1e-8
quietly cge_shock, reset
quietly cge_equation, clear
cge_variable W2B, value(0) fixed add(I7(com_man))
cge_variable V9 = -PQ(com_man) * W2B, add(I9)
cge_shock W2B, value(3)
quietly cge_solve, name(b2)
assert r(converged) == 1
mata: _cge_jexall()
assert r(maxdiff) < 1e-6
mata: _tad_cmp("a2", "b2", "QG", "com_man")
display as text "S2: largest difference apart from QG(com_man) " as result scalar(tad_d)
assert scalar(tad_d) < 1e-10
mata: st_numscalar("tad_qg", _tad_val("b2", "QG", "com_man") - _tad_val("", "QG", "com_man", "a2"))
assert abs(scalar(tad_qg) - 3) < 1e-9
quietly cge_shock, reset
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 5. Two variables on one element, an indexed variable, a defined one
* ---------------------------------------------------------------------
cge_variable WA, value(0) fixed add(I7(com_ser))
cge_variable WB, value(0) fixed add(I7(com_ser))
cge_shock WA, value(1.2)
cge_shock WB, value(0.8)
quietly cge_solve, name(a7b)
mata: _tad_cmp("a7", "a7b", "", "")
assert scalar(tad_d) < 1e-10
quietly cge_shock, reset
quietly cge_equation, clear
cge_variable WG(c), value(0) fixed add(I7)
mata: _tad_nadd()
assert scalar(tad_nadd) == 1 & scalar(tad_nel) == 3
cge_shock WG, elements(com_ser) value(2)
quietly cge_solve, name(a7c)
mata: _tad_cmp("a7", "a7c", "", "")
assert scalar(tad_d) < 1e-10
* saved and loaded with the model
tempfile mod
quietly cge_save using `"`mod'.cgem"', replace
quietly cge_equation, clear
quietly cge_use using `"`mod'.cgem"'
mata: _tad_nadd()
assert scalar(tad_nadd) == 1 & scalar(tad_nel) == 3
quietly cge_solve, name(a7d)
mata: _tad_cmp("a7", "a7d", "", "")
assert scalar(tad_d) < 1e-10
capture erase `"`mod'.cgem"'
quietly cge_shock, reset
quietly cge_equation, clear
mata: _tad_nadd()
assert scalar(tad_nadd) == 0 & scalar(tad_nel) == 0
* a defined variable: an ad valorem tax on the absorption of manufactures,
* zero at the base, raised in the scenario, paid to the government
cge_parameter ttx = 0
cge_variable TX = ttx * PQ(com_man) * QQ(com_man), add(I8)
cge_shock ttx, value(0.05)
cge_solve, name(tx)
assert r(converged) == 1
mata: _cge_jexall()
assert r(maxdiff) < 1e-6
mata: st_numscalar("tad_tx", _tad_val("tx", "TX", "") - 0.05 * _tad_val("tx", "PQ", "com_man") * _tad_val("tx", "QQ", "com_man"))
assert abs(scalar(tad_tx)) < 1e-10
mata: st_numscalar("tad_tx", _tad_val("tx", "TX", ""))
assert scalar(tad_tx) > 0
quietly cge_shock, reset
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 6. Errors
* ---------------------------------------------------------------------
capture noisily cge_variable E1, value(0) fixed add(NOSUCH)
assert _rc == 198
capture noisily cge_variable E1, value(0) fixed add(B1)
assert _rc == 198
capture noisily cge_variable E1, value(0) fixed add(U)
assert _rc == 198
capture noisily cge_variable E1, value(0) fixed add(I7(nosuch))
assert _rc == 111
capture noisily cge_variable E1, value(0) fixed add(I7)
assert _rc == 198
capture noisily cge_variable E1, value(0) fixed add()
assert _rc == 198
cge_variable WR, value(0) fixed
cge_equation g7: QG(com_ser) = qg(com_ser) * GADJ + WR, replace(I7(com_ser))
capture noisily cge_variable E1, value(0) fixed add(I7(com_ser))
assert _rc == 459
quietly cge_equation, clear
cge_model new
cge_variable X, value(1)
capture noisily cge_variable E1, value(0) fixed add(I7)
assert _rc == 198
clear
capture mata: mata drop _tad_keep()
capture mata: mata drop _tad_cmp()
capture mata: mata drop _tad_val()
capture mata: mata drop _tad_nadd()
foreach t in a7 a4 a1 a8 a2 {
    capture mata: rmexternal("cge__tad_`t'")
}
scalar drop tad_d tad_qg tad_pm tad_yg tad_tx tad_nadd tad_nel
