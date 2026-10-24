*! cge_loop.ado  v0.9.9  2026-10-24
*! cge-stata: solve the model for a list or grid of scenarios, as a GAMS loop
*! over a set of scenarios or GUSS does (Reference Manual, cge_loop)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_loop, rclass
    version 13.0
    syntax [using/] , NAME(name) [VALues(string asis) GRID SCale COLD NOSTORE KEEP(string) ///
        MEASures(string asis) CLEAR TOLerance(real 1e-10) ITERate(integer 100)]
    _cge_load
    if (`"`values'"' != "") == (`"`using'"' != "") {
        display as error "cge_loop: give values() or using, one of them"
        exit 198
    }
    if `tolerance' <= 0 | `iterate' < 1 {
        display as error "cge_loop: tolerance() must be positive and iterate() at least 1"
        exit 198
    }
    if `"`using'"' != "" & "`grid'" != "" {
        display as error "cge_loop: grid combines the lists of values(); a dataset lists its scenarios"
        exit 198
    }
    local targets
    local lists
    if `"`values'"' != "" {
        * target = numlist, separated by semicolons
        local spec `"`values'"'
        while `"`spec'"' != "" {
            gettoken part spec : spec, parse(";")
            if `"`part'"' == ";" continue
            local eq = strpos(`"`part'"', "=")
            if !`eq' {
                display as error `"cge_loop: values(): write target = values, as tm(com_man) = 0 0.1 0.2; `part' has no ="'
                exit 198
            }
            local t = subinstr(strtrim(substr(`"`part'"', 1, `eq' - 1)), " ", "", .)
            local nl = strtrim(substr(`"`part'"', `eq' + 1, .))
            if "`t'" == "" | `"`nl'"' == "" {
                display as error "cge_loop: values(): write target = values for each target"
                exit 198
            }
            capture numlist `"`nl'"'
            if _rc {
                display as error `"cge_loop: values(): `nl' is not a list of numbers"'
                exit 198
            }
            local targets `targets' `t'
            local lists `"`lists'`r(numlist)'|"'
        }
        local lists = substr(`"`lists'"', 1, strlen(`"`lists'"') - 1)
    }
    else {
        * a dataset of scenarios, one observation per scenario and target
        preserve
        quietly use `"`using'"', clear
        foreach v in scenario target value {
            capture confirm variable `v', exact
            if _rc {
                display as error "cge_loop: the dataset needs the variables scenario, target and value"
                exit 111
            }
        }
        mata: _cge_loop_read()
        restore
    }
    mata: _cge_loop("`name'", "`targets'", st_local("lists"), ("`grid'" != ""), ("`scale'" != ""), ("`cold'" != ""), ///
        ("`nostore'" == ""), "`keep'", st_local("measures"), ("`clear'" != ""), `tolerance', `iterate', (`"`using'"' != ""))
    return add
end
