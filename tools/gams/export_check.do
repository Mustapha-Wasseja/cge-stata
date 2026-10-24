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
    nests nestvat outces user usersets conditions inequalities pairs replace cgenest functions bounds boundscon
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
    * User variables and equations (version 0.6.1): real government savings
    * and nominal government consumption fixed through them
    else if "`case'" == "user" {
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas'
        cge_variable RGSAV = GSAV / CPI
        cge_variable GEXP = sum(c, PQ(c) * QG(c)), nominal
        cge_variable PREL(c) = PQ(c) * (1 + tv(c)) / CPI
        cge_variable LAM, value(1)
        cge_equation lam: QINV(com_man) = LAM * base(QINV(com_man)) * exp(0 * ln(CPI))
        quietly cge_closure, swap(RGSAV TINSADJ GEXP GADJ)
        cge_shock pwm, scale(1.1)
        cge_shock tm, value(0)
    }
    * User sets and parameters (version 0.7.1): a target for government
    * health purchases set by a user parameter, shocked, and a price index
    * with weights of the user's own over a user set
    else if "`case'" == "usersets" {
        quietly cge_synthetic, clear health
        quietly cge_sam, labels(account)
        quietly cge_map, `hltmap'
        quietly cge_calibrate, `sigmas'
        cge_set goods = c, except(com_ser com_hlt)
        cge_parameter hgoal = 1.1
        cge_parameter wg(goods), values(com_agr:2) default(1)
        cge_parameter sh(c,h), values(com_hlt.hhd:0.5) default(0.1)
        cge_variable PIDX = sum(goods, wg(goods) * PQ(goods)) + sh(com_hlt, hhd) * PQ(com_hlt)
        cge_variable LAM, value(1)
        cge_equation lam: QG(com_hlt) = LAM * hgoal * base(QG(com_hlt))
        quietly cge_closure, swap(LAM GADJ)
        cge_shock hgoal, value(1.2)
        cge_shock wg, elements(com_man) scale(2)
        cge_shock tm, value(0)
    }
    * conditions (version 0.7.2): conditional sums and terms, variables and
    * equations over conditional domains, and a target for government
    * purchases of goods only
    else if "`case'" == "conditions" {
        quietly cge_synthetic, clear health
        quietly cge_sam, labels(account)
        quietly cge_map, `hltmap'
        quietly cge_calibrate, `sigmas'
        cge_set goods = c, except(com_ser com_hlt)
        cge_variable MT = sum(c$(tm(c) > 0), PM(c) * QM(c)), nominal
        cge_variable GH = sum(c, (PQ(c) * QG(c))$(goods(c) | ord(c) == 4))
        cge_variable TMV(c)$(tm(c) > 0) = tm(c) * PM(c) * QM(c)
        cge_variable TOUT = TMV(com_ser) + 1
        cge_variable LAMC(c)$(goods(c)), value(1)
        cge_equation lc(c)$(goods(c)): QM(c) = LAMC(c) * base(QM(c))
        cge_variable LAM, value(1)
        cge_equation lam: sum(c$(goods(c)), QG(c)) = LAM * sum(c$(goods(c) & !sameas(c, com_hlt)), base(QG(c)))
        quietly cge_closure, swap(LAM GADJ)
        cge_shock LAM, value(1.1)
        cge_shock tm, value(0)
    }
    * inequalities paired with variables (version 0.9.0): an import quota with
    * its premium, a floor on government purchases with GADJ, a floor on a
    * relative price with an exogenous user variable, and an upper bound on a
    * defined user variable; every bound holds in the base
    else if "`case'" == "inequalities" {
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas'
        cge_equation quota: QM(com_man) =l= 1.02 * base(QM(com_man)), perp(RM(com_man))
        cge_equation gmin: QG(com_ser) >= 0.95 * base(QG(com_ser)), perp(GADJ)
        cge_variable FLOOR, lower(0)
        cge_variable PRF = PQ(com_agr) / CPI + FLOOR
        cge_equation pf: PRF >= 0.9999, perp(FLOOR)
        cge_variable PRU = PQ(com_agr) / CPI, upper(1.0001)
        cge_shock tm, value(0)
        cge_shock qg, elements(com_ser) scale(0.9)
    }
    * two indexes and sets of pairs (version 0.9.1): variables and equations
    * over (c,h), a sum over two indexes with a condition, sums and a domain
    * over a set of pairs of activities and commodities, a target over the
    * pairs met by GADJ, an exogenous variable over (c,h) that is shocked,
    * and a floor element by element with its own adjuster
    else if "`case'" == "pairs" {
        quietly cge_synthetic, clear institutions
        quietly cge_sam, labels(account)
        quietly cge_map, `instmap'
        quietly cge_calibrate, `sigmas'
        cge_set map(a,c) = act_agr.com_agr act_ser.com_ser
        cge_variable XH(c,h) = PQ(c) * QH(c, h), nominal
        cge_variable XS = sum((c,h)$(base(QH(c, h)) > 0), XH(c,h)), nominal
        cge_variable VM = sum(map(a,c), PA(a) * QA(a) - PQ(c) * QG(c))
        cge_variable Y(a,c)$(map(a,c)) = PA(a) / PQ(c)
        cge_variable LH(c,h)$(base(QH(c, h)) > 0), value(1)
        cge_equation lh(c,h)$(base(QH(c, h)) > 0): QH(c, h) = LH(c,h) * base(QH(c, h))
        cge_variable FX(c,h), value(1) fixed
        cge_variable FL(c,h), lower(0)
        cge_variable PH2(c,h) = PQ(c) * FX(c,h) + FL(c,h)
        cge_equation fl(c,h): PH2(c,h) >= 0.9999, perp(FL(c,h))
        cge_variable LAM, value(1)
        cge_equation lam: sum(map(a,c), QG(c)) = LAM * sum(map(a,c), base(QG(c)))
        quietly cge_closure, swap(LAM GADJ)
        cge_shock LAM, value(1.1)
        cge_shock FX, elements(com_man.hhd) value(1.05)
        cge_shock tm, value(0)
    }
    * built-in equations replaced (version 0.9.3): government purchases of
    * services fixed above the base, exports of agricultural goods at the base,
    * and the intermediate demand of manufacturing, written by the user
    else if "`case'" == "replace" {
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas'
        cge_equation gs: QG(com_ser) = 1.1 * base(QG(com_ser)), replace(I7(com_ser))
        cge_equation qe: QE(com_agr) = base(QE(com_agr)), replace(T2(com_agr))
        cge_equation q5(c,a)$(sameas(a, act_man) & base(QINT(c, a)) > 0): QINT(c, a) = base(QINT(c, a)) / base(QINTA(a)) * QINTA(a), replace(Q5)
        cge_shock tm, value(0)
    }
    * A block declared with cge_nest (version 0.11.0): two kinds of labour in a
    * nest of 1.5 below a top of 0.8 with capital, a payroll tax, and its cut
    else if "`case'" == "cgenest" {
        quietly cge_synthetic, clear nests
        quietly cge_sam, labels(account)
        quietly cge_map, activities(act_agr act_man act_ser act_ene) commodities(com_agr com_man com_ser com_ene) ///
            factors(lab_hi lab_lo cap) households(hhd) government(gov) savinv(sav) row(row)             ///
            dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) factortax(tax_pay:lab_hi)
        quietly cge_calibrate, `sigmas'
        quietly cge_nest begin va(a), output(QVA(a)) price(PVA(a)) s(0.8) efficiency(ad(a) / base(ad(a))) replace(Q3)
        quietly cge_nest nest labour, s(1.5)
        foreach f in lab_hi lab_lo cap {
            quietly cge_nest input QF(`f', a), price(W(`f') * WFDIST(`f', a) * (1 + tf(`f', a))) units(af(`f')) ///
                `=cond("`f'" == "cap", "", "in(labour)")' replace(Q4(`f', a))
        }
        quietly cge_nest end
        cge_shock tf, elements(lab_hi) scale(0.5)
        cge_shock tm, value(0)
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
    * functions and macros of the user language (version 0.9.7), in user
    * variables and in an equation that determines a free variable
    else if "`case'" == "functions" {
        quietly cge_synthetic, clear institutions
        quietly cge_sam, labels(account)
        quietly cge_map, `instmap'
        quietly cge_calibrate, `sigmas'
        cge_set goods = c, except(com_ser)
        cge_set map(a,c) = act_agr.com_agr act_man.com_man
        cge_macro ces(x, y, d, r) = (d * x^(-r) + (1 - d) * y^(-r))^(-1 / r)
        cge_macro rel(v) = v / CPI
        cge_variable F1 = max(QA(act_agr), QA(act_man), 120) + min(QA(act_agr), QA(act_man)) + abs(QA(act_agr) - 120)
        cge_variable F2 = sqr(PQ(com_man)) + log10(QA(act_ser)) + ifthen(tm(com_man) > 0.05 & tm(com_agr) > 0, QM(com_man), 1)
        cge_variable F3 = prod(c, PQ(c)) + smax(c, QE(c)) + smin(c$(goods(c)), QA(act_man) / QE(c)) + card(c) + card(map)
        cge_variable F4 = smax(map(a,c), QA(a) + QE(c)) * prod((c,h)$(base(QH(c, h)) > 0), QH(c, h) / base(QH(c, h)))
        cge_variable CQ(goods) = ces(QD(goods), QM(goods), 0.5, 0.5)
        cge_variable RP(c) = rel(PQ(c))
        cge_variable LAM, value(1)
        cge_equation lam: LAM * max(base(QG(com_ser)), QG(com_agr)) = QG(com_ser)
        cge_shock tm, value(0)
    }
    * attributes of variables (version 0.9.8): bounds that do not bind, scales
    * and starting levels, of model and user variables
    else if "`case'" == "bounds" {
        quietly cge_synthetic, clear institutions
        quietly cge_sam, labels(account)
        quietly cge_map, `instmap'
        quietly cge_calibrate, `sigmas'
        cge_variable RP(c) = PQ(c) / CPI
        cge_bound QM, lower(0.5) upper(2) relative
        cge_bound PQ(com_man), lower(0.5)
        cge_bound QF, elements(lab.act_agr cap.act_man) lower(1)
        cge_bound RP, lower(0.8) upper(1.25)
        cge_bound QA, scale(1000)
        cge_bound YI(hhd), scale(5)
        cge_bound EXR, level(1.2)
        cge_bound QE, level(1.1) relative
        cge_shock tm, value(0)
    }
    * with constraints, solved as a mixed complementarity problem: the scales
    * and starting levels, a quota that binds and a limit that does not, whose
    * room and marginal GAMS reports
    else if "`case'" == "boundscon" {
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas'
        cge_bound QM, lower(0.5) upper(2) relative
        cge_bound QA, scale(1000)
        cge_bound EXR, level(1.2)
        cge_constraint QM, elements(com_man) upper(1.02) scale
        cge_constraint QE, elements(com_agr) upper(2) scale
        cge_shock tm, value(0)
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
capture program drop _tariff_cut
program define _tariff_cut
    args t
    if `t' == 2 cge_shock tm, value(0)
end
foreach case in dyninst dynhealth dyndebt dynlag dynfore {
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
    else if "`case'" == "dynlag" {
        * lags in user equations (version 0.9.2): government purchases that
        * adjust halfway to revenue each period, and changes in output from one
        * and two periods before
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas'
        cge_variable GL, value(1)
        cge_equation gl: GL = 0.5 * lag(GL) + 0.5 * YG / base(YG)
        cge_variable LAMG, value(1)
        cge_equation lamg: GADJ = LAMG * GL
        quietly cge_closure, swap(LAMG GADJ)
        cge_variable DQA(a) = QA(a) - lag(QA(a))
        cge_variable D2 = QA(act_man) - lag(QA(act_man), 2)
        quietly cge_dynamic, name(dynlag) periods(0/4) capital(cap) depreciation(0.05) rental(0.15) ///
            growth(lab:0.02) tfp(0.01) shocks(_tariff_cut)
    }
    else if "`case'" == "dynfore" {
        * perfect foresight (version 0.10.2): investment-driven savings with
        * investment that follows Tobin's q, which looks a period ahead, and a
        * tariff cut in period 2 known from the start; the period in a user
        * variable; leads beyond the last period continue its growth. GAMS
        * solves each period with the values of the periods around it that
        * the run found.
        quietly cge_synthetic, clear
        quietly cge_sam, labels(account)
        quietly cge_map, `stdmap'
        quietly cge_calibrate, `sigmas'
        quietly cge_closure, savinv(investment)
        cge_variable RK = W(cap) / CPI
        cge_variable Q, value(10)
        cge_equation qeq: Q = (lead(RK) + 0.95 * lead(Q)) / 1.05
        cge_variable IRULE = IADJ / (Q / base(Q))^2
        quietly cge_closure, swap(IRULE IADJ)
        cge_variable TP = tperiod + 10 * tfirst + 100 * tlast
        quietly cge_dynamic, name(dynfore) periods(0/4) capital(cap) depreciation(0.05) rental(0.10) ///
            growth(lab:0.02) shocks(_tariff_cut) foresight terminal(growth)
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
program drop _donor_exit _debt_relief _tariff_cut

* A scenario loop (version 0.9.9): GAMS solves the scenarios in order, each
* from the solution of the one before, as cge_loop does; a shock in place is
* part of every scenario
display as text _n "{hline 60}" _n "Case " as result "loop"
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, `instmap'
quietly cge_calibrate, `sigmas'
cge_shock tm, elements(com_agr) value(0)
cge_loop, name(loop) values(tm(com_man) = 0 0.5 1 1.5; QFS(lab) = 1 1.02 1.04 1.06; qg(com_ser) = 1 1.1 1 0.9) ///
    scale tolerance(1e-12)
assert r(N_converged) == 4
if "`phase'" == "export" {
    cge_gams using `"`dir'/loop"', loop(loop) replace
}
else {
    capture confirm file `"`dir'/loop/cge_loop4.csv"'
    if !_rc {
        cge_gams using `"`dir'/loop"', loop(loop) compare noexport
        post `post' ("loop") ("loop") (r(base_maxdiff)) (r(maxdiff)) (r(modelstat)) (r(base_modelstat)) ///
            (r(walras)) (r(N_compared))
    }
}

if "`phase'" == "compare" {
    postclose `post'
    use `"`dir'/export_check.dta"', clear
    export delimited using `"`dir'/export_check.csv"', replace
    list, noobs abbreviate(16)
}
