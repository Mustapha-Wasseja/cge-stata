* Examples of [CGE] cge_multiplier. The SAM is SYNTHETIC.
*>> mult_setup
cge_synthetic, clear health
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser act_hlt)                     ///
    commodities(com_agr com_man com_ser com_hlt) factors(lab cap)        ///
    households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) ///
    saltax(tax_sal) imptax(tax_imp) insurance(shi)
*<<

*>> mult_table
set linesize 110
cge_multiplier
*<<
set linesize 100

*>> mult_decomp
set linesize 110
cge_multiplier, decompose
*<<
set linesize 100

*>> mult_inject
cge_multiplier, inject(com_hlt:10)
*<<

*>> mult_endo
set linesize 110
cge_multiplier, endogenous(gov) accounts(com_hlt hhd gov)
*<<
set linesize 100

*>> mult_offcircle
capture noisily cge_multiplier, endogenous(gov tax_sal) decompose
di as err "r(" _rc ");"
*<<

*>> mult_clear
quietly cge_multiplier, decompose clear
list row multiplier transfer open_loop closed_loop if column == "com_hlt", noobs sep(0)
*<<
