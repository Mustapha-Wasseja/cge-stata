* Examples of [CGE] cge_microsim. The SAM and the household survey are
* SYNTHETIC: the survey is generated below with a fixed seed and describes no
* country; the elasticities are illustrative.
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

*>> ms_sim
cge_closure, government(fixgsav direct)
cge_shock tm, value(0)
cge_solve, name(notariff)
*<<

*>> ms_survey
clear
set seed 2026
set obs 1000
generate str3 group = "hhd"
generate double hhsize = 1 + floor(6 * runiform())
generate double weight = 100 + 50 * runiform()
generate double wage = exp(rnormal(5, 0.7)) * hhsize
generate double profit = cond(runiform() < 0.3, exp(rnormal(5, 1)), 0)
generate double transfer = cond(runiform() < 0.2, 50 * runiform(), 0)
generate double cons = 0.9 * (wage + profit + transfer)
generate double food = cons * (0.6 - 0.3 * runiform())
generate double services = (cons - food) / 2
generate double goods = cons - food - services
summarize hhsize weight wage profit transfer cons food goods services
*<<

*>> ms_group
set linesize 110
cge_microsim [pweight = weight], sim(notariff) group(group) consumption(cons) size(hhsize) ///
    line(100)
*<<
set linesize 100

*>> ms_income
set linesize 110
cge_microsim [pweight = weight], sim(notariff) group(group) consumption(cons) size(hhsize) ///
    income(wage:lab profit:cap transfer:gov)                                          ///
    budget(food:com_agr goods:com_man services:com_ser) line(100) generate(nt)
*<<
set linesize 100

*>> ms_return
return list
matrix list r(table), format(%9.4f)
*<<

*>> ms_vars
summarize nt_nom nt_price nt_real nt_pc
*<<
