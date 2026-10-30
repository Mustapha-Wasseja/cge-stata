* test_microsim_sa.do -- the link to household surveys for standalone
* models (version 0.39.0; docs/model_spec.md, Section 49): each household's
* nominal consumption, price index, real consumption and its equivalent and
* compensating variations against values computed here from the solutions,
* with its own income components and budget shares and with its group's;
* poverty against the generated consumption; the decomposition adding up,
* without a channel of taxes and savings; bands from draws of the
* parameters; errors. The survey is SYNTHETIC.

version 13.0

_cge_load
capture mata: mata drop _tms_val()
mata:
// The value of variable v, element el, in simulation s ("" for the base)
real scalar _tms_val(string scalar s, string scalar v, string scalar el)
{
    struct cge_model scalar M
    M = _cge_load()
    if (s == "") return(M.x0[_cge_u_vpos(M, v, el)])
    return(M.simx[_cge_u_vpos(M, v, el), _cge_find(M.simname, s)])
}
end

* ---------------------------------------------------------------------
* The model: two groups with Cobb-Douglas demands for three goods; a supply
* shock and a rise of the first group's income
* ---------------------------------------------------------------------
cge_model new
cge_set c = g1 g2 g3
cge_set h = h1 h2
cge_parameter alpha(c,h), values(g1.h1:0.5 g2.h1:0.3 g3.h1:0.2 g1.h2:0.2 g2.h2:0.3 g3.h2:0.5)
cge_parameter ybar(h), values(h1:100 h2:50)
cge_parameter eta(c), values(g1:1 g2:1 g3:0.5)
cge_parameter A(c) = sum(h, alpha(c,h) * ybar(h))
cge_variable P(c), value(1)
cge_variable Y(h) = ybar(h)
cge_variable X(c) = A(c) * P(c)^eta(c)
cge_variable Q(c,h) = alpha(c,h) * Y(h) / P(c)
cge_equation MKT(c): sum(h, Q(c,h)) = X(c)
cge_variable PIDX = sum(c, P(c)) / 3
quietly cge_solve, name(bench)
cge_shock A, elements(g2) scale(0.8)
quietly cge_solve, name(supply)
cge_shock, reset
cge_shock ybar, elements(h1) scale(1.1)
quietly cge_solve, name(richer)
cge_shock, reset

* the roles are needed
clear
quietly set obs 10
generate grp = "h1"
generate double cons = 100
capture noisily cge_microsim, sim(richer) group(grp) consumption(cons)
assert _rc == 459
cge_model roles, groups(h) goods(c) prices(P) consumption(Q) income(Y)

* ---------------------------------------------------------------------
* A SYNTHETIC survey of 300 households
* ---------------------------------------------------------------------
clear
quietly set obs 300
set seed 4242
generate grp = cond(_n <= 180, "h1", "h2")
generate size = 1 + floor(runiform() * 5)
generate double inc_y = 50 + 200 * runiform()
generate double inc_f = 20 * runiform()
generate double cons = 0.9 * (inc_y + inc_f)
generate double b1 = cons * (0.2 + 0.3 * runiform())
generate double b2 = cons * (0.2 + 0.2 * runiform())
generate double b3 = cons - b1 - b2
generate double wt = 1 + runiform()

foreach s in richer supply {
    cge_microsim [pweight = wt], sim(`s') group(grp) consumption(cons) size(size) ///
        income(inc_y:Y inc_f:fixed) budget(b1:g1 b2:g2 b3:g3) line(40) generate(ms) replace
    local f0 = r(fgt0_base)
    local f1 = r(fgt0_sim)
    * the household's values, computed from the solution
    foreach g in h1 h2 {
        mata: st_local("yr_`g'", strofreal(_tms_val("`s'", "Y", "`g'") / _tms_val("", "Y", "`g'"), "%21.15g"))
    }
    foreach c in g1 g2 g3 {
        mata: st_local("pr_`c'", strofreal(_tms_val("`s'", "P", "`c'") / _tms_val("", "P", "`c'"), "%21.15g"))
    }
    tempvar nom pri gm d
    quietly generate double `nom' = cons * (inc_y * cond(grp == "h1", `yr_h1', `yr_h2') + inc_f) / (inc_y + inc_f)
    quietly generate double `pri' = (b1 * `pr_g1' + b2 * `pr_g2' + b3 * `pr_g3') / cons
    quietly generate double `gm' = exp((b1 * ln(`pr_g1') + b2 * ln(`pr_g2') + b3 * ln(`pr_g3')) / cons)
    quietly generate double `d' = max(reldif(ms_nom, `nom'), reldif(ms_price, `pri'), ///
        reldif(ms_pc, `nom' / `pri' / size), reldif(ms_ev, `nom' / `gm' - cons), reldif(ms_cv, `nom' - cons * `gm'))
    quietly summarize `d'
    assert r(max) < 1e-10
    * poverty from the generated consumption, with person weights
    quietly summarize size [iweight = wt * size]
    local tot = r(sum_w)
    quietly summarize size [iweight = wt * size] if ms_pc < 40
    assert reldif(`f1', r(sum_w) / `tot') < 1e-12
    quietly summarize size [iweight = wt * size] if cons / size < 40
    assert reldif(`f0', r(sum_w) / `tot') < 1e-12
    drop `nom' `pri' `gm' `d'
}
* the income of the second group does not change, nor the prices of g1 and
* g3 in the supply shock
assert `yr_h2' == 1 & reldif(`pr_g1', 1) < 1e-12 & reldif(`pr_g3', 1) < 1e-12

* without income() or budget(): the group's expenditure and base budget
* shares, which are the alpha of the group
cge_microsim [pweight = wt], sim(richer) group(grp) consumption(cons) size(size) generate(mg) replace nodisplay
foreach g in h1 h2 {
    mata: st_local("er_`g'", strofreal(_tms_val("richer", "Y", "`g'") / _tms_val("", "Y", "`g'"), "%21.15g"))
}
foreach c in g1 g2 g3 {
    mata: st_local("pr_`c'", strofreal(_tms_val("richer", "P", "`c'"), "%21.15g"))
}
tempvar d
quietly generate double `d' = reldif(mg_nom, cons * cond(grp == "h1", `er_h1', `er_h2'))
quietly replace `d' = max(`d', reldif(mg_price, cond(grp == "h1", 0.5 * `pr_g1' + 0.3 * `pr_g2' + 0.2 * `pr_g3', ///
    0.2 * `pr_g1' + 0.3 * `pr_g2' + 0.5 * `pr_g3')))
quietly replace `d' = max(`d', reldif(mg_ev, mg_nom / cond(grp == "h1", `pr_g1'^0.5 * `pr_g2'^0.3 * `pr_g3'^0.2, ///
    `pr_g1'^0.2 * `pr_g2'^0.3 * `pr_g3'^0.5) - cons))
quietly summarize `d'
assert r(max) < 1e-10
drop `d'

* ---------------------------------------------------------------------
* The decomposition: channels Y and prices, without taxes and savings; a
* scalar variable as a source
* ---------------------------------------------------------------------
cge_microsim [pweight = wt], sim(richer) group(grp) consumption(cons) size(size) ///
    income(inc_y:Y inc_f:PIDX) budget(b1:g1 b2:g2 b3:g3) line(40) decompose nodisplay
assert "`r(channels)'" == "Y PIDX prices"
matrix S = r(shapley)
local nc = colsof(S)
forvalues i = 1/`=rowsof(S)' {
    local sum = 0
    forvalues j = 2/`=`nc' - 1' {
        local sum = `sum' + S[`i', `j']
    }
    assert abs(S[`i', 1] + `sum' - S[`i', `nc']) < 1e-9 * max(1, abs(S[`i', `nc']))
}

* ---------------------------------------------------------------------
* Bands from draws of the parameters kept by cge_sensitivity
* ---------------------------------------------------------------------
capture program drop _tms_supply
program define _tms_supply
    cge_shock A, elements(g2) scale(0.8)
end
preserve
quietly cge_sensitivity, scenario(_tms_supply) draws(5) vary(eta) keep(sd) nodisplay
restore
cge_microsim [pweight = wt], sim(supply) group(grp) consumption(cons) size(size) line(40) bands(sd) nodisplay
assert r(N_draws) == 5
matrix BB = r(bands)
assert rowsof(BB) > 0

* ---------------------------------------------------------------------
* Errors
* ---------------------------------------------------------------------
capture noisily cge_microsim, sim(richer) group(grp) consumption(cons) income(inc_y:NOSUCH)
assert _rc == 111
capture noisily cge_microsim, sim(richer) group(grp) consumption(cons) income(inc_y:Q)
assert _rc == 198
capture noisily cge_microsim, sim(richer) group(grp) consumption(cons) income(inc_y:gov)
assert _rc == 111
capture noisily cge_microsim, sim(richer) group(grp) consumption(cons) budget(b1:nosuch)
assert _rc == 111
capture noisily cge_microsim, sim(richer) group(grp) consumption(cons) market(cons) dtax(b1)
assert _rc == 198
capture noisily cge_microsim, sim(richer) group(grp) consumption(cons) reweight(b1:1.1)
assert _rc == 198
replace grp = "h3" in 1
capture noisily cge_microsim, sim(richer) group(grp) consumption(cons)
assert _rc == 111
clear
capture program drop _tms_supply
capture mata: mata drop _tms_val()
