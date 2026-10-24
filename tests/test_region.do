* test_region.do -- linked regions (version 0.12.0; docs/model_spec.md,
* Section 21), against the Python reference (reference/cge_ref/regions.py;
* expected/link_<case>_<region>.csv and link_<case>_routes.csv): the base, a
* free-trade area between the regions, a rise in the rest of the world's price
* of manufactures and productivity in one region; each region's solution
* solves its own model; the start from regions solved alone; errors.

version 13.0
quietly do helpers_reference.do

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local instmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)             ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)

* A region's solution against expected/link_<case>_<region>.csv
capture program drop _compare_link
program define _compare_link
    args sim case region
    quietly cge_region select `region'
    tempfile stata
    quietly cge_results, sim(`sim') clear nodisplay
    quietly save `stata'
    quietly import delimited using "expected/link_`case'_`region'.csv", varnames(1) case(preserve) ///
        stringcols(1 2 3) asdouble clear
    rename (base value) (ref_base ref_value)
    quietly merge 1:1 variable element1 element2 using `stata'
    assert _merge == 3
    quietly generate double reldiff = abs(value - ref_value) / max(1, abs(ref_value))
    quietly summarize reldiff
    display as text "`case', region `region': " as result _N as text " values, largest relative difference " ///
        as result %9.2e r(max)
    assert r(max) < 1e-8
end

* The routes of a linked solution against expected/link_<case>_routes.csv
capture program drop _compare_routes
program define _compare_routes
    args sim case
    tempfile ref
    quietly import delimited using "expected/link_`case'_routes.csv", varnames(1) stringcols(1 2 3) asdouble clear
    rename (quantity price) (ref_q ref_p)
    quietly save `ref'
    quietly cge_region results, sim(`sim') clear
    quietly merge 1:1 exporter importer commodity using `ref'
    assert _merge == 3
    quietly generate double d = max(abs(quantity - ref_q) / max(1, abs(ref_q)), abs(price - ref_p) / max(1, abs(ref_p)))
    quietly summarize d
    display as text "`case', routes: " as result _N as text " routes, largest relative difference " as result %9.2e r(max)
    assert r(max) < 1e-8
end

_cge_load
capture mata: mata drop _tr_own()
mata:
// Each region's linked solution sim solved again on its own, from the base,
// with its parameters as stored: the largest difference
real scalar _tr_own(string scalar sim, string colvector regions)
{
    struct cge_model scalar M
    struct cge_par scalar p
    real colvector x
    real scalar r, k, conv, iter, err, d
    string scalar method
    d = 0
    for (r = 1; r <= rows(regions); r++) {
        M = _cge_rg_get(regions[r])
        k = _cge_sim_index(M, sim)
        p = M.simp[k]
        x = _cge_solve_point(M, p, M.simx[., k], M.x0, 1e-12, 100, 0, conv, iter, err, method)
        if (!conv) return(.)
        d = max((d, max(abs(x - M.simx[., k]) :/ M.xscale)))
    }
    return(d)
}
end

* ---------------------------------------------------------------------
* 1. Two regions and their trade
* ---------------------------------------------------------------------
capture noisily cge_region clear
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
cge_region add A
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, `instmap'
quietly cge_calibrate, `sigmas'
cge_region add B, units(2)
clear
input str4 exporter str4 importer str8 commodity double value double tariff
A B com_agr 8 .
A B com_man 24 0.08
A B com_ser 6 .
B A com_agr 10 .
B A com_man 30 .
B A com_ser 5 0
end
tempfile trade
quietly save `trade'
cge_region trade, exporter(exporter) importer(importer) commodity(commodity) value(value) tariff(tariff)
cge_region list
assert r(N_regions) == 2 & r(N_routes) == 18 & "`r(current)'" == "B"

* ---------------------------------------------------------------------
* 2. The cases against the reference
* ---------------------------------------------------------------------
cge_region solve, name(lbase)
assert r(iterations) == 0
foreach r in A B {
    _compare_link lbase base `r'
}
_compare_routes lbase base

* a free-trade area: the tariffs between the regions removed
cge_region tariff, from(A B) to(A B) value(0)
cge_region solve, name(lfta)
foreach r in A B {
    _compare_link lfta fta `r'
}
_compare_routes lfta fta
mata: st_numscalar("tr_d", _tr_own("lfta", ("A" \ "B")))
display as text "each region's solution on its own: " as result %9.2e scalar(tr_d)
assert scalar(tr_d) < 1e-9
* the same from the regions solved alone
quietly cge_region solve, name(lfta2) start(alone)
quietly cge_region results, sim(lfta2) clear
rename (quantity price) (q2 p2)
tempfile r2
quietly save `r2'
quietly cge_region results, sim(lfta) clear
quietly merge 1:1 exporter importer commodity using `r2', nogenerate
quietly generate double d = abs(q2 - quantity) / max(1, quantity)
quietly summarize d
assert r(max) < 1e-9
quietly cge_region world, reset

* the rest of the world's price of manufactures up by a tenth
cge_region world, commodities(com_man) import(1.1)
quietly cge_region solve, name(lworld)
foreach r in A B {
    _compare_link lworld world `r'
}
_compare_routes lworld world
quietly cge_region world, reset

* productivity of manufacturing in region A up by 5 per cent
cge_region select A
cge_shock ad, elements(act_man) scale(1.05)
quietly cge_region solve, name(lprod)
foreach r in A B {
    _compare_link lprod prod `r'
}
_compare_routes lprod prod
quietly cge_region select A
quietly cge_shock, reset

* ---------------------------------------------------------------------
* 3. Errors
* ---------------------------------------------------------------------
* a linked commodity's world price is set by the links
quietly cge_shock pwm, elements(com_man) scale(1.1)
capture noisily cge_region solve, name(bad)
assert _rc == 198
quietly cge_shock, reset
capture noisily cge_region select C
assert _rc == 111
capture noisily cge_region tariff, from(A) to(nowhere) value(0)
assert _rc == 111
capture noisily cge_region tariff, from(A) to(B)
assert _rc == 198
* more trade between the regions than a region's imports
quietly use `trade', clear
quietly replace value = 80 if exporter == "B" & commodity == "com_man"
capture noisily cge_region trade, exporter(exporter) importer(importer) commodity(commodity) value(value)
assert _rc == 459
cge_region clear
capture noisily cge_region list
assert _rc == 198
mata: mata drop _tr_own()
