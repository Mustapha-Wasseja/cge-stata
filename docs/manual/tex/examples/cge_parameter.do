* Examples of [CGE] cge_parameter. The SAM is SYNTHETIC; the weights and
* targets are illustrative.
*>> par_setup
cge_synthetic, clear health
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser act_hlt)                       ///
    commodities(com_agr com_man com_ser com_hlt) factors(lab cap)          ///
    households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir)   ///
    saltax(tax_sal) imptax(tax_imp) insurance(shi)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
*<<

*>> par_scalar
cge_parameter hgoal = 1.1
cge_variable LAM, value(1)
cge_equation lam: QG(com_hlt) = LAM * hgoal * base(QG(com_hlt))
cge_closure, swap(LAM GADJ)
cge_solve, name(goal)
*<<

*>> par_shock
cge_shock hgoal, value(1.2)
cge_solve, name(goal12)
cge_report, sims(goal goal12) tables(macro)
*<<

*>> par_values
cge_parameter w(c), values(com_agr:0.4 com_man:0.3 com_ser:0.2 com_hlt:0.1)
cge_variable PIDX = sum(c, w(c) * PQ(c))
*<<

*>> par_from
clear
input str8 commodity double share
"com_agr" 0.6
"com_man" 0.4
end
cge_parameter sw(c), from(share) labels(commodity)
*<<

*>> par_two
cge_parameter sh(c,h), values(com_hlt.hhd:0.5) default(0.1)
cge_parameter, list
*<<

*>> par_data
cge_parameters, clear
list if inlist(parameter, "hgoal", "w", "sw", "sh"), noobs sep(0)
*<<

*>> par_opt
cge_shock, reset
cge_optimize, instruments(hgoal) targets(government savings = 1.5) name(hgopt)
*<<
