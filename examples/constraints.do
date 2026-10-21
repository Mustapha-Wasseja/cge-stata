* constraints.do -- worked example: limits that bind in some scenarios and not
* in others (docs/model_spec.md, Section 16)
*
* The synthetic SAM is constructed for testing and describes no country; the
* elasticities and limits are illustrative.

version 13.0
clear all

cge_synthetic, clear health
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

* 1. Government purchases of health services rise by 20 per cent, without and
*    with a limit on what health providers can deliver: 3 per cent above the
*    base. When the limit binds, the price of health services rises above
*    cost and the rent goes to the providers' owners, here households.
cge_shock qg, elements(com_hlt) scale(1.2)
cge_solve, name(health20)
cge_constraint QA, elements(act_hlt) upper(1.03) scale rents(hhd)
cge_solve, name(health20_cap)

* 2. The same spending, with a government that may not run a deficit larger
*    than in the base: spending on other goods and services is cut once the
*    deficit reaches the ceiling
quietly cge_results, sim(health20) clear nodisplay
quietly summarize base if variable == "GSAV"
local gsav0 = r(mean)
cge_constraint, clear
cge_constraint GSAV, lower(`gsav0') adjust(GADJ) down
cge_solve, name(health20_rule)
cge_report, sims(health20 health20_cap health20_rule) tables(macro government)

* 3. An import quota on manufactures, 2 per cent above base imports, with
*    tariffs removed; the premium on the quota goes to the government, as if
*    the licences were auctioned. A limit is listed with cge_constraint, list.
cge_constraint, clear
cge_shock, reset
cge_shock tm, value(0)
cge_constraint QM, elements(com_man) upper(1.02) scale
cge_constraint, list
cge_solve, name(quota)
cge_results, sim(quota) clear nodisplay
list variable element1 base value if inlist(variable, "QM", "RM") & element1 == "com_man", noobs
