* Examples of [CGE] cge_aggregate. The SAMs are SYNTHETIC.
*>> agg_groups
cge_synthetic, clear institutions
cge_sam, labels(account)
cge_aggregate, groups(act_nag: act_man act_ser, com_nag: com_man com_ser, hh: hhd npi)
*<<

*>> agg_show
preserve
cge_samexport, clear
list account act_agr act_nag com_agr com_nag hh ent gov, noobs sep(0)
restore
*<<

*>> agg_map
cge_map, activities(act_agr act_nag) commodities(com_agr com_nag) factors(lab cap) ///
    households(hh) enterprises(ent) government(gov) savinv(sav) row(row)         ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
*<<

*>> agg_net
cge_sam, labels(account)
cge_aggregate, groups(hh: hhd npi) netdiagonal
return list
*<<

*>> agg_roles
cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov) savinv(sav)      ///
    row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_template using inst.csv, replace
import delimited using inst.csv, clear stringcols(_all)
quietly replace group = "dom" if inlist(account, "hhd", "npi", "ent")
export delimited account role pair group using inst.csv, replace
capture noisily cge_aggregate using inst.csv
di as err "r(" _rc ");"
*<<
