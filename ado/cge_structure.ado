*! cge_structure.ado  v0.35.0  2026-10-29
*! cge-stata: the structure of the system solved: a maximum matching of its
*! equations and free variables, the parts of a structurally singular
*! system and the blocks of its square part (Reference Manual,
*! cge_structure)
*!
*! Authors: Mustapha Wasseja Mohammed, Nadia S. Ouedraogo and Mahamat Podda Abouna
*! Requires: Stata 13+

program define cge_structure, rclass
    version 13.0
    syntax [, SIM(name) BASE FULL TOP(integer 10)]
    if `top' < 1 {
        display as error "top() must be at least 1"
        exit 198
    }
    _cge_load
    mata: _cge_structure("`sim'", ("`base'" != ""), ("`full'" != ""), `top')
    return add
end
