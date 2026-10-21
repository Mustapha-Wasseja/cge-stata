* test_outcomes.do -- health outcomes, days worked and demography (version
* 0.3.4; docs/model_spec.md, Section 15), against the Python reference

version 13.0

quietly do helpers_reference.do

local hltmap activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)
local outcomes healthcom(com_hlt) sickdays(lab:0.05) sickelas(lab:-0.4) mortality(0.01) mortelas(-0.3)

* Value of a health report measure for a simulation
capture program drop _health
program define _health, rclass
    args sim measure element
    preserve
    quietly cge_report, sims(`sim') tables(health) clear nodisplay
    quietly summarize value if measure == "`measure'" & element == "`element'"
    return scalar value = r(mean)
    restore
end

* ---------------------------------------------------------------------
* 1. Days lost to illness and a death rate, linked to health services
* ---------------------------------------------------------------------
cge_synthetic, clear health
quietly cge_sam, labels(account)
cge_map, `hltmap'
cge_calibrate, `sigmas' `outcomes'
assert r(max_residual) < 1e-12
quietly cge_parameters, clear
quietly summarize value if parameter == "sick0" & element1 == "lab"
assert r(mean) == 0.05
quietly summarize value if parameter == "hlink"
assert r(mean) == 1
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
mata: _cge_jaccheck(0, 1)
assert r(maxdiff) < 1e-5
mata: _cge_jaccheck(1)
assert r(maxdiff) < 1e-6
_standard_simulations hout_
cge_shock, reset
cge_shock qg, elements(com_hlt) scale(1.2)
cge_solve, name(hout_gov_health_up20) tolerance(1e-12)
_compare_reference hout_gov_health_up20
_compare_report hout_gov_health_up20
cge_shock, reset
cge_shock sick, elements(lab) scale(2)
cge_solve, name(hout_epidemic) tolerance(1e-12)
_compare_reference hout_epidemic
_compare_report hout_epidemic
cge_check, sim(hout_epidemic) homogeneity
quietly cge_closure, factors(lab:unemployed)
cge_solve, name(hout_epidemic_unemployed) tolerance(1e-12)
_compare_reference hout_epidemic_unemployed
quietly cge_closure, factors(lab:mobile)
cge_shock, reset
* A higher death rate changes nothing within the period
cge_shock mort, scale(1.5)
cge_solve, name(hout_mortality_up50) tolerance(1e-12)
assert r(iterations) == 0
_compare_reference hout_mortality_up50
_compare_report hout_mortality_up50
cge_shock, reset
_health hout_mortality_up50 mortality_rate
assert abs(r(value) - 15) < 1e-12
* More health services: fewer days lost and a lower death rate
_health hout_gov_health_up20 sick_day_share lab
assert r(value) < 5
_health hout_gov_health_up20 mortality_rate
assert r(value) < 10

* Days worked act as efficiency per worker: without days lost, labour
* efficiency equal to the epidemic's days worked gives the same solution
preserve
quietly cge_results, sim(hout_epidemic) clear nodisplay
quietly summarize value if variable == "DW" & element1 == "lab"
local dw = r(mean)
quietly summarize value if variable == "QA" & element1 == "act_agr"
local qa = r(mean)
restore
assert `dw' < 1
tempfile saved
quietly cge_save using "`saved'", replace
quietly cge_calibrate, `sigmas'
cge_shock af, elements(lab) value(`dw')
quietly cge_solve, name(asaf) tolerance(1e-12)
cge_shock, reset
preserve
quietly cge_results, sim(asaf) clear nodisplay
quietly summarize value if variable == "QA" & element1 == "act_agr"
assert reldif(r(mean), `qa') < 1e-9
restore

* A saved model keeps its outcomes
cge_use using "`saved'"
cge_shock sick, elements(lab) scale(2)
quietly cge_solve, name(hout_epidemic) tolerance(1e-12)
_compare_reference hout_epidemic
cge_shock, reset

* With the efficiency link as well
cge_calibrate, `sigmas' `outcomes' healthfac(lab) healthelas(0.3)
cge_shock qg, elements(com_hlt) scale(1.2)
cge_solve, name(hboth_gov_health_up20) tolerance(1e-12)
_compare_reference hboth_gov_health_up20
_compare_report hboth_gov_health_up20
cge_shock, reset

* ---------------------------------------------------------------------
* 2. Population and labour respond to deaths in dynamic runs
* ---------------------------------------------------------------------
capture program drop _health_up
program define _health_up
    args t
    if `t' == 1 cge_shock qg, elements(com_hlt) scale(1.2)
end
cge_calibrate, `sigmas' `outcomes'
quietly cge_closure, factors(cap:specific)
local common capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02) population(0.02) ///
    govgrowth(0.03) foreigngrowth(0.01) tfp(0.01) deathfactors(lab) deathshare(0.3) workingage(0.55)
cge_dynamic, name(hout) periods(0/4) `common'
cge_dynamic, name(houth) periods(0/4) `common' shocks(_health_up)
forvalues t = 0/4 {
    _compare_period hout`t' dyn_hout_p`t'
    _compare_period houth`t' dyn_hout_health_p`t'
    _compare_report hout`t' report_dyn_hout_p`t'
    _compare_report houth`t' report_dyn_hout_health_p`t'
}
* Fewer deaths from period 1 give a larger population from period 2
_health hout2 population
local p2 = r(value)
_health houth2 population
assert r(value) > `p2'

* ---------------------------------------------------------------------
* 3. Outcomes with zero elasticities need no health services
* ---------------------------------------------------------------------
cge_synthetic, clear
quietly cge_sam, labels(account)
cge_map, `stdmap'
cge_calibrate, `sigmas' sickdays(lab:0.05) mortality(0.01)
cge_shock sick, elements(lab) value(0.1)
quietly cge_solve, name(sick10) tolerance(1e-12)
cge_shock, reset
preserve
quietly cge_results, sim(sick10) clear nodisplay
quietly summarize value if variable == "DW" & element1 == "lab"
assert reldif(r(mean), 0.9 / 0.95) < 1e-14
quietly count if variable == "HS"
assert r(N) == 0
restore

* ---------------------------------------------------------------------
* 4. Errors
* ---------------------------------------------------------------------
capture noisily cge_calibrate, `sigmas' sickdays(lab:1)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' sickdays(lab:0.05) sickelas(cap:-0.2)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' sickdays(lab:0.05) sickelas(-0.2)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' mortelas(-0.3)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' mortality(1.2)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' sickdays(xyz:0.05)
assert _rc == 111
cge_calibrate, `sigmas'
capture noisily cge_shock sick, elements(lab) scale(2)
assert _rc == 459
capture noisily cge_shock mort, scale(2)
assert _rc == 459
quietly cge_closure, factors(cap:specific)
capture noisily cge_dynamic, name(bad) periods(0/1) capital(cap) depreciation(0.05) rental(0.15) deathfactors(lab)
assert _rc == 198
cge_calibrate, `sigmas' sickdays(lab:0.05) mortality(0.01)
quietly cge_closure, factors(cap:specific)
capture noisily cge_dynamic, name(bad) periods(0/1) capital(cap) depreciation(0.05) rental(0.15) deathfactors(cap)
assert _rc == 198
capture noisily cge_dynamic, name(bad) periods(0/1) capital(cap) depreciation(0.05) rental(0.15) ///
    deathfactors(lab) deathshare(1.5)
assert _rc == 198
capture noisily cge_dynamic, name(bad) periods(0/1) capital(cap) depreciation(0.05) rental(0.15) deathshare(0.3)
assert _rc == 198
capture noisily cge_shock sick, elements(lab) value(1)
assert _rc == 198
