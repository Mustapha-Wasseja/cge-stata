* test_cgenest.do -- nested CES and CET blocks declared with cge_nest
* (version 0.11.0; docs/model_spec.md, Section 20). A block of value added
* at the built-in elasticity gives the built-in solution, under shocks to
* tariffs, efficiency and the efficiency of a factor; so do a block of two
* nests with the same elasticity and a Cobb-Douglas block; a block of two
* nests with different elasticities against the built-in nests of value
* added, with a payroll tax; a CET block of exports and domestic sales against
* the built-in CET; the base holds after calibration again; errors.

version 13.0
quietly do helpers_reference.do

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

_cge_load
capture mata: mata drop _tn_diff()
mata:
// The largest difference between simulations a and b over the model's own
// variables, relative to their scale
real scalar _tn_diff(string scalar a, string scalar b)
{
    struct cge_model scalar M
    real colvector xa, xb, own
    M = _cge_load()
    xa = M.simx[., _cge_sim_index(M, a)]
    xb = M.simx[., _cge_sim_index(M, b)]
    own = (1::(M.nuv ? M.voff[rows(M.vname) - M.nuv + 1] : rows(M.x0)))
    return(max(abs(xa[own] - xb[own]) :/ M.xscale[own]))
}
end

capture program drop _tn_check
program define _tn_check
    args a b tol what
    mata: st_numscalar("tn_d", _tn_diff("`a'", "`b'"))
    display as text "`what': " as result %9.2e scalar(tn_d)
    assert scalar(tn_d) < `tol'
end

capture program drop _tn_shocks
program define _tn_shocks
    args tag
    quietly cge_shock tm, value(0)
    quietly cge_solve, name(`tag'1) tolerance(1e-12)
    quietly cge_shock, reset
    quietly cge_shock ad, elements(act_man) scale(1.1)
    quietly cge_solve, name(`tag'2) tolerance(1e-12)
    quietly cge_shock, reset
    quietly cge_shock af, elements(lab) scale(1.05)
    quietly cge_solve, name(`tag'3) tolerance(1e-12)
    quietly cge_shock, reset
end

* ---------------------------------------------------------------------
* 1. One nest of value added, at the built-in elasticity
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
_tn_shocks b
cge_nest begin va(a), output(QVA(a)) price(PVA(a)) s(0.8) efficiency(ad(a) / base(ad(a))) replace(Q3)
cge_nest input QF(lab, a), price(W(lab) * WFDIST(lab, a)) units(af(lab) * EFF(lab) * DW(lab)) replace(Q4(lab, a))
cge_nest input QF(cap, a), price(W(cap) * WFDIST(cap, a)) units(af(cap) * EFF(cap) * DW(cap)) replace(Q4(cap, a))
cge_nest end
assert r(N_equations) == 3
quietly cge_solve, name(n0) tolerance(1e-12)
assert r(iterations) == 0
_tn_shocks n
forvalues k = 1/3 {
    _tn_check b`k' n`k' 1e-10 "one nest against the built-in, shock `k'"
}
cge_nest, list
assert r(N_blocks) == 1 & "`r(blocks)'" == "va"
* with another elasticity, and the model calibrated again with the block in
* place: the block holds at the base and gives the built-in solution (which
* calibration drops, so it is kept as data)
quietly cge_equation, clear
quietly cge_calibrate, sigmava(1.5) sigmaq(2) sigmat(2)
_tn_shocks c
forvalues k = 1/3 {
    quietly cge_results, sim(c`k') clear nodisplay
    rename value v_builtin
    tempfile c`k'
    quietly save `c`k''
}
cge_nest begin va(a), output(QVA(a)) price(PVA(a)) s(1.5) efficiency(ad(a) / base(ad(a))) replace(Q3)
cge_nest input QF(lab, a), price(W(lab) * WFDIST(lab, a)) units(af(lab)) replace(Q4(lab, a))
cge_nest input QF(cap, a), price(W(cap) * WFDIST(cap, a)) units(af(cap)) replace(Q4(cap, a))
cge_nest end
quietly cge_calibrate, sigmava(1.5) sigmaq(2) sigmat(2)
quietly cge_solve, name(m0) tolerance(1e-12)
assert r(iterations) == 0
_tn_shocks m
forvalues k = 1/3 {
    quietly cge_results, sim(m`k') clear nodisplay
    quietly merge 1:1 variable element1 element2 using `c`k'', keep(match)
    quietly generate double rel = abs(value - v_builtin) / max(1, abs(v_builtin))
    quietly summarize rel
    display as text "elasticity 1.5, calibrated again, shock `k': " as result %9.2e r(max)
    assert r(max) < 1e-10
}
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 2. Two nests with the same elasticity: the one-level CES
* ---------------------------------------------------------------------
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov) savinv(sav) row(row) ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.6) sigmaq(2) sigmat(2)
_tn_shocks d
cge_nest begin va(a), output(QVA(a)) price(PVA(a)) s(0.6) efficiency(ad(a) / base(ad(a))) replace(Q3)
cge_nest nest k, s(0.6)
cge_nest input QF(lab, a), price(W(lab) * WFDIST(lab, a)) units(af(lab)) replace(Q4(lab, a))
cge_nest input QF(cap, a), price(W(cap) * WFDIST(cap, a)) units(af(cap)) in(k) replace(Q4(cap, a))
cge_nest end
_tn_shocks e
forvalues k = 1/3 {
    _tn_check d`k' e`k' 1e-10 "two nests, one elasticity, against the built-in, shock `k'"
}
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 3. A Cobb-Douglas block against the built-in Cobb-Douglas value added
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(1) sigmaq(2) sigmat(2)
_tn_shocks f
cge_nest begin va(a), output(QVA(a)) price(PVA(a)) s(1) efficiency(ad(a) / base(ad(a))) replace(Q3)
cge_nest input QF(lab, a), price(W(lab) * WFDIST(lab, a)) units(af(lab)) replace(Q4(lab, a))
cge_nest input QF(cap, a), price(W(cap) * WFDIST(cap, a)) units(af(cap)) replace(Q4(cap, a))
cge_nest end
_tn_shocks g
forvalues k = 1/3 {
    _tn_check f`k' g`k' 1e-10 "Cobb-Douglas block against the built-in, shock `k'"
}
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 4. Two nests with different elasticities against the built-in nests of
* value added (version 0.5.1, checked against the Python reference): two
* kinds of labour in a nest of 1.5 below a top of 0.8 with capital, and a
* payroll tax on skilled labour
* ---------------------------------------------------------------------
local nmap activities(act_agr act_man act_ser act_ene) commodities(com_agr com_man com_ser com_ene) ///
    factors(lab_hi lab_lo cap) households(hhd) government(gov) savinv(sav) row(row)             ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) factortax(tax_pay:lab_hi)
capture program drop _tn_nshocks
program define _tn_nshocks
    args tag
    quietly cge_shock tm, value(0)
    quietly cge_solve, name(`tag'1) tolerance(1e-12)
    quietly cge_shock, reset
    quietly cge_shock QFS, elements(lab_hi) scale(1.1)
    quietly cge_solve, name(`tag'2) tolerance(1e-12)
    quietly cge_shock, reset
    quietly cge_shock ad, elements(act_agr) scale(1.05)
    quietly cge_solve, name(`tag'3) tolerance(1e-12)
    quietly cge_shock, reset
    quietly cge_shock tf, elements(lab_hi) scale(0.5)
    quietly cge_solve, name(`tag'4) tolerance(1e-12)
    quietly cge_shock, reset
end
quietly cge_synthetic, clear nests
quietly cge_sam, labels(account)
quietly cge_map, `nmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) nests(labour: lab_hi lab_lo) sigmanest(labour:1.5)
_tn_nshocks p
forvalues k = 1/4 {
    quietly cge_results, sim(p`k') clear nodisplay
    quietly drop if inlist(variable, "QNA", "PNA")
    rename value v_builtin
    tempfile p`k'
    quietly save `p`k''
}
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_nest begin va(a), output(QVA(a)) price(PVA(a)) s(0.8) efficiency(ad(a) / base(ad(a))) replace(Q3)
cge_nest nest labour, s(1.5)
cge_nest input QF(lab_hi, a), price(W(lab_hi) * WFDIST(lab_hi, a) * (1 + tf(lab_hi, a))) units(af(lab_hi)) ///
    in(labour) replace(Q4(lab_hi, a))
cge_nest input QF(lab_lo, a), price(W(lab_lo) * WFDIST(lab_lo, a) * (1 + tf(lab_lo, a))) units(af(lab_lo)) ///
    in(labour) replace(Q4(lab_lo, a))
cge_nest input QF(cap, a), price(W(cap) * WFDIST(cap, a) * (1 + tf(cap, a))) units(af(cap)) replace(Q4(cap, a))
cge_nest end
quietly cge_solve, name(q0) tolerance(1e-12)
assert r(iterations) == 0
_tn_nshocks q
forvalues k = 1/4 {
    quietly cge_results, sim(q`k') clear nodisplay
    quietly merge 1:1 variable element1 element2 using `p`k'', keep(match using)
    assert _merge == 3
    quietly generate double rel = abs(value - v_builtin) / max(1, abs(v_builtin))
    quietly summarize rel
    display as text "two nests against the built-in nests, shock `k': " as result %9.2e r(max)
    assert r(max) < 1e-10
}
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 5. A CET block of exports and domestic sales against the built-in CET
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
_tn_shocks h
cge_nest begin x(c)$(QE(c) > 0 & QD(c) > 0), output(QX(c)) price(PX(c)) t(2) replace(P4)
cge_nest output QE(c), price(PE(c)) replace(T1)
cge_nest output QD(c), price(PD(c)) replace(T2)
cge_nest end
_tn_shocks i
forvalues k = 1/3 {
    _tn_check h`k' i`k' 1e-10 "CET block against the built-in, shock `k'"
}
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 6. Errors
* ---------------------------------------------------------------------
capture noisily cge_nest input QF(lab, a), price(W(lab))
assert _rc == 198
capture noisily cge_nest begin va(a), output(QVA(a)) price(PVA(a))
assert _rc == 198
capture noisily cge_nest begin va(a), output(QVA(a)) price(PVA(a)) s(0.5) t(1)
assert _rc == 198
cge_nest begin va(a), output(QVA(a)) price(PVA(a)) s(0.8) replace(Q3)
capture noisily cge_nest begin vb(a), output(QVA(a)) price(PVA(a)) s(0.8)
assert _rc == 198
capture noisily cge_nest output QF(lab, a), price(W(lab))
assert _rc == 198
capture noisily cge_nest nest k, t(0.5)
assert _rc == 198
capture noisily cge_nest input QF(lab, a), price(W(lab)) in(nowhere)
assert _rc == 111
capture noisily cge_nest end
assert _rc == 198
* a leaf that replaces an element of another block's domain
cge_nest input QF(lab, a), price(W(lab) * WFDIST(lab, a)) replace(Q4(lab, c))
capture noisily cge_nest end
assert _rc != 0
cge_nest, drop
mata: mata drop _tn_diff()
