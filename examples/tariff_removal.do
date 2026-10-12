* tariff_removal.do -- worked example on the synthetic SAM
*
* Removes all import tariffs under two closures and compares the results.
* The synthetic SAM is constructed for testing and describes no country;
* the elasticities are illustrative.

version 13.0
clear all

* 1. Read the SAM and assign accounts to model roles
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

* 2. Calibrate: elasticities of factor substitution, Armington and CET
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

* 3. Default closure: flexible exchange rate, flexible government savings,
*    savings-driven investment, mobile factors, CPI numeraire
cge_shock tm, value(0)
cge_solve, name(notariff)
cge_results, sim(notariff)

* 4. Same shock with fixed government savings: the lost tariff revenue is
*    replaced by a uniform rise in direct tax rates
cge_closure, government(fixgsav)
cge_solve, name(notariff_fixgsav)
cge_results, sim(notariff_fixgsav)

* 5. Validation checks on the last simulation
cge_check, homogeneity perturb(0.1)

* 6. Full results as a dataset
cge_results, sim(notariff) clear nodisplay
generate double pct_change = 100 * (value / base - 1) if base != 0
list variable element1 base value pct_change if inlist(variable, "QA", "W", "PQ"), ///
    noobs sepby(variable)
