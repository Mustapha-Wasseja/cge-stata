*! cge_gams.ado  v0.4.3  2026-10-21
*! cge-stata: write the model and a scenario as a GAMS program, and
*! optionally solve it in GAMS and compare the results (docs/gams.md)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_gams, rclass
    version 13.0
    syntax using/ [, SIM(name) REPLACE RUN COMPARE NOEXPORT GAMS(string) SOLVER(name) TYPE(name)]

    _cge_load
    if "`compare'" != "" & "`sim'" == "" {
        display as error "compare needs sim(): the stored simulation whose results GAMS should reproduce"
        exit 198
    }
    if "`noexport'" != "" & "`run'" == "" & "`compare'" == "" {
        display as error "noexport uses the files already in the folder: give run, compare or both"
        exit 198
    }
    if "`solver'" == "" local solver path
    local solver = strlower("`solver'")
    if "`type'" == "" {
        local type cns
        if inlist("`solver'", "ipopt", "ipopth", "minos", "snopt") local type nlp
        * a scenario with constraints is a mixed complementarity problem (from version 0.4.4)
        mata: st_local("hascons", strofreal(_cge_gams_hascons("`sim'")))
        if `hascons' local type mcp
    }
    local type = strlower("`type'")
    if !inlist("`type'", "cns", "nlp", "mcp") {
        display as error "type() must be cns (a constrained nonlinear system), nlp or mcp"
        exit 198
    }
    if "`run'" != "" & "`c(mode)'" == "batch" & "`c(os)'" == "Windows" {
        display as error "Stata in batch mode cannot start GAMS: run cge_run.gms in the folder with GAMS, " ///
            "then compare with cge_gams ..., sim() compare noexport"
        exit 198
    }

    local dir = subinstr(`"`using'"', "\", "/", .)
    if substr(`"`dir'"', -1, 1) == "/" local dir = substr(`"`dir'"', 1, length(`"`dir'"') - 1)
    local written cge_model.gms cge_closure.gms cge_write.gms cge_solve.gms cge_data.inc ///
        cge_shock_par.inc cge_shock_var.inc cge_constraints.inc cge_run.gms
    local name = cond("`sim'" == "", "current", "`sim'")

    if "`noexport'" == "" {
        * The folder is created if needed; files of an earlier export need replace
        mata: _cge_mkdirs(st_local("dir"))
        if "`replace'" == "" {
            foreach f of local written {
                capture confirm file `"`dir'/`f'"'
                if !_rc {
                    display as error `"`dir'/`f' already exists; specify replace"'
                    exit 602
                }
            }
        }
        mata: _cge_gams_export(st_local("dir"), "`sim'", "`solver'", "`type'")
        return add
        * The GAMS model, installed with the package
        foreach f in cge_model.gms cge_closure.gms cge_write.gms cge_solve.gms {
            quietly findfile `f'
            quietly copy `"`r(fn)'"' `"`dir'/`f'"', replace
        }
        display as text "Files: " as result "`written'"
        if "`run'" == "" & "`compare'" == "" {
            display as text "To solve it: " as result "gams cge_run.gms" as text " in that folder"
            exit
        }
    }
    else {
        capture confirm file `"`dir'/cge_run.gms"'
        if _rc {
            display as error `"no exported model in `dir': cge_run.gms not found"'
            exit 601
        }
    }

    if "`run'" != "" {
        * GAMS runs through a script in the folder, which can be run again by hand
        if `"`gams'"' == "" local gams gams
        capture erase `"`dir'/cge_base.csv"'
        capture erase `"`dir'/cge_`name'.csv"'
        local script = cond("`c(os)'" == "Windows", "cge_run.cmd", "cge_run.sh")
        capture erase `"`dir'/`script'"'
        tempname fh
        file open `fh' using `"`dir'/`script'"', write text
        if "`c(os)'" == "Windows" {
            file write `fh' "@echo off" _n
            file write `fh' `"cd /d "%~dp0""' _n
        }
        file write `fh' `""`gams'" cge_run.gms lo=2 lf=cge_run.log --cgesolver=`solver' --cgetype=`type'"' _n
        file close `fh'
        display as text "Running GAMS (" as result "`solver'" as text ") ..."
        if "`c(os)'" == "Windows" {
            local path = subinstr(`"`dir'/`script'"', "/", "\", .)
            capture noisily shell "`path'"
        }
        else {
            local here `"`c(pwd)'"'
            quietly cd `"`dir'"'
            capture noisily shell sh `script'
            local rc = _rc
            quietly cd `"`here'"'
            if `rc' exit `rc'
        }
        if _rc exit _rc
        return local script `script'
    }
    capture confirm file `"`dir'/cge_`name'.csv"'
    if _rc {
        display as error `"no GAMS results in `dir' (cge_`name'.csv); see cge_run.log and cge_run.lst there"'
        exit 601
    }
    if "`compare'" == "" {
        display as text "GAMS results: " as result `"`dir'/cge_base.csv"' as text " and " ///
            as result `"`dir'/cge_`name'.csv"'
        exit
    }
    mata: _cge_gams_compare(st_local("dir"), "`sim'")
    return add
end
