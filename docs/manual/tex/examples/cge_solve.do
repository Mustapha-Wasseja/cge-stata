* Examples of [CGE] cge_solve. The SAM is SYNTHETIC.
*>> solve_setup
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
*<<

*>> solve_notariff
cge_shock tm, value(0)
cge_solve, name(notariff)
*<<

*>> solve_trace
cge_solve, name(notariff) tolerance(1e-12) trace
*<<

*>> solve_return
return list
*<<

*>> solve_collapse
cge_shock, reset
cge_shock qg, scale(10)
cge_solve, name(qg10)
*<<

*>> solve_fail
cge_closure, savinv(investment)
capture noisily cge_solve, name(qg10fixed)
di as err "r(" _rc ");"
*<<

*>> solve_nlp
cge_model new
cge_set i = x1 x2 x3 x4
cge_parameter x0(i), values(x1:1 x2:5 x3:5 x4:1)
cge_variable X(i), value(x0(i))
cge_variable S, value(0)
cge_equation G1: X(x1) * X(x2) * X(x3) * X(x4) - S = 25
cge_equation G2: sum(i, X(i)^2) = 40
cge_bound X, lower(1) upper(5)
cge_bound S, lower(0)
cge_solve, name(hs071) minimize(X(x1) * X(x4) * (X(x1) + X(x2) + X(x3)) + X(x3))
matrix list r(marginals)
cge_results, sim(hs071)
*<<

*>> solve_entropy
cge_model new
cge_set r = r1 r2 r3
cge_set c = c1 c2 c3 c4
cge_parameter a(r,c), values(r1.c1:10 r1.c2:5 r1.c3:2 r1.c4:8 r2.c1:3 r2.c2:12 r2.c3:6 r2.c4:1 ///
    r3.c1:4 r3.c2:2 r3.c3:9 r3.c4:7)
cge_parameter u(r), values(r1:30 r2:20 r3:19)
cge_parameter v(c), values(c1:20 c2:21 c3:16 c4:12)
cge_variable X(r,c), value(a(r,c))
cge_equation ROW(r): sum(c, X(r,c)) = u(r)
cge_equation COL(c)$(ord(c) < card(c)): sum(r, X(r,c)) = v(c)
cge_bound X, lower(0)
cge_solve, name(ce) minimize(sum((r,c), X(r,c) * ln(X(r,c) / a(r,c))))
*<<
