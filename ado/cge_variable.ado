*! cge_variable.ado  v0.6.1  2026-10-21
*! cge-stata: add a user variable to the model, with the equation that
*! defines it or a base value (docs/model_spec.md, Section 19)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_variable, rclass
    version 13.0
    _cge_load
    if strtrim(`"`0'"') == "" {
        display as error "cge_variable: give NAME = expression, or NAME, value(#)"
        exit 198
    }
    mata: _cge_u_addvar(st_local("0"))
    return add
end
