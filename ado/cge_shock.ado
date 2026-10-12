*! cge_shock.ado  v0.1.0  2026-10-12
*! cge-stata: change a parameter or a fixed variable before solving
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_shock
    version 13.0
    syntax [name(name=target)] [, ELements(string) SCale(numlist max=1) ///
        VALue(numlist max=1) RESET]

    _cge_load
    if "`reset'" != "" {
        if "`target'" != "" | "`scale'" != "" | "`value'" != "" {
            display as error "reset may not be combined with a shock"
            exit 198
        }
        mata: _cge_shock("reset", "", "", .)
        exit
    }
    if "`target'" == "" {
        display as error "specify the parameter or variable to change"
        exit 198
    }
    if ("`scale'" == "") == ("`value'" == "") {
        display as error "specify exactly one of scale() and value()"
        exit 198
    }
    if "`scale'" != "" mata: _cge_shock("`target'", "`elements'", "scale", `scale')
    else mata: _cge_shock("`target'", "`elements'", "value", `value')
end
