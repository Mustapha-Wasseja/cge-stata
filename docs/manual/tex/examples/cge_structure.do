* Examples of [CGE] cge_structure. The SAM is SYNTHETIC.
*>> struct_setup
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
*<<

*>> struct_default
cge_structure, top(3)
*<<

*>> struct_singular
cge_variable Z, value(1)
cge_equation ez: CPI = base(CPI)
cge_structure, top(3)
return list
cge_equation, clear
*<<

*>> struct_standalone
cge_model new
cge_variable X1, value(1)
cge_variable X2, value(1)
cge_variable X3, value(1)
cge_variable X4, value(1)
cge_variable X5, value(1)
cge_variable X6, value(1)
cge_equation e1: X1 = 1
cge_equation e2: X2 = X1 + 1
cge_equation e3: X3 = 2 * X2
cge_equation e4: X4 + X5 = 3
cge_equation e5: X4 - X5 = 1
cge_equation e6: X6 = X5 * X3
cge_structure
*<<
