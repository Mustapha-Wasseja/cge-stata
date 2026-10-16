* test_sensitivity.do -- sensitivity analysis (version 0.2.1)

version 13.0

capture program drop _tariff_cut
program define _tariff_cut
    cge_shock tm, value(0)
end

* Health layout with a fund, LES demand, a top nest and the health link, and a
* closure that cge_sensitivity must keep after each recalibration
cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                            ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
local cal sigmava(0.8 0.6 1 0.9) sigmaq(2 1.5 1.2 2) sigmat(2 1.5 1.2 2) incelas(0.6 1 1.4 1.2) frisch(-2) ///
    sigmaa(0 0.5 1 0.5) healthcom(com_hlt) healthfac(lab) healthelas(0.3)
quietly cge_calibrate, `cal'
quietly cge_closure, factors(cap:specific)
cge_shock tm, value(0)
quietly cge_solve, name(central) tolerance(1e-12)
tempfile central
quietly cge_report, sims(central) clear nodisplay
quietly save `central'
cge_shock, reset

* Spread 0: every draw equals the central result, which equals a direct solve
cge_sensitivity, scenario(_tariff_cut) draws(3) spread(0) clear nodisplay
assert r(N_draws) == 3 & r(N_converged) == 3
quietly summarize pct if table != "elasticity" & measure == "gdp_real"
assert r(sd) < 1e-10
preserve
quietly keep if draw == 0 & table != "elasticity"
keep table measure element value
rename value v_sens
quietly merge 1:1 table measure element using `central', assert(match) nogenerate
assert abs(v_sens - value) <= 1e-9 * max(1, abs(value))
restore

* The model is restored: the earlier simulation is still there, unchanged
quietly cge_report, sims(central) clear nodisplay
cf _all using `central'

* Draws: within the bounds, reproducible with a seed, and each equal to a direct
* calibration with the drawn elasticities
tempfile s1 s2
cge_sensitivity, scenario(_tariff_cut) draws(5) seed(7) spread(0.4) vary(va q t a) saving("`s1'", replace)
cge_sensitivity, scenario(_tariff_cut) draws(5) seed(7) spread(0.4) vary(va q t a) clear nodisplay
quietly save `s2'
cf _all using `s1'
use `s1', clear
quietly bysort measure element (draw): generate double rel = value / value[1] if table == "elasticity"
quietly summarize rel if table == "elasticity" & draw > 0 & measure != "sigmaa"
assert r(min) >= 0.6 - 1e-12 & r(max) <= 1.4 + 1e-12 & r(sd) > 0
* Draw 3 by hand
foreach e in sigmava sigmaq sigmat sigmaa {
    quietly levelsof value if table == "elasticity" & draw == 3 & measure == "`e'", local(v) clean
    local `e' ""
    foreach a in act_agr act_man act_ser act_hlt com_agr com_man com_ser com_hlt {
        quietly summarize value if table == "elasticity" & draw == 3 & measure == "`e'" & element == "`a'"
        if r(N) local `e' "``e'' `=string(r(mean), "%21.17g")'"
    }
}
keep if draw == 3 & table != "elasticity"
keep table measure element pct
rename pct p_sens
tempfile d3
quietly save `d3'
cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                            ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
quietly cge_calibrate, sigmava(`sigmava') sigmaq(`sigmaq') sigmat(`sigmat') sigmaa(`sigmaa') ///
    incelas(0.6 1 1.4 1.2) frisch(-2) healthcom(com_hlt) healthfac(lab) healthelas(0.3)
quietly cge_closure, factors(cap:specific)
cge_shock tm, value(0)
quietly cge_solve, name(hand) tolerance(1e-12)
quietly cge_report, sims(hand) clear nodisplay
quietly merge 1:1 table measure element using `d3', assert(match) nogenerate
assert abs(p_sens - pct) <= 1e-6 * max(1, abs(pct)) if !missing(pct)

* One factor per elasticity type, and the triangular distribution
quietly cge_calibrate, `cal'
quietly cge_closure, factors(cap:specific)
cge_sensitivity, scenario(_tariff_cut) draws(4) common distribution(triangular) spread(0.5) clear
quietly bysort measure element (draw): generate double rel = value / value[1] if table == "elasticity"
quietly bysort draw measure (element): generate double gap = abs(rel - rel[1]) if table == "elasticity" & draw > 0
quietly summarize gap
assert r(max) < 1e-12
quietly summarize rel if table == "elasticity" & draw > 0 & measure != "sigmaa"
assert r(min) >= 0.5 & r(max) <= 1.5

* Errors
capture cge_sensitivity, scenario(nosuchprogram) draws(2)
assert _rc == 111
capture cge_sensitivity, scenario(_tariff_cut) draws(2) spread(1)
assert _rc == 198
capture cge_sensitivity, scenario(_tariff_cut) draws(2) vary(va zz)
assert _rc == 198
capture cge_sensitivity, scenario(_tariff_cut) draws(0)
assert _rc == 198

program drop _tariff_cut
