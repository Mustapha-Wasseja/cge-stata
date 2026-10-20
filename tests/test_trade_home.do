* test_trade_home.do -- trade and household extensions (version 0.3.2;
* docs/model_spec.md, Section 13): home consumption, export demand,
* export-only commodities and margins by market, against the Python reference

version 13.0

quietly do helpers_reference.do

local trademap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser com_cash) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                     ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)
local trade exportonly(com_cash) exportdemand(com_man:4 com_cash:2)

* ---------------------------------------------------------------------
* 1. Margins by market, an export-only cash crop and export demand
* ---------------------------------------------------------------------
cge_synthetic, clear trade
quietly cge_sam, labels(account)
cge_map, `trademap' domesticmargins(mtrd) importmargins(mtrm) exportmargins(mtre)
cge_calibrate, `sigmas' `trade'
assert r(max_residual) < 1e-12
quietly cge_parameters, clear
quietly summarize value if parameter == "icd" & element1 == "com_ser" & element2 == "com_man"
assert abs(r(mean) - 4 / 93) < 1e-15
quietly summarize value if parameter == "pwe" & element1 == "com_man"
assert abs(r(mean) - 40 / 38) < 1e-15
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
mata: _cge_jaccheck(1)
assert r(maxdiff) < 1e-6
_standard_simulations trade_
cge_shock, reset
cge_shock pwe, elements(com_man) scale(1.1)
cge_solve, name(trade_world_demand_up10) tolerance(1e-12)
_compare_reference trade_world_demand_up10
_compare_report trade_world_demand_up10
cge_shock, reset
cge_shock pwe, elements(com_cash) scale(0.8)
cge_solve, name(trade_cash_price_down20) tolerance(1e-12)
_compare_reference trade_cash_price_down20
* The full system gives the same solution
cge_solve, name(trade_full) tolerance(1e-12) full
_compare_reference trade_cash_price_down20
cge_check, sim(trade_full) homogeneity
cge_shock, reset

* A template records the margins by market; mapping from it gives the same model
tempfile tmpl
quietly cge_template using "`tmpl'.csv", replace
preserve
quietly import delimited using "`tmpl'.csv", varnames(1) stringcols(_all) clear
assert role == "domesticmargins" if account == "mtrd"
assert role == "importmargins" if account == "mtrm"
assert role == "exportmargins" if account == "mtre"
restore
cge_map using "`tmpl'.csv"
quietly cge_calibrate, `sigmas' `trade'
cge_shock tm, value(0)
quietly cge_solve, name(trade_tariff_removal) tolerance(1e-12)
_compare_reference trade_tariff_removal
capture erase "`tmpl'.csv"

* Export-only without margins by market; neither (the treatment before 0.3.2)
cge_synthetic, clear trade
quietly cge_sam, labels(account)
cge_map, `trademap' marginaccounts(mtrd mtrm mtre)
cge_calibrate, `sigmas' exportonly(com_cash)
cge_shock tm, value(0)
cge_solve, name(xonly_tariff_removal) tolerance(1e-12)
_compare_reference xonly_tariff_removal
cge_calibrate, `sigmas'
cge_shock tm, value(0)
cge_solve, name(tradeplain_tariff_removal) tolerance(1e-12)
_compare_reference tradeplain_tariff_removal

* Errors
capture noisily cge_calibrate, `sigmas' exportonly(com_man)
assert _rc == 459
capture noisily cge_calibrate, `sigmas' exportdemand(com_agr:2)
assert _rc == 459
capture noisily cge_calibrate, `sigmas' exportdemand(com_man:-1)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' exportdemand(com_xyz:2)
assert _rc == 111
cge_synthetic, clear trade
quietly cge_sam, labels(account)
capture noisily cge_map, `trademap' domesticmargins(mtrd) importmargins(mtrm) exportmargins(mtre com_cash)
assert _rc == 198 | _rc == 459

* ---------------------------------------------------------------------
* 2. Home consumption
* ---------------------------------------------------------------------
cge_synthetic, clear home
quietly cge_sam, labels(account)
cge_map, `stdmap'
cge_calibrate, `sigmas'
assert r(max_residual) < 1e-12
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
_standard_simulations home_
_compare_report home_tariff_removal
cge_shock, reset
cge_shock tq, elements(com_agr) scale(2)
cge_solve, name(home_sales_tax_agr_up) tolerance(1e-12)
_compare_reference home_sales_tax_agr_up
cge_check, sim(home_sales_tax_agr_up) homogeneity
cge_shock, reset

* With LES demand; then a dynamic run in which population growth scales the
* subsistence quantities of home goods
cge_calibrate, `sigmas' incelas(0.6 1 1.4) frisch(-2)
cge_shock tm, value(0)
cge_solve, name(home_les_tariff_removal) tolerance(1e-12)
_compare_reference home_les_tariff_removal
_compare_report home_les_tariff_removal
cge_shock, reset
quietly cge_closure, factors(cap:specific)
local common capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02) population(0.02) ///
    govgrowth(0.03) foreigngrowth(0.01)
cge_dynamic, name(home) periods(0/4) `common' tfp(0.01)
forvalues t = 0/4 {
    _compare_period home`t' dyn_home_p`t'
}

* The survey link prices home consumption at the activity price
quietly cge_closure, factors(cap:mobile)
cge_shock tm, value(0)
quietly cge_solve, name(notariff) tolerance(1e-12)
cge_shock, reset
quietly cge_results, sim(notariff) clear nodisplay
quietly summarize value if variable == "PA" & element1 == "act_agr"
local pa = r(mean)
clear
quietly set obs 2
generate str3 group = "hhd"
generate double cons = 100
generate double own = cond(_n == 1, 100, 0)
generate double food = cond(_n == 2, 100, 0)
cge_microsim, sim(notariff) group(group) consumption(cons) budget(own:act_agr food:com_agr) generate(m) nodisplay
assert abs(m_price[1] - `pa') < 1e-12
capture noisily cge_microsim, sim(notariff) group(group) consumption(cons) budget(own:act_xyz) nodisplay
assert _rc == 111
