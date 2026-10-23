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

* ---------------------------------------------------------------------
* 6. User sets and parameters (version 0.7.1)
* ---------------------------------------------------------------------
* The largest relative difference between two simulations, leaving out the
* variables named after them
capture program drop _usdiff
program define _usdiff, rclass
    gettoken a 0 : 0
    gettoken b skip : 0
    tempfile ta
    quietly cge_results, sim(`a') clear nodisplay
    quietly rename value va
    quietly save `ta'
    quietly cge_results, sim(`b') clear nodisplay
    quietly merge 1:1 variable element1 element2 using `ta', keepusing(va)
    quietly generate double d = abs(va - value) / max(1, abs(value))
    foreach s of local skip {
        quietly replace d = 0 if variable == "`s'"
    }
    quietly summarize d
    return scalar maxdiff = r(max)
end
local hltmap activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                            ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
quietly cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, `hltmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_set goods = c, except(com_ser com_hlt)
assert r(N_elements) == 2 & "`r(elements)'" == "com_agr com_man"
cge_set gh = goods com_hlt com_agr
assert r(N_elements) == 3 & "`r(elements)'" == "com_agr com_man com_hlt"
* sums over a user set equal the sums written out; a variable over a user set
cge_variable GG1 = sum(goods, PQ(goods) * QG(goods)), nominal
cge_variable GG2 = PQ(com_agr) * QG(com_agr) + PQ(com_man) * QG(com_man), nominal
cge_variable PG(goods) = PQ(goods) / CPI
assert r(N_elements) == 2
cge_variable PGH = sum(gh, sum(gh2, PQ(gh) * PQ(gh2)))
* user parameters: a scalar, by commodity, over a user set, with two indexes
cge_parameter hgoal = 1.1
assert r(N_elements) == 1
cge_parameter w(c), values(com_agr:0.4 com_man:0.3 com_ser:0.2 com_hlt:0.1)
assert r(N_elements) == 4
cge_parameter wg(goods), values(com_agr:2) default(1)
cge_parameter sh(c,h), values(com_hlt.hhd:0.5) default(0.1)
assert r(N_elements) == 4
cge_variable PIDX = sum(c, w(c) * PQ(c))
cge_variable PIDX2 = sum(goods, wg(goods) * PQ(goods)) + sh(com_hlt, hhd) ^ 2 * PQ(com_hlt)
* the exact Jacobian with user sets and parameters
mata: _cge_jexall()
assert r(maxdiff) < 1e-6
cge_shock tm, value(0)
quietly cge_solve, name(us1) tolerance(1e-12)
mata: _cge_jexcheck(0, "us1")
assert r(maxdiff) < 1e-6
quietly cge_results, sim(us1) clear nodisplay
foreach v in GG1 GG2 PIDX PIDX2 PGH CPI {
    quietly summarize value if variable == "`v'"
    local `v' = r(mean)
}
foreach c in com_agr com_man com_ser com_hlt {
    quietly summarize value if variable == "PQ" & element1 == "`c'"
    local pq_`c' = r(mean)
}
assert reldif(`GG1', `GG2') < 1e-12
assert reldif(`PIDX', 0.4 * `pq_com_agr' + 0.3 * `pq_com_man' + 0.2 * `pq_com_ser' + 0.1 * `pq_com_hlt') < 1e-12
assert reldif(`PIDX2', 2 * `pq_com_agr' + `pq_com_man' + 0.25 * `pq_com_hlt') < 1e-12
assert reldif(`PGH', (`pq_com_agr' + `pq_com_man' + `pq_com_hlt') ^ 2) < 1e-12
quietly summarize value if variable == "PG" & element1 == "com_man"
assert reldif(r(mean), `pq_com_man' / `CPI') < 1e-12
* the parameters as data
preserve
quietly cge_parameters, clear
quietly count if parameter == "w"
assert r(N) == 4
quietly summarize value if parameter == "sh" & element1 == "com_hlt" & element2 == "hhd"
assert r(mean) == 0.5
restore

* A target that a user parameter sets, and a shock to it: with LAM fixed and
* government consumption adjusting, QG(com_hlt) = hgoal * base; hgoal 1.2 is
* the same as a 20 per cent rise in every government purchase
quietly cge_shock, reset
cge_variable LAM, value(1)
cge_equation lam: QG(com_hlt) = LAM * hgoal * base(QG(com_hlt))
quietly cge_closure, swap(LAM GADJ)
cge_shock hgoal, value(1.2)
quietly cge_solve, name(goal12) tolerance(1e-12)
* the same shock applied by continuation
quietly cge_solve, name(goal12s) tolerance(1e-12) steps(4)
assert r(steps) == 4
_usdiff goal12 goal12s
assert r(maxdiff) < 1e-9
tempfile su
quietly cge_save using "`su'", replace
quietly cge_closure, swap(none)
quietly cge_shock, reset
cge_shock qg, scale(1.2)
quietly cge_solve, name(qg12) tolerance(1e-12)
_usdiff goal12 qg12 LAM GADJ
assert r(maxdiff) < 1e-9
* saved and loaded with the model; the shock is part of the saved state
quietly cge_use using "`su'"
cge_parameter, list
assert r(N_parameters) == 4
cge_set, list
assert r(N_sets) == 2
quietly cge_solve, name(goal12u) tolerance(1e-12)
_usdiff goal12 goal12u
assert r(maxdiff) < 1e-12
* an element of a user parameter as an instrument: government savings at
* their base value, 1 in this SAM, need hgoal at its base level 1
quietly cge_shock, reset
cge_optimize, instruments(hgoal) targets(government savings = 1) name(opthg)
assert r(converged) == 1
assert abs(el(r(instruments), 1, 1) - 1) < 1e-8
* calibration again keeps the sets and the base values of the parameters
cge_shock hgoal, value(1.5)
quietly cge_closure, swap(none)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_parameter, list
assert r(N_parameters) == 4
preserve
quietly cge_parameters, clear current
quietly summarize value if parameter == "hgoal"
assert r(mean) == 1.1
restore
* the GAMS program declares the parameters and the scenario changes them
quietly cge_closure, swap(LAM GADJ)
cge_shock hgoal, value(1.2)
quietly cge_solve, name(goal12g) tolerance(1e-12)
tempfile gd
cge_gams using "`gd'_p", sim(goal12g) replace
mata:
u = cat(st_local("gd") + "_p/cge_user.inc")
s = cat(st_local("gd") + "_p/cge_shock_par.inc")
st_numscalar("okp", sum(u :== "parameter UP_hgoal;") + sum(u :== "UP_hgoal = 1.1;") +
             sum(u :== "parameter UP_sh(*, *);") + sum(u :== "UP_sh('com_hlt', 'hhd') = 0.5;") +
             sum(strpos(u, "U_PIDX =e= ( ( UP_w('com_agr') * PQ('com_agr') ) +") :> 0) +
             sum(strpos(s, "UP_hgoal = ") :== 1))
end
assert scalar(okp) == 6
* errors
capture noisily cge_set goods = com_agr
assert _rc == 110
capture noisily cge_set c2 = com_agr
assert _rc == 198
capture noisily cge_set xx = nosuch
assert _rc == 111
capture noisily cge_parameter com_agr = 1
assert _rc == 110
capture noisily cge_parameter zz(c), values(nosuch:1)
assert _rc == 111
capture noisily cge_parameter zz(q), values(com_agr:1)
assert _rc == 198
capture noisily cge_parameter zz(c) = abc
assert _rc == 198
capture noisily cge_variable YY = w(com_agr, hhd)
assert _rc == 198
capture noisily cge_variable YY = sum(gods, PQ(gods))
assert _rc == 198
capture noisily cge_shock w, elements(nosuch) value(1)
assert _rc == 111
capture noisily cge_parameter, clear
assert _rc == 459
capture noisily cge_set, clear
assert _rc == 459
quietly cge_closure, swap(none)
cge_equation, clear
cge_parameter, clear
cge_set, clear
cge_parameter, list
assert r(N_parameters) == 0

* ---------------------------------------------------------------------
* 7. Conditional domains (version 0.7.2): conditions on sums, terms and the
* domains of variables and equations, evaluated at the base
* ---------------------------------------------------------------------
quietly cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, `hltmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
* the scenario without user variables, for comparison
cge_shock tm, value(0)
quietly cge_solve, name(cd0) tolerance(1e-12)
quietly cge_shock, reset
cge_set goods = c, except(com_ser com_hlt)
cge_parameter thr = 0
* in this SAM only com_agr and com_man carry an import tariff
cge_variable MT = sum(c$(tm(c) > thr), PM(c) * QM(c)), nominal
cge_variable MT2 = sum(c, (PM(c) * QM(c))$(tm(c) > 0)), nominal
cge_variable MT3 = PM(com_agr) * QM(com_agr) + PM(com_man) * QM(com_man), nominal
cge_variable GG = sum(c$(goods(c)), PQ(c) * QG(c))
cge_variable GG2 = sum(goods, PQ(goods) * QG(goods))
* logical operators, ord() and sameas(); an inner condition on the outer index
cge_variable GH = sum(c$(goods(c) & !(tm(c) <= 0) | ord(c) == 4), PQ(c) * QG(c))
cge_variable GH2 = sum(c$(sameas(c, com_agr) | sameas(c, com_man) | sameas(c, com_hlt)), PQ(c) * QG(c))
cge_variable GH3 = sum(c$(ord(c) != 3), PQ(c) * QG(c))
cge_variable HA = sum(c, sum(h$(sameas(c, com_agr)), PQ(c) * QH(c, h)))
cge_variable HA2 = sum(h, PQ(com_agr) * QH(com_agr, h))
cge_variable OW = sum(c, ord(c) * PQ(c))
* a domain with a condition; a reference outside it is 0
cge_variable TMV(c)$(tm(c) > thr) = tm(c) * PM(c) * QM(c)
assert r(N_elements) == 2
cge_variable TOUT = TMV(com_ser) + 1
* an empty conditional sum is 0
cge_variable NONE = sum(c$(tm(c) > 5), PQ(c))
* an equation over a conditional domain, with a variable over the same domain
cge_variable LAMC(c)$(goods(c)), value(1)
cge_equation lc(c)$(goods(c) & base(QM(c)) > 0): QM(c) = LAMC(c) * base(QM(c))
assert r(N_elements) == 2
cge_equation, list
assert r(N_variables) == 15
mata: _cge_jexall()
assert r(maxdiff) < 1e-6
* the definitions hold in a scenario, and the model's solution is unchanged
cge_shock tm, value(0)
quietly cge_solve, name(cd1) tolerance(1e-12)
mata: _cge_jexcheck(0, "cd1")
assert r(maxdiff) < 1e-6
_usdiff cd1 cd0 MT MT2 MT3 GG GG2 GH GH2 GH3 HA HA2 OW TMV TOUT NONE LAMC
assert r(maxdiff) < 1e-9
quietly cge_results, sim(cd1) clear nodisplay
foreach v in MT MT2 MT3 GG GG2 GH GH2 GH3 HA HA2 OW TOUT NONE {
    quietly summarize value if variable == "`v'"
    assert r(N) == 1
    local `v' = r(mean)
}
foreach c in com_agr com_man com_ser com_hlt {
    quietly summarize value if variable == "PQ" & element1 == "`c'"
    local pq_`c' = r(mean)
    quietly summarize value if variable == "QG" & element1 == "`c'"
    local qg_`c' = r(mean)
}
assert reldif(`MT', `MT3') < 1e-12 & reldif(`MT2', `MT3') < 1e-12
assert reldif(`GG', `GG2') < 1e-12
assert reldif(`GH', `GG' + `pq_com_hlt' * `qg_com_hlt') < 1e-12
assert reldif(`GH2', `GH') < 1e-12 & reldif(`GH3', `GH') < 1e-12
assert reldif(`HA', `HA2') < 1e-12
assert reldif(`OW', `pq_com_agr' + 2 * `pq_com_man' + 3 * `pq_com_ser' + 4 * `pq_com_hlt') < 1e-12
assert `TOUT' == 1 & `NONE' == 0
* only the elements in a domain are in the results
quietly count if variable == "TMV"
assert r(N) == 2
quietly count if variable == "TMV" & inlist(element1, "com_agr", "com_man")
assert r(N) == 2
quietly summarize value if variable == "TMV"
assert r(max) == 0
foreach c in com_agr com_man {
    quietly summarize value if variable == "QM" & element1 == "`c'"
    local qm = r(mean)
    quietly summarize base if variable == "QM" & element1 == "`c'"
    local qm0 = r(mean)
    quietly summarize value if variable == "LAMC" & element1 == "`c'"
    assert reldif(r(mean), `qm' / `qm0') < 1e-12
}
* a condition uses the base value of a parameter: a shock to thr leaves the
* domains and the sums as they were
cge_shock thr, value(1)
quietly cge_solve, name(cd2) tolerance(1e-12)
_usdiff cd1 cd2
assert r(maxdiff) < 1e-12
* saved and loaded with the model
tempfile cdm
quietly cge_save using "`cdm'", replace
quietly cge_use using "`cdm'"
quietly cge_solve, name(cd1u) tolerance(1e-12)
_usdiff cd1 cd1u
assert r(maxdiff) < 1e-12
* calibrating again keeps the conditions
quietly cge_calibrate, sigmava(0.5) sigmaq(2) sigmat(2)
cge_equation, list
assert r(N_variables) == 15
cge_shock tm, value(0)
quietly cge_solve, name(cd3) tolerance(1e-12)
quietly cge_results, sim(cd3) clear nodisplay
quietly count if variable == "TMV"
assert r(N) == 2
quietly summarize value if variable == "MT"
local mt = r(mean)
quietly summarize value if variable == "MT3"
assert reldif(`mt', r(mean)) < 1e-12
* the GAMS program writes out only the elements whose condition holds
tempfile gc
cge_gams using "`gc'_c", sim(cd3) replace
mata:
u = cat(st_local("gc") + "_c/cge_user.inc")
u2 = select(u, (strpos(u, "U_MT =e=") :> 0) :| (strpos(u, "U_TMV") :> 0))
u2
end
* errors
capture noisily cge_variable XX = sum(c, PQ(c) * (tm(c) > 0))
assert _rc == 198
capture noisily cge_variable XX = sum(c$(c == 1), PQ(c))
assert _rc == 198
capture noisily cge_variable XX = sum(c$(sameas(c, nosuch)), PQ(c))
assert _rc == 111
capture noisily cge_variable XX = sum(c$(goods(nosuch)), PQ(c))
assert _rc == 111
capture noisily cge_variable XX = sum(c$, PQ(c))
assert _rc == 198
capture noisily cge_variable XX = sum(c$(1 / tm(c) > 0), PQ(c))
assert _rc == 459
capture noisily cge_variable XX(c)$(tm(c) > 5) = PQ(c)
assert _rc == 459
capture noisily cge_equation xx(c)$(tm(c) > 5): PQ(c) = 1
assert _rc == 459
capture noisily cge_variable XX$(tm(com_agr) > 0) = 1
assert _rc == 198
capture noisily cge_variable XX = ord(c)
assert _rc == 198
capture noisily cge_variable XX = sameas(com_agr, com_agr)
assert _rc == 198
capture noisily cge_variable XX = PQ(com_agr)$(QM(com_agr) > 0 | !)
assert _rc == 198
capture noisily cge_variable ord, value(1)
assert _rc == 198
cge_equation, list
assert r(N_variables) == 15
* a parameter that only conditions use is still in use, as is a set
capture noisily cge_set, clear
assert _rc == 459
capture noisily cge_parameter, clear
assert _rc == 459
cge_equation, clear
cge_parameter, clear
cge_set, clear
program drop _usdiff

* ---------------------------------------------------------------------
* 9. Inequalities paired with variables, exogenous user variables and bounds
*    of user variables (version 0.9.0)
* ---------------------------------------------------------------------
* The largest relative difference between two simulations over the model's
* own variables (user variables, named from U_ or _, left out)
capture program drop _ineqdiff
program define _ineqdiff, rclass
    args a b
    tempfile ta
    quietly cge_results, sim(`a') clear nodisplay
    quietly rename value va
    quietly save `ta'
    quietly cge_results, sim(`b') clear nodisplay
    quietly merge 1:1 variable element1 element2 using `ta', keep(match) nogenerate
    quietly generate double d = abs(va - value) / max(1, abs(value))
    quietly replace d = 0 if substr(variable, 1, 1) == "_" | inlist(variable, "PRF", "PRF2", "PRU", "FLOOR", "XF")
    quietly summarize d
    return scalar maxdiff = r(max)
end
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

* An import quota as a user inequality, paired with the import premium, is the
* constraint of cge_constraint
cge_constraint QM, elements(com_man) upper(1.02) scale
cge_shock tm, value(0)
quietly cge_solve, name(qa) tolerance(1e-12)
cge_constraint, clear
cge_equation quota: QM(com_man) =l= 1.02 * base(QM(com_man)), perp(RM(com_man))
assert r(N_elements) == 1 & r(N_constraints) == 1
quietly cge_solve, name(qb) tolerance(1e-12)
_ineqdiff qa qb
assert r(maxdiff) < 1e-9
quietly cge_results, sim(qb) clear nodisplay
quietly summarize value if variable == "RM" & element1 == "com_man"
assert r(mean) > 0.01
quietly summarize value if variable == "_S_quota"
assert abs(r(mean)) < 1e-9
* not binding when the tariffs double: the premium stays at zero
cge_shock, reset
cge_shock tm, scale(2)
quietly cge_solve, name(qc) tolerance(1e-12)
quietly cge_results, sim(qc) clear nodisplay
quietly summarize value if variable == "RM" & element1 == "com_man"
assert r(mean) == 0
quietly summarize value if variable == "_S_quota"
assert r(mean) > 0
cge_shock, reset
* the exact Jacobian with the inequality
mata: _cge_jexall()
assert r(maxdiff) < 1e-6
* cge_constraint, clear keeps it; the listing shows it as written
cge_constraint, clear
assert r(N_constraints) == 1
cge_equation, list
cge_equation, clear

* A capacity limit over a conditional domain, with an index, is the
* constraint of cge_constraint on the same element
cge_constraint QA, elements(act_man) upper(1.01) scale
cge_shock tm, value(0)
quietly cge_solve, name(ca) tolerance(1e-12)
cge_constraint, clear
cge_equation cap(a)$(sameas(a, act_man)): QA(a) <= 1.01 * base(QA(a)), perp(RA(a))
quietly cge_solve, name(cb) tolerance(1e-12)
_ineqdiff ca cb
assert r(maxdiff) < 1e-9
cge_shock, reset
cge_equation, clear

* A floor on government purchases of services, with GADJ adjusting: binding,
* GADJ = 1.1 / 0.9; not binding at 0.8, GADJ = 1
cge_equation gmin: QG(com_ser) >= 1.1 * base(QG(com_ser)), perp(GADJ)
cge_shock qg, elements(com_ser) scale(0.9)
quietly cge_solve, name(gm) tolerance(1e-12)
quietly cge_results, sim(gm) clear nodisplay
quietly summarize value if variable == "GADJ"
assert reldif(r(mean), 1.1 / 0.9) < 1e-10
quietly summarize value if variable == "QG" & element1 == "com_ser"
local qg1 = r(mean)
quietly summarize base if variable == "QG" & element1 == "com_ser"
assert reldif(`qg1', 1.1 * r(mean)) < 1e-10
cge_equation, clear
cge_equation gmin: QG(com_ser) >= 0.8 * base(QG(com_ser)), perp(GADJ)
quietly cge_solve, name(gm2) tolerance(1e-12)
quietly cge_results, sim(gm2) clear nodisplay
quietly summarize value if variable == "GADJ"
assert r(mean) == 1
cge_shock, reset
cge_equation, clear

* max and min through a paired exogenous variable and through bounds
cge_variable FLOOR, lower(0)
assert r(N_elements) == 1
cge_variable PRF = PQ(com_agr) / CPI + FLOOR
cge_equation pf: PRF >= 1.001, perp(FLOOR)
cge_variable PRF2 = PQ(com_agr) / CPI, lower(1.001)
cge_variable PRU = PQ(com_agr) / CPI, upper(0.999)
cge_shock tm, value(0)
quietly cge_solve, name(fl) tolerance(1e-12)
quietly cge_results, sim(fl) clear nodisplay
quietly summarize value if variable == "PQ" & element1 == "com_agr"
local pa = r(mean)
quietly summarize value if variable == "CPI"
local ra = `pa' / r(mean)
foreach v in FLOOR PRF PRF2 PRU {
    quietly summarize value if variable == "`v'"
    local `v' = r(mean)
}
assert reldif(`PRF', max(1.001, `ra')) < 1e-10 & reldif(`PRF2', max(1.001, `ra')) < 1e-10
assert reldif(`PRU', min(0.999, `ra')) < 1e-10
assert reldif(`FLOOR', max(0, 1.001 - `ra')) < 1e-9
* with the tariffs doubled the price is above the floor and below the ceiling
cge_shock, reset
cge_shock tm, scale(2)
quietly cge_solve, name(fl2) tolerance(1e-12)
quietly cge_results, sim(fl2) clear nodisplay
quietly summarize value if variable == "PQ" & element1 == "com_agr"
local pa = r(mean)
quietly summarize value if variable == "CPI"
local ra = `pa' / r(mean)
foreach v in FLOOR PRF2 PRU {
    quietly summarize value if variable == "`v'"
    local `v' = r(mean)
}
assert reldif(`PRF2', max(1.001, `ra')) < 1e-10 & reldif(`PRU', min(0.999, `ra')) < 1e-10
assert `FLOOR' == 0 | reldif(`FLOOR', max(0, 1.001 - `ra')) < 1e-9
cge_shock, reset
mata: _cge_jexall()
assert r(maxdiff) < 1e-6

* An exogenous user variable takes its value, and a shock changes it
cge_variable XF, value(2) fixed
cge_variable XG = 3 * XF
cge_shock XF, value(4)
quietly cge_solve, name(xf) tolerance(1e-12)
quietly cge_results, sim(xf) clear nodisplay
quietly summarize value if variable == "XG"
assert reldif(r(mean), 12) < 1e-12
cge_shock, reset

* Saved and loaded, calibrated again, under another closure, and in a dynamic
* run, the inequalities and bounds are kept
cge_equation gmin: QG(com_ser) >= 1.1 * base(QG(com_ser)), perp(GADJ)
cge_shock qg, elements(com_ser) scale(0.9)
quietly cge_solve, name(k1) tolerance(1e-12)
tempfile sv
quietly cge_save using "`sv'", replace
quietly cge_use using "`sv'"
quietly cge_solve, name(k2) tolerance(1e-12)
_ineqdiff k1 k2
assert r(maxdiff) < 1e-12
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_constraint, list
assert r(N_constraints) == 4
cge_shock qg, elements(com_ser) scale(0.9)
quietly cge_solve, name(k3) tolerance(1e-12)
quietly cge_results, sim(k3) clear nodisplay
quietly summarize value if variable == "GADJ"
assert reldif(r(mean), 1.1 / 0.9) < 1e-10
quietly cge_closure, government(fixgsav direct)
cge_constraint, list
assert r(N_constraints) == 4
quietly cge_solve, name(k4) tolerance(1e-12)
quietly cge_results, sim(k4) clear nodisplay
quietly summarize value if variable == "GADJ"
assert reldif(r(mean), 1.1 / 0.9) < 1e-10
quietly cge_dynamic, name(kd) periods(0/2) capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02)
assert "`r(sims)'" == "kd0 kd1 kd2"
quietly cge_results, sim(kd2) clear nodisplay
quietly summarize value if variable == "QG" & element1 == "com_ser"
local q2 = r(mean)
quietly summarize base if variable == "QG" & element1 == "com_ser"
assert `q2' >= 1.1 * r(mean) * (1 - 1e-9)

* The GAMS program: the exogenous user variable fixed, the inequality's slack
* defined and paired with GADJ
tempfile gi
cge_gams using "`gi'_i", sim(k4) replace
mata:
u = cat(st_local("gi") + "_i/cge_user.inc")
c = cat(st_local("gi") + "_i/cge_constraints.inc")
st_numscalar("oki", sum(u :== "U_FLOOR.fx = 0;") + sum(u :== "variable U__S_gmin;") +
             (sum(strpos(c, "U__S_gmin") :> 0) >= 1) + (sum(strpos(c, "GADJ") :> 0) >= 1))
end
assert scalar(oki) == 4
cge_shock, reset
quietly cge_closure, government(flexgsav)

* Errors
capture noisily cge_equation bad: QG(com_ser) >= 1
assert _rc == 198
capture noisily cge_equation bad: QG(com_ser) >= 1, perp(PQ(com_agr))
assert _rc == 459
capture noisily cge_equation bad: QG(com_ser) >= 1, perp(NOSUCH)
assert _rc == 111
capture noisily cge_equation bad(c): QM(c) <= base(QM(c)), perp(RA(a))
assert _rc == 198
capture noisily cge_equation bad: QG(com_ser) = 1, perp(GADJ)
assert _rc == 198
capture noisily cge_variable XX, lower(0) upper(1)
assert _rc == 198
capture noisily cge_variable XX = PQ(com_agr), fixed
assert _rc == 198
capture noisily cge_variable _XX = 1
assert _rc == 198
capture noisily cge_variable XX <= 1
assert _rc == 198
quietly cge_closure, swap(none)
cge_equation, clear
cge_constraint, list
assert r(N_constraints) == 0
program drop _ineqdiff

* ---------------------------------------------------------------------
* 10. Two indexes and sets of pairs (version 0.9.1)
* ---------------------------------------------------------------------
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)                ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
* variables with two indexes, and sums over two indexes and over a set of pairs
cge_variable X(c,h) = PQ(c) * QH(c, h), nominal
assert r(N_elements) == 6
cge_variable XS = sum((c,h), X(c,h)), nominal
cge_variable XS2 = sum(c, sum(h, PQ(c) * QH(c, h))), nominal
cge_set map(a,c) = act_agr.com_agr act_man.com_man
assert r(N_elements) == 2
cge_variable VM = sum(map(a,c), PA(a) * QA(a) + PQ(c) * QG(c))
cge_variable VM2 = PA(act_agr) * QA(act_agr) + PQ(com_agr) * QG(com_agr) + PA(act_man) * QA(act_man) + PQ(com_man) * QG(com_man)
cge_variable VMH = sum(map(a,c)$(sameas(a, act_man)), PA(a) * QA(a))
* a domain of pairs, and an equation with two indexes over a conditional domain
cge_variable Y(a,c)$(map(a,c)) = PA(a) / PQ(c)
assert r(N_elements) == 2
cge_variable LH(c,h)$(base(QH(c, h)) > 0), value(1)
cge_equation lh(c,h)$(base(QH(c, h)) > 0): QH(c, h) = LH(c,h) * base(QH(c, h))
assert r(N_elements) == 4
* an exogenous variable with two indexes, and an inequality paired with it,
* element by element: PH2 = max(1, PQ(c))
cge_variable FX(c,h), value(1) fixed
cge_variable FY = sum((c,h), FX(c,h))
cge_variable FL(c,h), lower(0)
cge_variable PH2(c,h) = PQ(c) + FL(c,h)
cge_equation fl(c,h): PH2(c,h) >= 1, perp(FL(c,h))
assert r(N_elements) == 6
mata: _cge_jexall()
assert r(maxdiff) < 1e-6
cge_shock tm, value(0)
cge_shock FX, elements(com_agr.hhd) value(2)
quietly cge_solve, name(t2) tolerance(1e-12)
quietly cge_results, sim(t2) clear nodisplay
foreach v in XS XS2 VM VM2 VMH FY {
    quietly summarize value if variable == "`v'"
    assert r(N) == 1
    local `v' = r(mean)
}
assert reldif(`XS', `XS2') < 1e-12 & reldif(`VM', `VM2') < 1e-12 & `FY' == 7
quietly summarize value if variable == "PA" & element1 == "act_man"
local pam = r(mean)
quietly summarize value if variable == "QA" & element1 == "act_man"
assert reldif(`VMH', `pam' * r(mean)) < 1e-12
quietly count if variable == "Y"
assert r(N) == 2
quietly count if variable == "LH"
assert r(N) == 4
foreach c in com_agr com_man com_ser {
    quietly summarize value if variable == "PQ" & element1 == "`c'"
    local pq = r(mean)
    foreach h in hhd npi {
        * a household good with no flow is not in the results
        quietly summarize value if variable == "QH" & element1 == "`c'" & element2 == "`h'"
        local qh = cond(r(N), r(mean), 0)
        quietly summarize base if variable == "QH" & element1 == "`c'" & element2 == "`h'"
        local qh0 = cond(r(N), r(mean), 0)
        quietly summarize value if variable == "X" & element1 == "`c'" & element2 == "`h'"
        assert reldif(r(mean), `pq' * `qh') < 1e-12
        quietly summarize value if variable == "PH2" & element1 == "`c'" & element2 == "`h'"
        assert reldif(r(mean), max(1, `pq')) < 1e-10
        if `qh0' > 0 {
            quietly summarize value if variable == "LH" & element1 == "`c'" & element2 == "`h'"
            assert reldif(r(mean), `qh' / `qh0') < 1e-12
        }
    }
}
cge_shock, reset
* saved, loaded and calibrated again, they stay
tempfile s2
quietly cge_save using "`s2'", replace
quietly cge_use using "`s2'"
cge_set, list
assert r(N_sets) == 1
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_equation, list
assert r(N_equations) >= 20
* the GAMS program declares a variable with two indexes over pairs of labels
tempfile g2
cge_shock tm, value(0)
quietly cge_solve, name(t3) tolerance(1e-12)
cge_gams using "`g2'_t", sim(t3) replace
mata:
u = cat(st_local("g2") + "_t/cge_user.inc")
st_numscalar("ok2", sum(u :== "variable U_X(AC, AC);") + (sum(strpos(u, "U_X.l('com_agr', 'hhd')") :> 0) == 1) +
             sum(u :== "U_FX.fx('com_agr', 'hhd') = 1;"))
end
assert scalar(ok2) == 3
cge_shock, reset
* errors
capture noisily cge_variable XX(c,c) = PQ(c)
assert _rc == 198
capture noisily cge_variable XX(map) = 1
assert _rc == 198
capture noisily cge_set bad(a,c) = act_agr.com_xx
assert _rc == 111
capture noisily cge_set bad(a,c) = act_agr
assert _rc == 198
capture noisily cge_variable XX = X(com_agr)
assert _rc == 198
capture noisily cge_set, clear
assert _rc == 459
quietly cge_closure, swap(none)
cge_equation, clear
cge_set, clear

* ---------------------------------------------------------------------
* 11. Lags (version 0.9.2)
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)              ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
* changes from the period before, one and two periods back, and government
* purchases that adjust halfway to revenue each period
cge_variable DQA(a) = QA(a) - lag(QA(a))
cge_variable D2 = QA(act_man) - lag(QA(act_man), 2)
cge_variable GL, value(1)
cge_equation gl: GL = 0.5 * lag(GL) + 0.5 * YG / base(YG)
cge_variable LAMG, value(1)
cge_equation lamg: GADJ = LAMG * GL
quietly cge_closure, swap(LAMG GADJ)
mata: _cge_jexall()
assert r(maxdiff) < 1e-6
* a static simulation: the period before is the base
cge_shock tm, value(0)
quietly cge_solve, name(lst) tolerance(1e-12)
quietly cge_results, sim(lst) clear nodisplay
foreach a in act_agr act_man act_ser {
    quietly summarize value if variable == "QA" & element1 == "`a'"
    local qa = r(mean)
    quietly summarize base if variable == "QA" & element1 == "`a'"
    local qa0 = r(mean)
    quietly summarize value if variable == "DQA" & element1 == "`a'"
    assert abs(r(mean) - (`qa' - `qa0')) < 1e-10
    if "`a'" == "act_man" {
        quietly summarize value if variable == "D2"
        assert abs(r(mean) - (`qa' - `qa0')) < 1e-10
    }
}
quietly summarize value if variable == "YG"
local yg = r(mean)
quietly summarize base if variable == "YG"
local yg0 = r(mean)
quietly summarize value if variable == "GL"
assert reldif(r(mean), 0.5 + 0.5 * `yg' / `yg0') < 1e-12
local gl = r(mean)
quietly summarize value if variable == "GADJ"
assert reldif(r(mean), `gl') < 1e-12
cge_shock, reset
* a dynamic run: the values of the periods before, the base before the first
quietly cge_dynamic, name(lg) periods(0/4) capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02) tfp(0.01)
quietly cge_dynresults, run(lg) clear
keep if inlist(variable, "QA", "DQA", "D2", "GL", "GADJ", "YG")
keep period variable element1 base value
quietly reshape wide value, i(variable element1) j(period)
forvalues t = 0/4 {
    local t1 = `t' - 1
    local t2 = `t' - 2
    local l1 = cond(`t' >= 1, "value`t1'", "base")
    local l2 = cond(`t' >= 2, "value`t2'", "base")
    foreach a in act_agr act_man act_ser {
        quietly summarize value`t' if variable == "QA" & element1 == "`a'"
        local qa = r(mean)
        quietly summarize `l1' if variable == "QA" & element1 == "`a'"
        local qa1 = r(mean)
        quietly summarize `l2' if variable == "QA" & element1 == "`a'"
        local qa2 = r(mean)
        quietly summarize value`t' if variable == "DQA" & element1 == "`a'"
        assert abs(r(mean) - (`qa' - `qa1')) < 1e-9
        if "`a'" == "act_man" {
            quietly summarize value`t' if variable == "D2"
            assert abs(r(mean) - (`qa' - `qa2')) < 1e-9
        }
    }
    quietly summarize value`t' if variable == "YG"
    local yg = r(mean)
    quietly summarize `l1' if variable == "GL"
    local gl1 = r(mean)
    quietly summarize value`t' if variable == "GL"
    assert reldif(r(mean), 0.5 * `gl1' + 0.5 * `yg' / `yg0') < 1e-12
    local gl = r(mean)
    quietly summarize value`t' if variable == "GADJ"
    assert reldif(r(mean), `gl') < 1e-12
}
* the lags change the path: government purchases follow revenue with a delay
quietly summarize value4 if variable == "GL"
local gl4 = r(mean)
quietly summarize value4 if variable == "YG"
assert abs(`gl4' - r(mean) / `yg0') > 1e-4
* saved and loaded with the run; the lagged values stay with each period
tempfile s3
quietly cge_save using "`s3'", replace
quietly cge_use using "`s3'"
capture mata: mata drop _cge_test_xlag()
mata:
real matrix _cge_test_xlag(string scalar sim)
{
    struct cge_model scalar M
    M = _cge_load()
    // the lagged values less the base
    return(M.simp[_cge_sim_index(M, sim)].xlag :- M.x0)
}
end
mata: st_numscalar("nl", cols(_cge_test_xlag("lg3")) + all(_cge_test_xlag("lg0") :== 0) + any(_cge_test_xlag("lg3") :!= 0))
assert scalar(nl) == 6
quietly cge_dynresults, run(lg) clear
quietly summarize value if variable == "GL" & period == 4
assert reldif(r(mean), `gl4') < 1e-14
* the GAMS program holds each period's lagged values as parameters
tempfile g3
cge_gams using "`g3'_d", dynamic(lg) replace
mata:
u = cat(st_local("g3") + "_d/cge_user.inc")
u2 = cat(st_local("g3") + "_d/cge_lg2_par.inc")
// the value two periods before changes from period 3, the first after period 0
u3 = cat(st_local("g3") + "_d/cge_lg3_par.inc")
st_numscalar("ok3", sum(u :== "parameter LAG1_U_GL;") + sum(u :== "parameter LAG2_QA(*);") + sum(u :== "LAG1_U_GL = 1;") +
             (sum(strpos(u, "LAG1_U_GL") :> 0) == 3) + (sum(strpos(u2, "LAG1_U_GL = ") :== 1) == 1) +
             (sum(strpos(u2, "LAG2_QA('act_man') = ") :== 1) == 0) + (sum(strpos(u3, "LAG2_QA('act_man') = ") :== 1) == 1))
end
assert scalar(ok3) == 7
* the model is calibrated again with its lags
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_equation, list
assert r(N_equations) == 6
* errors
capture noisily cge_variable XL = lag(tm(com_agr))
assert _rc == 198
capture noisily cge_variable XL = lag(QA(act_agr), 5)
assert _rc == 198
capture noisily cge_variable XL = lag(QA(act_agr), 0)
assert _rc == 198
capture noisily cge_variable XL = lag(QA(act_xx))
assert _rc == 111
capture noisily cge_variable XL = lag()
assert _rc == 198
capture noisily cge_variable XL = 1 + 0 * lag(XL)
assert _rc == 198
capture noisily cge_variable lag, value(1)
assert _rc == 198
quietly cge_closure, swap(none)
cge_equation, clear

* ---------------------------------------------------------------------
* 12. Replacing built-in equations (version 0.9.3)
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)              ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
quietly cge_solve, name(ref) tolerance(1e-12)
cge_shock, reset
capture mata: mata drop _cge_test_simdiff()
mata:
// The largest relative difference between two simulations in the model's
// own variables
real scalar _cge_test_simdiff(string scalar a, string scalar b)
{
    struct cge_model scalar M
    real colvector x, y
    real scalar n
    M = _cge_load()
    n = (M.nuv ? M.voff[rows(M.vname) - M.nuv + 1] : rows(M.x0))
    x = M.simx[|1, _cge_sim_index(M, a) \ n, _cge_sim_index(M, a)|]
    y = M.simx[|1, _cge_sim_index(M, b) \ n, _cge_sim_index(M, b)|]
    return(max(abs(x - y) :/ rowmax((J(n, 1, 1), abs(y)))))
}
end
* the same equations written by the user, for every element of a block and
* for the cells of one activity in a block with two indexes: the solution is
* unchanged, which also checks which elements are replaced
cge_equation g7(c): QG(c) = qg(c) * GADJ, replace(I7)
assert r(N_elements) == 3
cge_equation q5(c,a)$(sameas(a, act_man) & base(QINT(c, a)) > 0): QINT(c, a) = base(QINT(c, a)) / base(QINTA(a)) * QINTA(a), replace(Q5)
assert r(N_elements) == 3
mata: _cge_jexall()
assert r(maxdiff) < 1e-6
cge_shock tm, value(0)
quietly cge_solve, name(same) tolerance(1e-12)
mata: st_numscalar("d", _cge_test_simdiff("same", "ref"))
assert scalar(d) < 1e-10
* transposed indexes do not match the block's domain
cge_shock, reset
cge_equation, clear
capture noisily cge_equation q5t(a,c): QINT(c, a) = QINT(c, a), replace(Q5)
assert _rc == 198
* other rules: government purchases of services 10 per cent above the base,
* the others scaled by GADJ, and exports of agricultural goods at the base
cge_equation gs: QG(com_ser) = 1.1 * base(QG(com_ser)), replace(I7(com_ser))
cge_equation qe: QE(com_agr) = base(QE(com_agr)), replace(T2(com_agr))
cge_equation, list
assert r(N_equations) == 2
cge_shock tm, value(0)
quietly cge_solve, name(rep) tolerance(1e-12)
quietly cge_results, sim(rep) clear nodisplay
quietly summarize value if variable == "GADJ"
* GADJ is fixed in the default closure
local gadj = r(mean)
foreach c in com_agr com_man com_ser {
    quietly summarize value if variable == "QG" & element1 == "`c'"
    local qg = r(mean)
    quietly summarize base if variable == "QG" & element1 == "`c'"
    if "`c'" == "com_ser" assert reldif(`qg', 1.1 * r(mean)) < 1e-12
    else assert reldif(`qg', `gadj' * r(mean)) < 1e-12
}
quietly summarize value if variable == "QE" & element1 == "com_agr"
local qe = r(mean)
quietly summarize base if variable == "QE" & element1 == "com_agr"
assert reldif(`qe', r(mean)) < 1e-12
quietly summarize value if variable == "QE" & element1 == "com_man"
local qe = r(mean)
quietly summarize base if variable == "QE" & element1 == "com_man"
assert reldif(`qe', r(mean)) > 1e-4
quietly summarize value if variable == "WALRAS"
assert abs(r(mean)) < 1e-8
* the replaced elements are left out of the system; it stays square
quietly cge_check, sim(rep)
* saved, loaded and calibrated again, the replacements stay
tempfile s4
quietly cge_save using "`s4'", replace
quietly cge_use using "`s4'"
quietly cge_solve, name(rep2) tolerance(1e-12)
mata: st_numscalar("d", _cge_test_simdiff("rep2", "rep"))
assert scalar(d) < 1e-10
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
quietly cge_solve, name(rep3) tolerance(1e-12)
quietly cge_results, sim(rep3) clear nodisplay
quietly summarize value if variable == "QG" & element1 == "com_ser"
local qg = r(mean)
quietly summarize base if variable == "QG" & element1 == "com_ser"
assert reldif(`qg', 1.1 * r(mean)) < 1e-12
* a dynamic run with the replacements
cge_shock, reset
quietly cge_dynamic, name(rd) periods(0/2) capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02)
quietly cge_dynresults, run(rd) clear
quietly summarize value if variable == "QE" & element1 == "com_agr" & period == 2
local qe = r(mean)
quietly summarize base if variable == "QE" & element1 == "com_agr" & period == 2
assert reldif(`qe', r(mean)) < 1e-12
* the GAMS program leaves the replaced elements out of cge_model.gms
tempfile g4
cge_shock tm, value(0)
quietly cge_solve, name(rep4) tolerance(1e-12)
cge_gams using "`g4'_r", sim(rep4) replace
mata:
u = cat(st_local("g4") + "_r/cge_user.inc")
g = cat(st_local("g4") + "_r/cge_model.gms")
st_numscalar("ok4", sum(u :== "XRP('I7', 'com_ser', '0') = 1;") + sum(u :== "XRP('T2', 'com_agr', '0') = 1;") +
             (sum(strpos(g, "not XRP('I7', C, '0')") :> 0) == 1))
end
assert scalar(ok4) == 3
cge_shock, reset
* errors
capture noisily cge_equation e1: QQ(com_ser) = 1, replace(S2(com_ser))
assert _rc == 198
capture noisily cge_equation e1: QG(com_ser) = 1, replace(XX)
assert _rc == 198
capture noisily cge_equation e1(f): QF(f, act_agr) = 1, replace(I7)
assert _rc == 198
capture noisily cge_equation e1: QG(com_ser) = 1, replace(I7)
assert _rc == 198
capture noisily cge_equation e1: QG(com_ser) = 1, replace(I7(com_xx))
assert _rc == 111
capture noisily cge_equation e1: QG(com_ser) = 2, replace(I7(com_ser))
assert _rc == 459
capture noisily cge_equation e1: QQ(com_man) = 1, replace(T6(com_man))
assert _rc == 459
capture noisily cge_equation e1: QG(com_man) <= 1, perp(GADJ) replace(I7(com_man))
assert _rc == 198
cge_equation, clear
