*! cge_constraint.ado  v0.4.4  2026-10-21
*! cge-stata: bounds that bind in some scenarios and not in others, each
*! paired with a variable that adjusts when it binds (docs/model_spec.md,
*! Section 16)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_constraint, rclass
    version 13.0
    syntax [anything(name=var)] [, ELements(string) UPper(string) LOwer(string) SCale ///
        ADJust(string) UP DOWN RENTs(name) LIST CLEAR]

    _cge_load
    if "`clear'" != "" {
        mata: _cge_cons_clear()
        return add
        exit
    }
    if "`list'" != "" {
        mata: _cge_cons_list()
        return add
        exit
    }
    if `"`var'"' == "" {
        display as error "give the variable to bound, or list or clear"
        exit 198
    }
    if `: word count `var'' != 1 {
        display as error "give one variable to bound"
        exit 198
    }
    if "`up'" != "" & "`down'" != "" {
        display as error "choose up or down"
        exit 198
    }
    local dir `up'`down'
    mata: _cge_constraint("`var'", st_local("elements"), strtrim(st_local("upper")), strtrim(st_local("lower")), ///
        ("`scale'" != ""), st_local("adjust"), "`dir'", "`rents'")
    return add
end
