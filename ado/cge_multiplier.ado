*! cge_multiplier.ado  v0.4.1  2026-10-21
*! cge-stata: accounting multipliers of the mapped SAM and their decomposition
*! (docs/sam_tools.md, Section 6; Pyatt and Round 1979)
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_multiplier, rclass
    version 13.0
    syntax [, ENDOgenous(namelist) EXOgenous(namelist) INJect(string) DECOMPose ///
        ACCounts(namelist) CLEAR]

    _cge_load
    if "`clear'" != "" clear
    mata: _cge_mult("`endogenous'", "`exogenous'", strtrim(st_local("inject")), "`decompose'" != "", ///
        "`accounts'", "`clear'" != "")
    return add
end
