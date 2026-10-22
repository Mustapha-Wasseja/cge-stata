*! cge_microsim.ado  v0.8.0  2026-10-23
*! cge-stata: pass one or more simulations to household survey data
*! (model_spec.md, Section 11): consumption, prices, poverty, inequality and
*! incidence by household
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_microsim, rclass
    version 13.0
    syntax [if] [in] [pweight aweight fweight iweight], SIM(string) GROUP(varname)   ///
        CONSumption(varname numeric) [SIZE(varname numeric) INCome(string)          ///
        BUDget(string) LINE(string) QUANTiles(integer 10) GENerate(name) REPLACE     ///
        DETail CLEAR SAVing(string) NODisplay]

    * Simulations: one or more (several from version 0.8.0)
    local sims `sim'
    local nsims : word count `sims'
    if `nsims' == 0 {
        display as error "sim(): give a simulation"
        exit 198
    }
    local dups : list dups sims
    if "`dups'" != "" {
        display as error "sim(): `dups' is given more than once"
        exit 198
    }

    * Poverty lines per person: positive numbers, or (from version 0.8.0)
    * numeric variables that give each household its line; without one, no
    * poverty measures are computed
    local lines ""
    local linevars ""
    foreach z of local line {
        if real("`z'") < . {
            if real("`z'") <= 0 {
                display as error "line() must be a positive poverty line per person"
                exit 198
            }
            local lines `lines' `z'
        }
        else {
            capture confirm numeric variable `z'
            if _rc {
                display as error "line(): `z' is neither a number nor a numeric variable"
                exit 198
            }
            unab z : `z', max(1)
            local lines `lines' `z'
            local linevars `linevars' `z'
        }
    }
    local dups : list dups lines
    if "`dups'" != "" {
        display as error "line(): `dups' is given more than once"
        exit 198
    }
    if `quantiles' < 2 | `quantiles' > 100 {
        display as error "quantiles() must be between 2 and 100"
        exit 198
    }

    * The results as a dataset (from version 0.8.0)
    local file ""
    local sreplace ""
    if `"`saving'"' != "" {
        gettoken file rest : saving, parse(",")
        local file = trim(`"`file'"')
        gettoken comma rest : rest, parse(",")
        if trim(`"`rest'"') == "replace" local sreplace replace
        else if trim(`"`rest'"') != "" {
            display as error "saving(): only the option replace is allowed"
            exit 198
        }
        if `"`file'"' == "" {
            display as error "saving(): give a file name"
            exit 198
        }
    }
    if "`clear'" != "" & "`generate'" != "" {
        display as error "clear replaces the survey with the results; use saving() to keep the variables of generate()"
        exit 198
    }

    marksample touse, novarlist
    * Survey weights of any type are used as proportional household weights
    local wvar ""
    if "`weight'" != "" {
        tempvar wvar
        quietly generate double `wvar' `exp' if `touse'
    }
    markout `touse' `consumption' `wvar' `size' `linevars'
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
        * with several simulations the variables are numbered: prefix_nom1, ...
        local num ""
        if `nsims' > 1 local num `nsims'
        if strlen("`generate'") + strlen("`num'") > 26 {
            display as error "generate(): use a name of at most " 26 - strlen("`num'") " characters"
            exit 198
        }
        local gvars `generate'_q
        forvalues k = 1/`nsims' {
            local sfx ""
            if `nsims' > 1 local sfx `k'
            foreach suffix in nom price real pc {
                local gvars `gvars' `generate'_`suffix'`sfx'
            }
        }
        foreach v of local gvars {
            capture confirm new variable `v'
            if _rc {
                if "`replace'" == "" {
                    display as error "variable `v' already exists; use replace"
                    exit 110
                }
                drop `v'
            }
        }
    }
    _cge_load
    mata: _cge_microsim("`sims'", "`touse'", "`gs'", "`consumption'", "`wvar'", "`size'", ///
        `"`income'"', `"`budget'"', "`lines'", `quantiles', "`generate'",              ///
        ("`nodisplay'" == ""), ("`detail'" != ""))
    return add

    if "`clear'" != "" {
        drop _all
        mata: _cge_ms_post()
        if `"`file'"' != "" {
            save `"`file'"', `sreplace'
        }
    }
    else if `"`file'"' != "" {
        preserve
        drop _all
        mata: _cge_ms_post()
        save `"`file'"', `sreplace'
        restore
    }
    else mata: _cge_ms_drop()
end
