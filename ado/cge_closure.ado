*! cge_closure.ado  v0.3.3  2026-10-20
*! cge-stata: choose the model closure
*! Sets closures for the external account, government, savings-investment,
*! the numeraire and each factor (model_spec.md, Section 6)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_closure, rclass
    version 13.0
    syntax [, EXTernal(string) GOVernment(string) SAVinv(string) ///
        NUMeraire(string) FACtors(string)]

    local facgiven = (`"`factors'"' != "")
    foreach opt in external government savinv numeraire {
        local `opt' = lower(trim(`"``opt''"'))
    }

    _cge_load
    mata: _cge_closure("`external'", "`government'", "`savinv'", "`numeraire'", ///
        "`factors'", `facgiven')
    return add
end
