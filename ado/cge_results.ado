*! cge_results.ado  v0.6.4  2026-10-22
*! cge-stata: report the results of a simulation
*! Displays a summary and optionally loads or saves all results as a dataset
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_results, rclass
    version 13.0
    syntax [, SIM(name) CLEAR SAVing(string) NODisplay]

    _cge_load
    * The summary's results are stored with or without the display (from version 0.6.4)
    if "`nodisplay'" == "" mata: _cge_results_show("`sim'")
    else quietly mata: _cge_results_show("`sim'")

    if `"`saving'"' != "" {
        preserve
        drop _all
        mata: _cge_results_data("`sim'")
        _cge_results_label
        save `saving'
        restore
    }
    if "`clear'" != "" {
        drop _all
        mata: _cge_results_data("`sim'")
        _cge_results_label
    }
    return add
end

program define _cge_results_label
    label variable variable "Model variable"
    label variable element1 "First set element"
    label variable element2 "Second set element"
    label variable base "Base value"
    label variable value "Simulated value"
end
