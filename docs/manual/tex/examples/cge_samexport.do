* Examples of [CGE] cge_samexport. The SAMs are SYNTHETIC.
*>> sxp_csv
cge_synthetic, clear unbalanced
cge_sam, labels(account)
quietly cge_balance
cge_samexport using balanced.csv, replace
cge_sam using balanced.csv, clear
*<<

*>> sxp_long
cge_samexport, clear long
list in 1/6, noobs sep(0)
*<<

*>> sxp_mapped
cge_synthetic, clear national
cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)             ///
    dirtax(gov) saltax(gov) imptax(tax_imp)
cge_samexport, clear mapped long
list if inlist("_dirtax", row, column) | inlist("_saltax", row, column), noobs sep(0)
*<<
