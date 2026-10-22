* Examples of [CGE] cge_set. The SAM is SYNTHETIC.
*>> set_setup
cge_synthetic, clear health
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser act_hlt)                       ///
    commodities(com_agr com_man com_ser com_hlt) factors(lab cap)          ///
    households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir)   ///
    saltax(tax_sal) imptax(tax_imp) insurance(shi)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
*<<

*>> set_define
cge_set goods = c, except(com_ser com_hlt)
cge_set services = com_ser com_hlt
return list
*<<

*>> set_use
cge_variable GGOODS = sum(goods, PQ(goods) * QG(goods)), nominal
cge_variable PREL(services) = PQ(services) / CPI
cge_shock tm, value(0)
cge_solve, name(notariff)
cge_results, sim(notariff) clear nodisplay
list variable element1 base value if inlist(variable, "GGOODS", "PREL"), noobs
*<<

*>> set_list
cge_set, list
*<<

*>> set_err
capture noisily cge_variable X = sum(goodz, PQ(goodz))
di as err "r(" _rc ");"
*<<
