*! cge_nest.ado  v0.11.0  2026-10-24
*! cge-stata: declare a nested CES or CET block, as MPSGE's production
*! blocks, written as user variables and equations in calibrated share form
*! (model_spec.md, Section 20)
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_nest, rclass
    version 13.0
    * a standalone model has no SAM (from version 0.13.0)
    _cge_load
    mata: _cge_need_sam()
    _cge_load
    gettoken sub rest : 0, parse(" ,")
    if "`sub'" == "," | "`sub'" == "" {
        syntax [, LIST DROP]
        if "`list'" != "" & "`drop'" != "" {
            display as error "give list or drop, not both"
            exit 198
        }
        if "`drop'" != "" {
            mata: _cge_nest_drop()
            display as text "The open block is dropped"
            exit
        }
        mata: _cge_nest_list()
        return add
        exit
    }
    local line `"cge_nest `0'"'
    if "`sub'" == "begin" {
        * the head may carry an index and a condition: everything before the comma
        mata: _cge_nest_split(st_local("rest"), "head", "0")
        syntax , OUTput(string) PRice(string) [S(string) T(string) EFFiciency(string) REPlace(string)]
        mata: _cge_nest_begin(st_local("head"), st_local("output"), st_local("price"), st_local("s"), ///
            st_local("t"), st_local("efficiency"), st_local("replace"), st_local("line"))
        display as text "Block {res}`head'{txt} begun"
        exit
    }
    if "`sub'" == "nest" {
        local 0 `"`rest'"'
        syntax name(name=nest) , [S(string) T(string) IN(name)]
        mata: _cge_nest_nest("`nest'", st_local("s"), st_local("t"), "`in'", st_local("line"))
        exit
    }
    if "`sub'" == "input" | "`sub'" == "output" {
        mata: _cge_nest_split(st_local("rest"), "q", "0")
        syntax , PRice(string) [UNits(string) IN(name) REPlace(string)]
        mata: _cge_nest_leaf(`= cond("`sub'" == "input", 1, 2)', st_local("q"), st_local("price"), ///
            st_local("units"), "`in'", st_local("replace"), st_local("line"))
        exit
    }
    if "`sub'" == "end" {
        if strtrim(`"`rest'"') != "" {
            display as error "cge_nest end takes no arguments"
            exit 198
        }
        capture noisily quietly mata: _cge_nest_end()
        if _rc {
            local rc = _rc
            mata: _cge_nest_abort()
            display as error "the block was not added; it is still open: correct it, or drop it with cge_nest, drop"
            exit `rc'
        }
        display as text "Block {res}`r(name)'{txt}: " as result r(N_variables) as text " user variable(s) and " ///
            as result r(N_equations) as text " equation(s)"
        return add
        exit
    }
    display as error "cge_nest: give begin, nest, input, output or end, or the option list or drop"
    exit 198
end
