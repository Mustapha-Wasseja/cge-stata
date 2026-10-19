* test_fiscal.do -- fiscal instruments (version 0.3.1; docs/model_spec.md,
* Section 12): tax replacement closures, VAT with input credits, and public
* debt and interest, static and dynamic, against the Python reference

version 13.0

quietly do helpers_reference.do

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local instmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)             ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)
local debt debt(domestic:100 foreign:40) interest(domestic:0.05 foreign:0.03)

* ---------------------------------------------------------------------
* 1. VAT with input credits (12.2): act_agr exempt, act_ser half recovered
* ---------------------------------------------------------------------
cge_synthetic, clear vat
quietly cge_sam, labels(account)
cge_map, `stdmap' vattax(tax_vat)
cge_calibrate, `sigmas' vatcredit(act_agr:0 act_ser:0.5)
assert r(max_residual) < 1e-12
quietly cge_parameters, clear
quietly summarize value if parameter == "kappa" & element1 == "act_man"
assert r(mean) == 1
_standard_simulations vat_
cge_shock, reset
cge_shock tv, scale(1.2)
cge_solve, name(vat_rate_up20) tolerance(1e-12)
_compare_reference vat_rate_up20
_compare_report vat_rate_up20
cge_shock, reset
cge_shock kappa, value(1)
cge_solve, name(vat_credit_full) tolerance(1e-12)
_compare_reference vat_credit_full
cge_shock, reset

* The exact derivatives of the VAT model agree with differences, and the
* reduced and full systems give the same solution
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
mata: _cge_jaccheck(1)
assert r(maxdiff) < 1e-6
cge_shock tv, scale(1.2)
cge_solve, name(vat_full) tolerance(1e-12) full
_compare_reference vat_rate_up20
cge_shock, reset

* ---------------------------------------------------------------------
* 2. Revenue-neutral tax replacement (12.1)
* ---------------------------------------------------------------------
* Tariffs removed, VAT rates adjust; VAT rates cut, tariffs adjust
cge_closure, government(fixgsav vat)
assert "`r(closure)'" == "flexexr fixgsav:vat savings cpi lab:mobile cap:mobile"
cge_shock tm, value(0)
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
cge_solve, name(vat_tariff_removal_vat) tolerance(1e-12)
_compare_reference vat_tariff_removal_vat
_compare_report vat_tariff_removal_vat
cge_shock, reset
cge_closure, government(fixgsav:import)
cge_shock tv, scale(0.8)
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
cge_solve, name(vat_rate_cut_import) tolerance(1e-12)
_compare_reference vat_rate_cut_import
* The instrument cannot be shocked while it adjusts
capture cge_shock TMADJ, value(2)
assert _rc == 459
cge_shock, reset
cge_closure, government(flexgsav)

* Standard layout: sales taxes, or direct taxes, replace tariffs
quietly do setup_synthetic.do
cge_closure, government(fixgsav sales)
cge_shock tm, value(0)
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
cge_solve, name(rep_tariff_removal_sales) tolerance(1e-12)
_compare_reference rep_tariff_removal_sales
_compare_report rep_tariff_removal_sales
cge_closure, government(fixgsav direct)
assert "`r(closure)'" == "flexexr fixgsav savings cpi lab:mobile cap:mobile"
cge_solve, name(rep_tariff_removal_direct) tolerance(1e-12)
_compare_reference rep_tariff_removal_direct
* Closure errors: a tax without revenue, an unknown instrument
capture noisily cge_closure, government(fixgsav vat)
assert _rc == 459
capture noisily cge_closure, government(fixgsav export)
assert _rc == 198
capture noisily cge_closure, government(fixgsav sales direct)
assert _rc == 198
* VAT parameters need a VAT account
capture noisily cge_shock tv, scale(2)
assert _rc == 459
cge_shock, reset
cge_closure, government(flexgsav)

* VAT recorded within the sales tax of the standard layout
cge_synthetic, clear
quietly cge_sam, labels(account)
cge_map, `stdmap' vatshare(com_man:0.5 com_ser:1)
assert r(vat_moved) == 16
cge_calibrate, `sigmas'
cge_shock tm, value(0)
cge_solve, name(vshare_tariff_removal) tolerance(1e-12)
_compare_reference vshare_tariff_removal
quietly cge_samexport, clear mapped
assert com_man == 6 if account == "_vatshare"
assert com_ser == 0 if account == "tax_sal"
* A VAT introduced where the SAM has none: an empty VAT account, then a rate
cge_synthetic, clear
quietly cge_sam, labels(account)
cge_map, `stdmap' vatshare(0)
assert r(vat_moved) == 0
quietly cge_calibrate, `sigmas'
cge_shock tv, value(0.1)
cge_solve, name(vintro_vat10) tolerance(1e-12)
_compare_reference vintro_vat10
mata: _cge_jaccheck()
assert r(maxdiff) < 1e-6
cge_check, sim(vintro_vat10) homogeneity
* vatcredit() needs a VAT account; vattax() and vatshare() exclude each other
cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
capture noisily cge_calibrate, `sigmas' vatcredit(0.5)
assert _rc == 198
cge_synthetic, clear vat
quietly cge_sam, labels(account)
capture noisily cge_map, `stdmap' vattax(tax_vat) vatshare(0.5)
assert _rc == 198
quietly cge_map, `stdmap' vattax(tax_vat)
capture noisily cge_calibrate, `sigmas' vatcredit(act_agr:1.5)
assert _rc == 198

* A template records the VAT account; mapping from it gives the same model
tempfile tmpl
quietly cge_template using "`tmpl'.csv", replace
preserve
quietly import delimited using "`tmpl'.csv", varnames(1) stringcols(_all) clear
assert role == "vattax" if account == "tax_vat"
restore
cge_map using "`tmpl'.csv"
assert strpos(`"`r(command)'"', "vattax(tax_vat)") > 0
quietly cge_calibrate, `sigmas' vatcredit(act_agr:0 act_ser:0.5)
cge_shock tv, scale(1.2)
quietly cge_solve, name(vat_rate_up20) tolerance(1e-12)
_compare_reference vat_rate_up20
capture erase "`tmpl'.csv"

* ---------------------------------------------------------------------
* 3. Public debt and interest (12.3)
* ---------------------------------------------------------------------
cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, `instmap'
cge_calibrate, `sigmas' `debt'
assert r(max_residual) < 1e-12
quietly cge_parameters, clear
quietly summarize value if parameter == "phi"
assert abs(r(mean) - 40 / 140) < 1e-15
quietly summarize value if parameter == "trrg"
assert abs(r(mean) - (2 - 1.2)) < 1e-14
quietly summarize value if parameter == "hold" & element1 == "hhd"
assert abs(r(mean) - 15 / 23) < 1e-15
* The base is unchanged
cge_solve, name(base) tolerance(1e-12)
assert r(iterations) == 0
cge_shock rf, scale(2)
cge_solve, name(debt_rate_up) tolerance(1e-12)
_compare_reference debt_rate_up
_compare_report debt_rate_up
cge_shock, reset
cge_shock fdebt, scale(0.5)
cge_solve, name(debt_relief) tolerance(1e-12)
_compare_reference debt_relief
_compare_report debt_relief
cge_shock, reset
cge_closure, numeraire(dpi)
cge_shock tm, value(0)
cge_solve, name(debt_tariff_removal_dpi) tolerance(1e-12)
_compare_reference debt_tariff_removal_dpi
cge_shock, reset
cge_closure, numeraire(cpi)

* A saved model keeps its debt and VAT parameters
tempfile saved
quietly cge_save using "`saved'", replace
quietly cge_use using "`saved'"
quietly cge_solve, name(debt_relief2) tolerance(1e-12)
cge_shock fdebt, scale(0.5)
quietly cge_solve, name(debt_relief) tolerance(1e-12)
_compare_reference debt_relief
cge_shock, reset

* Debt errors
cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, `instmap'
capture noisily cge_calibrate, `sigmas' debt(domestic:1000) interest(domestic:0.05)
assert _rc == 459
capture noisily cge_calibrate, `sigmas' debt(foreign:400) interest(foreign:0.03)
assert _rc == 459
capture noisily cge_calibrate, `sigmas' `debt' debtholders(hhd:0.5)
assert _rc == 198
capture noisily cge_calibrate, `sigmas' debt(external:10)
assert _rc == 198
quietly cge_calibrate, `sigmas'
capture noisily cge_shock rd, scale(2)
assert _rc == 459

* Dynamic runs: deficits are borrowed; debt relief in period 2
quietly cge_calibrate, `sigmas' `debt'
quietly cge_closure, factors(cap:specific)
local common capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02) population(0.02) ///
    govgrowth(0.03) foreigngrowth(0.01)
cge_dynamic, name(debt) periods(0/4) `common' tfp(0.01)
forvalues t = 0/4 {
    _compare_period debt`t' dyn_debt_p`t'
    _compare_report debt`t' report_dyn_debt_p`t'
}
capture program drop _debt_relief
program define _debt_relief
    args t
    if `t' == 2 cge_shock fdebt, scale(0.5)
end
cge_dynamic, name(relief) periods(0/4) `common' tfp(0.01) shocks(_debt_relief)
forvalues t = 0/4 {
    _compare_period relief`t' dyn_debt_relief_p`t'
    _compare_report relief`t' report_dyn_debt_relief_p`t'
}

* ---------------------------------------------------------------------
* 4. A model saved by version 0.3.0 (tests/data/model_v030.cgem: the standard
*    layout with a tariff removal) gains the tax scaling factors and solves,
*    also under a replacement closure
* ---------------------------------------------------------------------
cge_use using "data/model_v030.cgem"
assert "`r(saved_by)'" == "0.3.0"
cge_solve, name(tariff_removal) tolerance(1e-12)
_compare_reference tariff_removal
cge_closure, government(fixgsav sales)
cge_solve, name(rep_tariff_removal_sales) tolerance(1e-12)
_compare_reference rep_tariff_removal_sales
