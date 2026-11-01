*! _cge_load.ado  v0.44.0  2026-11-01
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
    * no command finds the definitions of cge_mpsge end that an error left
    * without their refresh (from version 0.44.0)
    mata: _cge_ub_clear()
end
