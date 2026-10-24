* gdx_check.do -- the check of cge_gdx (version 0.10.0; see run_gdx_check.py,
* which runs this file twice):
*   do gdx_check.do prepare DIR GAMS   write the GAMS programs and the scripts
*                                       of gdxdump, and export a scenario to GAMS
*   do gdx_check.do compare DIR GAMS   read what GAMS and gdxdump wrote and
*                                       compare it with Stata; writes DIR/gdx_check.csv
* The synthetic SAMs describe no country; the elasticities are illustrative.

version 13.0
args phase dir gams
if !inlist("`phase'", "prepare", "compare") | `"`dir'"' == "" | `"`gams'"' == "" {
    display as error "usage: do gdx_check.do prepare|compare DIR GAMS"
    exit 198
}
clear all
set more off
local instmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)             ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)
local nr = cond("`phase'" == "prepare", "norun", "norun")

* the model and two simulations, the same in both phases
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, `instmap'
quietly cge_calibrate, `sigmas'
cge_shock tm, value(0)
quietly cge_solve, name(notariff) tolerance(1e-12)
cge_shock, reset
cge_shock qg, elements(com_ser) scale(1.1)
quietly cge_solve, name(gspend) tolerance(1e-12)
cge_shock, reset

if "`phase'" == "prepare" {
    * the GDX file of the model; the scripts that read it back
    cge_gdx write using `"`dir'/m.gdx"', sims(notariff gspend) norun gams(`"`gams'"')
    foreach s in SAM CAL LEVEL AC {
        cge_gdx read using `"`dir'/m.gdx"', symbol(`s') norun clear gams(`"`gams'"')
    }
    cge_gdx list using `"`dir'/m.gdx"', norun gams(`"`gams'"')
    * a scenario solved by GAMS, whose solution GAMS writes as a GDX file
    cge_gams using `"`dir'/exp"', sim(notariff) replace
    foreach s in QA PQ EXR SAM {
        cge_gdx read using `"`dir'/exp/sol.gdx"', symbol(`s') norun clear gams(`"`gams'"')
    }
    exit
}

* compare: the SAM, the parameters and the levels read back, exactly
tempname post
postfile `post' str24 check double(N maxdiff) using `"`dir'/gdx_check.dta"', replace
capture program drop _gdx_diff
program define _gdx_diff, rclass
    * the largest difference between value and ref, relative to max(1, |ref|)
    quietly generate double rel = abs(value - ref) / max(1, abs(ref))
    quietly summarize rel
    return scalar maxdiff = cond(r(N), r(max), .)
    return scalar N = r(N)
end
* the SAM, as the model holds it
capture mata: mata drop _gdx_samref()
mata:
void _gdx_samref()
{
    struct cge_model scalar M
    real scalar i, j, n
    M = _cge_load()
    n = sum(M.S :!= 0)
    stata("clear")
    st_addobs(n)
    (void) st_addvar("str32", ("row", "column"))
    (void) st_addvar("double", "ref")
    n = 0
    for (i = 1; i <= rows(M.S); i++) {
        for (j = 1; j <= cols(M.S); j++) {
            if (M.S[i, j] == 0) continue
            n++
            st_sstore(n, ("row", "column"), (M.labels[i], M.labels[j]))
            st_store(n, "ref", M.S[i, j])
        }
    }
}
end
tempfile ref
mata: _gdx_samref()
quietly save `ref'
cge_gdx read using `"`dir'/m.gdx"', symbol(SAM) norun clear
rename (`r(indexes)') (row column)
quietly merge 1:1 row column using `ref'
assert _merge == 3
_gdx_diff
post `post' ("SAM") (r(N)) (r(maxdiff))
* the calibrated parameters
cge_parameters, clear
quietly drop if value == 0 | missing(value)
quietly replace element1 = "-" if element1 == ""
quietly replace element2 = "-" if element2 == ""
rename value ref
quietly save `ref', replace
cge_gdx read using `"`dir'/m.gdx"', symbol(CAL) norun clear
rename (dim1 dim2 dim3) (parameter element1 element2)
* GAMS's labels ignore case: qg, a parameter, shares the label of QG
quietly replace parameter = lower(parameter)
quietly merge 1:1 parameter element1 element2 using `ref'
assert _merge == 3
_gdx_diff
post `post' ("CAL") (r(N)) (r(maxdiff))
* the levels at the base and the two simulations
foreach s in notariff gspend {
    quietly cge_results, sim(`s') clear nodisplay
    quietly generate sim = "`s'"
    quietly expand 2, generate(isbase)
    quietly replace sim = "base" if isbase
    quietly replace value = base if isbase
    quietly drop if isbase & "`s'" == "gspend"
    quietly drop isbase
    quietly drop if value == 0 | missing(value)
    quietly replace element1 = "-" if element1 == ""
    quietly replace element2 = "-" if element2 == ""
    quietly keep sim variable element1 element2 value
    rename value ref
    if "`s'" == "gspend" append using `ref'
    quietly save `ref', replace
}
cge_gdx read using `"`dir'/m.gdx"', symbol(LEVEL) norun clear
rename (sim dim2 dim3 dim4) (sim variable element1 element2)
quietly merge 1:1 sim variable element1 element2 using `ref'
assert _merge == 3
_gdx_diff
post `post' ("LEVEL") (r(N)) (r(maxdiff))
* the accounts and the list of symbols
cge_gdx read using `"`dir'/m.gdx"', symbol(AC) norun clear
post `post' ("AC") (_N) (0)
cge_gdx list using `"`dir'/m.gdx"', norun clear
assert "`r(symbols)'" != ""
post `post' ("symbols") (r(N_symbols)) (0)
* the solution of GAMS, read from its GDX file, against Stata's
foreach v in QA PQ EXR {
    quietly cge_results, sim(notariff) clear nodisplay
    quietly keep if variable == "`v'"
    rename value ref
    quietly keep element1 ref
    quietly save `ref', replace
    cge_gdx read using `"`dir'/exp/sol.gdx"', symbol(`v') norun clear
    if r(dim) == 1 {
        rename `r(indexes)' element1
        quietly merge 1:1 element1 using `ref', keep(match)
    }
    else {
        quietly generate element1 = ""
        quietly merge 1:1 element1 using `ref', keep(match)
    }
    rename level value
    _gdx_diff
    post `post' ("GAMS `v'") (r(N)) (r(maxdiff))
}
* a SAM read from the GAMS model's own GDX file calibrates the same model
cge_sam using `"`dir'/exp/sol.gdx"', symbol(SAM) norun clear
quietly cge_map, `instmap'
quietly cge_calibrate, `sigmas'
cge_shock tm, value(0)
quietly cge_solve, name(fromgdx) tolerance(1e-12)
quietly cge_results, sim(fromgdx) clear nodisplay
rename value ref
quietly save `ref', replace
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, `instmap'
quietly cge_calibrate, `sigmas'
cge_shock tm, value(0)
quietly cge_solve, name(direct) tolerance(1e-12)
quietly cge_results, sim(direct) clear nodisplay
quietly merge 1:1 variable element1 element2 using `ref'
assert _merge == 3
_gdx_diff
post `post' ("SAM from GAMS") (r(N)) (r(maxdiff))
postclose `post'
use `"`dir'/gdx_check.dta"', clear
export delimited using `"`dir'/gdx_check.csv"', replace
list, noobs
