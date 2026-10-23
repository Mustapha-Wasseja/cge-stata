* Examples of [CGE] cge_equation. The SAM is SYNTHETIC.
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)             ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> eq_lam
cge_variable LAM, value(1)
cge_equation lam: QG(com_ser) = LAM * base(QG(com_ser))
cge_closure, swap(LAM GADJ)
cge_shock LAM, value(1.1)
cge_solve, name(qgser)
*<<

*>> eq_lam_res
quietly cge_results, sim(qgser) clear nodisplay
list variable element1 base value if inlist(variable, "LAM", "GADJ", "QG"), noobs
*<<

*>> eq_index
cge_variable PIX(c), value(1)
cge_equation pix(c): ln(PIX(c)) = ln(PQ(c)) - ln(CPI)
cge_variable CVOL, value(1)
cge_equation cvol: sum(c, PQ(c) * QH(c, hhd)) = CVOL * sum(c, PQ(c) * base(QH(c, hhd)))
quietly cge_solve, name(qgser)
quietly cge_results, sim(qgser) clear nodisplay
list variable element1 base value if inlist(variable, "PIX", "CVOL"), noobs
*<<

*>> eq_list
cge_equation, list
return list
*<<

*>> eq_err
capture noisily cge_equation bad: QG(com_xxx) = 1
di as err "r(" _rc ");"
capture noisily cge_equation, clear
di as err "r(" _rc ");"
cge_closure, swap(none)
cge_equation, clear
*<<

*>> eq_cond
cge_set goods = c, except(com_ser)
cge_variable MT = sum(c$(tm(c) > 0), PM(c) * QM(c)), nominal
cge_variable TMV(c)$(tm(c) > 0) = tm(c) * PM(c) * QM(c)
cge_variable LQM(c)$(tm(c) > 0), value(1)
cge_equation lqm(c)$(tm(c) > 0): QM(c) = LQM(c) * base(QM(c))
cge_variable GGOODS = sum(c, (PQ(c) * QG(c))$(goods(c)))
cge_shock tm, value(0)
cge_solve, name(notariff)
quietly cge_results, sim(notariff) clear nodisplay
list variable element1 base value if inlist(variable, "MT", "TMV", "LQM", "GGOODS"), noobs
*<<

*>> eq_ineq
set linesize 120
cge_shock, reset
cge_equation quota: QM(com_man) =l= 1.02 * base(QM(com_man)), perp(RM(com_man))
cge_equation rev: YG >= base(YG), perp(TQADJ)
cge_variable PRA = PQ(com_agr) / CPI, lower(0.9995) upper(1.0005)
cge_shock tm, value(0)
cge_solve, name(ineq)
quietly cge_results, sim(ineq) clear nodisplay
list variable element1 base value if inlist(variable, "QM", "RM", "YG", "TQADJ", "PRA"), noobs sepby(variable)
*<<
set linesize 100

*>> eq_cond_err
capture noisily cge_variable X1 = sum(c$(1 / tm(c) > 0), PQ(c))
di as err "r(" _rc ");"
capture noisily cge_variable X2(c)$(tm(c) > 1) = PQ(c)
di as err "r(" _rc ");"
capture noisily cge_variable X3 = sum(c, PQ(c) * (tm(c) > 0))
di as err "r(" _rc ");"
*<<

*>> eq_pairs
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)                ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_variable XH(c,h)$(base(QH(c, h)) > 0) = PQ(c) * QH(c, h), nominal
cge_variable XS = sum((c,h), XH(c,h)), nominal
cge_set map(a,c) = act_agr.com_agr act_man.com_man
cge_variable VMAP = sum(map(a,c), PA(a) * QA(a)), nominal
cge_variable PR(a,c)$(map(a,c)) = PA(a) / PQ(c)
cge_shock tm, value(0)
cge_solve, name(pairs)
quietly cge_results, sim(pairs) clear nodisplay
list variable element1 element2 base value if inlist(variable, "XH", "XS", "VMAP", "PR"), ///
    noobs sepby(variable)
*<<

*>> eq_lag
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)              ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_variable GL, value(1)
cge_equation gl: GL = 0.5 * lag(GL) + 0.5 * YG / base(YG)
cge_variable LAMG, value(1)
cge_equation lamg: GADJ = LAMG * GL
quietly cge_closure, swap(LAMG GADJ)
cge_variable DQA = QA(act_man) - lag(QA(act_man))
cge_dynamic, name(lagged) periods(0/4) capital(cap) depreciation(0.05) rental(0.15) ///
    growth(lab:0.02) tfp(0.01)
quietly cge_dynresults, run(lagged) clear
quietly keep if inlist(variable, "YG", "GL", "GADJ", "DQA")
keep period variable value
quietly reshape wide value, i(period) j(variable) string
rename value* *
list period YG GL GADJ DQA, noobs
*<<

*>> eq_replace
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)              ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_equation qe: QE(com_agr) = base(QE(com_agr)), replace(T2(com_agr))
cge_equation gs: QG(com_ser) = 1.1 * base(QG(com_ser)), replace(I7(com_ser))
cge_equation, list
cge_shock tm, value(0)
cge_solve, name(replaced)
quietly cge_results, sim(replaced) clear nodisplay
list variable element1 base value if inlist(variable, "QE", "QG", "WALRAS"), noobs sepby(variable)
*<<

*>> eq_replace_same
cge_shock, reset
cge_equation, clear
cge_shock tm, value(0)
quietly cge_solve, name(original)
cge_equation q5(c,a)$(sameas(a, act_man) & base(QINT(c, a)) > 0): ///
    QINT(c, a) = base(QINT(c, a)) / base(QINTA(a)) * QINTA(a), replace(Q5)
quietly cge_solve, name(rewritten)
foreach s in original rewritten {
    quietly cge_results, sim(`s') clear nodisplay
    quietly summarize value if variable == "QA" & element1 == "act_man"
    display "`s'" _col(12) "QA(act_man) = " %14.10f r(mean)
}
*<<
