*! cge_solve.ado  v0.10.1  2026-10-24
*! cge-stata: solve the model and store a named simulation
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_solve, rclass
    version 13.0
    syntax [, NAME(name) TOLerance(real 1e-10) ITERate(integer 100) TRACE FULL STEPs(integer 0) DIAGnose ///
        SParse DENse]
    if "`sparse'" != "" & "`dense'" != "" {
        display as error "give sparse or dense, not both"
        exit 198
    }

    if `steps' < 0 {
        display as error "steps() must be 0 (continuation only after a failure), 1 (none) or more"
        exit 198
    }
    _cge_load
    mata: _cge_solve("`name'", `tolerance', `iterate', ("`trace'" != ""), ("`full'" != ""), `steps', ///
        ("`diagnose'" != ""), "`sparse'`dense'")
    local converged = r(converged)
    return add
    if `converged' != 1 exit 430
end
