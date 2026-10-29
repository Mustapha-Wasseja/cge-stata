* run_all.do -- cge-stata Stata test suite
* Run from the tests folder, e.g. with tools/run_stata_tests.ps1.
* Results lines start with PASS or FAIL; the last line is a summary.

version 13.0
clear all
set more off

* Use the development copies of the package files ahead of any installed copy
adopath ++ "../ado"
adopath ++ "../data"

local tests test_environment test_synthetic_sam test_reference_agreement test_checks test_reporting test_dynamics test_sensitivity test_microsim test_samtools test_fiscal test_trade_home test_labour test_outcomes test_elasticities test_multipliers test_spa test_gams test_constraints test_solver_tools test_factor_taxes test_nests test_output_ces test_optimize test_user test_bounds test_loop test_gdx test_sparse test_foresight test_fsjac test_cgenest test_region test_linkjac test_standalone test_mcp test_optgrad test_nlp test_status test_models test_mip test_parallel test_nash test_modlib test_multiindex test_lagindex test_scipy test_hessian test_setalgebra test_reverse test_examples

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
