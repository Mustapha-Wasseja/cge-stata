*! cge_equation.ado  v0.9.0  2026-10-23
*! cge-stata: add a user equation to the model, or list or remove the user
*! variables and equations (docs/model_spec.md, Section 19)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_equation, rclass
    version 13.0
    _cge_load
    if substr(strtrim(`"`0'"'), 1, 1) == "," {
        syntax , [LIST CLEAR]
        if "`list'" != "" & "`clear'" != "" {
            display as error "give list or clear, not both"
            exit 198
        }
        if "`clear'" != "" mata: _cge_u_clear()
        else mata: _cge_u_list()
        return add
        exit
    }
    if strtrim(`"`0'"') == "" {
        display as error "cge_equation: give NAME: expression = expression"
        exit 198
    }
    mata: _cge_u_addeq(st_local("0"))
    return add
end
