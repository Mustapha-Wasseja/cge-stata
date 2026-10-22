* Examples of [CGE] cge_elasticities. The SAM is SYNTHETIC; the elasticities
* are the published values of the package's library.
*>> elas_list
set linesize 110
cge_elasticities sigmaq, country(TGO SLE BWA)
*<<
set linesize 100

*>> elas_load
cge_elasticities incelas, country(TGO) clear
list id category value se, noobs
*<<

*>> elas_setup
cge_synthetic, clear
cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                 ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
*<<

*>> elas_values
cge_elasticities sigmaq, country(TGO) values
local sq `r(values)'
cge_elasticities incelas, country(TGO) values map(com_agr:food) others(other)
local ie `r(values)'
cge_elasticities frisch, values
local fr `r(values)'
*<<

*>> elas_calibrate
cge_calibrate, sigmava(0.8) sigmaq(`sq') sigmat(2) incelas(`ie') frisch(`fr')
*<<

*>> elas_ambiguous
capture noisily cge_elasticities sigmaq, country(TGO SLE) values
di as err "r(" _rc ");"
*<<

*>> elas_return
cge_elasticities sigmat, country(SLE) values
return list
*<<

* A file of the user's own entries
file open fh using myvalues.csv, write replace text
file write fh "id,parameter,country,category,value,source,definition" _n
file write fh "MY2026-ARM-AGR,sigmaq,TGO,agriculture,1.4,MY2026,sector Armington elasticity" _n
file write fh "MY2026-ARM-MAN,sigmaq,TGO,manufactures,2.1,MY2026,sector Armington elasticity" _n
file close fh
*>> elas_user
type myvalues.csv
cge_elasticities sigmaq using myvalues.csv, source(MY2026) values ///
    map(com_agr:agriculture) others(manufactures)
*<<
