* export_check.do -- cases for the check of cge_gams (version 0.4.3; see
* run_export_check.py, which runs this file twice):
*   do export_check.do export DIR    solve each case in Stata and export it to DIR/<case>
*   do export_check.do compare DIR   solve each case again and compare it with the
*                                    GAMS results in DIR/<case>; writes DIR/export_check.csv
* The synthetic SAMs describe no country; the elasticities are illustrative.

version 13.0
args phase dir
if !inlist("`phase'", "export", "compare") | `"`dir'"' == "" {
    display as error "usage: do export_check.do export|compare DIR"
    exit 198
}
clear all
set more off

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local instmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)             ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local hltmap activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
local trademap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser com_cash) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                     ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sutmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser com_fuel) ///
    factors(lab cap) households(hhd) government(gov) savinv(si) row(row)                      ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) marginaccounts(trd trp) stocks(dstk)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)

* Each case: data, mapping, calibration, closure and shocks; one simulation
local cases std closures unemployed mixed inst_les margins territorial sut health vat debt ///
    trade home wagecurve minwage outcomes fquant quota capacity peglimit nodeficit wagefloor swaps ftax ///
    nests nestvat outces
local ncase : word count `cases'

tempname post
if "`phase'" == "compare" {
    postfile `post' str20 case str20 sim double(base_maxdiff maxdiff modelstat base_modelstat walras N) ///
        using `"`dir'/export_check.dta"', replace
}
foreach case of local cases {
    display as text _n "{hline 60}" _n "Case " as result "`case'"
    if "`case'" == "std" {
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas'
        cge_shock tm, value(0)
    }
    else if "`case'" == "closures" {
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas'
        quietly cge_closure, external(fixexr) government(fixgsav sales) savinv(investment) numeraire(dpi) ///
            factors(cap:specific)
        cge_shock pwm, scale(1.1)
        cge_shock QFS, elements(lab) scale(1.05)
    }
    else if "`case'" == "unemployed" {
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas'
        quietly cge_closure, government(fixgsav import) factors(lab:unemployed)
        cge_shock FSAV, scale(0.8)
        cge_shock W, elements(lab) scale(0.98)
    }
    else if "`case'" == "mixed" {
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, sigmava(0.5 1 1.5) sigmaq(0.6 3 1.2) sigmat(0.7 4 1) sigmaa(0.5 1 0)
        cge_shock ad, elements(act_agr) scale(1.05)
        cge_shock ta, elements(act_man) value(0.02)
    }
    else if "`case'" == "inst_les" {
        quietly cge_synthetic, clear institutions
        quietly cge_sam, labels(account)
        quietly cge_map, `instmap'
        quietly cge_calibrate, `sigmas' incelas(0.6 1 1.4) frisch(-2 -3)
        quietly cge_closure, government(fixgsav)
        cge_shock trdr, scale(0.5)
        cge_shock tm, value(0)
    }
    else if "`case'" == "margins" {
        quietly cge_synthetic, clear margins
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap' margins(act_ser)
        quietly cge_calibrate, `sigmas'
        cge_shock tm, value(0)
    }
    else if "`case'" == "territorial" {
        quietly cge_synthetic, clear territorial
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap' territorial(com_tc act_tc)
        quietly cge_calibrate, `sigmas'
        cge_shock pwm, scale(1.1)
    }
    else if "`case'" == "sut" {
        quietly cge_synthetic, clear sut
        quietly cge_sam, labels(account)
        quietly cge_map, `sutmap'
        quietly cge_calibrate, `sigmas'
        cge_shock pwe, elements(com_agr) scale(1.1)
        cge_shock qinv, scale(1.1)
    }
    else if "`case'" == "health" {
        quietly cge_synthetic, clear health
        quietly cge_sam, labels(account)
        quietly cge_map, `hltmap'
        quietly cge_calibrate, `sigmas' healthcom(com_hlt) healthfac(lab) healthelas(0.3)
        cge_shock qg, elements(com_hlt) scale(1.2)
        cge_shock tshi, elements(lab) scale(1.5)
    }
    else if "`case'" == "vat" {
        quietly cge_synthetic, clear vat
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap' vattax(tax_vat)
        quietly cge_calibrate, `sigmas' vatcredit(act_agr:0 act_ser:0.5)
        quietly cge_closure, government(fixgsav vat)
        cge_shock tm, value(0)
        cge_shock kappa, elements(act_agr) value(1)
    }
    else if "`case'" == "debt" {
        quietly cge_synthetic, clear institutions
        quietly cge_sam, labels(account)
        quietly cge_map, `instmap'
        quietly cge_calibrate, `sigmas' debt(domestic:100 foreign:40) interest(domestic:0.05 foreign:0.03)
        cge_shock rf, scale(2)
        cge_shock rd, scale(1.5)
    }
    else if "`case'" == "trade" {
        quietly cge_synthetic, clear trade
        quietly cge_sam, labels(account)
        quietly cge_map, `trademap' domesticmargins(mtrd) importmargins(mtrm) exportmargins(mtre)
        quietly cge_calibrate, `sigmas' exportonly(com_cash) exportdemand(com_man:4 com_cash:2)
        cge_shock pwe, elements(com_cash) scale(0.8)
        cge_shock pwe, elements(com_man) scale(1.1)
    }
    else if "`case'" == "home" {
        quietly cge_synthetic, clear home
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas' incelas(0.6 1 1.4) frisch(-2)
        cge_shock tq, elements(com_agr) scale(2)
    }
    else if "`case'" == "wagecurve" {
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas' unemployment(lab:0.15) wagecurve(lab:0.1)
        quietly cge_closure, factors(lab:wagecurve)
        cge_shock pwm, scale(1.1)
        cge_shock qlf, elements(lab) scale(1.02)
    }
    else if "`case'" == "minwage" {
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas' minwage(lab:0.95)
        quietly cge_closure, factors(lab:minwage)
        cge_shock pwm, scale(1.5)
    }
    else if "`case'" == "outcomes" {
        quietly cge_synthetic, clear health
        quietly cge_sam, labels(account)
        quietly cge_map, `hltmap'
        quietly cge_calibrate, `sigmas' healthcom(com_hlt) sickdays(lab:0.05) sickelas(lab:-0.4) ///
            mortality(0.01) mortelas(-0.3)
        cge_shock sick, elements(lab) scale(2)
        cge_shock qg, elements(com_hlt) scale(1.2)
    }
    else if "`case'" == "fquant" {
        matrix fq = (80, 20, 30 \ 37, 40, 50)
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas' fquantities(fq)
        cge_shock tm, value(0)
    }
    * Constraints (version 0.4.4), solved in GAMS as mixed complementarity problems
    else if "`case'" == "quota" {
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas'
        cge_shock tm, value(0)
        cge_constraint QM, elements(com_man) upper(1.02) scale rents(hhd)
    }
    else if "`case'" == "capacity" {
        quietly cge_synthetic, clear health
        quietly cge_sam, labels(account)
        quietly cge_map, `hltmap'
        quietly cge_calibrate, `sigmas'
        cge_shock qg, elements(com_hlt) scale(1.2)
        cge_constraint QA, elements(act_hlt) upper(1.03) scale rents(cap)
    }
    else if "`case'" == "peglimit" {
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas'
        quietly cge_closure, external(fixexr)
        cge_shock pwe, scale(0.8)
        cge_constraint FSAV, upper(2) scale adjust(EXR) up
    }
    else if "`case'" == "nodeficit" {
        quietly cge_synthetic, clear institutions
        quietly cge_sam, labels(account)
        quietly cge_map, `instmap'
        quietly cge_calibrate, `sigmas'
        cge_shock tm, value(0)
        cge_constraint QM, elements(com_man) upper(1.02) scale rents(row)
        cge_constraint GSAV, lower(0) adjust(GADJ) down
    }
    else if "`case'" == "wagefloor" {
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas'
        cge_shock pwm, scale(1.1)
        cge_constraint W, elements(lab) lower(1) scale adjust(QFS) down
    }
    * Closure swaps (version 0.4.5)
    else if "`case'" == "swaps" {
        quietly cge_synthetic, clear institutions
        quietly cge_sam, labels(account)
        quietly cge_map, `instmap'
        quietly cge_calibrate, `sigmas'
        quietly cge_closure, swap(GSAV GADJ W(lab) QFS(lab))
        cge_shock tm, value(0)
        cge_shock GSAV, scale(1.5)
    }
    * Taxes on factor use and income (version 0.5.0)
    else if "`case'" == "ftax" {
        quietly cge_synthetic, clear factortax
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap' factortax(tax_pay:lab) factorincometax(tax_fy)
        quietly cge_calibrate, sigmava(0.5 1 1.5) sigmaq(0.6 3 1.2) sigmat(0.7 4 1)
        cge_shock tf, elements(lab) scale(0.5)
        cge_shock tf, elements(cap) value(0.05)
        cge_shock tfy, elements(cap) scale(2)
    }
    * Nests of value added (version 0.5.1): Cobb-Douglas value added in one
    * activity and a Cobb-Douglas labour nest; dearer energy and a payroll tax cut
    else if "`case'" == "nests" {
        quietly cge_synthetic, clear nests
        quietly cge_sam, labels(account)
        quietly cge_map, activities(act_agr act_man act_ser act_ene) commodities(com_agr com_man com_ser com_ene) ///
            factors(lab_hi lab_lo cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir)    ///
            saltax(tax_sal) imptax(tax_imp) factortax(tax_pay:lab_hi)
        quietly cge_calibrate, sigmava(0.5 1 1.5 0.8) sigmaq(2) sigmat(2) nests(labour: lab_hi lab_lo, ke: cap com_ene) ///
            sigmanest(labour:1 ke:0.25)
        cge_shock pwm, elements(com_ene) scale(1.5)
        cge_shock tf, elements(lab_hi) scale(0.5)
    }
    * Output of manufactures from two activities, combined by a CES function
    * (version 0.5.2), with mixed elasticities
    else if "`case'" == "outces" {
        quietly cge_synthetic, clear multiproduct
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, sigmava(0.5 1 1.5) sigmaq(0.6 3 1.2) sigmat(0.7 4 1) sigmaac(com_man:2)
        cge_shock ad, elements(act_agr) scale(1.05)
        cge_shock pwm, scale(1.1)
    }
    * A nest of capital and manufactures, with VAT not every activity recovers
    else if "`case'" == "nestvat" {
        quietly cge_synthetic, clear vat
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap' vattax(tax_vat)
        quietly cge_calibrate, `sigmas' vatcredit(act_agr:0 act_ser:0.5) nests(km: cap com_man) sigmanest(0.5)
        quietly cge_closure, factors(cap:specific)
        cge_shock tv, scale(1.2)
    }
    quietly cge_solve, name(`case') tolerance(1e-12)
    assert r(converged) == 1
    if "`phase'" == "export" {
        cge_gams using `"`dir'/`case'"', sim(`case') replace
    }
    else {
        * cases that GAMS did not solve (constraints with a solver that is not an MCP solver)
        capture confirm file `"`dir'/`case'/cge_`case'.csv"'
        if _rc continue
        cge_gams using `"`dir'/`case'"', sim(`case') compare noexport
        post `post' ("`case'") ("`case'") (r(base_maxdiff)) (r(maxdiff)) (r(modelstat)) (r(base_modelstat)) ///
            (r(walras)) (r(N_compared))
    }
}
* Dynamic runs (version 0.5.3): every period exported, and solved by GAMS in
* order, each from the solution of the period before
local dyncommon capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02) population(0.02) ///
    govgrowth(0.03) foreigngrowth(0.01)
capture program drop _donor_exit _debt_relief
program define _donor_exit
    args t
    if `t' >= 2 cge_shock trshir, value(0)
end
program define _debt_relief
    args t
    if `t' == 2 cge_shock fdebt, scale(0.5)
end
foreach case in dyninst dynhealth dyndebt {
    display as text _n "{hline 60}" _n "Case " as result "`case'"
    if "`case'" == "dyninst" {
        * LES demand, whose subsistence quantities grow with population
        quietly cge_synthetic, clear institutions
        quietly cge_sam, labels(account)
        quietly cge_map, `instmap'
        quietly cge_calibrate, `sigmas' incelas(0.6 1 1.4) frisch(-2 -3)
        quietly cge_dynamic, name(dyninst) periods(0/3) capital(cap) depreciation(0.06) rental(0.12) ///
            growth(lab:0.025) population(0.025) govgrowth(0.03) foreigngrowth(0.02) tfp(0.02 0.01 0)
    }
    else if "`case'" == "dynhealth" {
        * the health link, capital specific to each activity, efficiency
        * calibrated to a growth target, and a donor exit from the insurance fund
        quietly cge_synthetic, clear health
        quietly cge_sam, labels(account)
        quietly cge_map, `hltmap'
        quietly cge_calibrate, `sigmas' healthcom(com_hlt) healthfac(lab) healthelas(0.3)
        quietly cge_closure, factors(cap:specific)
        quietly cge_dynamic, name(health) periods(0/3) `dyncommon' gdpgrowth(0.03)
        quietly cge_dynamic, name(dynhealth) periods(0/3) `dyncommon' baseline(health) shocks(_donor_exit)
    }
    else if "`case'" == "dyndebt" {
        * public debt, which grows with each period's deficit, and debt relief
        * in period 2
        quietly cge_synthetic, clear institutions
        quietly cge_sam, labels(account)
        quietly cge_map, `instmap'
        quietly cge_calibrate, `sigmas' debt(domestic:100 foreign:40) interest(domestic:0.05 foreign:0.03)
        quietly cge_closure, factors(cap:specific)
        quietly cge_dynamic, name(dyndebt) periods(0/3) `dyncommon' tfp(0.01) shocks(_debt_relief)
    }
    if "`phase'" == "export" {
        cge_gams using `"`dir'/`case'"', dynamic(`case') replace
    }
    else {
        capture confirm file `"`dir'/`case'/cge_`case'3.csv"'
        if _rc continue
        cge_gams using `"`dir'/`case'"', dynamic(`case') compare noexport
        post `post' ("`case'") ("`case'") (r(base_maxdiff)) (r(maxdiff)) (r(modelstat)) (r(base_modelstat)) ///
            (r(walras)) (r(N_compared))
    }
}
program drop _donor_exit _debt_relief

if "`phase'" == "compare" {
    postclose `post'
    use `"`dir'/export_check.dta"', clear
    export delimited using `"`dir'/export_check.csv"', replace
    list, noobs abbreviate(16)
}
