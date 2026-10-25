*! cge_balance.ado  v0.3.0  2026-10-18
*! cge-stata: balance a SAM by RAS or cross entropy, keeping signs, zeros and
*! fixed cells (docs/sam_tools.md, Section 5)
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_balance, rclass
    version 13.0
    syntax [, METHod(string) TARGets(string) TOTals(string) FIXed(string) ///
        TOLerance(real 1e-10) ITERate(integer -1) NODisplay]

    if "`method'" == "" local method ras
    local method = strlower("`method'")
    if !inlist("`method'", "ras", "ce") {
        display as error "method() is ras or ce"
        exit 198
    }
    if "`targets'" == "" local targets average
    if "`method'" == "ce" & "`targets'" != "average" {
        display as error "targets() applies to method(ras); give known totals with totals()"
        exit 198
    }
    if !inlist("`targets'", "average", "rows", "columns") {
        display as error "targets() is average, rows or columns"
        exit 198
    }
    if `tolerance' <= 0 {
        display as error "tolerance() must be positive"
        exit 198
    }
    if `iterate' < 0 local iterate = cond("`method'" == "ras", 10000, 100)
    _cge_load
    mata: _cge_balance("`method'", "`targets'", st_local("totals"), st_local("fixed"), ///
        `tolerance', `iterate', ("`nodisplay'" == ""))
    return add
end
