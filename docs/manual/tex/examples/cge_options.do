* Examples of [CGE] cge_options. The SAM is SYNTHETIC.
*>> opt_setup
cge_synthetic, clear
cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                 ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
cge_options
*<<

*>> opt_sparse
cge_solve, name(dense) tolerance(1e-12)
cge_options, linsolver(sparse)
cge_solve, name(sparse) tolerance(1e-12)
cge_solve, name(sparsefull) tolerance(1e-12) full
quietly cge_results, sim(dense) clear nodisplay
rename value v_dense
tempfile d
quietly save `d'
foreach s in sparse sparsefull {
    quietly cge_results, sim(`s') clear nodisplay
    quietly merge 1:1 variable element1 element2 using `d', nogenerate
    quietly generate double rel = abs(value - v_dense) / max(1, abs(v_dense))
    quietly summarize rel
    display "`s' against dense: largest relative difference " %9.2e r(max)
}
*<<
