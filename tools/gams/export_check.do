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
    trade home wagecurve minwage outcomes fquant
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
    quietly cge_solve, name(`case') tolerance(1e-12)
    assert r(converged) == 1
    if "`phase'" == "export" {
        cge_gams using `"`dir'/`case'"', sim(`case') replace
    }
    else {
        cge_gams using `"`dir'/`case'"', sim(`case') compare noexport
        post `post' ("`case'") ("`case'") (r(base_maxdiff)) (r(maxdiff)) (r(modelstat)) (r(base_modelstat)) ///
            (r(walras)) (r(N_compared))
    }
}
if "`phase'" == "compare" {
    postclose `post'
    use `"`dir'/export_check.dta"', clear
    export delimited using `"`dir'/export_check.csv"', replace
    list, noobs abbreviate(16)
}
