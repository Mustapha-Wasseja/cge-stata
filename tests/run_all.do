* run_all.do -- cge-stata Stata test suite
* Run from the tests folder, e.g. with tools/run_stata_tests.ps1.
* Results lines start with PASS or FAIL; the last line is a summary.

version 13.0
clear all
set more off

* Use the development copies of the package files ahead of any installed copy
adopath ++ "../ado"
adopath ++ "../data"

local tests test_environment test_synthetic_sam test_reference_agreement test_checks

local npass = 0
local nfail = 0
foreach t of local tests {
    capture noisily do `t'.do
    if _rc {
        display as error "FAIL `t' (rc = " _rc ")"
        local ++nfail
    }
    else {
        display as result "PASS `t'"
        local ++npass
    }
}

display _n "Summary: `npass' passed, `nfail' failed"
if `nfail' > 0 exit 9
