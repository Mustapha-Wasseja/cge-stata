*! cge_set.ado  v0.7.1  2026-10-22
*! cge-stata: user sets of elements, for the indexes of user variables,
*! equations, sums and parameters (Reference Manual, User variables and
*! equations)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_set, rclass
    version 13.0
    _cge_load
    if substr(strtrim(`"`0'"'), 1, 1) == "," {
        syntax , [LIST CLEAR]
        if "`list'" != "" & "`clear'" != "" {
            display as error "give list or clear, not both"
            exit 198
        }
        if "`clear'" != "" mata: _cge_us_clear()
        else mata: _cge_us_list()
        return add
        exit
    }
    if strtrim(`"`0'"') == "" {
        display as error "cge_set: give name = elements"
        exit 198
    }
    mata: _cge_us_add(st_local("0"))
    return add
end
