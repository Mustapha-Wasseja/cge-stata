*! cge_solve.ado  v0.1.0  2026-10-12
*! cge-stata: solve the model and store a named simulation
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_solve, rclass
    version 13.0
    syntax [, NAME(name) TOLerance(real 1e-10) ITERate(integer 100) TRACE FULL]

    _cge_load
    mata: _cge_solve("`name'", `tolerance', `iterate', ("`trace'" != ""), ("`full'" != ""))
    local converged = r(converged)
    return add
    if `converged' != 1 exit 430
end
