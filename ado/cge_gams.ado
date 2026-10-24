*! cge_gams.ado  v0.9.8  2026-10-24
*! cge-stata: write the model and a scenario as a GAMS program, and
*! optionally solve it in GAMS and compare the results (docs/gams.md)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_gams, rclass
    version 13.0
    syntax using/ [, SIM(name) DYNamic(name) REPLACE RUN COMPARE NOEXPORT GAMS(string) SOLVER(name) TYPE(name) ///
        IMPort(name)]

    _cge_load
    if "`sim'" != "" & "`dynamic'" != "" {
        display as error "give sim() for a static simulation or dynamic() for a dynamic run, not both"
        exit 198
    }
    if "`compare'" != "" & "`sim'" == "" & "`dynamic'" == "" {
        display as error "compare needs sim() or dynamic(): the stored simulation or dynamic run whose results GAMS should reproduce"
        exit 198
    }
    * The periods of a dynamic run (from version 0.5.3)
    if "`dynamic'" != "" mata: _cge_run_sims_local("`dynamic'", "periods")
    if "`noexport'" != "" & "`run'" == "" & "`compare'" == "" & "`import'" == "" {
        display as error "noexport uses the files already in the folder: give run, compare or import()"
        exit 198
    }
    if "`import'" != "" & "`dynamic'" != "" {
        display as error "import() takes a static scenario: give sim() or the current shocks"
        exit 198
    }
    if "`solver'" == "" local solver path
    local solver = strlower("`solver'")
    if "`type'" == "" {
        local type cns
        if inlist("`solver'", "ipopt", "ipopth", "minos", "snopt") local type nlp
        * a scenario with constraints is a mixed complementarity problem (from version 0.4.4)
        if "`dynamic'" == "" {
            mata: st_local("hascons", strofreal(_cge_gams_hascons("`sim'")))
            if `hascons' local type mcp
        }
    }
    local type = strlower("`type'")
    if !inlist("`type'", "cns", "nlp", "mcp") {
        display as error "type() must be cns (a constrained nonlinear system), nlp or mcp"
        exit 198
    }
    if "`run'" != "" & "`c(mode)'" == "batch" & "`c(os)'" == "Windows" {
        display as error "Stata in batch mode cannot start GAMS: run cge_run.gms in the folder with GAMS, " ///
            "then compare with cge_gams ..., sim() compare noexport (or dynamic())"
        exit 198
    }

    local dir = subinstr(`"`using'"', "\", "/", .)
    if substr(`"`dir'"', -1, 1) == "/" local dir = substr(`"`dir'"', 1, length(`"`dir'"') - 1)
    local written cge_model.gms cge_closure.gms cge_write.gms cge_solve.gms cge_data.inc ///
        cge_shock_par.inc cge_shock_var.inc cge_constraints.inc cge_cons_write.inc cge_bounds.inc cge_user.inc ///
        cge_user_write.inc cge_run.gms
    local name = cond("`sim'" == "", "current", "`sim'")
    * a dynamic run writes one pair of scenario files and one result file per period
    local results cge_`name'.csv
    if "`dynamic'" != "" {
        local name `dynamic'
        local written cge_model.gms cge_closure.gms cge_write.gms cge_solve.gms cge_data.inc ///
            cge_constraints.inc cge_cons_write.inc cge_bounds.inc cge_user.inc cge_user_write.inc cge_run.gms
        local results
        foreach p of local periods {
            local results `results' cge_`p'.csv
        }
    }

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
        if "`dynamic'" != "" mata: _cge_gams_export_dyn(st_local("dir"), "`dynamic'", "`solver'", "`type'")
        else mata: _cge_gams_export(st_local("dir"), "`sim'", "`solver'", "`type'")
        return add
        * The GAMS model, installed with the package
        foreach f in cge_model.gms cge_closure.gms cge_write.gms cge_solve.gms {
            quietly findfile `f'
            quietly copy `"`r(fn)'"' `"`dir'/`f'"', replace
        }
        * The path that findfile leaves in r() is not a result
        mata: st_rclear()
        display as text "Files: " as result "`written'" _c
        if "`dynamic'" != "" display as text " and the scenario files of each period"
        else display
        if "`run'" == "" & "`compare'" == "" & "`import'" == "" {
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
        foreach f of local results {
            capture erase `"`dir'/`f'"'
        }
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
    foreach f of local results {
        capture confirm file `"`dir'/`f'"'
        if _rc {
            display as error `"no GAMS results in `dir' (`f'); see cge_run.log and cge_run.lst there"'
            exit 601
        }
    }
    * The GAMS solution as a Stata simulation (from version 0.6.2)
    if "`import'" != "" {
        mata: _cge_gams_import(st_local("dir"), "`sim'", "`import'")
        return add
        if "`compare'" == "" exit
    }
    if "`compare'" == "" {
        display as text "GAMS results: " as result `"`dir'/cge_base.csv"' as text " and " ///
            as result "`results'"
        exit
    }
    if "`dynamic'" != "" mata: _cge_gams_compare_dyn(st_local("dir"), "`dynamic'")
    else mata: _cge_gams_compare(st_local("dir"), "`sim'")
    return add
end
