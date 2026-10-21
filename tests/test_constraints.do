* test_constraints.do -- bounds and complementarity (version 0.4.4;
* docs/model_spec.md, Section 16), against the Python reference, which finds
* the regimes by an active-set method

version 13.0
quietly do helpers_reference.do

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local hltmap activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)

* Regimes of a simulation, from r(constraints) of cge_solve, against
* expected/con_regimes.csv
capture program drop _compare_regimes
program define _compare_regimes
    args sim
    local rest `"`r(constraints)'"'
    preserve
    quietly import delimited using "expected/con_regimes.csv", varnames(1) clear
    quietly keep if case == "`sim'"
    assert _N > 0
    forvalues i = 1/`=_N' {
        local want = cond(binding[`i'] == 1, ": binding", ": not binding")
        local pos = strpos(`"`rest'"', ";")
        local one = cond(`pos', substr(`"`rest'"', 1, max(`pos' - 1, 1)), `"`rest'"')
        assert strpos(`"`one'"', "`want'") > 0
        local rest = substr(`"`rest'"', `pos' + 1, .)
    }
    display as text "regimes `sim': " as result _N as text " constraint(s) as in the reference"
    restore
end

* ---------------------------------------------------------------------
* 1. Against the reference
* ---------------------------------------------------------------------
cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'

* An import quota 2 per cent above base imports of manufactures, with tariffs
* removed: the premium goes to the government, to households, or abroad
foreach r in gov hhd row {
    quietly cge_constraint, clear
    quietly cge_shock, reset
    cge_shock tm, value(0)
    cge_constraint QM, elements(com_man) upper(1.02) scale rents(`r')
    local name = cond("`r'" == "gov", "con_quota", "con_quota_`r'")
    cge_solve, name(`name') tolerance(1e-12)
    assert r(N_binding) == 1 & r(N_constraints) == 1
    _compare_regimes `name'
    _compare_reference `name'
}
_compare_report con_quota_row
* A quota that does not bind, and one at base imports without a shock
cge_constraint QM, elements(com_man) upper(2) scale
cge_solve, name(con_quota_slack) tolerance(1e-12)
assert r(N_binding) == 0
_compare_reference con_quota_slack
quietly cge_shock, reset
cge_constraint QM, elements(com_man) upper(1) scale
cge_solve, name(con_quota_base) tolerance(1e-12)
_compare_reference con_quota_base
* An export quota with world prices of manufactures 20 per cent higher
quietly cge_constraint, clear
cge_shock pwe, elements(com_man) scale(1.2)
cge_constraint QE, elements(com_man) upper(1.05) scale
cge_solve, name(con_export_quota) tolerance(1e-12)
_compare_regimes con_export_quota
_compare_reference con_export_quota
_compare_report con_export_quota
* A capacity limit on services, with government purchases of services up 50
* per cent; the rent goes to capital
quietly cge_constraint, clear
quietly cge_shock, reset
cge_shock qg, elements(com_ser) scale(1.5)
cge_constraint QA, elements(act_ser) upper(1.01) scale rents(cap)
cge_solve, name(con_capacity) tolerance(1e-12)
_compare_regimes con_capacity
_compare_reference con_capacity
_compare_report con_capacity
* A limit on foreign borrowing under a fixed exchange rate, with world export
* prices down 20 per cent: the currency depreciates
quietly cge_constraint, clear
quietly cge_shock, reset
quietly cge_closure, external(fixexr)
cge_shock pwe, scale(0.8)
cge_constraint FSAV, upper(2) scale adjust(EXR) up
cge_solve, name(con_peg_limit) tolerance(1e-12)
_compare_regimes con_peg_limit
_compare_reference con_peg_limit
* A government that may not borrow, with tariffs removed: spending is cut,
* or direct taxes rise
quietly cge_constraint, clear
quietly cge_shock, reset
quietly cge_closure, external(flexexr)
cge_shock tm, value(0)
cge_constraint GSAV, lower(0) adjust(GADJ) down
cge_solve, name(con_deficit_spending) tolerance(1e-12)
_compare_regimes con_deficit_spending
_compare_reference con_deficit_spending
quietly cge_constraint, clear
cge_constraint GSAV, lower(0) adjust(TINSADJ) up
cge_solve, name(con_deficit_tax) tolerance(1e-12)
_compare_reference con_deficit_tax
* Both a quota and the ban on borrowing
quietly cge_constraint, clear
cge_constraint QM, elements(com_man) upper(1.02) scale
cge_constraint GSAV, lower(0) adjust(GADJ) down
cge_solve, name(con_two) tolerance(1e-12)
assert r(N_binding) == 2
_compare_regimes con_two
_compare_reference con_two
* A floor on the nominal wage of labour, with import prices up 10 per cent:
* employment falls
quietly cge_constraint, clear
quietly cge_shock, reset
cge_shock pwm, scale(1.1)
cge_constraint W, elements(lab) lower(1) scale adjust(QFS) down
cge_solve, name(con_wage_floor) tolerance(1e-12)
_compare_reference con_wage_floor
* The same with the full system, and the grouped Jacobian at the solution
cge_solve, name(wage_floor_full) tolerance(1e-12) full
quietly cge_results, sim(wage_floor_full) clear nodisplay
quietly generate double v1 = value
tempfile full
quietly save `full'
quietly cge_results, sim(con_wage_floor) clear nodisplay
quietly merge 1:1 variable element1 element2 using `full', keepusing(v1)
quietly generate double d = abs(v1 - value) / max(1, abs(value))
quietly summarize d
assert r(max) < 1e-10
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-5
mata: _cge_jaccheck(0, 1)
assert r(maxdiff) < 1e-5

* Capacity of health services, with government purchases of health services up
* 20 per cent; the rent goes to households
cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, `hltmap'
quietly cge_calibrate, `sigmas'
cge_shock qg, elements(com_hlt) scale(1.2)
cge_constraint QA, elements(act_hlt) upper(1.03) scale rents(hhd)
cge_solve, name(con_health_capacity) tolerance(1e-12)
_compare_regimes con_health_capacity
_compare_reference con_health_capacity

* ---------------------------------------------------------------------
* 2. Equivalences
* ---------------------------------------------------------------------
cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
* A premium set by hand acts as a tariff, whose revenue goes to the government
quietly cge_parameters, clear
quietly summarize value if parameter == "tm" & element1 == "com_man"
local tm = r(mean)
cge_shock tm, elements(com_man) value(`=`tm' + 0.05')
quietly cge_solve, name(tariff) tolerance(1e-12)
quietly cge_shock, reset
cge_shock RM, elements(com_man) value(0.05)
quietly cge_solve, name(premium) tolerance(1e-12)
quietly cge_results, sim(premium) clear nodisplay
quietly generate double v1 = value
quietly save `full', replace
quietly cge_results, sim(tariff) clear nodisplay
quietly merge 1:1 variable element1 element2 using `full', keepusing(v1)
quietly generate double d = abs(v1 - value) / max(1, abs(value))
quietly summarize d if variable != "RM"
assert r(max) < 1e-10

* ---------------------------------------------------------------------
* 3. Constraints are kept by a reset of shocks and replaced on the same
*    bound; saved with the model; and checked against the closure
* ---------------------------------------------------------------------
quietly cge_shock, reset
cge_shock tm, value(0)
cge_constraint QM, elements(com_man) upper(1.02) scale
quietly cge_shock, reset
cge_shock tm, value(0)
cge_constraint, list
assert r(N_constraints) == 1
quietly cge_solve, name(q1) tolerance(1e-12)
assert r(N_binding) == 1
cge_constraint QM, elements(com_man) upper(1.01) scale
cge_constraint, list
assert r(N_constraints) == 1
quietly cge_solve, name(q2) tolerance(1e-12)
quietly cge_results, sim(q2) clear nodisplay
quietly summarize value if variable == "QM" & element1 == "com_man"
assert abs(r(mean) - 60.6) < 1e-9
tempfile saved
cge_save using "`saved'", replace
quietly cge_use using "`saved'"
cge_constraint, list
assert r(N_constraints) == 1
quietly cge_solve, name(q3) tolerance(1e-12)
assert r(N_binding) == 1
quietly cge_results, sim(q3) clear nodisplay
quietly summarize value if variable == "QM" & element1 == "com_man"
assert abs(r(mean) - 60.6) < 1e-9
* The adjusting variable must stay fixed under the closure
cge_constraint, clear
cge_constraint GSAV, lower(0) adjust(GADJ) down
capture noisily cge_closure, government(fixgsav)
assert _rc == 459
cge_constraint, clear
quietly cge_closure, government(flexgsav)

* ---------------------------------------------------------------------
* 4. Errors
* ---------------------------------------------------------------------
capture noisily cge_constraint QM, elements(com_man)
assert _rc == 198
capture noisily cge_constraint QM, elements(com_man) upper(1) lower(0.5)
assert _rc == 198
capture noisily cge_constraint XYZ, upper(1)
assert _rc == 198
capture noisily cge_constraint QM, elements(com_xyz) upper(1)
assert _rc == 111
capture noisily cge_constraint FSAV, upper(1) adjust(EXR) up
assert _rc == 459
capture noisily cge_constraint GSAV, lower(0) adjust(EXR) up
assert _rc == 459
capture noisily cge_constraint GSAV, lower(0) adjust(GADJ)
assert _rc == 198
capture noisily cge_constraint QD, elements(com_man) upper(1) scale
assert _rc == 198
capture noisily cge_constraint GSAV, lower(0) adjust(GADJ) down rents(hhd)
assert _rc == 198
capture noisily cge_constraint QM, elements(com_man) upper(1) scale rents(tax_dir)
assert _rc == 111
capture noisily cge_constraint QM, upper(1) scale adjust(EXR) up
assert _rc == 198
capture noisily cge_constraint QF, elements(lab) upper(1) scale adjust(QFS lab) down
assert _rc == 198
capture noisily cge_constraint GSAV, lower(0) adjust(GADJ) up down
assert _rc == 198
cge_constraint GSAV, lower(0) adjust(GADJ) down
capture noisily cge_constraint QG, elements(com_ser) upper(1) scale adjust(GADJ) down
assert _rc == 459
cge_constraint, clear

* ---------------------------------------------------------------------
* 5. Dynamic runs and sensitivity analysis keep the constraints
* ---------------------------------------------------------------------
cge_constraint QM, elements(com_man) upper(1.02) scale
quietly cge_dynamic, name(dq) periods(0/2) capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02)
quietly cge_results, sim(dq2) clear nodisplay
quietly summarize value if variable == "QM" & element1 == "com_man"
assert r(mean) <= 61.2 + 1e-9
capture program drop _no_tariffs
program define _no_tariffs
    cge_shock tm, value(0)
end
quietly cge_shock, reset
cge_sensitivity, scenario(_no_tariffs) draws(3) seed(1) tables(macro) nodisplay
assert r(N_draws) == 3 & r(N_converged) == 3
cge_constraint, list
assert r(N_constraints) == 1
program drop _no_tariffs
