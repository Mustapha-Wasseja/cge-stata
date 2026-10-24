*! cge_model.ado  v0.13.0  2026-10-24
*! cge-stata: start a standalone model, written whole in the user language,
*! and describe the model in memory (Reference Manual, cge_model)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_model, rclass
    version 13.0
    gettoken sub rest : 0, parse(" ,")
    if `"`sub'"' == "" {
        display as error "cge_model: give new or describe"
        exit 198
    }
    if strtrim(`"`rest'"') != "" {
        display as error `"cge_model `sub': no arguments or options are allowed"'
        exit 198
    }
    _cge_load
    if "`sub'" == "new" mata: _cge_model_new()
    else if "`sub'" == substr("describe", 1, max(1, length("`sub'"))) mata: _cge_model_describe()
    else {
        display as error `"cge_model: unknown subcommand `sub'; give new or describe"'
        exit 198
    }
    return add
end
