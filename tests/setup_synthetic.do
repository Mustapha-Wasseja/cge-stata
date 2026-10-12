* setup_synthetic.do -- load, map and calibrate the synthetic SAM for tests
* Optional argument: elasticity options for cge_calibrate.

version 13.0
args sigmas
if `"`sigmas'"' == "" local sigmas "sigmava(0.8) sigmaq(2) sigmat(2)"

cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, `sigmas'
