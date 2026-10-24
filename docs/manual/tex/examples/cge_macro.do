* Examples of [CGE] cge_macro. The SAM is SYNTHETIC.
*>> mac_setup
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
*<<

*>> mac_define
cge_macro ces(x, y, d, r) = (d * x^(-r) + (1 - d) * y^(-r))^(-1 / r)
cge_macro rel(v) = v / CPI
cge_macro half = 0.5
cge_macro cesq(c) = ces(QD(c), QM(c), half, half)
cge_macro, list
cge_variable CQ(c)$(base(QM(c)) > 0) = cesq(c)
cge_variable RP(c) = rel(PQ(c))
cge_shock tm, value(0)
cge_solve, name(notariff)
quietly cge_results, sim(notariff) clear nodisplay
list variable element1 base value if inlist(variable, "QD", "QM", "CQ", "RP"), ///
    noobs sepby(variable)
*<<

*>> mac_err
capture noisily cge_variable X = ces(QD(com_man), QM(com_man))
di as err "r(" _rc ");"
capture noisily cge_variable X = rel
di as err "r(" _rc ");"
capture noisily cge_macro loop(x) = loop(x) + 1
di as err "r(" _rc ");"
capture noisily cge_macro, clear
di as err "r(" _rc ");"
*<<
