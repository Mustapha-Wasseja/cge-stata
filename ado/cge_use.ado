*! cge_use.ado  v0.1.15  2026-10-16
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
    if strpos(`"`fn'"', ".") == 0 local fn `"`fn'.cgem"'
    mata: _cge_use(`"`fn'"')
    return add
    return local filename `"`fn'"'
end
