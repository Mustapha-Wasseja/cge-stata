* test_reporting.do -- report tables, parameters, and saving and loading a model
* (version 0.1.15; docs/model_spec.md, Section 9)

version 13.0

quietly do helpers_reference.do

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

* Standard layout
quietly do setup_synthetic.do
cge_shock tm, value(0)
quietly cge_solve, name(tariff_removal) tolerance(1e-12)
_compare_report tariff_removal

* Enterprise, non-profit institution and transfers abroad
cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)                ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock trdr, scale(0.5)
quietly cge_solve, name(inst_transfers_abroad_down50) tolerance(1e-12)
_compare_report inst_transfers_abroad_down50

* LES demand: equivalent and compensating variations
quietly do setup_synthetic.do "sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1 1.4) frisch(-2)"
cge_shock pwm, scale(1.1)
quietly cge_solve, name(les_import_price_up10) tolerance(1e-12)
_compare_report les_import_price_up10

* Supply-use layout: margins, an imported-only commodity, exports from composite supply
cge_synthetic, clear sut
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser com_fuel) ///
    factors(lab cap) households(hhd) government(gov) savinv(si) row(row)                         ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) marginaccounts(trd trp) stocks(dstk)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock pwm, scale(1.1)
quietly cge_solve, name(sut_import_price_up10) tolerance(1e-12)
_compare_report sut_import_price_up10

* Health layout: fund and health link, with the health table
local hltmap activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                            ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
local hltcal sigmava(0.8) sigmaq(2) sigmat(2) healthcom(com_hlt) healthfac(lab) healthelas(0.3)
cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, `hltmap'
quietly cge_calibrate, `hltcal'
cge_shock tshi, elements(lab) scale(1.5)
quietly cge_solve, name(eff_contribution_up50) tolerance(1e-12)
_compare_report eff_contribution_up50

* Several simulations, displayed, and saved to Excel (one sheet per table)
cge_shock, reset
cge_shock qg, elements(com_hlt) scale(1.2)
quietly cge_solve, name(gov_health) tolerance(1e-12)
cge_report, sims(eff_contribution_up50 gov_health) tables(macro health welfare)
assert r(N_sims) == 2
tempfile xl
local xl "`xl'.xlsx"
cge_report, sims(_all) nodisplay saving("`xl'", replace)
preserve
quietly import excel using "`xl'", sheet("health") firstrow clear
assert _N == 4
quietly import excel using "`xl'", sheet("macro") firstrow clear
assert _N == 17
restore
capture cge_report, tables(nosuchtable) nodisplay
assert _rc == 198
capture cge_report, sims(nosuchsim) nodisplay
assert _rc == 111

* Parameters as a dataset
cge_parameters, clear
quietly count if parameter == "ica"
assert r(N) == 16
quietly summarize value if parameter == "tshi" & element1 == "lab"
assert abs(r(mean) - 6 / 135) < 1e-12
quietly summarize value if parameter == "etah" & element1 == "lab"
assert r(mean) == 0.3
cge_parameters, clear sim(eff_contribution_up50)
quietly summarize value if parameter == "tshi" & element1 == "lab"
assert abs(r(mean) - 1.5 * 6 / 135) < 1e-12

* Save and load: the loaded model holds every simulation, reports the same
* results and solves again to the same point
tempfile r1 r2 fn
local fn "`fn'.cgem"
quietly cge_report, sims(_all) clear nodisplay
quietly save `r1'
cge_save using "`fn'", replace
capture cge_save using "`fn'"
assert _rc == 602
mata: rmexternal("cge__model")
capture cge_report, nodisplay
assert _rc == 459
cge_use using "`fn'"
quietly cge_report, sims(_all) clear nodisplay
quietly save `r2'
use `r1', clear
cf _all using `r2'
cge_shock, reset
cge_shock tshi, elements(lab) scale(1.5)
quietly cge_solve, name(again) tolerance(1e-12)
quietly cge_results, sim(again) clear nodisplay
rename value again
tempfile again
quietly save `again'
quietly cge_results, sim(eff_contribution_up50) clear nodisplay
quietly merge 1:1 variable element1 element2 using `again', assert(match) nogenerate
assert abs(value - again) <= 1e-9 * max(1, abs(value))
cge_check, homogeneity perturb(0.1)
assert r(failures) == 0

* A model saved before calibration can be loaded and calibrated
cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, `hltmap'
cge_save using "`fn'", replace
mata: rmexternal("cge__model")
cge_use using "`fn'"
quietly cge_calibrate, `hltcal'
assert r(max_residual) < 1e-12
capture cge_use using "`r1'"
assert _rc == 610

program drop _compare_report
