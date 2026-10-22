*! cge_save.ado  v0.6.4  2026-10-22
*! cge-stata: save the model in memory, with its simulations, to a file
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_save, rclass
    version 13.0
    syntax using/ [, REPLACE]

    _cge_load
    local fn `"`using'"'
    * The default extension, when the file name has none (a period in a folder name
    * does not count, from version 0.6.4)
    mata: st_local("ext", pathsuffix(st_local("fn")))
    if `"`ext'"' == "" local fn `"`fn'.cgem"'
    mata: _cge_save(`"`fn'"', ("`replace'" != ""))
    return local filename `"`fn'"'
end
