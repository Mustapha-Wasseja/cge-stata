*! cge_sam.ado  v0.1.0  2026-10-12
*! cge-stata: read a social accounting matrix (SAM)
*! Reads a SAM from the data in memory or from a file and checks its structure
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_sam, rclass
    version 13.0
    syntax [using/] [, LABels(name) SHEET(string) CLEAR]

    if `"`using'"' != "" {
        mata: st_local("ext", strlower(pathsuffix(st_local("using"))))
        if "`ext'" == ".csv" {
            import delimited using `"`using'"', varnames(1) case(preserve) ///
                stringcols(1) asdouble `clear'
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

    _cge_load
    mata: _cge_sam("`labels'", "`accounts'")

    return add
    return local labels "`labels'"
end
