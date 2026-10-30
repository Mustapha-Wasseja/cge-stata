* Examples of [CGE] cge_variable. The SAM is SYNTHETIC.
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)             ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> var_gexp
cge_variable GEXP = sum(c, PQ(c) * QG(c)), nominal
return list
cge_closure, swap(GEXP GADJ)
cge_shock pwm, scale(1.1)
cge_solve, name(budget)
*<<

*>> var_gexp_res
quietly cge_results, sim(budget) clear nodisplay
list variable element1 base value if inlist(variable, "GEXP", "GADJ", "QG"), noobs
*<<

*>> var_index
cge_variable PREL(c) = PQ(c) * (1 + tv(c)) / CPI
quietly cge_solve, name(budget)
quietly cge_results, sim(budget) clear nodisplay
list variable element1 base value if variable == "PREL", noobs
*<<

*>> var_rw
cge_shock, reset
cge_closure, swap(none)
cge_variable RW = W(lab) / CPI
cge_closure, swap(RW QFS(lab))
cge_shock pwm, scale(1.1)
quietly cge_solve, name(realwage)
quietly cge_results, sim(realwage) clear nodisplay
list variable element1 base value if inlist(variable, "RW", "W", "QFS") & element1 != "cap", noobs
*<<

*>> var_value
cge_variable LAM, value(1)
capture noisily cge_check
di as err "r(" _rc ");"
capture noisily cge_solve, name(unpaired)
di as err "r(" _rc ");"
*<<

quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)             ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> var_add
cge_parameter ttx = 0
cge_variable TX = ttx * PQ(com_man) * QQ(com_man), add(I8)
cge_shock ttx, value(0.05)
quietly cge_solve, name(mantax)
quietly cge_report, sims(mantax) tables(government items) items(tax = TX) clear
list measure base value pct if inlist(measure, "revenue", "spending", "savings", "tax"), noobs
*<<
