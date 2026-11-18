*! cge_sam.ado  v0.51.0  2026-11-18
*! cge-stata: read a social accounting matrix (SAM)
*! Reads a SAM from the data in memory or from a file, wide or long, and
*! checks its structure (docs/sam_tools.md, Section 1)
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_sam, rclass
    version 13.0
    syntax [using/] [, LABels(name) SHEET(string) CLEAR LONG(namelist min=3 max=3) DIRECT SYMbol(name) NORUN GAMS(string)]

    _cge_load
    local fname
    if `"`using'"' != "" {
        * A SAM shipped with the package (from version 0.51.0), such as IFPRI's
        * 2019 SAM for Malawi, cge_malawi_sam.csv, is read from the package
        * when the working directory has no file of that name
        capture confirm file `"`using'"'
        if _rc {
            mata: st_local("shipped", _cge_sam_shipped(st_local("using")))
            if `"`shipped'"' != "" {
                display as text `"(`using': the copy shipped with cge-stata)"'
                local using `"`shipped'"'
            }
        }
        local fname `"`using'"'
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
            mata: _cge_sam_csv(st_local("using"), st_local("labels"))
            return add
            return local source "direct"
            return local filename `"`fname'"'
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
        else if "`ext'" == ".gdx" {
            * a parameter with two indexes in a GDX file (from version 0.10.0),
            * read through gdxdump
            if "`long'" != "" {
                display as error "cge_sam reads a GDX symbol as long data itself; give symbol(), not long()"
                exit 198
            }
            if "`symbol'" == "" local symbol SAM
            if `"`gams'"' != "" local gamsopt `"gams(`"`gams'"')"'
            cge_gdx read using `"`using'"', symbol(`symbol') `norun' `clear' `gamsopt'
            if "`r(kind)'" == "" exit
            if r(dim) != 2 | "`r(kind)'" != "parameter" {
                display as error "`symbol' is a `r(kind)' with `r(dim)' index(es); a SAM is a parameter with two"
                exit 459
            }
            local long `r(indexes)' value
        }
        else {
            display as error "cge_sam reads .csv, .dta, .xls, .xlsx and .gdx files"
            exit 198
        }
        if "`ext'" != ".gdx" & ("`symbol'" != "" | "`norun'" != "" | `"`gams'"' != "") {
            display as error "symbol(), norun and gams() read a GDX file"
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
        if `"`fname'"' != "" return local filename `"`fname'"'
        exit
    }

    * The labels: the variable named in labels() or else, from version 0.51.0,
    * of the string variables, the one whose values are the names of the
    * numeric variables, as the codes of a SAM published with a column of
    * descriptions are (before, the first string variable)
    quietly ds, has(type string)
    local strvars `r(varlist)'
    if "`labels'" == "" {
        local labels : word 1 of `strvars'
        if "`labels'" == "" {
            display as error "no string variable with account labels; specify labels()"
            exit 111
        }
        if `: word count `strvars'' > 1 {
            quietly ds, has(type numeric)
            mata: st_local("labels", _cge_sam_labvar(st_local("strvars"), st_global("r(varlist)")))
        }
    }
    confirm string variable `labels'
    * The other string variables hold text, such as descriptions of the
    * accounts, and are left out (from version 0.51.0; before, an error)
    local accounts
    local text
    quietly ds `labels', not
    foreach v in `r(varlist)' {
        capture confirm numeric variable `v'
        if _rc local text `text' `v'
        else local accounts `accounts' `v'
    }
    * The variable list of ds is not a result of this command
    mata: st_rclear()
    if "`text'" != "" {
        local nt : word count `text'
        display as text "Account labels from variable " as result "`labels'" as text "; text in " ///
            plural(`nt', "variable") " " as result "`text'" as text " left out"
    }

    mata: _cge_sam("`labels'", "`accounts'")

    return add
    return local labels "`labels'"
    return local source "wide"
    if `"`fname'"' != "" return local filename `"`fname'"'
end
