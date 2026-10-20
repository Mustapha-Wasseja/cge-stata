* elasticities.do -- worked example: published elasticities from the library
* (docs/elasticities.md) as calibration options
*
* The synthetic SAM is constructed for testing and describes no country. The
* Togo values are applied to it only to show the commands; the mapping of its
* commodities to consumption categories is illustrative.

version 13.0
clear all

* What the library holds for Togo
cge_elasticities, country(TGO)

* The entries with their definitions, notes and sources
cge_elasticities incelas, country(TGO) clear
list id value published location check, noobs clean

cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

* Aggregate trade elasticities set every commodity to the national level; the
* source warns that aggregate values are lower than sector ones
cge_elasticities sigmaq, country(TGO) values
local sq `r(values)'
cge_elasticities sigmat, country(TGO) values
local st `r(values)'
cge_elasticities sigmava, country(AFR) values
local va `r(values)'
* Income elasticities by consumption category, and the Frisch parameter
cge_elasticities incelas, country(TGO) values map(com_agr:food) others(other)
local ie `r(values)'
cge_elasticities frisch, values
local fr `r(values)'

cge_calibrate, sigmava(`va') sigmaq(`sq') sigmat(`st') incelas(`ie') frisch(`fr')
cge_shock tm, value(0)
cge_solve, name(notariff)
cge_report, sims(notariff) tables(macro welfare)
