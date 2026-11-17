*! cge_dynamic.ado  v0.10.2  2026-10-24
*! cge-stata: solve a dynamic run, recursive or with perfect foresight
*! (model_spec.md, Section 10). Each period is stored as the simulation
*! <name><period>
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_dynamic, rclass
    version 13.0
    * a standalone model has no SAM (from version 0.13.0)
    _cge_load
    mata: _cge_need_sam()
    syntax , NAME(name) PERiods(numlist integer ascending min=2) [CAPital(namelist)  ///
        DEPreciation(numlist >=0 <1) RENTal(numlist >0) SENSitivity(real 1)             ///
        GROWth(string) TFP(numlist) GDPgrowth(numlist) BASEline(name)                   ///
        POPulation(real 0) GOVgrowth(real 0) FOReigngrowth(real 0) SHOCKs(name)         ///
        TOLerance(real 1e-12) ITERate(integer 100)                                      ///
        DEATHFactors(namelist) DEATHShare(real 0) WORKingage(real 1)                    ///
        FORESight TERMinal(string) START(string)]

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
    if "`foresight'" == "" & (`"`terminal'"' != "" | `"`start'"' != "") {
        display as error "terminal() and start() need foresight"
        exit 198
    }
    _cge_load
    mata: _cge_dyn_start("`name'", "`periods'", "`capital'", "`depreciation'", "`rental'", ///
        `sensitivity', `"`growth'"', "`tfp'", "`gdpgrowth'", "`baseline'", `population',   ///
        `govgrowth', `foreigngrowth', `tolerance', `iterate', "`deathfactors'", `deathshare', ///
        `workingage', `= "`foresight'" != ""')

    * Perfect foresight (from version 0.10.2): the exogenous path of every
    * period, its shocks included, then the periods solved together. The
    * shocks() program runs twice in each period, the second time quietly, to
    * find its effect on capital and debt.
    if "`foresight'" != "" {
        local first 1
        foreach t of numlist `periods' {
            if `first' {
                capture noisily mata: _cge_fs_start(`"`terminal'"', `"`start'"')
            }
            else {
                capture noisily mata: _cge_fs_advance()
                if !_rc & "`shocks'" != "" {
                    capture noisily mata: _cge_fs_probe(1)
                    if !_rc {
                        capture noisily `shocks' `t'
                        if _rc {
                            local rc = _rc
                            mata: _cge_dyn_abort()
                            display as error "shocks(): `shocks' `t' failed; run `name' not stored"
                            exit `rc'
                        }
                        capture noisily mata: _cge_fs_probe(2)
                    }
                    if !_rc {
                        capture quietly `shocks' `t'
                        if !_rc capture noisily mata: _cge_fs_probe(3)
                    }
                }
                if !_rc capture noisily mata: _cge_fs_record()
            }
            if _rc {
                local rc = _rc
                mata: _cge_dyn_abort()
                display as error "period `t' failed; run `name' not stored"
                exit `rc'
            }
            local first 0
        }
        capture noisily mata: _cge_fs_solve()
        if _rc {
            local rc = _rc
            mata: _cge_dyn_abort()
            display as error "run `name' not stored"
            exit `rc'
        }
        mata: _cge_dyn_end()
        mata: _cge_run_sims_local("`name'", "sims")
        display as text "Dynamic run {res}`name'{txt} with perfect foresight stored as simulations: {res}`sims'"
        return local sims "`sims'"
        return local name "`name'"
        return local foresight "foresight"
        exit
    }

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
