*! cge_microsim.ado  v0.8.3  2026-10-23
*! cge-stata: pass one or more simulations to household survey data
*! (model_spec.md, Section 11): consumption, prices, poverty, inequality and
*! incidence by household; welfare, the decomposition of the changes and
*! fiscal incidence; reweighting, survey-design standard errors and bands
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_microsim, rclass
    version 13.0
    syntax [if] [in] [pweight aweight fweight iweight], SIM(string) GROUP(varname)   ///
        CONSumption(varname numeric) [SIZE(varname numeric) INCome(string)          ///
        BUDget(string) LINE(string) QUANTiles(integer 10) GENerate(name) REPLACE     ///
        DETail DECompose MARKet(varname numeric) DTax(varlist numeric) TRANSfers(varlist numeric) ///
        ITax(varlist numeric) SUBsidies(varlist numeric) INKind(string) REWeight(string) SVY BANDs(name) ///
        CLEAR SAVing(string) NODisplay]

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
    * Fiscal incidence (from version 0.8.2): market income and the instruments
    if "`market'" == "" & "`dtax'`transfers'`itax'`subsidies'`inkind'" != "" {
        display as error "give market() with the fiscal instruments"
        exit 198
    }
    if "`clear'" != "" & "`generate'" != "" {
        display as error "clear replaces the survey with the results; use saving() to keep the variables of generate()"
        exit 198
    }

    marksample touse, novarlist
    * Survey weights of any type are used as proportional household weights
    local wvar ""
    if "`weight'" != "" {
        if "`svy'" != "" {
            display as error "with svy, the weights are those of svyset"
            exit 198
        }
        tempvar wvar
        quietly generate double `wvar' `exp' if `touse'
    }
    * The survey design (from version 0.8.3): one stage, strata and clusters,
    * as svyset declares them
    local stvar ""
    local suvar ""
    if "`svy'" != "" {
        quietly svyset
        if `"`r(settings)'"' == ", clear" {
            display as error "data not set up for svy; use svyset"
            exit 119
        }
        if "`r(stages)'" != "" & "`r(stages)'" != "1" {
            display as error "svy: only designs with one stage are supported"
            exit 459
        }
        if "`r(fpc1)'" != "" {
            display as error "svy: finite population corrections are not supported"
            exit 459
        }
        if "`r(vce)'" != "" & "`r(vce)'" != "linearized" {
            display as error "svy: only linearized variances are supported"
            exit 459
        }
        if "`r(wvar)'" != "" {
            if "`r(wtype)'" != "pweight" {
                display as error "svy: the weights of svyset must be pweights"
                exit 459
            }
            tempvar wvar
            quietly generate double `wvar' = `r(wvar)' if `touse'
        }
        local su1 "`r(su1)'"
        local st1 "`r(strata1)'"
        if "`st1'" != "" {
            tempvar stvar
            quietly egen long `stvar' = group(`st1') if `touse', missing
            markout `touse' `st1', strok
        }
        if "`su1'" != "" & "`su1'" != "_n" {
            tempvar suvar
            quietly egen long `suvar' = group(`su1') if `touse', missing
            markout `touse' `su1', strok
        }
    }
    markout `touse' `consumption' `wvar' `size' `linevars' `market' `dtax' `transfers' `itax' `subsidies'
    * Variables named in income() and budget() must exist and be numeric
    foreach spec in income budget inkind reweight {
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
            local sfxs nom price real pc ev cv
            if "`market'" != "" local sfxs `sfxs' ym yn yd yc yf
            if "`reweight'" != "" local sfxs `sfxs' w
            foreach suffix of local sfxs {
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
        ("`nodisplay'" == ""), ("`detail'" != ""), ("`decompose'" != ""), "`market'", "`dtax'",       ///
        "`transfers'", "`itax'", "`subsidies'", `"`inkind'"', `"`reweight'"', ("`svy'" != ""),   ///
        "`stvar'", "`suvar'", "`bands'")
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
