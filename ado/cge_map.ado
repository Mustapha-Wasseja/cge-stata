*! cge_map.ado  v0.1.4  2026-10-14
*! cge-stata: assign SAM accounts to model roles
*! Checks the SAM against the flows the model represents (model_spec.md, 7.0)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_map, rclass
    version 13.0
    syntax , activities(namelist) commodities(namelist) factors(namelist) ///
        households(namelist) government(name) savinv(name) row(name)        ///
        [enterprises(namelist) margins(namelist) territorial(namelist)       ///
        dirtax(name) saltax(name) imptax(name) exptax(name) acttax(name)     ///
        report(string) replace]

    _cge_load
    mata: _cge_map("`activities'", "`commodities'", "`factors'", "`households'", ///
        "`enterprises'", "`government'", "`savinv'", "`row'", "`dirtax'",          ///
        "`saltax'", "`imptax'", "`exptax'", "`acttax'", "`margins'",                ///
        "`territorial'", `"`report'"',                                              ///
        ("`replace'" != ""))
    return add
end
