*! cge_use.ado  v0.6.4  2026-10-22
*! cge-stata: load a model saved with cge_save
*! Replaces the model in memory; the dataset in memory is not changed
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_use, rclass
    version 13.0
    syntax using/

    _cge_load
    local fn `"`using'"'
    * The default extension, when the file name has none (a period in a folder name
    * does not count, from version 0.6.4)
    mata: st_local("ext", pathsuffix(st_local("fn")))
    if `"`ext'"' == "" local fn `"`fn'.cgem"'
    mata: _cge_use(`"`fn'"')
    return add
    return local filename `"`fn'"'
end
