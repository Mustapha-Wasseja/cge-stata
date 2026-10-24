*! cge_options.ado  v0.10.1  2026-10-24
*! cge-stata: settings of the solver, as GAMS's option statement
*! (Reference Manual, cge_options)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_options, rclass
    version 13.0
    syntax [, LINsolver(name)]
    if "`linsolver'" != "" & !inlist("`linsolver'", "dense", "sparse", "auto") {
        display as error "linsolver() takes dense, sparse or auto"
        exit 198
    }
    _cge_load
    mata: _cge_options("`linsolver'")
    return add
end
