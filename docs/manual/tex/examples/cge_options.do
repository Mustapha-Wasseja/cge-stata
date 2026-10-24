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

*>> opt_mcp
cge_shock, reset
cge_options, linsolver(dense)
foreach a in act_agr act_man act_ser {
    quietly cge_constraint QA, elements(`a') upper(1) scale adjust(RA `a') up
}
quietly cge_constraint QM, elements(com_agr) upper(0.98) scale adjust(RM com_agr) up
quietly cge_constraint QM, elements(com_man) upper(0.98) scale adjust(RM com_man) up
cge_shock qinv, scale(1.5)
cge_solve, name(semismooth)
cge_options, mcp(activeset)
quietly cge_solve, name(activeset)
display "active set: " r(iterations) " iterations, " r(N_binding) " binding"
quietly cge_results, sim(semismooth) clear nodisplay
rename value v_ss
tempfile ss
quietly save `ss'
quietly cge_results, sim(activeset) clear nodisplay
quietly merge 1:1 variable element1 element2 using `ss', nogenerate
quietly generate double rel = abs(value - v_ss) / max(1, abs(v_ss))
quietly summarize rel
display "semismooth against active set: largest relative difference " %9.2e r(max)
cge_options, mcp(semismooth)
*<<

*>> opt_limits
cge_constraint, clear
cge_shock, reset
cge_shock tm, value(0)
cge_options, iterate(2)
capture noisily cge_solve, name(two) steps(1)
display "model status " r(modelstat) ", solver status " r(solvestat)
capture noisily cge_solve, name(none) timelimit(0)
display "model status " r(modelstat) ", solver status " r(solvestat)
cge_options, reset
cge_solve, name(solved)
display "model status " r(modelstat) ", solver status " r(solvestat)
*<<
