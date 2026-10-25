*! cge_samexport.ado  v0.3.0  2026-10-18
*! cge-stata: write the SAM of the current model to a file or to memory
*! (docs/sam_tools.md, Section 2)
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_samexport, rclass
    version 13.0
    syntax [using/] [, REPLACE LONG MAPPED CLEAR SHEET(string)]

    if `"`using'"' == "" & "`clear'" == "" {
        display as error "give a file with using, or clear to load the SAM as data"
        exit 198
    }
    _cge_load
    local islong = ("`long'" != "")
    local ismapped = ("`mapped'" != "")

    if `"`using'"' != "" {
        mata: st_local("ext", strlower(pathsuffix(st_local("using"))))
        if "`ext'" == ".csv" {
            mata: _cge_sam_write(st_local("using"), `islong', `ismapped', ("`replace'" != ""))
        }
        else if inlist("`ext'", ".dta", ".xlsx", ".xls") {
            if "`replace'" == "" {
                capture confirm new file `"`using'"'
                if _rc {
                    display as error `"file `using' already exists; specify replace"'
                    exit 602
                }
            }
            if `"`sheet'"' == "" local sheet "SAM"
            preserve
            quietly {
                drop _all
                mata: _cge_sam_todata(`islong', `ismapped')
                if "`ext'" == ".dta" save `"`using'"', `replace'
                else export excel using `"`using'"', sheet(`"`sheet'"') firstrow(variables) `replace'
            }
            restore
            display as text `"SAM saved to `using'"'
        }
        else {
            display as error "cge_samexport writes .csv, .dta, .xls and .xlsx files"
            exit 198
        }
    }
    if "`clear'" != "" {
        drop _all
        mata: _cge_sam_todata(`islong', `ismapped')
        display as text "SAM loaded as data: " _N " observations"
    }
end
