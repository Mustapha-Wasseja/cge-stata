*! cge_elasticities.ado  v0.44.0  2026-11-01
*! cge-stata: published elasticities, with their sources (docs/elasticities.md)
*! Lists or loads entries of the elasticity library, or turns them into
*! option values for cge_calibrate
*!
*! Authors: Mustapha Wasseja Mohammed, Nadia S. Ouedraogo and Mahamat Podda Abouna
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
    if "`using'" != "" confirm file `"`using'"'
    _cge_load
    * the library and its sources from the package's bundle (from version
    * 0.44.0: Stata's package files take at most 100 files), each into a
    * file of its own name that lasts the session
    foreach f in lib src {
        local name = cond("`f'" == "lib", "cge_elasticities.csv", "cge_elasticity_sources.csv")
        mata: st_local("`f'", _cge_bundle_tmp("`name'"))
        mata: _cge_bundle_get("cge_elasticity_library.txt", "`name'", st_local("`f'"))
    }
    if "`clear'" != "" clear
    mata: _cge_elas("`parameter'", "`country'", "`category'", "`source'", "`id'", `"`lib'"', `"`src'"', ///
        `"`using'"', "`clear'" != "", "`values'" != "", "`map'", "`others'")
    return add
end
