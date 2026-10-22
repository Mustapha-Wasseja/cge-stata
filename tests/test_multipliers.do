* test_multipliers.do -- SAM accounting multipliers and their decomposition
* (version 0.4.1; docs/sam_tools.md, Section 6), against the Python reference

version 13.0

* The multipliers of the model in memory against expected/multipliers_<case>.csv
capture program drop _compare_mult
program define _compare_mult
    args case options
    tempfile stata
    quietly cge_multiplier, `options' clear
    drop row_block column_block
    quietly save `stata'
    quietly import delimited using "expected/multipliers_`case'.csv", varnames(1) case(preserve) ///
        stringcols(1 2) asdouble clear
    foreach v in multiplier transfer open_loop closed_loop {
        capture confirm variable `v'
        if !_rc rename `v' ref_`v'
    }
    quietly merge 1:1 row column using `stata'
    assert _merge == 3
    local worst 0
    foreach v of varlist ref_* {
        local s = substr("`v'", 5, .)
        quietly generate double d_`s' = abs(`s' - `v') / max(1, abs(`v'))
        quietly summarize d_`s'
        local worst = max(`worst', r(max))
    }
    display as text "multipliers `case': " as result _N as text " cells, largest relative difference " ///
        as result %9.2e `worst'
    assert `worst' < 1e-12
end

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

* ---------------------------------------------------------------------
* 1. Against the reference, five cases
* ---------------------------------------------------------------------
cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
_compare_mult std decompose
_compare_mult std_plain

cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)             ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
_compare_mult inst decompose
_compare_mult inst_gov "endogenous(gov) exogenous(ent) decompose"
* A sales tax account in the institutions block breaks the circle: commodities
* (production) pay it
capture noisily cge_multiplier, endogenous(tax_sal) decompose
assert _rc == 459
cge_multiplier, endogenous(tax_sal)
assert r(N_endogenous) == 12

cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                            ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
_compare_mult health decompose

cge_synthetic, clear sut
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser com_fuel) ///
    factors(lab cap) households(hhd) government(gov) savinv(si) row(row)                       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) marginaccounts(trd trp) stocks(dstk)
_compare_mult sut decompose
* 3 activities, 4 commodities, 2 margin accounts, 2 factors and 1 household
cge_multiplier
assert r(N_endogenous) == 12

* ---------------------------------------------------------------------
* 2. Injections: M x, with the totals in r()
* ---------------------------------------------------------------------
cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                            ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
cge_multiplier, inject(com_hlt:100 com_ser:50) clear
local output = r(output)
local va = r(value_added)
local hh = r(household_income)
assert r(injection) == 150
tempfile inj
quietly save `inj'
* The same from the expected multipliers
quietly import delimited using "expected/multipliers_health.csv", varnames(1) stringcols(1 2) asdouble clear
quietly keep if inlist(column, "com_hlt", "com_ser")
quietly generate double x = cond(column == "com_hlt", 100, 50)
quietly generate double dy = multiplier * x
collapse (sum) dy, by(row)
rename row account
quietly merge 1:1 account using `inj', assert(match) nogenerate
assert abs(change - dy) <= 1e-10 * max(1, abs(dy))
quietly summarize dy if substr(account, 1, 4) == "act_"
assert reldif(r(sum), `output') < 1e-12
quietly summarize dy if inlist(account, "lab", "cap")
assert reldif(r(sum), `va') < 1e-12
quietly summarize dy if account == "hhd"
assert reldif(r(sum), `hh') < 1e-12
* Changes relative to base incomes
assert reldif(pct, 100 * change / abs(base)) < 1e-12

* ---------------------------------------------------------------------
* 3. Decomposition identities and a calibrated model left intact
* ---------------------------------------------------------------------
cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
quietly cge_solve, name(notariff)
cge_multiplier, decompose clear
generate double one = (row == column)
assert abs(one + transfer + open_loop + closed_loop - multiplier) < 1e-12
* Transfers are within blocks and open-loop effects reach other blocks
assert transfer == 0 if row_block != column_block
assert open_loop == 0 if row_block == column_block
cge_report, sims(notariff) tables(macro) nodisplay
assert r(N_sims) == 1

* ---------------------------------------------------------------------
* 4. Errors
* ---------------------------------------------------------------------
capture noisily cge_multiplier, exogenous(gov)
assert _rc == 198
capture noisily cge_multiplier, endogenous(hhd)
assert _rc == 198
capture noisily cge_multiplier, exogenous(xyz)
assert _rc == 111
capture noisily cge_multiplier, inject(gov:10)
assert _rc == 198
capture noisily cge_multiplier, inject(com_agr)
assert _rc == 198
capture noisily cge_multiplier, accounts(gov)
assert _rc == 198
* Every account endogenous: nothing leaks
capture noisily cge_multiplier, endogenous(gov sav row tax_dir tax_sal tax_imp)
assert _rc == 459
cge_synthetic, clear
quietly cge_sam, labels(account)
capture noisily cge_multiplier
assert _rc == 459

* inject() with decompose: the decomposition, which the effects of an
* injection do not use, no longer needs the circular structure (version 0.6.4)
cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
capture noisily cge_multiplier, endogenous(tax_sal) decompose
assert _rc == 459
cge_multiplier, endogenous(tax_sal) decompose inject(com_ser:10)
assert r(injection) == 10
