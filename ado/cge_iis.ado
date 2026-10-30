*! cge_iis.ado  v0.36.0  2026-10-30
*! cge-stata: an irreducible infeasible set of the bounds and constraints of
*! the current scenario, by the deletion filter (Reference Manual, cge_iis)
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_iis, rclass
    version 13.0
    syntax [, TOLerance(real -1) ITERate(integer -1) TRACE]
    if `tolerance' != -1 & !(`tolerance' > 0) {
        display as error "tolerance() must be positive"
        exit 198
    }
    if `iterate' != -1 & `iterate' < 1 {
        display as error "iterate() must be 1 or more"
        exit 198
    }
    _cge_load
    mata: _cge_iis(`tolerance', `iterate', ("`trace'" != ""))
    return add
end
