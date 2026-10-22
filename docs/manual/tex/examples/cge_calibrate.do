* Examples of [CGE] cge_calibrate. The SAMs are SYNTHETIC.
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)         ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

*>> cal_uniform
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
*<<

*>> cal_return
return list
*<<

*>> cal_sector
cge_calibrate, sigmava(0.5 1 1.5) sigmaq(0.6 3 1.2) sigmat(0.7 4 1)
*<<

*>> cal_sigmaq1
capture noisily cge_calibrate, sigmava(0.8) sigmaq(1) sigmat(2)
di as err "r(" _rc ");"
*<<

*>> cal_les
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1 1.4) frisch(-2)
*<<

*>> cal_labour
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) unemployment(lab:0.15) wagecurve(lab:0.1)
*<<

*>> cal_sut
cge_synthetic, clear sut
cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser)                    ///
    commodities(com_agr com_man com_ser com_fuel) factors(lab cap)      ///
    households(hhd) government(gov) savinv(si) row(row) dirtax(tax_dir) ///
    saltax(tax_sal) imptax(tax_imp) marginaccounts(trd trp) stocks(dstk)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
*<<
