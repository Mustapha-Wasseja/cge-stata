*! cge_bound.ado  v0.18.0  2026-10-25
*! cge-stata: attributes of model and user variables, as GAMS's .lo, .up,
*! .scale, .l and .fx (Reference Manual, cge_bound)
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_bound, rclass
    version 13.0
    _cge_load
    if substr(strtrim(`"`0'"'), 1, 1) == "," {
        syntax , [LIST CLEAR]
        if "`list'" != "" & "`clear'" != "" {
            display as error "give list or clear, not both"
            exit 198
        }
        if "`clear'" != "" mata: _cge_bd_clear("")
        else mata: _cge_bd_list()
        return add
        exit
    }
    * the variable, as NAME or, as in GAMS, NAME(e) or NAME(e1,e2)
    gettoken spec 0 : 0, parse(",")
    local spec = subinstr(strtrim(`"`spec'"'), " ", "", .)
    local inline
    if strpos(`"`spec'"', "(") {
        if substr(`"`spec'"', -1, 1) != ")" {
            display as error "cge_bound: write the variable as NAME, NAME(e) or NAME(e1,e2)"
            exit 198
        }
        local inline = subinstr(substr(`"`spec'"', strpos(`"`spec'"', "(") + 1, strlen(`"`spec'"') - strpos(`"`spec'"', "(") - 1), ",", ".", .)
        local spec = substr(`"`spec'"', 1, strpos(`"`spec'"', "(") - 1)
    }
    capture confirm name `spec'
    if _rc {
        display as error "cge_bound: give a model or user variable"
        exit 198
    }
    local var `spec'
    syntax [, ELements(string) LOwer(string) UPper(string) SCale(string) LEVel(string) ///
        FIX(string) RELative CLEAR INTeger BINary CONTinuous]
    if `"`inline'"' != "" {
        if `"`elements'"' != "" {
            display as error "cge_bound: give the elements in parentheses or in elements(), not both"
            exit 198
        }
        local elements `"`inline'"'
    }
    * the type of a variable of a standalone model (from version 0.18.0), as
    * GAMS's integer and binary variables
    local types `integer' `binary' `continuous'
    if "`types'" != "" {
        if wordcount("`types'") > 1 | `"`lower'`upper'`scale'`level'`fix'`relative'`clear'"' != "" {
            display as error "cge_bound: give one of integer, binary and continuous, alone"
            exit 198
        }
        mata: _cge_int_add("`var'", st_local("elements"), "`types'")
        return add
        exit
    }
    if "`clear'" != "" {
        if `"`elements'`lower'`upper'`scale'`level'`fix'`relative'"' != "" {
            display as error "clear removes every attribute of `var'; give it alone"
            exit 198
        }
        mata: _cge_bd_clear("`var'")
        return add
        exit
    }
    mata: _cge_bd_add("`var'", st_local("elements"), st_local("lower"), st_local("upper"), st_local("scale"), ///
        st_local("level"), st_local("fix"), ("`relative'" != ""))
    return add
end
