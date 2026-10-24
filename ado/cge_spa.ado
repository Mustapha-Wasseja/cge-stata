*! cge_spa.ado  v0.4.2  2026-10-21
*! cge-stata: structural path analysis of the mapped SAM
*! (docs/sam_tools.md, Section 7; Defourny and Thorbecke 1984)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_spa, rclass
    version 13.0
    * a standalone model has no SAM (from version 0.13.0)
    _cge_load
    mata: _cge_need_sam()
    syntax , FROM(name) TO(name) [MAXlength(integer 6) THReshold(real 0.001) TOP(integer 10) ///
        ENDOgenous(namelist) EXOgenous(namelist) CLEAR]

    if `maxlength' < 1 {
        display as error "maxlength() must be at least 1"
        exit 198
    }
    if `threshold' < 0 {
        display as error "threshold() must be zero or positive"
        exit 198
    }
    if `top' < 1 {
        display as error "top() must be at least 1"
        exit 198
    }
    _cge_load
    if "`clear'" != "" clear
    mata: _cge_spa("`from'", "`to'", `maxlength', `threshold', `top', "`endogenous'", "`exogenous'", ///
        "`clear'" != "")
    return add
end
