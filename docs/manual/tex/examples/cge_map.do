* Examples of [CGE] cge_map. The SAMs are SYNTHETIC.
*>> map_standard
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)         ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
*<<

*>> map_problem
set linesize 110
cge_synthetic, clear national
cge_sam, labels(account)
capture noisily cge_map, activities(act_agr act_man act_ser)                              ///
    commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) ///
    government(gov) savinv(sav) row(row) imptax(tax_imp) report(problems.csv)
di as err "r(" _rc ");"
*<<
set linesize 100

*>> map_cells
import delimited using problems.csv, clear
list, noobs abbreviate(16)
*<<

*>> map_national
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)         ///
    dirtax(gov) saltax(gov) imptax(tax_imp)
*<<

*>> map_template
cge_template using roles.csv, replace
import delimited using roles.csv, clear
list account role pair, noobs
cge_map using roles.csv
*<<

*>> map_sut
cge_synthetic, clear sut
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser)                            ///
    commodities(com_agr com_man com_ser com_fuel) factors(lab cap)      ///
    households(hhd) government(gov) savinv(si) row(row) dirtax(tax_dir) ///
    saltax(tax_sal) imptax(tax_imp) marginaccounts(trd trp) stocks(dstk)
*<<
