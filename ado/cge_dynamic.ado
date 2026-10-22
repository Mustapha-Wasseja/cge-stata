*! cge_dynamic.ado  v0.6.4  2026-10-22
*! cge-stata: solve a recursive dynamic run (model_spec.md, Section 10)
*! Each period is stored as the simulation <name><period>
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_dynamic, rclass
    version 13.0
    syntax , NAME(name) PERiods(numlist integer ascending min=2) [CAPital(namelist)  ///
        DEPreciation(numlist >=0 <1) RENTal(numlist >0) SENSitivity(real 1)             ///
        GROWth(string) TFP(numlist) GDPgrowth(numlist) BASEline(name)                   ///
        POPulation(real 0) GOVgrowth(real 0) FOReigngrowth(real 0) SHOCKs(name)         ///
        TOLerance(real 1e-12) ITERate(integer 100)                                      ///
        DEATHFactors(namelist) DEATHShare(real 0) WORKingage(real 1)]

    * Simulation names must be valid Stata names
    foreach t of numlist `periods' {
        if `t' < 0 {
            display as error "periods() must be zero or positive"
            exit 198
        }
        capture confirm name `name'`t'
        if _rc | strlen("`name'`t'") > 32 {
            display as error "`name'`t' is not a valid simulation name; use a shorter name()"
            exit 198
        }
    }
    _cge_load
    mata: _cge_dyn_start("`name'", "`periods'", "`capital'", "`depreciation'", "`rental'", ///
        `sensitivity', `"`growth'"', "`tfp'", "`gdpgrowth'", "`baseline'", `population',   ///
        `govgrowth', `foreigngrowth', `tolerance', `iterate', "`deathfactors'", `deathshare', ///
        `workingage')
    * A run that fails leaves the model, and its stored simulations, as they
    * were before the run (from version 0.6.4)
    local first 1
    foreach t of numlist `periods' {
        if !`first' {
            capture noisily mata: _cge_dyn_advance()
            if _rc {
                local rc = _rc
                mata: _cge_dyn_abort()
                display as error "period `t' failed; run `name' not stored"
                exit `rc'
            }
            if "`shocks'" != "" {
                capture noisily `shocks' `t'
                if _rc {
                    local rc = _rc
                    mata: _cge_dyn_abort()
                    display as error "shocks(): `shocks' `t' failed; run `name' not stored"
                    exit `rc'
                }
            }
        }
        capture noisily mata: _cge_dyn_solve(`t', `first')
        if _rc {
            local rc = _rc
            mata: _cge_dyn_abort()
            display as error "period `t' failed; run `name' not stored"
            exit `rc'
        }
        local first 0
    }
    mata: _cge_dyn_end()
    mata: _cge_run_sims_local("`name'", "sims")
    display as text "Dynamic run {res}`name'{txt} stored as simulations: {res}`sims'"
    return local sims "`sims'"
    return local name "`name'"
end
