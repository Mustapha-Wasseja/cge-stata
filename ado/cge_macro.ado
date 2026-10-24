*! cge_macro.ado  v0.9.7  2026-10-24
*! cge-stata: macros of the language of user variables and equations, as
*! GAMS's $macro (Reference Manual, User variables and equations)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_macro, rclass
    version 13.0
    _cge_load
    if substr(strtrim(`"`0'"'), 1, 1) == "," {
        syntax , [LIST CLEAR]
        if "`list'" != "" & "`clear'" != "" {
            display as error "give list or clear, not both"
            exit 198
        }
        if "`clear'" != "" mata: _cge_um_clear()
        else mata: _cge_um_list()
        return add
        exit
    }
    if strtrim(`"`0'"') == "" {
        display as error "cge_macro: give name(a, b) = expression"
        exit 198
    }
    mata: _cge_um_add(st_local("0"))
    return add
end
