*! cge_sensitivity.ado  v0.8.3  2026-10-23
*! cge-stata: sensitivity of a scenario's results to the elasticities
*! Monte Carlo draws of the elasticities; the model is recalibrated for each
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_sensitivity, rclass
    version 13.0
    syntax , SCENario(name) DRAWs(integer) [SEED(integer 12345) SPRead(real 0.5)  ///
        DISTribution(string) COMMON VARy(string) TABles(string) KEEP(name) CLEAR SAVing(string) NODisplay]

    if `draws' < 1 {
        display as error "draws() must be at least 1"
        exit 198
    }
    if "`distribution'" == "" local distribution uniform
    capture program list `scenario'
    if _rc {
        display as error "scenario(): program `scenario' not found"
        exit 111
    }
    local file ""
    local replace ""
    if `"`saving'"' != "" {
        gettoken file rest : saving, parse(",")
        local file = trim(`"`file'"')
        gettoken comma rest : rest, parse(",")
        if trim(`"`rest'"') == "replace" local replace replace
    }
    _cge_load

    * The model is saved and restored exactly at the end
    tempfile model
    local model "`model'.cgem"
    quietly cge_save using "`model'", replace
    mata: _cge_sens_init(`draws', `seed', `spread', "`distribution'", "`vary'", ("`common'" != ""), "`keep'")
    display as text "Sensitivity analysis: " as result `draws' as text " draws of the elasticities (" ///
        as result "`distribution'" as text " within +/-" as result `spread' * 100 as text " per cent)"
    forvalues d = 0/`draws' {
        capture quietly mata: _cge_sens_calibrate(`d')
        local rc = _rc
        if !`rc' {
            capture quietly `scenario'
            local rc = _rc
            if `rc' {
                display as error "scenario(): `scenario' failed"
                quietly cge_use using "`model'"
                mata: _cge_sens_end()
                exit `rc'
            }
            capture quietly cge_solve, name(_sens)
            local conv = (_rc == 0)
        }
        else local conv 0
        mata: _cge_sens_collect(`d', `conv')
        if mod(`d', 10) == 0 & `d' > 0 display as text "  " as result `d' as text " draws done"
    }
    quietly cge_use using "`model'"
    * The draws kept as simulations keep0, keep1, ... (from version 0.8.3)
    if "`keep'" != "" mata: _cge_sens_keep("`keep'")
    * The results of restoring the model are not results of this command
    mata: st_rclear()

    local show = ("`nodisplay'" == "")
    if "`clear'" != "" {
        drop _all
        mata: _cge_sens_finish("`tables'", `show', 1)
        local show 0
    }
    else if `"`file'"' == "" {
        mata: _cge_sens_finish("`tables'", `show', 0)
    }
    if `"`file'"' != "" {
        preserve
        drop _all
        mata: _cge_sens_finish("`tables'", `show', 1)
        save `"`file'"', `replace'
        restore
    }
    mata: _cge_sens_end()
    return add
end
