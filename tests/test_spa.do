* test_spa.do -- structural path analysis (version 0.4.2; docs/sam_tools.md,
* Section 7), against the Python reference

version 13.0

* Paths found by cge_spa against expected/spa_<case>.csv
capture program drop _compare_spa
program define _compare_spa
    args case options
    tempfile stata
    quietly cge_spa, `options' clear
    local glob = r(global)
    keep path direct multiplier total
    quietly save `stata'
    quietly import delimited using "expected/spa_`case'.csv", varnames(1) case(preserve) ///
        stringcols(1) asdouble clear
    quietly summarize total if path == "_global"
    assert reldif(r(mean), `glob') < 1e-12
    quietly drop if path == "_global"
    rename (direct multiplier total) (ref_direct ref_multiplier ref_total)
    quietly merge 1:1 path using `stata'
    assert _merge == 3
    local worst 0
    foreach v in direct multiplier total {
        quietly generate double d_`v' = abs(`v' - ref_`v') / max(1, abs(ref_`v'))
        quietly summarize d_`v'
        local worst = max(`worst', r(max))
    }
    display as text "paths `case': " as result _N as text " paths, largest relative difference " ///
        as result %9.2e `worst'
    assert `worst' < 1e-12
end

* ---------------------------------------------------------------------
* 1. Against the reference
* ---------------------------------------------------------------------
cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                            ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
_compare_spa health "from(com_hlt) to(hhd)"
* The largest path: health services -> health activity -> labour -> households
cge_spa, from(com_hlt) to(hhd)
assert r(path1) == "com_hlt > act_hlt > lab > hhd"
assert r(N_paths) == 6 & r(share) > 97 & r(share) < 98
* The global influence is the multiplier
local glob = r(global)
preserve
quietly cge_multiplier, clear
quietly summarize multiplier if row == "hhd" & column == "com_hlt"
assert reldif(r(mean), `glob') < 1e-14
restore

cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
_compare_spa std "from(com_agr) to(hhd)"

cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)             ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
_compare_spa inst "from(com_ser) to(npi) maxlength(8) threshold(0.0001)"

* Every elementary path: the total influences add up to the multiplier
cge_synthetic, clear sut
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser com_fuel) ///
    factors(lab cap) households(hhd) government(gov) savinv(si) row(row)                       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) marginaccounts(trd trp) stocks(dstk)
_compare_spa sut_all "from(com_fuel) to(hhd) maxlength(12) threshold(0)"
cge_spa, from(com_fuel) to(hhd) maxlength(12) threshold(0)
assert reldif(r(explained), r(global)) < 1e-12

* ---------------------------------------------------------------------
* 2. Limits and errors
* ---------------------------------------------------------------------
cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                            ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
cge_spa, from(com_hlt) to(hhd) maxlength(3) clear
assert length <= 3
cge_spa, from(com_hlt) to(hhd) threshold(0.1) clear
assert abs(direct) >= 0.1 * r(global)
cge_spa, from(com_hlt) to(hhd) top(2)
assert r(N_paths) == 6
capture noisily cge_spa, from(hhd) to(hhd)
assert _rc == 198
capture noisily cge_spa, from(gov) to(hhd)
assert _rc == 198
capture noisily cge_spa, from(com_hlt) to(hhd) maxlength(0)
assert _rc == 198
capture noisily cge_spa, from(com_hlt) to(hhd) threshold(-1)
assert _rc == 198
* The government alone endogenous changes nothing, since no endogenous account
* pays it directly; with the tax accounts endogenous too, taxes are spent again
* and the multiplier rises
cge_spa, from(com_hlt) to(hhd)
local g0 = r(global)
cge_spa, from(com_hlt) to(hhd) endogenous(gov)
assert reldif(r(global), `g0') < 1e-14
cge_spa, from(com_hlt) to(hhd) endogenous(gov tax_dir tax_sal tax_imp)
assert r(global) > `g0'
