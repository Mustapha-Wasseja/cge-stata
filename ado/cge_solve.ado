*! cge_solve.ado  v0.4.5  2026-10-21
*! cge-stata: solve the model and store a named simulation
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_solve, rclass
    version 13.0
    syntax [, NAME(name) TOLerance(real 1e-10) ITERate(integer 100) TRACE FULL STEPs(integer 0) DIAGnose]

    if `steps' < 0 {
        display as error "steps() must be 0 (continuation only after a failure), 1 (none) or more"
        exit 198
    }
    _cge_load
    mata: _cge_solve("`name'", `tolerance', `iterate', ("`trace'" != ""), ("`full'" != ""), `steps', ///
        ("`diagnose'" != ""))
    local converged = r(converged)
    return add
    if `converged' != 1 exit 430
end
