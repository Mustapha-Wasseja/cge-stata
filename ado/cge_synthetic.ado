*! cge_synthetic.ado  v0.3.2  2026-10-20
*! cge-stata: load the synthetic social accounting matrix (SAM)
*! Loads a bundled synthetic SAM and reports its balance
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_synthetic, rclass
    version 13.0
    syntax [, CLEAR NATional INStitutions MARgins TERritorial MULTiproduct NONimported SUT HEALTH UNBalanced VAT HOME TRADE]

    if ("`national'" != "") + ("`institutions'" != "") + ("`margins'" != "") ///
        + ("`territorial'" != "") + ("`multiproduct'" != "") + ("`nonimported'" != "") ///
        + ("`sut'" != "") + ("`health'" != "") + ("`unbalanced'" != "") + ("`vat'" != "") + ("`home'" != "") + ("`trade'" != "") > 1 {
        display as error "choose only one layout"
        exit 198
    }
    local file cge_synthetic_sam.csv
    local layout "standard layout"
    if "`national'" != "" {
        local file cge_synthetic_sam_na.csv
        local layout "national-accounts layout"
    }
    if "`institutions'" != "" {
        local file cge_synthetic_sam_inst.csv
        local layout "institutions layout"
    }
    if "`margins'" != "" {
        local file cge_synthetic_sam_margins.csv
        local layout "margins layout"
    }
    if "`territorial'" != "" {
        local file cge_synthetic_sam_tc.csv
        local layout "territorial-correction layout"
    }
    if "`multiproduct'" != "" {
        local file cge_synthetic_sam_mp.csv
        local layout "multi-product layout"
    }
    if "`nonimported'" != "" {
        local file cge_synthetic_sam_cnm.csv
        local layout "non-imported layout"
    }
    if "`sut'" != "" {
        local file cge_synthetic_sam_sut.csv
        local layout "supply-use layout"
    }
    if "`health'" != "" {
        local file cge_synthetic_sam_health.csv
        local layout "health layout"
    }
    if "`home'" != "" {
        local file cge_synthetic_sam_home.csv
        local layout "home-consumption layout"
    }
    if "`trade'" != "" {
        local file cge_synthetic_sam_trade.csv
        local layout "trade layout"
    }
    if "`vat'" != "" {
        local file cge_synthetic_sam_vat.csv
        local layout "VAT layout"
    }
    if "`unbalanced'" != "" {
        local file cge_synthetic_sam_unbal.csv
        local layout "institutions layout, unbalanced for the balancing tests"
    }
    quietly findfile `file'
    local samfile `"`r(fn)'"'

    import delimited using `"`samfile'"', varnames(1) case(preserve) ///
        stringcols(1) asdouble `clear'

    /* ------------------------------------------------------------------ */
    /*  Structure: square SAM with matching row and column labels         */
    /* ------------------------------------------------------------------ */
    quietly ds account, not
    local accounts `r(varlist)'
    local n : word count `accounts'

    if _N != `n' {
        display as error "SAM is not square: `=_N' rows and `n' columns"
        exit 459
    }
    forvalues i = 1/`n' {
        local acc : word `i' of `accounts'
        if account[`i'] != "`acc'" {
            * A label that is not a valid Stata name (s-i) was renamed as a
            * variable (si); cge_sam then uses the variable name
            capture confirm name `=account[`i']'
            if _rc == 0 {
                display as error "row `i' is labelled " account[`i'] ///
                    " but column `i' is labelled `acc'"
                exit 459
            }
        }
    }

    /* ------------------------------------------------------------------ */
    /*  Balance: row total equals column total for every account           */
    /* ------------------------------------------------------------------ */
    tempvar rowtotal
    quietly egen double `rowtotal' = rowtotal(`accounts')

    local maxdiff = 0
    local grand = 0
    forvalues i = 1/`n' {
        local acc : word `i' of `accounts'
        quietly summarize `acc', meanonly
        local diff = abs(`rowtotal'[`i'] - r(sum))
        if `diff' > `maxdiff' local maxdiff = `diff'
        local grand = `grand' + r(sum)
    }

    display as text _n "Synthetic SAM loaded (`layout'): " as result `n' as text ///
        " accounts, total " as result %9.2f `grand'
    display as text "Largest row-column imbalance: " as result %9.2e `maxdiff'

    return scalar N_accounts = `n'
    return scalar total = `grand'
    return scalar maxdiff = `maxdiff'
    return local accounts "`accounts'"
    return local filename `"`samfile'"'
end
