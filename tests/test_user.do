* test_user.do -- user variables and equations (version 0.6.1;
* docs/model_spec.md, Section 19). Checked against closures that give the same
* model, against the definitions themselves, and (tools/gams) against GAMS

version 13.0
quietly do helpers_reference.do

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

* ---------------------------------------------------------------------
* 1. Real government savings held at the base, the direct tax rate
*    adjusting: with the CPI as numeraire, this is the closure fixgsav
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_variable RGSAV = GSAV / CPI
assert r(N_elements) == 1
cge_closure, swap(RGSAV TINSADJ)
cge_shock tm, value(0)
cge_solve, name(user_rgsav) tolerance(1e-12)
assert r(converged) == 1
tempfile stata
quietly cge_results, sim(user_rgsav) clear nodisplay
quietly drop if variable == "RGSAV"
quietly save `stata'
quietly import delimited using "expected/rep_tariff_removal_direct.csv", varnames(1) case(preserve) ///
    stringcols(1 2 3) asdouble clear
rename (base value) (ref_base ref_value)
quietly merge 1:1 variable element1 element2 using `stata'
assert _merge == 3
quietly generate double rel = abs(value - ref_value) / max(1, abs(ref_value))
quietly summarize rel
display as text "real government savings fixed by a user equation, against fixgsav: " as result %9.2e r(max)
assert r(max) < 1e-9

* ---------------------------------------------------------------------
* 2. Indexed variables, sums and parameters; nominal government
*    consumption fixed, government consumption volumes adjusting
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_variable PSH(c) = PQ(c) * (1 + tv(c)) / CPI
assert r(N_elements) == 3
cge_variable GEXP = sum(c, PQ(c) * QG(c)), nominal
cge_equation, list
assert r(N_variables) == 2 & r(N_equations) == 4
cge_closure, swap(GEXP GADJ)
cge_shock pwm, scale(1.1)
cge_solve, name(user_gexp) tolerance(1e-12)
assert r(converged) == 1
quietly cge_results, sim(user_gexp) clear nodisplay
quietly summarize value if variable == "GEXP"
assert reldif(r(mean), 45) < 1e-12
quietly summarize value if variable == "CPI"
local cpi = r(mean)
quietly keep if inlist(variable, "PQ", "QG", "PSH")
quietly drop element2 base
quietly reshape wide value, i(element1) j(variable) string
quietly generate double spend = valuePQ * valueQG
quietly summarize spend
assert reldif(r(sum), 45) < 1e-12
quietly generate double gap = abs(valuePSH - valuePQ / `cpi')
quietly summarize gap
assert r(max) < 1e-12
cge_check, sim(user_gexp) homogeneity
assert r(failures) == 0

* ---------------------------------------------------------------------
* 3. A variable given a value, an equation with base(), and a swap: services
*    bought by the government 10 per cent above the base fix GADJ at 1.1
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_variable LAM, value(1)
cge_equation lam: QG(com_ser) = LAM * base(QG(com_ser))
cge_shock tm, value(0)
quietly cge_solve, name(lam1) tolerance(1e-12)
quietly cge_results, sim(lam1) clear nodisplay
quietly summarize value if variable == "LAM"
assert reldif(r(mean), 1) < 1e-13
cge_closure, swap(LAM GADJ)
cge_shock LAM, value(1.1)
cge_solve, name(lam11) tolerance(1e-12)
quietly cge_results, sim(lam11) clear nodisplay
quietly summarize value if variable == "GADJ"
assert reldif(r(mean), 1.1) < 1e-12
* a nonlinear equation with exp() and ln(), and a power
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_variable ZZ = exp(ln(CPI) * 2) - CPI ^ 2 + -1 * -1
* the exact Jacobian of user equations (version 0.7.0)
cge_variable YY = sum(c, PQ(c) ^ 1.5 * QG(c) / sqrt(QQ(c))) + EXR ^ CPI - ln(YG) * tm(com_man)
cge_variable XR(c) = PQ(c) * QQ(c) / (1 + QM(c)) - exp(-PD(c))
mata: _cge_jexall()
assert r(maxdiff) < 1e-6
quietly cge_solve, name(zz) tolerance(1e-12)
mata: _cge_jexcheck(0, "zz")
assert r(maxdiff) < 1e-6
quietly cge_results, sim(zz) clear nodisplay
quietly summarize value if variable == "ZZ"
assert reldif(r(mean), 1) < 1e-12

* ---------------------------------------------------------------------
* 4. Saved models, calibration again, dynamic runs and the GAMS export
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_variable RGSAV = GSAV / CPI
cge_variable GEXP = sum(c, PQ(c) * QG(c)), nominal
cge_closure, swap(RGSAV TINSADJ GEXP GADJ)
cge_shock pwm, scale(1.1)
quietly cge_solve, name(both) tolerance(1e-12)
tempfile saved
quietly cge_save using "`saved'", replace
quietly cge_use using "`saved'"
cge_equation, list
assert r(N_variables) == 2
quietly cge_solve, name(both2) tolerance(1e-12)
quietly cge_results, sim(both2) clear nodisplay
quietly summarize value if variable == "GEXP"
assert reldif(r(mean), 45) < 1e-12
* calibrating again keeps them
quietly cge_calibrate, sigmava(0.5) sigmaq(2) sigmat(2)
cge_equation, list
assert r(N_variables) == 2
quietly cge_dynamic, name(udyn) periods(0/2) capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02)
assert "`r(sims)'" == "udyn0 udyn1 udyn2"
quietly cge_closure, swap(RGSAV TINSADJ GEXP GADJ)
quietly cge_solve, name(both3) tolerance(1e-12)
tempfile gdir
cge_gams using "`gdir'_u", sim(both3) replace
mata:
u = cat(st_local("gdir") + "_u/cge_user.inc")
v = cat(st_local("gdir") + "_u/cge_shock_var.inc")
st_numscalar("oku", sum(u :== "variable U_RGSAV;") + sum(u :== "UE1..  U_RGSAV =e= GSAV / CPI;") +
             sum(strpos(u, "UE2..  U_GEXP =e= ( ( PQ('com_agr') * QG('com_agr') ) +") :== 1) +
             sum(v :== "U_RGSAV.fx = U_RGSAV.l;"))
end
assert scalar(oku) == 4

* ---------------------------------------------------------------------
* 5. Errors
* ---------------------------------------------------------------------
capture noisily cge_equation, clear
assert _rc == 459
quietly cge_closure, swap(none)
cge_equation, clear
cge_equation, list
assert r(N_variables) == 0
capture noisily cge_variable GSAV = 1
assert _rc == 110
capture noisily cge_variable XX = NOSUCH * 2
assert _rc == 111
capture noisily cge_variable XX = PQ(xyz)
assert _rc == 111
capture noisily cge_variable XX = PQ(com_agr
assert _rc == 198
capture noisily cge_variable XX = 2 * * 3
assert _rc == 198
capture noisily cge_variable XX = sum(z, PQ(z))
assert _rc == 198
capture noisily cge_variable XX(c) = PQ(a)
assert _rc == 198
capture noisily cge_variable XX
assert _rc == 198
capture noisily cge_equation e1 PQ(com_agr) = 1
assert _rc == 198
cge_variable XX = CPI
capture noisily cge_variable XX = CPI
assert _rc == 110
cge_equation, clear

* ---------------------------------------------------------------------
* Version 0.6.4: a variable without its equation leaves the system without a
* square Jacobian, and cge_solve stops with error 459; a user variable
* indexed by institutions is shocked over that set
* ---------------------------------------------------------------------
quietly do setup_synthetic.do
cge_variable LAM, value(1)
capture noisily cge_solve, name(unpaired)
assert _rc == 459
cge_equation lam: QG(com_ser) = LAM * base(QG(com_ser))
cge_solve, name(paired)
assert r(converged) == 1
cge_variable UI(i), value(1)
cge_equation ui(i): UI(i) = 1
* gov is an element of the set of i: the shock fails only because UI is free
capture noisily cge_shock UI, elements(gov) value(2)
assert _rc == 459
capture noisily cge_shock UI, elements(nosuch) value(2)
assert _rc == 111
cge_equation, clear
