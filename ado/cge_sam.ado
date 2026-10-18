*! cge_sam.ado  v0.3.0  2026-10-18
*! cge-stata: read a social accounting matrix (SAM)
*! Reads a SAM from the data in memory or from a file, wide or long, and
*! checks its structure (docs/sam_tools.md, Section 1)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_sam, rclass
    version 13.0
    syntax [using/] [, LABels(name) SHEET(string) CLEAR LONG(namelist min=3 max=3) DIRECT]

    _cge_load
    if `"`using'"' != "" {
        mata: st_local("ext", strlower(pathsuffix(st_local("using"))))
        if "`direct'" != "" & "`ext'" != ".csv" {
            display as error "direct reads .csv files only"
            exit 198
        }
        if "`direct'" != "" & "`long'" != "" {
            display as error "direct and long() may not be combined"
            exit 198
        }
        * A wide CSV file with more accounts than fit as variables is read directly
        if "`ext'" == ".csv" & "`long'" == "" & "`direct'" == "" {
            mata: st_local("ncols", strofreal(_cge_csv_ncols(st_local("using"))))
            if `ncols' + 1 > c(maxvar) {
                display as text "The SAM has `ncols' accounts, more than fit as variables; reading the file directly"
                local direct direct
            }
        }
        if "`direct'" != "" {
            mata: _cge_sam_csv(st_local("using"))
            return add
            return local source "direct"
            exit
        }
        if "`ext'" == ".csv" {
            if "`long'" != "" {
                import delimited using `"`using'"', varnames(1) case(preserve) asdouble `clear'
            }
            else {
                import delimited using `"`using'"', varnames(1) case(preserve) ///
                    stringcols(1) asdouble `clear'
            }
        }
        else if "`ext'" == ".dta" {
            use `"`using'"', `clear'
        }
        else if inlist("`ext'", ".xlsx", ".xls") {
            if `"`sheet'"' != "" local sheetopt `"sheet(`"`sheet'"')"'
            import excel using `"`using'"', firstrow case(preserve) `sheetopt' `clear'
        }
        else {
            display as error "cge_sam reads .csv, .dta, .xls and .xlsx files"
            exit 198
        }
    }
    else if "`direct'" != "" {
        display as error "direct needs a .csv file named with using"
        exit 198
    }

    * Long data: one observation per cell
    if "`long'" != "" {
        tokenize `long'
        confirm string variable `1' `2'
        confirm numeric variable `3'
        mata: _cge_sam_long("`1'", "`2'", "`3'")
        return add
        return local source "long"
        exit
    }

    if "`labels'" == "" {
        quietly ds, has(type string)
        local labels : word 1 of `r(varlist)'
        if "`labels'" == "" {
            display as error "no string variable with account labels; specify labels()"
            exit 111
        }
    }
    confirm string variable `labels'
    quietly ds `labels', not
    local accounts `r(varlist)'
    confirm numeric variable `accounts'

    mata: _cge_sam("`labels'", "`accounts'")

    return add
    return local labels "`labels'"
    return local source "wide"
end
