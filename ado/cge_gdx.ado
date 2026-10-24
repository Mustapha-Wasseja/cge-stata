*! cge_gdx.ado  v0.10.0  2026-10-24
*! cge-stata: GAMS data exchange (GDX) files, written by GAMS and read by
*! gdxdump (Reference Manual, cge_gdx)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_gdx, rclass
    version 13.0
    gettoken sub 0 : 0, parse(" ,")
    if !inlist("`sub'", "write", "read", "list") {
        display as error "cge_gdx: write, read or list, as cge_gdx read using file.gdx, symbol(SAM) clear"
        exit 198
    }
    syntax using/ [, SIMs(string) SYMbol(name) CLEAR REPLACE NORUN GAMS(string)]
    _cge_load
    * the file, its folder and its stem
    local file = subinstr(`"`using'"', "\", "/", .)
    mata: st_local("ext", strlower(pathsuffix(st_local("file"))))
    if "`ext'" == "" local file `"`file'.gdx"'
    else if "`ext'" != ".gdx" {
        display as error "cge_gdx: give a .gdx file"
        exit 198
    }
    mata: st_local("dir", pathrmsuffix(st_local("file")))
    mata: st_local("base", pathbasename(st_local("dir")))
    mata: st_local("dir", substr(st_local("file"), 1, strlen(st_local("file")) - strlen(pathbasename(st_local("file")))))
    mata: st_local("gdxname", pathbasename(st_local("file")))
    if `"`dir'"' == "" local dir "./"
    * GAMS and gdxdump: gams() names gams.exe, with gdxdump in its folder
    if `"`gams'"' == "" {
        local gamsexe gams
        local gdxdump gdxdump
    }
    else {
        local gamsexe = subinstr(`"`gams'"', "\", "/", .)
        mata: st_local("gdir", substr(st_local("gamsexe"), 1, strlen(st_local("gamsexe")) - strlen(pathbasename(st_local("gamsexe")))))
        local gdxdump = `"`gdir'gdxdump"' + cond("`c(os)'" == "Windows", ".exe", "")
    }
    local batch = ("`c(mode)'" == "batch" & "`c(os)'" == "Windows")
    local sext = cond("`c(os)'" == "Windows", "cmd", "sh")

    if "`sub'" == "write" {
        if "`symbol'" != "" | "`clear'" != "" {
            display as error "cge_gdx write: symbol() and clear belong to cge_gdx read"
            exit 198
        }
        if "`replace'" == "" {
            capture confirm file `"`file'"'
            if !_rc {
                display as error `"`file' already exists; specify replace"'
                exit 602
            }
        }
        mata: _cge_mkdirs(st_local("dir"))
        mata: _cge_gdx_write(st_local("dir") + "`base'_write.gms", st_local("gdxname"), st_local("sims"))
        return add
        _cge_gdx_script `"`dir'`base'_write.`sext'"' `"`gamsexe'"' `"`base'_write.gms lo=2 lf=`base'_write.log"'
        if "`norun'" != "" | `batch' {
            if `batch' & "`norun'" == "" display as text "Stata in batch mode cannot start GAMS."
            display as text "To write " as result `"`file'"' as text ", run " as result `"`dir'`base'_write.`sext'"' as text " (GAMS)"
            exit
        }
        capture erase `"`file'"'
        _cge_gdx_run `"`dir'`base'_write.`sext'"'
        capture confirm file `"`file'"'
        if _rc {
            display as error `"GAMS did not write `file'; see `dir'`base'_write.log"'
            exit 601
        }
        display as text "Wrote " as result `"`file'"' as text ": the SAM, the calibrated parameters (CAL) and the levels of the variables (LEVEL) at " ///
            as result "`r(sims)'"
        exit
    }

    * read and list: gdxdump writes a text file, which Stata reads
    if "`sims'" != "" {
        display as error "cge_gdx `sub': sims() belongs to cge_gdx write"
        exit 198
    }
    if "`sub'" == "read" {
        if "`symbol'" == "" {
            display as error "cge_gdx read: give the symbol, as symbol(SAM)"
            exit 198
        }
        if "`clear'" == "" {
            display as error "cge_gdx read replaces the data in memory: give clear"
            exit 4
        }
        local out `base'_`symbol'.csv
        local args `""`gdxname'" symb=`symbol' format=csv dFormat=hexponential CSVAllFields CSVSetText output="`out'""'
        local script `base'_read_`symbol'.`sext'
    }
    else {
        if "`symbol'" != "" {
            display as error "cge_gdx list: symbol() belongs to cge_gdx read"
            exit 198
        }
        local out `base'_symbols.txt
        local args `""`gdxname'" symbols output="`out'""'
        local script `base'_symbols.`sext'
    }
    if "`norun'" != "" | `batch' {
        * the output of an earlier run of the script, if any
        capture confirm file `"`dir'`out'"'
        if _rc {
            _cge_gdx_script `"`dir'`script'"' `"`gdxdump'"' `"`args'"'
            if `batch' & "`norun'" == "" display as text "Stata in batch mode cannot start gdxdump."
            display as text "Run " as result `"`dir'`script'"' as text " (gdxdump), then repeat with norun"
            exit
        }
    }
    else {
        capture confirm file `"`file'"'
        if _rc {
            display as error `"`file' not found"'
            exit 601
        }
        capture erase `"`dir'`out'"'
        _cge_gdx_script `"`dir'`script'"' `"`gdxdump'"' `"`args'"'
        _cge_gdx_run `"`dir'`script'"'
    }
    if "`sub'" == "read" mata: _cge_gdx_csv(st_local("dir") + st_local("out"), "`symbol'")
    else mata: _cge_gdx_symbols(st_local("dir") + st_local("out"), ("`clear'" != ""))
    return add
end

* A script that runs a program in its folder
program define _cge_gdx_script
    args script exe cmdargs
    capture erase `"`script'"'
    tempname fh
    file open `fh' using `"`script'"', write text
    if "`c(os)'" == "Windows" {
        file write `fh' "@echo off" _n
        file write `fh' `"cd /d "%~dp0""' _n
    }
    else file write `fh' `"cd "$(dirname "$0")""' _n
    file write `fh' `""`exe'" `cmdargs'"' _n
    file close `fh'
end

* Runs a script with shell
program define _cge_gdx_run
    args script
    if "`c(os)'" == "Windows" {
        local path = subinstr(`"`script'"', "/", "\", .)
        capture noisily shell "`path'"
    }
    else capture noisily shell sh "`script'"
    if _rc exit _rc
end
