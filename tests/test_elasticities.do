* test_elasticities.do -- the elasticity library (version 0.3.5;
* docs/elasticities.md): listing, loading, values for cge_calibrate, a user's
* file, and errors

version 13.0

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

* ---------------------------------------------------------------------
* 1. Listing and loading
* ---------------------------------------------------------------------
cge_elasticities sigmaq, country(TGO SLE BWA)
assert r(N) == 3
assert r(ids) == "DGR2023-ARM-BWA DGR2023-ARM-SLE DGR2023-ARM-TGO"
cge_elasticities, clear
assert _N == 531
quietly count if parameter == "sigmaq"
assert r(N) == 51
quietly count if parameter == "incelas"
assert r(N) == 47 * 9
* Every entry has a source with its details, a location and a check
assert source != "" & authors != "" & year != "" & location != "" & check != ""
quietly summarize value if id == "DGR2023-CET-TGO"
assert r(mean) == 0.542
quietly summarize value if id == "MSMR2011-INC-SLE-health"
assert r(mean) == 2.031
cge_elasticities incelas, country(TGO) category(food health) clear
assert _N == 2
cge_elasticities, source(BGG2007) clear
assert _N == 2 & parameter == "mortelas"

* ---------------------------------------------------------------------
* 2. Values for cge_calibrate
* ---------------------------------------------------------------------
cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
cge_elasticities sigmaq, country(TGO) values
assert r(values) == "0.620 0.620 0.620" & r(ids) == "DGR2023-ARM-TGO DGR2023-ARM-TGO DGR2023-ARM-TGO"
local sq `r(values)'
cge_elasticities sigmat, country(TGO) values
local st `r(values)'
cge_elasticities sigmava, country(AFR) values
assert r(values) == "0.5897 0.5897 0.5897"
local va `r(values)'
cge_elasticities incelas, country(TGO) values map(com_agr:food com_man:other) others(other)
assert r(values) == "0.804 1.913 1.913"
assert r(ids) == "MSMR2011-INC-TGO-food MSMR2011-INC-TGO-other MSMR2011-INC-TGO-other"
local ie `r(values)'
cge_elasticities frisch, values
assert r(values) == "-1.3661"
local fr `r(values)'
cge_elasticities wagecurve, country(ZAF) values
assert r(values) == "0.1"
cge_calibrate, sigmava(`va') sigmaq(`sq') sigmat(`st') incelas(`ie') frisch(`fr')
assert r(max_residual) < 1e-12
quietly cge_parameters, clear
quietly summarize value if parameter == "sq" & element1 == "com_man"
assert reldif(r(mean), 0.62) < 1e-15

* ---------------------------------------------------------------------
* 3. A user's file adds entries
* ---------------------------------------------------------------------
tempfile user
preserve
clear
quietly set obs 1
generate str20 id = "USER-ARM-man"
generate str6 parameter = "sigmaq"
generate str3 country = "TGO"
generate str12 category = "manufactures"
generate double value = 2.5
generate str4 source = "USER"
quietly export delimited using "`user'.csv", replace
restore
cge_elasticities sigmaq using "`user'.csv", country(TGO)
assert r(N) == 2
cge_elasticities sigmaq using "`user'.csv", country(TGO) values map(com_man:manufactures) others(aggregate)
assert r(values) == "0.620 2.5 0.620"
* Ids must be unique
preserve
clear
quietly set obs 1
generate str20 id = "DGR2023-ARM-TGO"
generate str6 parameter = "sigmaq"
generate str3 country = "TGO"
generate str12 category = "aggregate"
generate double value = 1
generate str4 source = "USER"
quietly export delimited using "`user'.csv", replace
restore
capture noisily cge_elasticities sigmaq using "`user'.csv"
assert _rc == 459
capture erase "`user'.csv"

* ---------------------------------------------------------------------
* 4. Errors
* ---------------------------------------------------------------------
capture noisily cge_elasticities sigmaq, country(XYZ)
assert _rc == 111
capture noisily cge_elasticities incelas, country(TGO) values
assert _rc == 459
capture noisily cge_elasticities incelas, country(TGO) values map(com_xyz:food)
assert _rc == 111
capture noisily cge_elasticities incelas, country(TGO) values map(com_agr:food)
assert _rc == 459
capture noisily cge_elasticities incelas, country(TGO) values map(com_agr:fruit) others(food)
assert _rc == 111
capture noisily cge_elasticities sigmaq, country(TGO) map(com_agr:aggregate)
assert _rc == 198
capture noisily cge_elasticities, country(TGO) values
assert _rc == 198
capture noisily cge_elasticities wagecurve, values
assert _rc == 459
capture noisily cge_elasticities sigmaq, country(TGO) values clear
assert _rc == 198
capture noisily cge_elasticities sigmaq using nofile.csv
assert _rc == 601
cge_synthetic, clear
quietly cge_sam, labels(account)
capture noisily cge_elasticities sigmaq, country(TGO) values
assert _rc == 459
