*! cge_save.ado  v0.1.15  2026-10-16
*! cge-stata: save the model in memory, with its simulations, to a file
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_save, rclass
    version 13.0
    syntax using/ [, REPLACE]

    _cge_load
    local fn `"`using'"'
    if strpos(`"`fn'"', ".") == 0 local fn `"`fn'.cgem"'
    mata: _cge_save(`"`fn'"', ("`replace'" != ""))
    return local filename `"`fn'"'
end
