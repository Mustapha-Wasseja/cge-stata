* test_report_sa.do -- reports of standalone models and the roles of their
* variables (version 0.37.0; docs/model_spec.md, Section 47): the variables
* and items of a standalone model, its groups' expenditure, price indexes
* and incomes, and their equivalent and compensating variations, against
* values computed here from the solutions (Cobb-Douglas demands, for which
* the variations are exact); consumption indexed either way; the report as
* a dataset and an Excel file; roles kept by cge_save and cge_use; items and
* variables in the report of a model from a SAM; errors.

version 13.0

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)

_cge_load
capture mata: mata drop _trs_val()
mata:
// The value of variable v, element el ("" for a scalar), in simulation s
real scalar _trs_val(string scalar s, string scalar v, string scalar el)
{
    struct cge_model scalar M
    M = _cge_load()
    if (s == "") return(M.x0[_cge_u_vpos(M, v, el)])
    return(M.simx[_cge_u_vpos(M, v, el), _cge_find(M.simname, s)])
}
end

* ---------------------------------------------------------------------
* 1. Two groups with Cobb-Douglas demands for three goods in upward-sloping
*    supply, incomes given: the price of each good is (sum(h, alpha(c,h)
*    Y(h)) / A(c))^(1/(1+eta)), 1 at the base
* ---------------------------------------------------------------------
cge_model new
cge_set c = g1 g2 g3
cge_set h = h1 h2
cge_parameter alpha(c,h), values(g1.h1:0.5 g2.h1:0.3 g3.h1:0.2 g1.h2:0.2 g2.h2:0.3 g3.h2:0.5)
foreach e in g1.h1:0.5 g2.h1:0.3 g3.h1:0.2 g1.h2:0.2 g2.h2:0.3 g3.h2:0.5 {
    gettoken cg v : e, parse(":")
    local v = substr("`v'", 2, .)
    local a_`=subinstr("`cg'", ".", "_", 1)' `v'
}
cge_parameter ybar(h), values(h1:100 h2:50)
cge_parameter eta(c), values(g1:1 g2:1 g3:0.5)
cge_parameter A(c) = sum(h, alpha(c,h) * ybar(h))
cge_variable P(c), value(1)
cge_variable Y(h) = ybar(h)
cge_variable X(c) = A(c) * P(c)^eta(c)
cge_variable Q(c,h) = alpha(c,h) * Y(h) / P(c)
cge_equation MKT(c): sum(h, Q(c,h)) = X(c)
* consumption with the groups first, the same values
cge_variable QT(h,c) = Q(c,h)
quietly cge_solve, name(bench)
assert r(converged) == 1
cge_shock A, elements(g2) scale(0.8)
quietly cge_solve, name(supply)
cge_shock, reset
cge_shock ybar, elements(h1) scale(1.1)
quietly cge_solve, name(income)
cge_shock, reset

* the roles
cge_model roles, groups(h) goods(c) prices(P) consumption(Q) income(Y)
assert "`r(groups)'" == "h" & "`r(goods)'" == "c" & "`r(prices)'" == "P" & "`r(consumption)'" == "Q" & "`r(income)'" == "Y"
cge_model roles, list
assert "`r(consumption)'" == "Q"

* the report: every variable, items, groups, welfare
cge_report, sims(supply income) items(total = sum(c, P(c) * X(c)); pg2 = P(g2))
assert r(N_sims) == 2
* 20 variable elements (P 3, Y 2, X 3, Q 6, QT 6), 2 items, 2 groups x 6
* measures and 2 groups x 2 variations
assert r(N_measures) == 20 + 2 + 12 + 4
quietly cge_report, sims(supply income) items(total = sum(c, P(c) * X(c)); pg2 = P(g2)) clear
assert _N == 2 * 38
* the values against those computed from the solutions
foreach s in supply income {
    foreach g in h1 h2 {
        mata: st_local("y0", strofreal(_trs_val("", "Y", "`g'"), "%21.15g"))
        mata: st_local("y1", strofreal(_trs_val("`s'", "Y", "`g'"), "%21.15g"))
        local lg 0
        local la 0
        foreach c in g1 g2 g3 {
            mata: st_local("p1", strofreal(_trs_val("`s'", "P", "`c'"), "%21.15g"))
            local lg = `lg' + `a_`c'_`g'' * ln(`p1')
            local la = `la' + `a_`c'_`g'' * `p1'
        }
        local G = exp(`lg')
        * all income is spent: expenditure equals income
        local ev = `y1' / `G' - `y0'
        local cv = `y1' - `y0' * `G'
        quietly summarize value if sim == "`s'" & table == "welfare" & measure == "ev" & element == "`g'"
        assert reldif(r(mean), `ev') < 1e-10
        quietly summarize pct if sim == "`s'" & table == "welfare" & measure == "ev" & element == "`g'"
        assert reldif(r(mean), 100 * `ev' / `y0') < 1e-10
        quietly summarize value if sim == "`s'" & table == "welfare" & measure == "cv" & element == "`g'"
        assert reldif(r(mean), `cv') < 1e-10
        quietly summarize value if sim == "`s'" & table == "groups" & measure == "price_geometric" & element == "`g'"
        assert reldif(r(mean), `G') < 1e-12
        quietly summarize value if sim == "`s'" & table == "groups" & measure == "price_laspeyres" & element == "`g'"
        assert reldif(r(mean), `la') < 1e-12
        quietly summarize value if sim == "`s'" & table == "groups" & measure == "expenditure" & element == "`g'"
        assert reldif(r(mean), `y1') < 1e-10
        quietly summarize pct if sim == "`s'" & table == "groups" & measure == "real_income" & element == "`g'"
        assert reldif(r(mean), 100 * (`y1' / (`y0' * `G') - 1)) < 1e-10
        quietly summarize base if sim == "`s'" & table == "groups" & measure == "income" & element == "`g'"
        assert reldif(r(mean), `y0') < 1e-12
    }
    * the items
    local tot 0
    foreach c in g1 g2 g3 {
        mata: st_local("p1", strofreal(_trs_val("`s'", "P", "`c'"), "%21.15g"))
        mata: st_local("x1", strofreal(_trs_val("`s'", "X", "`c'"), "%21.15g"))
        local tot = `tot' + `p1' * `x1'
    }
    quietly summarize value if sim == "`s'" & table == "items" & measure == "total"
    assert reldif(r(mean), `tot') < 1e-12
    quietly summarize base if sim == "`s'" & table == "items" & measure == "total"
    assert reldif(r(mean), 150) < 1e-12
    * a variable
    mata: st_local("p1", strofreal(_trs_val("`s'", "P", "g2"), "%21.15g"))
    quietly summarize pct if sim == "`s'" & table == "variables" & measure == "P" & element == "g2"
    assert reldif(r(mean), 100 * (`p1' - 1)) < 1e-12
    quietly summarize value if sim == "`s'" & table == "items" & measure == "pg2"
    assert reldif(r(mean), `p1') < 1e-12
}
* the supply shock raises the price of g2 by sqrt(1.25) and lowers the
* welfare of both groups, which spend 30 per cent on it, alike
quietly summarize value if sim == "supply" & table == "variables" & measure == "P" & element == "g2"
assert reldif(r(mean), sqrt(1.25)) < 1e-10
quietly summarize pct if sim == "supply" & table == "welfare" & measure == "ev"
assert reldif(r(min), 100 * (1.25^(-0.15) - 1)) < 1e-9 & reldif(r(max), r(min)) < 1e-12
* two-index elements are labelled e1.e2
quietly count if table == "variables" & measure == "Q" & element == "g2.h1"
assert r(N) == 2

* consumption with the groups first gives the same groups and welfare
preserve
keep if inlist(table, "groups", "welfare")
sort sim table measure element
tempfile g1
quietly save `g1'
restore
quietly cge_model roles, groups(h) goods(c) prices(P) consumption(QT) income(Y)
quietly cge_report, sims(supply income) tables(groups welfare) clear
sort sim table measure element
rename (base value pct) (base2 value2 pct2)
quietly merge 1:1 sim table measure element using `g1'
assert _merge == 3
assert reldif(value, value2) < 1e-13 & (reldif(pct, pct2) < 1e-13 | pct == pct2)
quietly cge_model roles, groups(h) goods(c) prices(P) consumption(Q) income(Y)

* without income(), no income rows
quietly cge_model roles, groups(h) goods(c) prices(P) consumption(Q)
assert "`r(income)'" == ""
quietly cge_report, sims(supply) tables(groups) nodisplay
assert r(N_measures) == 2 * 4
quietly cge_model roles, groups(h) goods(c) prices(P) consumption(Q) income(Y)

* some variables only
quietly cge_report, sims(supply) variables(P Y) nodisplay
assert r(N_measures) == 5 + 12 + 4

* the report as a dataset file and as an Excel file, one sheet per table
tempfile rep
quietly cge_report, sims(supply income) items(total = sum(c, P(c) * X(c))) saving(`"`rep'.dta"')
use `"`rep'.dta"', clear
assert _N == 2 * (20 + 1 + 12 + 4)
quietly cge_report, sims(supply income) items(total = sum(c, P(c) * X(c))) saving(`"`rep'.xlsx"') nodisplay
foreach t in variables items groups welfare {
    import excel using `"`rep'.xlsx"', sheet("`t'") firstrow clear
    assert _N > 0
}
capture erase `"`rep'.dta"'
capture erase `"`rep'.xlsx"'
clear

* roles are saved with the model
tempfile mod
quietly cge_save using `"`mod'.cgem"', replace
quietly cge_model roles, clear
cge_model roles, list
assert "`r(groups)'" == ""
quietly cge_use using `"`mod'.cgem"'
cge_model roles, list
assert "`r(groups)'" == "h" & "`r(income)'" == "Y"
capture erase `"`mod'.cgem"'

* ---------------------------------------------------------------------
* 2. Errors of the roles and the report
* ---------------------------------------------------------------------
capture noisily cge_model roles, groups(h) goods(h) prices(P) consumption(Q)
assert _rc == 198
capture noisily cge_model roles, groups(h) goods(c) prices(Q) consumption(Q)
assert _rc == 198
capture noisily cge_model roles, groups(h) goods(c) prices(P) consumption(P)
assert _rc == 198
capture noisily cge_model roles, groups(h) goods(c) prices(P) consumption(Q) income(P)
assert _rc == 198
capture noisily cge_model roles, groups(nosuch) goods(c) prices(P) consumption(Q)
assert _rc == 111
capture noisily cge_model roles, groups(h) goods(c) prices(NOSUCH) consumption(Q)
assert _rc == 111
capture noisily cge_model roles, groups(h) goods(c)
assert _rc == 198
capture noisily cge_model roles, clear list
assert _rc == 198
capture noisily cge_report, items(1bad = P(g1))
assert _rc == 198
capture noisily cge_report, items(a = P(g1); a = P(g2))
assert _rc == 198
capture noisily cge_report, items(a P(g1))
assert _rc == 198
capture noisily cge_report, variables(NOSUCH)
assert _rc == 111
capture noisily cge_report, tables(macro)
assert _rc == 198
quietly cge_model roles, clear
capture noisily cge_report, tables(groups)
assert _rc == 459
* without roles the report has the variables
quietly cge_report, sims(supply) nodisplay
assert r(N_measures) == 20

* ---------------------------------------------------------------------
* 3. Items and variables in the report of a model from a SAM
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
quietly cge_shock tm, value(0)
quietly cge_solve, name(notariff)
quietly cge_shock, reset
capture noisily cge_model roles, groups(h) goods(c) prices(P) consumption(Q)
assert _rc == 198
quietly cge_report, sims(notariff) nodisplay
local n0 = r(N_measures)
cge_report, sims(notariff) items(absorb = sum(c, PQ(c) * QQ(c))) variables(PQ)
assert r(N_measures) == `n0' + 1 + 3
quietly cge_report, sims(notariff) items(absorb = sum(c, PQ(c) * QQ(c))) variables(PQ) clear
local tot 0
foreach c in com_agr com_man com_ser {
    mata: st_local("pq", strofreal(_trs_val("notariff", "PQ", "`c'"), "%21.15g"))
    mata: st_local("qq", strofreal(_trs_val("notariff", "QQ", "`c'"), "%21.15g"))
    local tot = `tot' + `pq' * `qq'
}
quietly summarize value if table == "items" & measure == "absorb"
assert reldif(r(mean), `tot') < 1e-12
quietly count if table == "variables" & measure == "PQ"
assert r(N) == 3
capture noisily cge_report, tables(variables)
assert _rc == 198
capture noisily cge_report, tables(macro) items(a = PQ(com_man))
assert _rc == 198
clear
capture mata: mata drop _trs_val()
