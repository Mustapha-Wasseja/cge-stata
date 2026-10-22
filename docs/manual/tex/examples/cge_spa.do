* Examples of [CGE] cge_spa. The SAM is SYNTHETIC.
*>> spa_setup
cge_synthetic, clear health
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser act_hlt)                     ///
    commodities(com_agr com_man com_ser com_hlt) factors(lab cap)        ///
    households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) ///
    saltax(tax_sal) imptax(tax_imp) insurance(shi)
*<<

*>> spa_paths
cge_spa, from(com_hlt) to(hhd)
*<<

*>> spa_return
return list
*<<

*>> spa_all
cge_spa, from(com_hlt) to(hhd) maxlength(10) threshold(0) top(3) clear
summarize total
display r(sum)
tabulate length
*<<
