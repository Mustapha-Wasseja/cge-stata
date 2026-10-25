*! cge_modlib.ado  v0.21.0  2026-10-25
*! cge-stata: a library of ready-to-run models written in the user language,
*! as GAMS's model library (Reference Manual, cge_modlib)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_modlib, rclass
    version 13.0
    gettoken sub rest : 0, parse(" ,")
    local models exchange crusoe markets hs071 transport ras knapsack cournot
    if "`sub'" == "" | "`sub'" == "list" {
        display as text _n "The model library of cge-stata"
        display as text "{hline 78}"
        display as text %-11s "Model" %-8s "Kind" "Title"
        display as text "{hline 78}"
        foreach m of local models {
            _cge_modlib_read `m'
            display as text %-11s "{bf:`m'}" %-8s "`r(kind)'" as result "`r(title)'"
        }
        display as text "{hline 78}"
        display as text "cge_modlib describe {it:model} shows a model; cge_modlib run {it:model} runs it;"
        display as text "cge_modlib copy {it:model} copies it to the current folder"
        return local models `models'
        return scalar N_models = `: word count `models''
        exit
    }
    gettoken name rest : rest, parse(" ,")
    if "`name'" == "" | !`: list name in models' {
        display as error "cge_modlib `sub': give one of the models: `models'"
        exit 198
    }
    if "`sub'" == "describe" {
        _cge_modlib_read `name'
        local fn `"`r(fn)'"'
        display as text _n "Model " as result "`name'" as text ": " as result "`r(title)'"
        display as text "Kind:      " as result "`r(kind)'"
        display as text "Reference: " as result "`r(reference)'"
        display as text "Expected:  " as result "`r(expect)'"
        display as text "File:      " as result "cge_ml_`name'.do"
        return local title `"`r(title)'"'
        return local expect `"`r(expect)'"'
        return local kind `"`r(kind)'"'
        exit
    }
    if "`sub'" == "run" {
        quietly findfile cge_ml_`name'.do
        local fn `"`r(fn)'"'
        do `"`fn'"'
        exit
    }
    if "`sub'" == "copy" {
        local 0 `"`rest'"'
        syntax [, REPLACE]
        quietly findfile cge_ml_`name'.do
        copy `"`r(fn)'"' "cge_ml_`name'.do", `replace'
        display as text "Copied to " as result "cge_ml_`name'.do" as text " in the current folder"
        exit
    }
    display as error "cge_modlib: give list, describe, run or copy"
    exit 198
end

* The header of a model of the library: its title, kind, reference and
* expected results, from the lines *! name: text
program define _cge_modlib_read, rclass
    args m
    quietly findfile cge_ml_`m'.do
    return local fn `"`r(fn)'"'
    tempname fh
    file open `fh' using `"`r(fn)'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if substr(`"`line'"', 1, 2) == "*!" {
            local text = strtrim(substr(`"`line'"', 3, .))
            foreach k in title kind reference expect {
                if substr(`"`text'"', 1, strlen("`k'") + 1) == "`k':" {
                    local `k' = strtrim(substr(`"`text'"', strlen("`k'") + 2, .))
                }
            }
        }
        file read `fh' line
    }
    file close `fh'
    foreach k in title kind reference expect {
        return local `k' `"``k''"'
    }
end
