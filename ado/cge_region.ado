*! cge_region.ado  v0.12.0  2026-10-24
*! cge-stata: link calibrated single-country models through bilateral trade,
*! as multi-region models do (model_spec.md, Section 21)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_region, rclass
    version 13.0
    _cge_load
    gettoken sub 0 : 0, parse(" ,")
    if "`sub'" == "add" {
        syntax name(name=reg) [using/] [, UNits(real 1) REPLACE]
        if `"`using'"' != "" quietly cge_use using `"`using'"'
        mata: _cge_region_add("`reg'", `units', `= "`replace'" != ""')
        exit
    }
    if "`sub'" == "select" {
        syntax name(name=reg)
        mata: _cge_region_select("`reg'")
        exit
    }
    if "`sub'" == "trade" {
        syntax [using/] , EXPorter(string) IMPorter(string) COMmodity(string) VALue(string) ///
            [TARiff(string) SIGma(string) ROWelasticity(string)]
        if `"`using'"' != "" {
            preserve
            quietly use `"`using'"', clear
        }
        foreach v in exporter importer commodity value tariff {
            if "``v''" != "" confirm variable ``v''
        }
        confirm string variable `exporter' `importer' `commodity'
        confirm numeric variable `value'
        if "`tariff'" != "" confirm numeric variable `tariff'
        mata: _cge_region_trade("`exporter'", "`importer'", "`commodity'", "`value'", "`tariff'", ///
            st_local("sigma"), st_local("rowelasticity"))
        if `"`using'"' != "" restore
        exit
    }
    if "`sub'" == "tariff" {
        syntax , [FROM(string) TO(string) COMmodities(string) VALue(string) SCale(string)]
        if ("`value'" == "") == ("`scale'" == "") {
            display as error "cge_region tariff: give value() or scale()"
            exit 198
        }
        confirm number `value'`scale'
        mata: _cge_region_tariff(st_local("from"), st_local("to"), st_local("commodities"), ///
            `= cond("`value'" == "", ".", "`value'")', `= cond("`scale'" == "", ".", "`scale'")')
        exit
    }
    if "`sub'" == "world" {
        syntax , [COMmodities(string) IMPort(string) EXPort(string) RESET]
        if "`reset'" == "" & "`import'" == "" & "`export'" == "" {
            display as error "cge_region world: give import(), export() or reset"
            exit 198
        }
        if "`import'" != "" confirm number `import'
        if "`export'" != "" confirm number `export'
        mata: _cge_region_world(st_local("commodities"), `= cond("`import'" == "", ".", "`import'")', ///
            `= cond("`export'" == "", ".", "`export'")', `= "`reset'" != ""')
        exit
    }
    if "`sub'" == "solve" {
        syntax , NAME(name) [TOLerance(real 1e-10) ITERate(integer 100) START(string)]
        mata: _cge_region_solve("`name'", `tolerance', `iterate', st_local("start"))
        return add
        exit
    }
    if "`sub'" == "results" {
        syntax , SIM(name) CLEAR
        quietly drop _all
        mata: _cge_region_results("`sim'")
        return add
        exit
    }
    if "`sub'" == "list" {
        syntax
        mata: _cge_region_list()
        return add
        exit
    }
    if "`sub'" == "clear" {
        syntax
        mata: _cge_region_clear()
        exit
    }
    display as error "cge_region: give add, select, trade, tariff, world, solve, results, list or clear"
    exit 198
end
