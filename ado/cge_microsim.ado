*! cge_microsim.ado  v0.2.2  2026-10-16
*! cge-stata: pass a simulation to household survey data (model_spec.md,
*! Section 11): consumption, prices, poverty and inequality by household
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_microsim, rclass
    version 13.0
    syntax [if] [in] [pweight aweight fweight iweight], SIM(name) GROUP(varname)   ///
        CONSumption(varname numeric) [SIZE(varname numeric) INCome(string)          ///
        BUDget(string) LINE(real -1) GENerate(name) REPLACE NODisplay]

    marksample touse, novarlist
    * Survey weights of any type are used as proportional household weights
    local wvar ""
    if "`weight'" != "" {
        tempvar wvar
        quietly generate double `wvar' `exp' if `touse'
    }
    markout `touse' `consumption' `wvar' `size'
    * Variables named in income() and budget() must exist and be numeric
    foreach spec in income budget {
        foreach pair of local `spec' {
            gettoken v : pair, parse(":")
            confirm numeric variable `v'
            markout `touse' `v'
        }
    }
    * The group as a string: the variable itself, its value labels, or its values
    tempvar gs
    capture confirm string variable `group'
    if !_rc quietly generate `gs' = `group'
    else {
        capture decode `group', generate(`gs')
        if _rc quietly generate `gs' = string(`group')
    }
    markout `touse' `gs', strok
    if "`generate'" != "" {
        if strlen("`generate'") > 26 {
            display as error "generate(): use a name of at most 26 characters"
            exit 198
        }
        foreach suffix in nom price real pc {
            capture confirm new variable `generate'_`suffix'
            if _rc {
                if "`replace'" == "" {
                    display as error "variable `generate'_`suffix' already exists; use replace"
                    exit 110
                }
                drop `generate'_`suffix'
            }
        }
    }
    _cge_load
    mata: _cge_microsim("`sim'", "`touse'", "`gs'", "`consumption'", "`wvar'", "`size'", ///
        `"`income'"', `"`budget'"', `line', "`generate'", ("`nodisplay'" == ""))
    return add
end
