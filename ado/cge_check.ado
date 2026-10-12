*! cge_check.ado  v0.1.0  2026-10-12
*! cge-stata: run the model validation checks (model_spec.md, Section 8)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_check, rclass
    version 13.0
    syntax [, SIM(name) HOMogeneity PERTurb(real 0) SEED(integer 12345)]

    if `perturb' < 0 | `perturb' >= 1 {
        display as error "perturb() must be at least 0 and less than 1"
        exit 198
    }
    _cge_load
    mata: _cge_check("`sim'", ("`homogeneity'" != ""), `perturb', `seed')
    local failures = r(failures)
    return add
    if `failures' > 0 exit 9
end
