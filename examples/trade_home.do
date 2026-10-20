* trade_home.do -- worked example: home consumption, an export-only cash crop,
* margins by market and export demand (docs/model_spec.md, Section 13)
*
* The synthetic SAMs are constructed for testing and describe no country; the
* elasticities are illustrative.

version 13.0
clear all

* 1. Home consumption: the household eats 20 of its own agricultural output
cge_synthetic, clear home
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1 1.4) frisch(-2)

* A doubled sales tax on food bears on marketed food only
cge_shock tq, elements(com_agr) scale(2)
cge_solve, name(foodtax)
cge_report, sims(foodtax) tables(macro welfare)

* 2. A cash crop that is all exported, margins by market, and a downward-sloping
*    world demand for manufactures and the cash crop
cge_synthetic, clear trade
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser com_cash) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)                                     ///
    domesticmargins(mtrd) importmargins(mtrm) exportmargins(mtre)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) exportonly(com_cash) ///
    exportdemand(com_man:4 com_cash:2)

* A 20 per cent fall in world demand for the cash crop
cge_shock pwe, elements(com_cash) scale(0.8)
cge_solve, name(cashfall)
cge_report, sims(cashfall) tables(macro commodities welfare)
