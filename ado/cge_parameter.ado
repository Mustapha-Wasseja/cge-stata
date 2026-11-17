*! cge_parameter.ado  v0.7.1  2026-10-22
*! cge-stata: user parameters with values, for user variables and equations;
*! cge_shock changes them (Reference Manual, User variables and equations)
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_parameter, rclass
    version 13.0
    _cge_load
    if substr(strtrim(`"`0'"'), 1, 1) == "," {
        syntax , [LIST CLEAR]
        if "`list'" != "" & "`clear'" != "" {
            display as error "give list or clear, not both"
            exit 198
        }
        if "`clear'" != "" mata: _cge_up_clear()
        else mata: _cge_up_list()
        return add
        exit
    }
    if strtrim(`"`0'"') == "" {
        display as error "cge_parameter: give NAME = #, or NAME(i), values() or from()"
        exit 198
    }
    mata: _cge_up_add(st_local("0"))
    return add
end
