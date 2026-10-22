* Examples of [CGE] cge_sam. The SAMs are SYNTHETIC.
*>> sam_wide
cge_synthetic, clear
cge_sam, labels(account)
*<<

*>> sam_rename
cge_synthetic, clear sut
cge_sam, labels(account)
*<<

*>> sam_long
clear
input str8 row str8 column double value
"act"  "com"  100
"com"  "act"   40
"com"  "hhd"   50
"com"  "s-i"   10
"lab"  "act"   60
"hhd"  "lab"   60
"s-i"  "hhd"   10
"hhd"  "com"    .
end
cge_sam, long(row column value)
*<<

* A wide CSV file, written as cge_samexport writes it
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_samexport using sam.csv, replace

*>> sam_direct
cge_synthetic, clear
cge_sam using sam.csv, direct
describe, short
*<<

* A CSV file with a thousands separator
file open fh using bad.csv, write replace
file write fh "account,act,com" _n
file write fh `"act,0,"1,234""' _n
file write fh `"com,"1,234",0"' _n
file close fh

*>> sam_notnum
type bad.csv
capture noisily cge_sam using bad.csv, direct
di as err "r(" _rc ");"
*<<
