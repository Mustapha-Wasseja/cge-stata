*! _cge_tmpl.ado  v0.3.0  2026-10-18
*! cge-stata: read a mapping template into Mata (docs/sam_tools.md, Section 3)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define _cge_tmpl
    version 13.0
    syntax using/ [, SHEET(string)]

    confirm file `"`using'"'
    mata: st_local("ext", strlower(pathsuffix(st_local("using"))))
    preserve
    quietly {
        drop _all
        if "`ext'" == ".csv" {
            import delimited using `"`using'"', varnames(1) case(lower) stringcols(_all) clear
        }
        else if inlist("`ext'", ".xlsx", ".xls") {
            if `"`sheet'"' != "" {
                import excel using `"`using'"', sheet(`"`sheet'"') firstrow case(lower) allstring clear
            }
            else {
                * The sheet written by cge_template, or else the first sheet
                capture import excel using `"`using'"', sheet("accounts") firstrow case(lower) allstring clear
                if _rc import excel using `"`using'"', firstrow case(lower) allstring clear
            }
        }
        else if "`ext'" == ".dta" {
            use `"`using'"', clear
        }
        else {
            noisily display as error "a template is a .csv, .xls, .xlsx or .dta file"
            exit 198
        }
    }
    capture confirm string variable account
    if _rc {
        display as error "the template has no string variable account"
        exit 111
    }
    foreach v in role pair group {
        local `v'var ""
        capture confirm variable `v'
        if !_rc {
            capture confirm string variable `v'
            if _rc {
                quietly tostring `v', replace
                quietly replace `v' = "" if `v' == "."
            }
            local `v'var `v'
        }
    }
    mata: _cge_tmpl_store("account", "`rolevar'", "`pairvar'", "`groupvar'")
    restore
end
