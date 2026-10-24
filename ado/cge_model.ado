*! cge_model.ado  v0.17.0  2026-10-25
*! cge-stata: start a standalone model, written whole in the user language,
*! describe the model in memory, and define named models over subsets of
*! its equations, as GAMS's model statement (Reference Manual, cge_model)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_model, rclass
    version 13.0
    gettoken sub rest : 0, parse(" ,")
    if `"`sub'"' == "" {
        display as error "cge_model: give new, describe, define, drop or list"
        exit 198
    }
    _cge_load
    * named models (from version 0.17.0)
    if "`sub'" == "define" {
        if strtrim(`"`rest'"') == "" {
            display as error "cge_model define: give a name and its equations, as cge_model define m1 = e1 e2"
            exit 198
        }
        mata: _cge_mdef_add(st_local("rest"))
    }
    else if "`sub'" == "drop" {
        local rest = strtrim(`"`rest'"')
        if `"`rest'"' == "" | wordcount(`"`rest'"') != 1 {
            display as error "cge_model drop: give one model name, or _all"
            exit 198
        }
        mata: _cge_mdef_drop(st_local("rest"))
    }
    else if "`sub'" == "list" {
        if strtrim(`"`rest'"') != "" {
            display as error "cge_model list: no arguments are allowed"
            exit 198
        }
        mata: _cge_mdef_list()
    }
    else if "`sub'" == substr("describe", 1, max(1, length("`sub'"))) {
        local rest = strtrim(`"`rest'"')
        if wordcount(`"`rest'"') > 1 {
            display as error "cge_model describe: give at most one model name"
            exit 198
        }
        mata: _cge_model_describe(st_local("rest"))
    }
    else if "`sub'" == "new" {
        if strtrim(`"`rest'"') != "" {
            display as error "cge_model new: no arguments or options are allowed"
            exit 198
        }
        mata: _cge_model_new()
    }
    else {
        display as error `"cge_model: unknown subcommand `sub'; give new, describe, define, drop or list"'
        exit 198
    }
    return add
end
