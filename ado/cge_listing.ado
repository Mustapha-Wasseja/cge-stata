*! cge_listing.ado  v0.9.8  2026-10-24
*! cge-stata: the equation listing and infeasibility report: every element of
*! the model's equations at a point, with its residual; and the solution
*! listing, with bounds and marginals (Reference Manual, cge_listing)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_listing, rclass
    version 13.0
    syntax [, SIM(name) BASE CURrent BLOCKs(string) ALL TOP(integer 20) TOLerance(real 1e-8) CLEAR ///
        SOLution VARiables(string)]
    _cge_load
    * the solution listing (from version 0.9.8)
    if "`solution'" != "" {
        mata: _cge_solution("`sim'", ("`base'" != ""), ("`current'" != ""), st_local("variables"), st_local("blocks"), ///
            ("`all'" != ""), ("`clear'" != ""))
        return add
        exit
    }
    if `"`variables'"' != "" {
        display as error "variables() lists blocks of variables in the solution listing; give solution"
        exit 198
    }
    if `top' < 1 {
        display as error "top() must be at least 1"
        exit 198
    }
    if `tolerance' <= 0 {
        display as error "tolerance() must be positive"
        exit 198
    }
    mata: _cge_listing("`sim'", ("`base'" != ""), ("`current'" != ""), st_local("blocks"), `top', `tolerance', ///
        ("`all'" != ""), ("`clear'" != ""))
    return add
end
