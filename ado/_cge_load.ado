*! _cge_load.ado  v0.1.0  2026-10-12
*! cge-stata: load the Mata library on first use in a Stata session
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define _cge_load, rclass
    version 13.0
    capture mata: _cge_version()
    if _rc {
        quietly findfile cge_mata.mata
        quietly run `"`r(fn)'"'
    }
end
