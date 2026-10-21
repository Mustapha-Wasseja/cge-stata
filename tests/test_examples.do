* test_examples.do -- every worked example in examples/ runs to the end
* (version 0.4.0; docs/manual)

version 13.0

local examples tariff_removal sam_preparation elasticities multipliers fiscal_instruments ///
    trade_home labour_market health_outcomes raw_sam_to_results gams_export
foreach f of local examples {
    display as text _n "Example `f'"
    quietly do "../examples/`f'.do"
    display as result "  ran to the end"
}
