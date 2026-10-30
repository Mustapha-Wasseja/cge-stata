*! cge_sensitivity.ado  v0.38.0  2026-10-30
*! cge-stata: sensitivity of a scenario's results to the elasticities
*! Monte Carlo draws of the elasticities; the model is recalibrated for each.
*! From version 0.38.0, draws of the parameters of a standalone model, each
*! draw measured from its own benchmark
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_sensitivity, rclass
    version 13.0
    syntax , SCENario(name) DRAWs(integer) [SEED(integer 12345) SPRead(real 0.5)  ///
        DISTribution(string) COMMON VARy(string) TABles(string) KEEP(name) CLEAR SAVing(string) NODisplay ///
        CALibrate(name) VARIables(string) ITEMs(string)]

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
    if "`calibrate'" != "" {
        capture program list `calibrate'
        if _rc {
            display as error "calibrate(): program `calibrate' not found"
            exit 111
        }
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
    * a standalone model (from version 0.38.0): draws of its parameters
    mata: _cge_sens_sa_local()
    if !`sa' & "`calibrate'" != "" {
        display as error "calibrate(): a model from a SAM is calibrated again for each draw; calibrate() is for standalone models"
        exit 198
    }

    * The model is saved and restored exactly at the end
    tempfile model
    local model "`model'.cgem"
    quietly cge_save using "`model'", replace
    if `sa' {
        mata: _cge_sens_sa_init(`draws', `seed', `spread', "`distribution'", st_local("vary"), ("`common'" != ""), ///
            "`keep'", st_local("variables"), st_local("items"))
        display as text "Sensitivity analysis: " as result `draws' as text " draws of the parameters `vary' (" ///
            as result "`distribution'" as text " within +/-" as result `spread' * 100 as text " per cent)"
    }
    else {
        mata: _cge_sens_init(`draws', `seed', `spread', "`distribution'", "`vary'", ("`common'" != ""), "`keep'", ///
            st_local("variables"), st_local("items"))
        display as text "Sensitivity analysis: " as result `draws' as text " draws of the elasticities (" ///
            as result "`distribution'" as text " within +/-" as result `spread' * 100 as text " per cent)"
    }
    forvalues d = 0/`draws' {
        if `sa' {
            * the model as it was, the parameters of the draw, the program
            * of calibrate() and the draw's benchmark, its base
            quietly cge_use using "`model'"
            capture quietly mata: _cge_sens_sa_apply(`d')
            local rc = _rc
            if !`rc' & "`calibrate'" != "" {
                * parameters used by equations may be assigned again
                mata: (void) _cge_recal(1)
                capture quietly `calibrate'
                local rc = _rc
                mata: (void) _cge_recal(0)
                if `rc' {
                    display as error "calibrate(): `calibrate' failed"
                    quietly cge_use using "`model'"
                    mata: _cge_sens_end()
                    exit `rc'
                }
            }
            if !`rc' {
                capture quietly cge_solve, name(_sensbase)
                local rc = _rc
                if !`rc' quietly mata: _cge_sens_sa_rebase()
            }
        }
        else {
            capture quietly mata: _cge_sens_calibrate(`d')
            local rc = _rc
        }
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
        capture noisily mata: _cge_sens_collect(`d', `conv')
        if _rc {
            local rc = _rc
            quietly cge_use using "`model'"
            mata: _cge_sens_end()
            exit `rc'
        }
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
