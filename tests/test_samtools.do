* test_samtools.do -- SAM tools (version 0.3.0; docs/sam_tools.md): readers,
* writer, mapping template, aggregation and balancing, against the Python
* reference (expected files samtools_*.csv and agg_*.csv)

version 13.0

quietly do helpers_reference.do

* The SAM of the current model against a CSV file: the same labels, and cells
* within tol times the largest cell of the file
capture program drop _compare_sam
program define _compare_sam
    args file tol
    tempfile mine
    quietly cge_samexport using "`mine'.csv", replace
    preserve
    quietly import delimited using "`mine'.csv", varnames(1) case(preserve) stringcols(1) asdouble clear
    local lab1 ""
    forvalues i = 1/`=_N' {
        local lab1 `lab1' `=account[`i']'
    }
    quietly ds account, not
    mkmat `r(varlist)', matrix(_A)
    quietly import delimited using "`file'", varnames(1) case(preserve) stringcols(1) asdouble clear
    local lab2 ""
    forvalues i = 1/`=_N' {
        local lab2 `lab2' `=account[`i']'
    }
    assert "`lab1'" == "`lab2'"
    quietly ds account, not
    mkmat `r(varlist)', matrix(_B)
    mata: st_local("d", strofreal(max(abs(st_matrix("_A") - st_matrix("_B"))) / ///
        max((1, max(abs(st_matrix("_B"))))), "%21.0g"))
    display as text "`file': largest relative difference " as result %9.2e `d'
    assert `d' <= `tol'
    restore
    capture erase "`mine'.csv"
end

* The unbalanced SAM, read again
capture program drop _unbalanced
program define _unbalanced
    quietly cge_synthetic, clear unbalanced
    quietly cge_sam, labels(account)
end

local inst activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)         ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

* ---------------------------------------------------------------------
* 1. Balancing (Section 5)
* ---------------------------------------------------------------------

* RAS with average targets
_unbalanced
cge_balance, tolerance(1e-12)
assert abs(r(iterations) - 589) <= 2
assert r(maxdiff) <= 2e-12 * 158.729
_compare_sam "expected/samtools_ras.csv" 1e-9
tempfile ras
quietly cge_samexport using "`ras'.csv", replace

* Cross entropy with every total known gives the RAS solution
quietly cge_samexport, clear
quietly ds account, not
egen double total = rowtotal(`r(varlist)')
local tot ""
forvalues i = 1/`=_N' {
    local tot `tot' `=account[`i']':`=strofreal(total[`i'], "%21.0g")'
}
_unbalanced
cge_balance, method(ce) totals(`tot') tolerance(1e-12)
_compare_sam "`ras'.csv" 1e-9

* RAS with row totals as targets, a given target and fixed cells
_unbalanced
cge_balance, targets(rows) totals(gov:71) fixed(hhd:lab com_man:sav ent:cap) tolerance(1e-12)
_compare_sam "expected/samtools_ras_fixed.csv" 1e-9
quietly cge_samexport, clear
assert lab == 134.4151 if account == "hhd"
assert sav == 37.8098 if account == "com_man"
assert cap == 94.6853 if account == "ent"

* Cross entropy: totals estimated, then two totals known and fixed cells
_unbalanced
cge_balance, method(ce) tolerance(1e-12)
assert r(iterations) == 3
_compare_sam "expected/samtools_ce.csv" 1e-9
_unbalanced
cge_balance, method(ce) totals(act_agr:97 hhd:290) fixed(row:* hhd:lab) tolerance(1e-12)
assert r(iterations) == 5
_compare_sam "expected/samtools_ce_totals.csv" 1e-9

* The balanced SAM maps and calibrates (benchmark replication is checked)
cge_map, `inst'
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

* A balanced SAM is unchanged
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
cge_balance
assert r(iterations) == 1 & r(maxrelchange) < 1e-13
quietly cge_sam, labels(account)
cge_balance, method(ce)
assert r(iterations) == 0 & r(N_changed) == 0

* Targets that cannot be met, and other errors; the SAM is then unchanged
_unbalanced
capture noisily cge_balance, fixed(row:*)
assert _rc == 430
capture noisily cge_balance, fixed(tax_dir)
assert _rc == 459
capture noisily cge_balance, totals(lab:100) fixed(hhd:lab)
assert _rc == 459
capture noisily cge_balance, method(ce) fixed(tax_dir)
assert _rc == 459
capture cge_balance, fixed(nosuch:row)
assert _rc == 111
capture cge_balance, method(xyz)
assert _rc == 198
capture cge_balance, method(ce) targets(rows)
assert _rc == 198
capture cge_balance, totals(gov)
assert _rc == 198
capture cge_balance, fixed(*:*)
assert _rc == 198
quietly cge_balance, method(ce)
assert abs(r(maxdiff_before) - 12.0859) < 1e-6

* ---------------------------------------------------------------------
* 2. Template and aggregation (Sections 3 and 4)
* ---------------------------------------------------------------------

quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
tempfile tmpl tmpl2 tmpl3 tmpl4
* (tempfile names may repeat, so files named from them are replaced)
cge_template using "`tmpl'.csv", replace
assert r(N_accounts) == 17
capture cge_template using "`tmpl'.csv"
assert _rc == 602
* Roles and groups filled in as a user would, in mixed case and singular forms
preserve
quietly import delimited using "`tmpl'.csv", varnames(1) stringcols(_all) clear
assert _N == 17
assert role == "" & pair == "" & group == ""
assert real(difference) == 0
quietly replace role = "activities" if inlist(account, "act_agr", "act_man", "act_ser")
quietly replace role = "commodity" if substr(account, 1, 4) == "com_"
quietly replace role = "factors" if inlist(account, "lab", "cap")
quietly replace role = "Households" if inlist(account, "hhd", "npi")
quietly replace role = "enterprise" if account == "ent"
quietly replace role = "government" if account == "gov"
quietly replace role = "savinv" if account == "sav"
quietly replace role = "row" if account == "row"
quietly replace role = "dirtax" if account == "tax_dir"
quietly replace role = "saltax" if account == "tax_sal"
quietly replace role = "imptax" if account == "tax_imp"
quietly replace group = "act_nag" if inlist(account, "act_man", "act_ser")
quietly replace group = "com_nag" if inlist(account, "com_man", "com_ser")
quietly replace group = "hh" if inlist(account, "hhd", "npi")
quietly export delimited using "`tmpl'.csv", replace
* Versions with errors
quietly replace role = "factors" if account == "npi"
quietly export delimited using "`tmpl2'.csv", replace
quietly replace role = "Households" if account == "npi"
quietly replace role = "housholds" if account == "hhd"
quietly export delimited using "`tmpl3'.csv", replace
quietly replace role = "Households" if account == "hhd"
quietly replace role = "government" if account == "ent"
quietly export delimited using "`tmpl4'.csv", replace
restore

* Mapping from the template, before aggregation: pairs by largest sale
cge_map using "`tmpl'.csv"
assert strpos(`"`r(command)'"', "commodities(com_agr com_man com_ser)") > 0
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
_standard_simulations inst_

* Aggregation with the template's groups, then mapping from its roles
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
cge_aggregate using "`tmpl'.csv"
assert r(N_accounts) == 14 & r(N_diagonal) == 3 & r(maxdiff) < 1e-12
_compare_sam "expected/samtools_agg.csv" 1e-14
capture cge_aggregate using "`tmpl'.csv"
assert _rc == 459
cge_map using "`tmpl'.csv"
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
_standard_simulations agg_

* groups() gives the same SAM; netdiagonal removes the diagonal cells
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
cge_aggregate, groups(act_nag: act_man act_ser, com_nag: com_man com_ser, hh: hhd npi)
_compare_sam "expected/samtools_agg.csv" 1e-14
quietly cge_sam, labels(account)
cge_aggregate, groups(act_nag: act_man act_ser, com_nag: com_man com_ser, hh: hhd npi) netdiagonal
assert r(maxdiff) < 1e-12 & abs(r(total) - (1866 - 8)) < 1e-9
quietly cge_samexport, clear
assert hh == 0 if account == "hh"
assert gov == 0 if account == "gov"

* Template errors
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
capture noisily cge_aggregate using "`tmpl2'.csv"
assert _rc == 459
capture noisily cge_map using "`tmpl3'.csv"
assert _rc == 198
capture noisily cge_map using "`tmpl4'.csv"
assert _rc == 198
capture noisily cge_map using "`tmpl'.csv", government(gov)
assert _rc == 198
capture cge_aggregate, groups(a: act_man, b: act_man)
assert _rc == 198
capture cge_aggregate, groups(act_agr: act_man act_ser)
assert _rc == 198
capture cge_aggregate, groups(x: nosuch)
assert _rc == 111
capture cge_aggregate, groups(1x: act_man act_ser)
assert _rc == 198
capture cge_aggregate using "`tmpl'.csv", groups(x: act_man)
assert _rc == 198
capture cge_map, activities(act_agr) commodities(com_agr)
assert _rc == 198

* A template written from a mapped model: taxes paid directly to government
* (national-accounts layout), in Excel
quietly cge_synthetic, clear national
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                ///
    dirtax(gov) saltax(gov) imptax(tax_imp)
tempfile xl
cge_template using "`xl'.xlsx", replace
preserve
quietly import excel using "`xl'.xlsx", sheet("accounts") firstrow allstring clear
assert role == "government dirtax saltax" if account == "gov"
assert role == "activities" & pair == "com" + substr(account, 4, .) if substr(account, 1, 4) == "act_"
quietly import excel using "`xl'.xlsx", sheet("roles") firstrow allstring clear
assert _N == 21
restore
cge_map using "`xl'.xlsx"
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
_standard_simulations

* Territorial correction: the commodity is listed first although the
* activity comes first in the SAM
quietly cge_synthetic, clear territorial
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) territorial(com_tc act_tc)
cge_template using "`tmpl4'.csv", replace
cge_map using "`tmpl4'.csv"
assert strpos(`"`r(command)'"', "territorial(com_tc act_tc)") > 0
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
cge_solve, name(tc_tariff_removal) tolerance(1e-12)
_compare_reference tc_tariff_removal

* ---------------------------------------------------------------------
* 3. Readers and writer (Sections 1 and 2)
* ---------------------------------------------------------------------

* Wide data, the direct reader and long data give the same SAM
quietly cge_synthetic, clear unbalanced
local f `"`r(filename)'"'
quietly cge_sam, labels(account)
tempfile w
quietly cge_samexport using "`w'.csv", replace
cge_sam using `"`f'"', direct
assert "`r(source)'" == "direct" & r(N_accounts) == 17
_compare_sam "`w'.csv" 0
quietly cge_samexport, clear long
assert _N == 68
cge_sam, long(row column value)
assert "`r(source)'" == "long"
_compare_sam "`w'.csv" 0

* A SAM written and read again is unchanged, to the last digit
quietly cge_balance, method(ce)
tempfile exact
quietly cge_samexport, clear long
rename value value0
quietly save `exact'
foreach form in wide long {
    local opt = cond("`form'" == "long", "long", "")
    quietly cge_samexport using "`w'.csv", replace `opt'
    if "`form'" == "wide" cge_sam using "`w'.csv", direct
    else cge_sam using "`w'.csv", long(row column value) clear
    quietly cge_samexport, clear long
    quietly merge 1:1 row column using `exact'
    assert _merge == 3
    assert value == value0
}

* The SAM after the layout rewrites, with internal tax accounts
quietly cge_synthetic, clear national
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                ///
    dirtax(gov) saltax(gov) imptax(tax_imp)
cge_samexport, clear mapped
assert _N == 15
assert account[14] == "_dirtax" & account[15] == "_saltax"
tempfile dta
cge_samexport using "`dta'.dta", replace
capture cge_samexport using "`dta'.dta"
assert _rc == 602
capture cge_samexport
assert _rc == 198

* Labels that are not valid Stata names: the direct reader converts them as
* Stata does when it imports the file
tempfile lab
tempname fh
file open `fh' using "`lab'.csv", write replace
file write `fh' "account,s-i,1abc,x y" _n "s-i,1,2,3" _n "1abc,4,5,6" _n `""x y",7,8,9"' _n
file close `fh'
cge_sam using "`lab'.csv", direct
quietly cge_samexport, clear
assert account[1] == "si" & account[2] == "abc" & account[3] == "xy"
assert si[3] == 7
cge_sam using "`lab'.csv", clear
assert account[1] == "si" & account[2] == "abc" & account[3] == "xy"

* Reader errors
file open `fh' using "`lab'.csv", write replace
file write `fh' "account,a,b" _n "a,1,x1" _n "b,1,2" _n
file close `fh'
capture noisily cge_sam using "`lab'.csv", direct
assert _rc == 459
file open `fh' using "`lab'.csv", write replace
file write `fh' "account,a,b" _n "a,1,2" _n
file close `fh'
capture noisily cge_sam using "`lab'.csv", direct
assert _rc == 459
file open `fh' using "`lab'.csv", write replace
file write `fh' "account,a,b" _n "b,1,2" _n "a,1,2" _n
file close `fh'
capture noisily cge_sam using "`lab'.csv", direct
assert _rc == 459
file open `fh' using "`lab'.csv", write replace
file write `fh' "account,a.b,ab" _n "a.b,1,2" _n "ab,1,2" _n
file close `fh'
capture noisily cge_sam using "`lab'.csv", direct
assert _rc == 459
capture cge_sam using "`dta'.dta", direct
assert _rc == 198
clear
quietly set obs 2
generate str1 r = "a"
generate str1 c = "b"
generate double v = 1
capture noisily cge_sam, long(r c v)
assert _rc == 459
generate double rn = 1
capture cge_sam, long(rn c v)
assert _rc == 7

* A SAM with more accounts than Stata/IC can hold as variables: two cells in
* each row, read from long data, written as CSV and read again
clear
quietly set obs 4200
generate long i = mod(_n - 1, 2100) + 1
generate long j = cond(_n <= 2100, mod(i, 2100) + 1, mod(i + 6, 2100) + 1)
generate str6 row = "a" + string(i)
generate str6 column = "a" + string(j)
generate double value = 1 + mod(i * 7, 13) / 10
quietly summarize value
local total = r(sum)
cge_sam, long(row column value)
assert r(N_accounts) == 2100 & reldif(r(total), `total') < 1e-12
tempfile big
cge_samexport using "`big'.csv", replace
cge_sam using "`big'.csv", clear
if c(maxvar) < 2101 assert "`r(source)'" == "direct"
assert r(N_accounts) == 2100 & reldif(r(total), `total') < 1e-12
tempfile bigt
cge_template using "`bigt'.csv", replace
assert r(N_accounts) == 2100

* Files named from tempfiles are not removed by Stata
foreach f in "`ras'.csv" "`tmpl'.csv" "`tmpl2'.csv" "`tmpl3'.csv" "`tmpl4'.csv" "`xl'.xlsx" ///
    "`w'.csv" "`dta'.dta" "`lab'.csv" "`big'.csv" "`bigt'.csv" {
    capture erase `f'
}
