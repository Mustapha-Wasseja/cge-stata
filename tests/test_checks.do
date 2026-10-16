* test_checks.do -- validation checks, closures and error handling
* (docs/model_spec.md, Sections 6 and 8)

version 13.0
quietly do setup_synthetic.do

* Checks on a simulation, with homogeneity and a perturbed start
cge_shock tm, value(0)
quietly cge_solve, name(notariff)
cge_check, homogeneity perturb(0.1)
assert r(failures) == 0

* The grouped Jacobian (version 0.1.9) equals the column-by-column one, also
* with a tariff on com_ser, which pays none in the base, and another closure
quietly do setup_synthetic.do
cge_shock tm, elements(com_ser) value(0.1)
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6 & r(groups) < r(columns)
quietly cge_closure, external(fixexr) savinv(investment) factors(cap:specific)
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
quietly do setup_synthetic.do
cge_shock tm, value(0)
quietly cge_solve, name(notariff)

* The fallback solver: with no Newton iterations allowed, Powell's hybrid method
* (solvenl, at most three extra arguments in Stata 13) must find the solution
quietly do setup_synthetic.do
cge_shock tm, value(0)
cge_solve, name(fallback) iterate(0) tolerance(1e-6)
assert r(converged) == 1 & "`r(method)'" == "broydenpowell"
quietly cge_results, sim(fallback) clear nodisplay
tempfile fallback
quietly save `fallback'
quietly do setup_synthetic.do
cge_shock tm, value(0)
quietly cge_solve, name(newton)
quietly cge_results, sim(newton) clear nodisplay
rename value newton
quietly merge 1:1 variable element1 element2 using `fallback', assert(match) nogenerate
quietly generate double reldiff = abs(value - newton) / max(1, abs(newton))
quietly summarize reldiff
display "fallback against Newton: largest relative difference " %9.2e r(max)
assert r(max) < 1e-4

* Every closure is square and reproduces the base without iterating
cge_shock, reset
local n = 0
foreach ext in flexexr fixexr {
    foreach gov in flexgsav fixgsav {
        foreach si in savings investment {
            foreach num in cpi dpi {
                foreach fac in "lab:mobile" "lab:unemployed" "cap:specific" ///
                    "lab:unemployed cap:specific" {
                    quietly cge_closure, external(`ext') government(`gov') ///
                        savinv(`si') numeraire(`num') factors(`fac')
                    quietly cge_solve, name(closure_check)
                    assert r(converged) == 1 & r(iterations) == 0
                    local ++n
                }
            }
        }
    }
}
assert `n' == 64

* Alternative closures adjust the intended variable
quietly cge_closure, external(fixexr) government(flexgsav) savinv(savings) ///
    numeraire(cpi) factors(lab:mobile)
cge_shock tm, value(0)
quietly cge_solve, name(fixexr)
quietly cge_results, sim(fixexr) clear nodisplay
assert value == 1 if variable == "EXR"
assert value > base if variable == "FSAV"

quietly do setup_synthetic.do
quietly cge_closure, government(fixgsav)
cge_shock tm, value(0)
quietly cge_solve, name(fixgsav)
quietly cge_results, sim(fixgsav) clear nodisplay
assert abs(value - base) < 1e-9 if variable == "GSAV"
assert value > 1 if variable == "TINSADJ"

quietly do setup_synthetic.do
quietly cge_closure, savinv(investment)
cge_shock FSAV, scale(0.8)
quietly cge_solve, name(invdriven)
quietly cge_results, sim(invdriven) clear nodisplay
assert value == 1 if variable == "IADJ"
assert value > 1 if variable == "MPSADJ"

quietly do setup_synthetic.do
quietly cge_closure, factors(lab:unemployed)
cge_shock ad, elements(act_agr) scale(1.05)
quietly cge_solve, name(unemployed)
quietly cge_results, sim(unemployed) clear nodisplay
assert value == 1 if variable == "W" & element1 == "lab"
assert abs(value - base) > 1e-6 if variable == "QFS" & element1 == "lab"

quietly do setup_synthetic.do
quietly cge_closure, factors(cap:specific)
cge_shock QFS, elements(lab) scale(1.05)
quietly cge_solve, name(specific)
quietly cge_results, sim(specific) clear nodisplay
assert abs(value - base) < 1e-9 if variable == "QF" & element1 == "cap"
quietly summarize value if variable == "WFDIST" & element1 == "cap"
assert r(max) - r(min) > 1e-6

* Factor quantities: average wages and wage distortions differ from one
matrix fq = (80, 20, 30 \ 37, 40, 50)
cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) fquantities(fq)
assert r(max_residual) < 1e-12
quietly cge_solve, name(fqbase)
assert r(iterations) == 0
quietly cge_results, sim(fqbase) clear nodisplay
assert abs(base - 135 / 130) < 1e-12 if variable == "W" & element1 == "lab"

* Tiny export share with a low CET elasticity: exports of com_agr cut to 1e-4
* (the rest goes to households, financed by foreign savings), so the CET share
* of exports is 1 - 1e-12 and 1 - delta must not be computed by subtraction
cge_synthetic, clear
quietly recast double hhd row
quietly replace hhd = hhd + (20 - 1e-4) in 4
quietly replace row = row - (20 - 1e-4) in 4
quietly replace hhd = hhd - (20 - 1e-4) in 14
quietly replace row = row + (20 - 1e-4) in 14
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(0.5)
assert r(max_residual) < 1e-12
quietly cge_solve, name(tinyexport)
assert r(iterations) == 0

* The checks do not depend on the SAM's units: the same SAM in units a million
* times smaller passes them (WALRAS, zero in the base, is measured against the
* largest SAM entry)
cge_synthetic, clear
foreach v of varlist _all {
    if "`v'" != "account" quietly replace `v' = `v' * 1e6
}
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_check, homogeneity perturb(0.1)
assert r(failures) == 0

* Supply-use layout (version 0.1.7): the label s-i becomes si; margin accounts,
* a commodity imported only and a stock-change account
quietly findfile cge_synthetic_sam_sut.csv
cge_sam using "`r(fn)'", labels(account) clear
assert account[17] == "si"
local sutopts activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser com_fuel) ///
    factors(lab cap) households(hhd) government(gov) savinv(si) row(row)                       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) marginaccounts(trd trp)
capture cge_map, `sutopts'
assert _rc == 459
quietly cge_map, `sutopts' stocks(dstk)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
assert r(max_residual) < 1e-12
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
cge_check, homogeneity perturb(0.1)
assert r(failures) == 0
cge_shock pwm, elements(com_fuel) scale(1.25)
quietly cge_solve, name(fuel25)
quietly cge_results, sim(fuel25) clear nodisplay
assert value > base if variable == "PQ" & element1 == "com_fuel"
assert value < base if variable == "QM" & element1 == "com_fuel"
quietly count if inlist(variable, "PX", "PD", "QX", "QD") & element1 == "com_fuel"
assert r(N) == 0
quietly count if variable == "QT"
assert r(N) == 2

* Exports drawn from composite supply (version 0.1.8): com_agr exports more than
* its output and com_fuel re-exports; a higher world price raises their exports
quietly count if variable == "QER"
assert r(N) == 2
quietly count if inlist(variable, "QE", "PE") & inlist(element1, "com_agr", "com_fuel")
assert r(N) == 0
cge_synthetic, clear sut
quietly cge_sam, labels(account)
quietly cge_map, `sutopts' stocks(dstk)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock pwe, elements(com_agr) scale(1.1)
quietly cge_solve, name(agr_pwe10)
cge_check
assert r(failures) == 0
quietly cge_results, sim(agr_pwe10) clear nodisplay
assert value > base if variable == "QER" & element1 == "com_agr"
assert value > base if variable == "QA" & element1 == "act_agr"

* A stock-change account may receive payments only from savings-investment
cge_synthetic, clear sut
quietly replace row = row + 1 in 18
quietly replace row = row - 1 in 17
quietly cge_sam, labels(account)
capture cge_map, `sutopts' stocks(dstk)
assert _rc == 459

* The grouped Jacobian on the other layouts, after a shock: enterprises and
* transfers abroad (institutions), margins netted out of an activity, the
* territorial correction, secondary production and a non-imported commodity
local base activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) government(gov) savinv(sav) row(row)                          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
foreach layout in institutions margins territorial multiproduct nonimported {
    local extra households(hhd)
    if "`layout'" == "institutions" local extra households(hhd npi) enterprises(ent)
    if "`layout'" == "margins" local extra households(hhd) margins(act_ser)
    if "`layout'" == "territorial" local extra households(hhd) territorial(com_tc act_tc)
    cge_synthetic, clear `layout'
    quietly cge_sam, labels(account)
    quietly cge_map, `base' `extra'
    quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
    quietly cge_shock FSAV, scale(0.8)
    quietly cge_shock tm, value(0.05)
    mata: _cge_jaccheck()
    assert r(maxdiff) < 1e-6
}

* ---------------------------------------------------------------------
* Errors
* ---------------------------------------------------------------------

* A valid label that does not match its variable
cge_synthetic, clear
quietly replace account = "savings" in 14
capture cge_sam, labels(account)
assert _rc == 459

* Each activity needs a paired commodity
cge_synthetic, clear
quietly cge_sam, labels(account)
capture cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
assert _rc == 198
local mapopts activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)              ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

* Unbalanced SAM
cge_synthetic, clear
quietly replace com_agr = com_agr + 1 in 1
quietly cge_sam, labels(account)
capture cge_map, `mapopts'
assert _rc == 459

* Flow the model does not represent: household pays the government directly.
* The report lists the problem cell.
cge_synthetic, clear
quietly replace hhd = hhd + 5 in 10
quietly replace hhd = hhd - 5 in 14
quietly replace gov = gov + 5 in 14
quietly cge_sam, labels(account)
tempfile report
capture cge_map, `mapopts' report("`report'") replace
assert _rc == 459
preserve
quietly import delimited using "`report'", varnames(1) stringcols(_all) clear
assert _N == 1
assert problem == "flow not represented" & paid_by == "hhd" & received_by == "gov"
assert real(value) == 5
restore

* Account with flows but no role
cge_synthetic, clear
quietly cge_sam, labels(account)
capture cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                 ///
    dirtax(tax_dir) saltax(tax_sal)
assert _rc == 459

* A different pairing is allowed from version 0.1.4: it only names primary
* commodities, and activities may produce any commodity
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_man com_agr com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                 ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
assert r(max_residual) < 1e-12

* Cobb-Douglas Armington function is not available in version 0.1
quietly cge_map, `mapopts'
capture cge_calibrate, sigmava(0.8) sigmaq(1) sigmat(2)
assert _rc == 198

* National-accounts layout: amounts rewritten, and ambiguous or missing tax options
local naopts activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)
cge_synthetic, clear national
quietly cge_sam, labels(account)
cge_map, `naopts' dirtax(gov) saltax(gov) imptax(tax_imp)
assert r(exports_moved) == 75
assert r(taxes_rerouted) == 55
capture cge_map, `naopts' dirtax(gov) saltax(gov) imptax(gov)
assert _rc == 198
capture cge_map, `naopts' dirtax(gov) imptax(tax_imp)
assert _rc == 459

* Institutions layout: checks, every macro closure, and an enterprise that consumes
local instopts activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)              ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, `instopts'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
assert r(N_equations) == 105
cge_shock tm, value(0)
quietly cge_solve, name(inst_notariff)
cge_check, homogeneity perturb(0.1)
assert r(failures) == 0
cge_shock, reset
foreach ext in flexexr fixexr {
    foreach gov in flexgsav fixgsav {
        foreach si in savings investment {
            foreach num in cpi dpi {
                quietly cge_closure, external(`ext') government(`gov') savinv(`si') ///
                    numeraire(`num') factors(lab:unemployed cap:specific)
                quietly cge_solve, name(inst_closure)
                assert r(converged) == 1 & r(iterations) == 0
            }
        }
    }
}
cge_synthetic, clear institutions
quietly replace ent = ent + 2 in 6     // com_ser sold to the enterprise
quietly replace ent = ent - 2 in 16    // instead of enterprise savings
quietly replace sav = sav - 2 in 6     // investment demand for com_ser falls
quietly cge_sam, labels(account)
capture cge_map, `instopts'
assert _rc == 459

* npi saves all its income but still makes offsetting transfers (+2 to hhd,
* -2 abroad): its transfer shares are undefined, so calibration stops
cge_synthetic, clear institutions
quietly replace npi = 9 in 16          // savings of npi: all of its income
quietly replace npi = 0 in 6           // no consumption
quietly replace sav = sav + 10 in 6    // investment demand for com_ser instead
quietly replace npi = 2 in 9           // transfer to hhd
quietly replace npi = -2 in 17         // negative transfer abroad
quietly replace hhd = hhd + 2 in 17    // hhd pays the 2 abroad
quietly cge_sam, labels(account)
quietly cge_map, `instopts'
capture cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
assert _rc == 459

* Margins layout: amount moved, and margins() errors
cge_synthetic, clear margins
quietly cge_sam, labels(account)
cge_map, `mapopts' margins(act_ser)
assert r(margins_moved) == 10
capture cge_map, `mapopts'
assert _rc == 459
capture cge_map, `mapopts' margins(act_agr)
assert _rc == 459
capture cge_map, `mapopts' margins(com_ser)
assert _rc == 198

* Territorial correction: amounts rewritten, and errors
cge_synthetic, clear territorial
quietly cge_sam, labels(account)
cge_map, `mapopts' territorial(com_tc act_tc)
assert r(territorial_imports) == 4 & r(territorial_exports) == 9
capture cge_map, `mapopts'
assert _rc == 459
capture cge_map, `mapopts' territorial(com_ser)
assert _rc == 198
capture cge_map, `mapopts' territorial(com_tc act_tc lab)
assert _rc == 198

* Negative secondary sale: kept as a negative yield, with a note
cge_synthetic, clear multiproduct
quietly replace com_agr = -1 in 3      // act_ser sells -1 of com_agr
quietly replace com_ser = 151 in 3     // and 1 more com_ser
quietly replace hhd = hhd - 1 in 4     // households buy 1 less com_agr
quietly replace hhd = hhd + 1 in 6     // and 1 more com_ser
quietly cge_sam, labels(account)
cge_map, `mapopts'
assert r(N_negative_sales) == 1
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
assert r(max_residual) < 1e-12

* Commands in the wrong order
cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `mapopts'
capture cge_solve
assert _rc == 459

* Top nest (version 0.1.12): checks, Jacobian and errors
quietly do setup_synthetic.do "sigmava(0.8) sigmaq(2) sigmat(2) sigmaa(0 0.5 1)"
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
cge_shock pwm, scale(1.1)
quietly cge_solve, name(nest_pwm)
cge_check, homogeneity perturb(0.1)
assert r(failures) == 0
cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
capture cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) sigmaa(0.5 1)
assert _rc == 198

* LES household demand (version 0.1.11): checks, Jacobian and errors
quietly do setup_synthetic.do "sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1 1.4) frisch(-2)"
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
cge_shock pwm, scale(1.1)
quietly cge_solve, name(les_pwm)
cge_check, homogeneity perturb(0.1)
assert r(failures) == 0
quietly cge_results, sim(les_pwm)
assert el(r(ev), 1, 1) < 0
cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
capture cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1 1.4)
assert _rc == 198
capture cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) frisch(-0.5)
assert _rc == 198
capture cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1) frisch(-2)
assert _rc == 198

* Spending and transfer parameters (version 0.1.10)
quietly do setup_synthetic.do
cge_shock qg, elements(com_ser) scale(1.2)
cge_shock trgr, value(2)
capture cge_shock trgr, elements(com_ser) value(1)
assert _rc == 198
capture cge_shock trdr, elements(com_ser) value(1)
assert _rc == 111
quietly cge_solve, name(spending)
quietly cge_results, sim(spending) clear nodisplay
assert abs(value - 1.2 * base) < 1e-9 if variable == "QG" & element1 == "com_ser"
quietly do setup_synthetic.do

* Health insurance fund (version 0.1.13): mapping, checks, Jacobian and errors
local hltopts activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                            ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_synthetic, clear health
quietly cge_sam, labels(account)
capture cge_map, `hltopts'
assert _rc == 459
quietly cge_map, `hltopts' insurance(shi)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
assert r(max_residual) < 1e-12
cge_shock tshi, elements(lab) scale(1.5)
cge_shock trshir, value(2)
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
quietly cge_solve, name(shi_up)
cge_check, homogeneity perturb(0.1)
assert r(failures) == 0
quietly cge_closure, external(fixexr) savinv(investment) factors(cap:specific)
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
quietly cge_results, sim(shi_up) clear nodisplay
assert value > base if variable == "QSHI" & element1 == "com_hlt"
assert value > base if variable == "YIF" & element1 == "shi" & element2 == "lab"
quietly count if variable == "QSHI"
assert r(N) == 1
* A transfer from the fund to households is not represented
cge_synthetic, clear health
assert account[11] == "hhd" & account[17] == "sav"
quietly replace shi = shi + 1 in 11
quietly replace shi = shi - 1 in 17
quietly replace hhd = hhd + 1 in 17
quietly cge_sam, labels(account)
capture cge_map, `hltopts' insurance(shi)
assert _rc == 459
* Labour efficiency linked to health services (version 0.1.14): Jacobian,
* checks, the equivalence of lower efficiency and less labour, and errors
cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, `hltopts' insurance(shi)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) healthcom(com_hlt) healthfac(lab) healthelas(0.3)
assert r(max_residual) < 1e-12
cge_shock qg, elements(com_hlt) scale(1.2)
cge_shock af, elements(lab) scale(0.98)
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
quietly cge_solve, name(eff_up)
cge_check, homogeneity perturb(0.1)
assert r(failures) == 0
quietly cge_closure, external(fixexr) savinv(investment) factors(cap:specific)
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
quietly cge_results, sim(eff_up) clear nodisplay
quietly count if variable == "EFF"
assert r(N) == 1
quietly summarize value if variable == "EFF" & element1 == "lab"
local eff = r(mean)
quietly summarize base if variable == "HS"
local hs0 = r(mean)
quietly summarize value if variable == "HS"
assert abs(`eff' - (r(mean) / `hs0')^0.3) < 1e-10 & `eff' != 1
* Without the link, labour 2 per cent less efficient equals 2 per cent less labour
cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, `hltopts' insurance(shi)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock af, elements(lab) scale(0.98)
quietly cge_solve, name(af98)
cge_shock, reset
cge_shock QFS, elements(lab) scale(0.98)
quietly cge_solve, name(qfs98)
tempfile af98
quietly cge_results, sim(af98) clear nodisplay
rename value v_af
quietly save `af98'
quietly cge_results, sim(qfs98) clear nodisplay
quietly merge 1:1 variable element1 element2 using `af98', assert(match) nogenerate
quietly generate double rel = abs(v_af - value) / max(1, abs(value))
quietly summarize rel if inlist(variable, "QA", "QVA", "QQ", "YF", "PQ")
assert r(max) < 1e-8
assert abs(v_af - 0.98 * value) < 1e-8 * value if variable == "W" & element1 == "lab"
* Errors
cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, `hltopts' insurance(shi)
capture cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) healthelas(0.3)
assert _rc == 198
capture cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) healthcom(com_hlt) healthfac(lab cap) healthelas(0.3 0.1 0.2)
assert _rc == 198
capture cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) healthcom(com_xyz) healthelas(0.3)
assert _rc == 111
capture cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) healthcom(com_hlt) healthfac(lab)
assert _rc == 198

* Reduced system (version 0.2.0): with every explicit definition left out
* (LES, a top nest, margins-free health layout with a fund and the health
* link), the reduced and full systems give the same solution, and both
* grouped Jacobians equal the column-by-column ones
cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, `hltopts' insurance(shi)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1 1.4 1.2) frisch(-2) ///
    sigmaa(0 0.5 1 0.5) healthcom(com_hlt) healthfac(lab) healthelas(0.3)
local neq = r(N_equations)
cge_shock pwm, scale(1.1)
cge_shock qg, elements(com_hlt) scale(1.2)
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6 & r(columns) < `neq'
mata: _cge_jaccheck(1)
assert r(maxdiff) < 1e-6 & r(columns) == `neq'
cge_solve, name(reduced) tolerance(1e-12)
assert r(N_solved) < `neq' & r(max_residual) < 1e-12
cge_solve, name(full) tolerance(1e-12) full
assert r(N_solved) == `neq'
quietly cge_results, sim(reduced) clear nodisplay
rename value v_reduced
tempfile red
quietly save `red'
quietly cge_results, sim(full) clear nodisplay
quietly merge 1:1 variable element1 element2 using `red', assert(match) nogenerate
assert abs(v_reduced - value) <= 1e-10 * max(1, abs(value))

* Fund parameters need a fund
quietly do setup_synthetic.do
capture cge_shock tshi, elements(lab) scale(1.5)
assert _rc == 459
capture cge_shock trshi, value(1)
assert _rc == 459

* Shocks: a free variable cannot be set; unknown names are rejected
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
capture cge_shock EXR, value(1.1)
assert _rc == 459
capture cge_shock nosuchthing, value(1)
assert _rc == 198
capture cge_shock tm, elements(nosuchgood) value(0)
assert _rc == 111
capture cge_shock tm, scale(2) value(0)
assert _rc == 198
