*! cge_dynresults.ado  v0.6.4  2026-10-22
*! cge-stata: the results of a dynamic run as a dataset, one observation per
*! period and variable element, optionally compared with a baseline run
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_dynresults, rclass
    version 13.0
    * a standalone model has no SAM (from version 0.13.0)
    _cge_load
    mata: _cge_need_sam()
    syntax , RUN(name) CLEAR [BASEline(name)]

    _cge_load
    * The data in memory are kept if the run cannot be loaded (from version 0.6.4)
    preserve
    drop _all
    mata: _cge_dyn_data("`run'", "`baseline'")
    sort period variable element1 element2
    restore, not
    return local run "`run'"
end
