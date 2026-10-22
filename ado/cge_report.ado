*! cge_report.ado  v0.6.4  2026-10-22
*! cge-stata: standard report tables for one or more simulations
*! Macroeconomic aggregates, government, institutions, factors, activities,
*! commodities, health and welfare (model_spec.md, Section 9)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_report, rclass
    version 13.0
    syntax [, SIMs(string) RUN(name) TABles(string) CLEAR SAVing(string) NODisplay]

    _cge_load
    if "`run'" != "" {
        if "`sims'" != "" {
            display as error "choose sims() or run(), not both"
            exit 198
        }
        * Every period of a dynamic run, in order
        mata: _cge_run_sims_local("`run'", "sims")
    }
    local file ""
    local replace ""
    if `"`saving'"' != "" {
        gettoken file rest : saving, parse(",")
        local file = trim(`"`file'"')
        gettoken comma rest : rest, parse(",")
        if trim(`"`rest'"') == "replace" local replace replace
        else if trim(`"`rest'"') != "" {
            display as error "saving(): only the option replace is allowed"
            exit 198
        }
    }
    local show = ("`nodisplay'" == "")
    if "`clear'" != "" {
        drop _all
        mata: _cge_report_run("`sims'", "`tables'", `show', "long")
        local show 0
    }
    else if `"`file'"' == "" {
        mata: _cge_report_run("`sims'", "`tables'", `show', "")
    }
    if `"`file'"' != "" {
        mata: st_local("ext", strlower(pathsuffix(st_local("file"))))
        preserve
        drop _all
        if inlist("`ext'", ".xlsx", ".xls") {
            mata: _cge_report_run("`sims'", "`tables'", `show', "wide")
            if "`replace'" != "" capture erase `"`file'"'
            else {
                capture confirm new file `"`file'"'
                if _rc {
                    display as error `"file `file' already exists; use saving(`file', replace)"'
                    exit 602
                }
            }
            quietly levelsof table, local(tabs) clean
            * Sheets in the order of the report
            foreach t in macro government debt institutions factors activities commodities health welfare {
                if strpos(" `tabs' ", " `t' ") == 0 continue
                quietly export excel table measure element base v* p* if table == "`t'" ///
                    using `"`file'"', sheet("`t'") sheetreplace firstrow(varlabels)
            }
            display as text `"Report saved to {res}`file'{txt} (one sheet per table)"'
        }
        else {
            mata: _cge_report_run("`sims'", "`tables'", `show', "long")
            save `"`file'"', `replace'
        }
        restore
    }
    return add
end
