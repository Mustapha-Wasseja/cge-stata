* Examples of [CGE] cge. The SAM of cge_workflow is SYNTHETIC; that of cge_malawi
* is IFPRI's 2019 SAM for Malawi, shipped with the package.
*>> cge_display
cge
*<<

*>> cge_workflow
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)         ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
cge_solve, name(notariff)
cge_results
*<<

*>> cge_malawi
cge_sam using cge_malawi_sam.csv, clear
quietly levelsof Code if substr(Code, 1, 1) == "a", local(acts) clean
quietly levelsof Code if substr(Code, 1, 1) == "c", local(coms) clean
local hhds hhdr1 hhdr2 hhdr3 hhdr4 hhdr5 hhdu1 hhdu2 hhdu3 hhdu4 hhdu5
set linesize 110
capture noisily cge_map, activities(`acts') commodities(`coms') ///
    factors(flabn flabp flabs flnd fcap) households(`hhds') enterprises(ent) ///
    government(gov) savinv(si) row(row) dirtax(dtax) saltax(stax) imptax(mtax) marginaccounts(trc)
cge_aggregate, groups(gov: gov dtax) netdiagonal
cge_balance, nodisplay
cge_map, activities(`acts') commodities(`coms') ///
    factors(flabn flabp flabs flnd fcap) households(`hhds' ent) ///
    government(gov) savinv(si) row(row) dirtax(gov) saltax(stax) imptax(mtax) marginaccounts(trc)
set linesize 100
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
cge_solve, name(notariff)
cge_shock, reset
cge_shock ad, elements(amaiz) scale(1.1)
cge_solve, name(maize)
cge_report, sims(notariff maize) tables(macro welfare)
*<<
