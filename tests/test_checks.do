* test_checks.do -- validation checks, closures and error handling
* (docs/model_spec.md, Sections 6 and 8)

version 13.0
quietly do setup_synthetic.do

* Checks on a simulation, with homogeneity and a perturbed start
cge_shock tm, value(0)
quietly cge_solve, name(notariff)
cge_check, homogeneity perturb(0.1)
assert r(failures) == 0

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

* ---------------------------------------------------------------------
* Errors
* ---------------------------------------------------------------------
local mapopts activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)              ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

* Unbalanced SAM
cge_synthetic, clear
quietly replace com_agr = com_agr + 1 in 1
quietly cge_sam, labels(account)
capture cge_map, `mapopts'
assert _rc == 459

* Flow the model does not represent: household pays the government directly
cge_synthetic, clear
quietly replace hhd = hhd + 5 in 10
quietly replace hhd = hhd - 5 in 14
quietly replace gov = gov + 5 in 14
quietly cge_sam, labels(account)
capture cge_map, `mapopts'
assert _rc == 459

* Account with flows but no role
cge_synthetic, clear
quietly cge_sam, labels(account)
capture cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                 ///
    dirtax(tax_dir) saltax(tax_sal)
assert _rc == 459

* Activity paired with the wrong commodity
capture cge_map, activities(act_agr act_man act_ser) commodities(com_man com_agr com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                 ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
assert _rc == 459

* Cobb-Douglas Armington function is not available in version 0.1
quietly cge_map, `mapopts'
capture cge_calibrate, sigmava(0.8) sigmaq(1) sigmat(2)
assert _rc == 198

* Commands in the wrong order
capture cge_solve
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
