*! cge_elasticities.ado  v0.3.5  2026-10-20
*! cge-stata: published elasticities, with their sources (docs/elasticities.md)
*! Lists or loads entries of the elasticity library, or turns them into
*! option values for cge_calibrate
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_elasticities, rclass
    version 13.0
    syntax [name(name=parameter)] [using/] [, Country(string) CATegory(string) SOUrce(string) ///
        ID(string) CLEAR VALues MAP(string) OTHers(name)]

    if "`clear'" != "" & "`values'" != "" {
        display as error "clear and values may not be combined"
        exit 198
    }
    if ("`map'" != "" | "`others'" != "") & "`values'" == "" {
        display as error "map() and others() need values"
        exit 198
    }
    quietly findfile cge_elasticities.csv
    local lib "`r(fn)'"
    quietly findfile cge_elasticity_sources.csv
    local src "`r(fn)'"
    if "`using'" != "" confirm file `"`using'"'
    _cge_load
    if "`clear'" != "" clear
    mata: _cge_elas("`parameter'", "`country'", "`category'", "`source'", "`id'", `"`lib'"', `"`src'"', ///
        `"`using'"', "`clear'" != "", "`values'" != "", "`map'", "`others'")
    return add
end
