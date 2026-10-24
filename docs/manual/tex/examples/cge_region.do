* Examples of [CGE] cge_region. The SAMs and the trade between the regions
* are SYNTHETIC.
*>> reg_setup
capture cge_region clear
cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_region add A
cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)             ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_region add B, units(2)
*<<

*>> reg_trade
clear
input str4 exporter str4 importer str8 commodity double value double tariff
A B com_agr  8 .
A B com_man 24 0.08
A B com_ser  6 .
B A com_agr 10 .
B A com_man 30 .
B A com_ser  5 0
end
cge_region trade, exporter(exporter) importer(importer) commodity(commodity) value(value) tariff(tariff)
cge_region list
*<<

*>> reg_fta
cge_region tariff, from(A B) to(A B) value(0)
cge_region solve, name(fta)
*<<

*>> reg_routes
cge_region results, sim(fta) clear
format base quantity price value %9.3f
format tariff_base tariff %6.3f
list exporter importer commodity base quantity price tariff_base tariff if commodity == "com_man", ///
    noobs sep(0)
*<<

*>> reg_report
cge_region select A
cge_report, sims(fta) tables(macro)
*<<
