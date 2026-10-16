*! cge_parameters.ado  v0.1.15  2026-10-16
*! cge-stata: the calibrated parameters as a dataset
*! One observation per parameter element (model_spec.md, Section 4)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_parameters, rclass
    version 13.0
    syntax , CLEAR [SIM(name) CURrent]

    if "`sim'" != "" & "`current'" != "" {
        display as error "choose sim() or current, not both"
        exit 198
    }
    _cge_load
    drop _all
    mata: _cge_param_data("`sim'", ("`current'" != ""))
    return add
end
