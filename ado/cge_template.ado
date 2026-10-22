*! cge_template.ado  v0.6.4  2026-10-22
*! cge-stata: write a template that maps SAM accounts to model roles and
*! groups them for aggregation (docs/sam_tools.md, Section 3)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_template, rclass
    version 13.0
    syntax using/ [, REPLACE]

    _cge_load
    mata: st_local("ext", strlower(pathsuffix(st_local("using"))))
    if !inlist("`ext'", ".csv", ".xlsx", ".xls") {
        display as error "cge_template writes .csv, .xls and .xlsx files"
        exit 198
    }
    if "`replace'" == "" {
        capture confirm new file `"`using'"'
        if _rc {
            display as error `"file `using' already exists; specify replace"'
            exit 602
        }
    }
    preserve
    drop _all
    mata: _cge_template_data()
    format row_total column_total difference %21.0g
    local n = _N
    quietly {
        if "`ext'" == ".csv" {
            export delimited using `"`using'"', `replace'
        }
        else {
            export excel using `"`using'"', sheet("accounts") firstrow(variables) `replace'
            _cge_roles_data
            export excel using `"`using'"', sheet("roles") firstrow(variables) sheetmodify
        }
    }
    restore
    display as text `"Template saved to `using'"'
    return scalar N_accounts = `n'
end

* The valid entries of the role column, for the roles sheet
program define _cge_roles_data
    drop _all
    set obs 27
    generate str16 role = ""
    generate str90 meaning = ""
    local k = 0
    foreach line in ///
        "activities|an activity (production sector)" ///
        "commodities|a commodity" ///
        "factors|a factor of production" ///
        "households|a household group, or a non-profit institution" ///
        "enterprises|an enterprise" ///
        "government|the government (one account)" ///
        "savinv|savings-investment (one account)" ///
        "row|the rest of the world (one account)" ///
        "dirtax|the direct tax account" ///
        "saltax|the sales tax account, or the government account if sales taxes are paid to it" ///
        "imptax|the import tariff account, or the government account" ///
        "exptax|the export tax account, or the government account" ///
        "acttax|the activity tax account, or the government account" ///
        "margins|a margin activity whose margins are netted out (also an activity)" ///
        "territorial|territorial correction: the commodity first, then its activity if any" ///
        "marginaccounts|a margin account paid by commodities" ///
        "stocks|a stock-change account, merged into savings-investment" ///
        "insurance|the social health insurance fund (one account)" ///
        "vattax|the VAT account, or the government account if VAT is paid to it" ///
        "domesticmargins|a margin account paid per unit of domestic sales" ///
        "importmargins|a margin account paid per unit of imports" ///
        "exportmargins|a margin account paid per unit of exports" ///
        "factortax|an account of taxes on the use of a factor; the pair column names the factor" ///
        "factorincometax|the account of taxes on factor income" ///
        "(blank)|no role: allowed only for an account without flows" ///
        "pair column|for an activity, its paired commodity; blank for the commodity it sells most" ///
        "group column|for aggregation, the account it is merged into; blank to keep it" {
        local ++k
        gettoken r m : line, parse("|")
        local m = substr(`"`m'"', 2, .)
        replace role = "`r'" in `k'
        replace meaning = `"`m'"' in `k'
    }
end
