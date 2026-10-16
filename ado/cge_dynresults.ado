*! cge_dynresults.ado  v0.2.0  2026-10-16
*! cge-stata: the results of a dynamic run as a dataset, one observation per
*! period and variable element, optionally compared with a baseline run
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_dynresults, rclass
    version 13.0
    syntax , RUN(name) CLEAR [BASEline(name)]

    _cge_load
    drop _all
    mata: _cge_dyn_data("`run'", "`baseline'")
    sort period variable element1 element2
    return local run "`run'"
end
