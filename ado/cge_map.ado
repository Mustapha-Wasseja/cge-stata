*! cge_map.ado  v0.3.2  2026-10-20
*! cge-stata: assign SAM accounts to model roles
*! Checks the SAM against the flows the model represents (model_spec.md, 7.0);
*! the roles may be read from a template (docs/sam_tools.md, Section 3)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_map, rclass
    version 13.0
    syntax [using/] [, activities(namelist) commodities(namelist) factors(namelist) ///
        households(namelist) government(name) savinv(name) row(name)                ///
        enterprises(namelist) margins(namelist) territorial(namelist)              ///
        marginaccounts(namelist) stocks(namelist) insurance(name)                  ///
        dirtax(name) saltax(name) imptax(name) exptax(name) acttax(name)           ///
        vattax(name) VATShare(string) DOMESTICmargins(namelist) IMPORTmargins(namelist) ///
        EXPORTmargins(namelist) SHEET(string) report(string) replace]

    _cge_load
    local roles `activities'`commodities'`factors'`households'`government'`savinv'`row'
    local roles `roles'`enterprises'`margins'`territorial'`marginaccounts'`stocks'`insurance'
    local roles `roles'`dirtax'`saltax'`imptax'`exptax'`acttax'`vattax'
    local roles `roles'`domesticmargins'`importmargins'`exportmargins'
    if `"`using'"' != "" {
        if "`roles'" != "" {
            display as error "with a template, give no role options"
            exit 198
        }
        _cge_tmpl using `"`using'"', sheet(`"`sheet'"')
        mata: _cge_map_template(`"`report'"', ("`replace'" != ""), strtrim(st_local("vatshare")))
        return add
        exit
    }
    if `"`sheet'"' != "" {
        display as error "sheet() needs a template named with using"
        exit 198
    }
    foreach opt in activities commodities factors households government savinv row {
        if "``opt''" == "" {
            display as error "option `opt'() required"
            exit 198
        }
    }
    mata: _cge_map("`activities'", "`commodities'", "`factors'", "`households'", ///
        "`enterprises'", "`government'", "`savinv'", "`row'", "`dirtax'",          ///
        "`saltax'", "`imptax'", "`exptax'", "`acttax'", "`margins'",                ///
        "`territorial'", "`marginaccounts'", "`stocks'", "`insurance'",             ///
        `"`report'"', ("`replace'" != ""), "`vattax'", strtrim(st_local("vatshare")),     ///
        "`domesticmargins'", "`importmargins'", "`exportmargins'")
    return add
end
