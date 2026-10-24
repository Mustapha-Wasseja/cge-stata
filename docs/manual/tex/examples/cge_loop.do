* Examples of [CGE] cge_loop. The SAM is SYNTHETIC.
*>> loop_setup
cge_synthetic, clear
cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                 ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
*<<

*>> loop_sweep
cge_loop, name(tariff) values(tm(com_man) = 0(0.05)0.3) ///
    measures(YG, welfare equivalent_variation hhd, sum(c, PQ(c) * QG(c)))
matrix list r(measures), format(%10.4f)
*<<

*>> loop_grid
cge_loop, name(two) values(tm(com_man) = 0 0.1 0.2; tm(com_agr) = 0 0.1) grid keep(QM) clear
list scenario t1 t2 element1 value if element1 != "com_ser", noobs sepby(scenario)
*<<

*>> loop_using
clear
input str8 scenario str14 target double value
"cut"    "tm(com_man)"  0.5
"cut"    "tm(com_agr)"  0.5
"spend"  "qg(com_ser)"  1.1
end
list, noobs
tempfile sc
quietly save `sc'
cge_loop using `sc', name(policy) scale measures(YG, welfare equivalent_variation hhd)
*<<

*>> loop_gams
cge_gams using gams_tariff, loop(tariff) replace
type gams_tariff/cge_tariff2_par.inc
*<<
