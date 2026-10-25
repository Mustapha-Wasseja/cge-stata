*! cge_solve.ado  v0.18.0  2026-10-25
*! cge-stata: solve the model and store a named simulation
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_solve, rclass
    version 13.0
    * tolerance(), iterate() and timelimit() default to the settings of
    * cge_options (from version 0.16.0): 1e-10, 100 and none unless changed
    * model() and from() (from version 0.17.0): a named model of a standalone
    * model, and a start from a stored simulation
    syntax [, NAME(name) TOLerance(real -1) ITERate(integer -1) TIMElimit(real -1) TRACE FULL STEPs(integer 0) ///
        DIAGnose SParse DENse MAXimize(string) MINimize(string) MODel(name) FROM(name) HOLD(string) ///
        NODes(integer -1) OPTCR(real -1)]
    if "`sparse'" != "" & "`dense'" != "" {
        display as error "give sparse or dense, not both"
        exit 198
    }

    if `steps' < 0 {
        display as error "steps() must be 0 (continuation only after a failure), 1 (none) or more"
        exit 198
    }
    if `tolerance' != -1 & !(`tolerance' > 0) {
        display as error "tolerance() must be positive"
        exit 198
    }
    if `iterate' < -1 {
        display as error "iterate() must be 0 or more"
        exit 198
    }
    * branch and bound (from version 0.18.0)
    if `nodes' != -1 & `nodes' < 1 {
        display as error "nodes() must be 1 or more"
        exit 198
    }
    if `optcr' != -1 & !(`optcr' >= 0) {
        display as error "optcr() must be 0 or more"
        exit 198
    }
    if `timelimit' != -1 & !(`timelimit' >= 0) {
        display as error "timelimit() must be 0 or more seconds"
        exit 198
    }
    * a nonlinear programme of a standalone model (from version 0.15.0)
    if `"`maximize'"' != "" & `"`minimize'"' != "" {
        display as error "give maximize() or minimize(), not both"
        exit 198
    }
    local obj
    if `"`maximize'"' != "" local obj `"max:`maximize'"'
    if `"`minimize'"' != "" local obj `"min:`minimize'"'
    _cge_load
    * the deadline of the time limit is cleared even when the solve stops with
    * an error
    capture noisily mata: _cge_solve("`name'", `tolerance', `iterate', ("`trace'" != ""), ("`full'" != ""), `steps', ///
        ("`diagnose'" != ""), "`sparse'`dense'", st_local("obj"), `timelimit', "`model'", "`from'", st_local("hold"), `nodes', `optcr')
    local rc = _rc
    mata: _cge_deadline_set(.)
    if `rc' exit `rc'
    local converged = r(converged)
    return add
    if `converged' != 1 exit 430
end
