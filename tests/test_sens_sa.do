* test_sens_sa.do -- sensitivity analysis of standalone models (version
* 0.38.0; docs/model_spec.md, Section 48): draws of a supply elasticity
* against the price and welfare each implies; draws of incomes, which move
* the benchmark, with the changes measured from each draw's own benchmark;
* a calibrate() program that keeps the benchmark; draws kept as
* simulations; the model restored; items and variables in the sensitivity
* of a model from a SAM; errors.

version 13.0

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)

_cge_load
capture mata: mata drop _tss_nsims()
mata:
// The number of stored simulations, and the start of variable v, element el
void _tss_nsims(string scalar v, string scalar el)
{
    struct cge_model scalar M
    M = _cge_load()
    st_numscalar("tss_ns", rows(M.simname))
    st_numscalar("tss_x0", M.x0[_cge_u_vpos(M, v, el)])
}
end

* ---------------------------------------------------------------------
* 1. Two groups with Cobb-Douglas demands for three goods; the supply of g2
*    falls by a fifth, so that its price rises by 1.25^(1/(1+eta(g2))) and
*    both groups, which spend 30 per cent on it, lose 100 (P^-0.3 - 1) per
*    cent of their expenditure
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
cge_model roles, groups(h) goods(c) prices(P) consumption(Q) income(Y)
quietly cge_solve, name(bench)
mata: _tss_nsims("P", "g2")
local ns0 = scalar(tss_ns)

capture program drop _tss_supply
program define _tss_supply
    cge_shock A, elements(g2) scale(0.8)
end

cge_sensitivity, scenario(_tss_supply) draws(20) vary(eta) seed(2026) items(pg2 = P(g2)) clear
assert r(N_draws) == 20 & r(N_converged) == 20
* every draw against the price and welfare that its elasticity implies
quietly levelsof draw, local(draws)
assert wordcount("`draws'") == 21
foreach d of local draws {
    quietly summarize value if draw == `d' & table == "parameter" & measure == "eta" & element == "g2"
    local e = r(mean)
    local p = 1.25^(1 / (1 + `e'))
    quietly summarize value if draw == `d' & table == "items" & measure == "pg2"
    assert reldif(r(mean), `p') < 1e-9
    quietly summarize pct if draw == `d' & table == "welfare" & measure == "ev"
    assert reldif(r(min), 100 * (`p'^(-0.3) - 1)) < 1e-8 & reldif(r(max), r(min)) < 1e-10
    quietly summarize base if draw == `d' & table == "variables" & measure == "P" & element == "g2"
    assert reldif(r(mean), 1) < 1e-12
}
* the central draw has the central elasticity, 1; the others are within half
quietly summarize value if draw == 0 & table == "parameter" & measure == "eta" & element == "g2"
assert r(mean) == 1
quietly summarize value if draw > 0 & table == "parameter" & measure == "eta" & element == "g2"
assert r(min) >= 0.5 & r(max) <= 1.5 & r(sd) > 0.1
* the elements of eta are drawn separately, and with common together
quietly summarize value if draw > 0 & table == "parameter" & element == "g1"
local m1 = r(mean)
quietly summarize value if draw > 0 & table == "parameter" & element == "g3"
assert reldif(`m1', 2 * r(mean)) > 1e-6
* the model in memory is as it was
mata: _tss_nsims("P", "g2")
assert scalar(tss_ns) == `ns0' & scalar(tss_x0) == 1
quietly cge_sensitivity, scenario(_tss_supply) draws(5) vary(eta) common clear
quietly summarize value if draw > 0 & table == "parameter" & element == "g1"
local m1 = r(mean)
quietly summarize value if draw > 0 & table == "parameter" & element == "g3"
assert reldif(`m1', 2 * r(mean)) < 1e-12
* the same seed gives the same draws
quietly cge_sensitivity, scenario(_tss_supply) draws(5) vary(eta) seed(7) clear
quietly summarize pct if table == "items"
local s1 = r(sum)
quietly cge_sensitivity, scenario(_tss_supply) draws(5) vary(eta) seed(7) clear
quietly summarize pct if table == "items"
assert r(sum) == `s1'

* ---------------------------------------------------------------------
* 2. Draws of incomes move the benchmark: P(c)^(1+eta) = sum(h, alpha
*    ybar) / A(c) with A at its central value. Each draw is measured from
*    its own benchmark, so the change in the price of g2 is the same in
*    every draw, while its base is not
* ---------------------------------------------------------------------
cge_sensitivity, scenario(_tss_supply) draws(10) vary(ybar) seed(11) clear nodisplay
assert r(N_converged) == 10
quietly levelsof draw, local(draws)
foreach d of local draws {
    quietly summarize value if draw == `d' & table == "parameter" & element == "h1"
    local y1 = r(mean)
    quietly summarize value if draw == `d' & table == "parameter" & element == "h2"
    local y2 = r(mean)
    quietly summarize base if draw == `d' & table == "variables" & measure == "P" & element == "g2"
    assert reldif(r(mean), sqrt((0.3 * `y1' + 0.3 * `y2') / 45)) < 1e-9
    quietly summarize pct if draw == `d' & table == "variables" & measure == "P" & element == "g2"
    assert reldif(r(mean), 100 * (sqrt(1.25) - 1)) < 1e-8
}
quietly summarize base if table == "variables" & measure == "P" & element == "g2"
assert r(sd) > 1e-3

* ---------------------------------------------------------------------
* 3. A calibrate() program that sets A again from the drawn incomes keeps
*    the benchmark at prices of 1
* ---------------------------------------------------------------------
capture program drop _tss_calib
program define _tss_calib
    cge_parameter A(c) = sum(h, alpha(c,h) * ybar(h))
end
cge_sensitivity, scenario(_tss_supply) draws(10) vary(ybar) seed(11) calibrate(_tss_calib) clear nodisplay
assert r(N_converged) == 10
quietly summarize base if table == "variables" & measure == "P"
assert reldif(r(min), 1) < 1e-12 & reldif(r(max), 1) < 1e-12
quietly summarize pct if table == "variables" & measure == "P" & element == "g2"
assert reldif(r(min), 100 * (sqrt(1.25) - 1)) < 1e-8 & reldif(r(max), r(min)) < 1e-10
* outside calibrate(), a parameter used by the equations is changed by
* cge_shock, not assigned again
capture noisily cge_parameter A(c) = sum(h, alpha(c,h) * ybar(h))
assert _rc == 459

* ---------------------------------------------------------------------
* 4. Draws kept as simulations, a table chosen, and the default display
* ---------------------------------------------------------------------
cge_sensitivity, scenario(_tss_supply) draws(3) vary(eta) keep(kd) tables(groups)
cge_report, sims(kd0 kd1 kd2 kd3) tables(variables) variables(P) nodisplay
assert r(N_sims) == 4
cge_sensitivity, scenario(_tss_supply) draws(3) vary(eta) tables(all) nodisplay
cge_model roles, clear
cge_sensitivity, scenario(_tss_supply) draws(2) vary(eta)
cge_model roles, groups(h) goods(c) prices(P) consumption(Q) income(Y)

* ---------------------------------------------------------------------
* 5. Errors
* ---------------------------------------------------------------------
capture noisily cge_sensitivity, scenario(_tss_supply) draws(2)
assert _rc == 198
capture noisily cge_sensitivity, scenario(_tss_supply) draws(2) vary(nosuch)
assert _rc == 111
capture noisily cge_sensitivity, scenario(_tss_supply) draws(2) vary(eta eta)
assert _rc == 198
capture noisily cge_sensitivity, scenario(_tss_supply) draws(2) vary(eta) calibrate(nosuch)
assert _rc == 111
capture program drop _tss_bad
program define _tss_bad
    error 499
end
capture noisily cge_sensitivity, scenario(_tss_supply) draws(2) vary(eta) calibrate(_tss_bad)
assert _rc == 499
mata: _tss_nsims("P", "g2")
assert scalar(tss_ns) > 0 & scalar(tss_x0) == 1
capture noisily cge_sensitivity, scenario(_tss_supply) draws(2) vary(eta) tables(macro)
assert _rc == 198

* ---------------------------------------------------------------------
* 6. Items and variables in the sensitivity of a model from a SAM
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
capture program drop _tss_tariff
program define _tss_tariff
    cge_shock tm, value(0)
end
cge_sensitivity, scenario(_tss_tariff) draws(3) items(absorption = sum(c, PQ(c) * QQ(c))) variables(QA) clear
assert r(N_converged) == 3
quietly count if table == "items" & measure == "absorption"
assert r(N) == 4
quietly count if table == "variables" & measure == "QA"
assert r(N) == 12
quietly count if table == "elasticity" & draw == 0
assert r(N) > 0
capture noisily cge_sensitivity, scenario(_tss_tariff) draws(2) calibrate(_tss_calib)
assert _rc == 198
clear
capture program drop _tss_supply _tss_calib _tss_bad _tss_tariff
capture mata: mata drop _tss_nsims()
scalar drop tss_ns tss_x0
