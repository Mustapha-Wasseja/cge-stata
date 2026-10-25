*! cge_options.ado  v0.27.0  2026-10-25
*! cge-stata: settings of the solver, as GAMS's option statement
*! (Reference Manual, cge_options)
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_options, rclass
    version 13.0
    syntax [, LINsolver(name) MCP(name) TOLerance(real -1) ITERate(integer -1) TIMElimit(real -1) ///
        JACobian(name) RESET]
    * python (from version 0.27.0): SciPy's SuperLU, Stata 16 and later
    if "`linsolver'" != "" & !inlist("`linsolver'", "dense", "sparse", "auto", "python") {
        display as error "linsolver() takes dense, sparse, auto or python"
        exit 198
    }
    * the method for constraints (from version 0.14.0)
    if "`mcp'" != "" & !inlist("`mcp'", "semismooth", "activeset") {
        display as error "mcp() takes semismooth or activeset"
        exit 198
    }
    * the tolerance, iteration limit and time limit of cge_solve and the
    * Jacobian of Newton's method (from version 0.16.0)
    if `tolerance' != -1 & !(`tolerance' > 0) {
        display as error "tolerance() must be positive"
        exit 198
    }
    if `iterate' != -1 & `iterate' < 1 {
        display as error "iterate() must be 1 or more"
        exit 198
    }
    if `timelimit' != -1 & !(`timelimit' >= 0) {
        display as error "timelimit() must be 0 or more seconds"
        exit 198
    }
    if "`jacobian'" != "" & !inlist("`jacobian'", "exact", "differences") {
        display as error "jacobian() takes exact or differences"
        exit 198
    }
    _cge_load
    mata: _cge_options("`linsolver'", "`mcp'", `tolerance', `iterate', `timelimit', "`jacobian'", ("`reset'" != ""))
    return add
end
