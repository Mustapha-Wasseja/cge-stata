*! cge_aggregate.ado  v0.3.0  2026-10-18
*! cge-stata: merge SAM accounts into groups (docs/sam_tools.md, Section 4)
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_aggregate, rclass
    version 13.0
    syntax [using/] [, GROUPS(string) SHEET(string) NETdiagonal]

    if (`"`using'"' != "") + (`"`groups'"' != "") != 1 {
        display as error "give either a template with using or groups()"
        exit 198
    }
    _cge_load
    if `"`using'"' != "" {
        _cge_tmpl using `"`using'"', sheet(`"`sheet'"')
        mata: _cge_aggregate_template(("`netdiagonal'" != ""))
    }
    else {
        mata: _cge_aggregate_spec(st_local("groups"), ("`netdiagonal'" != ""))
    }
    return add
end
