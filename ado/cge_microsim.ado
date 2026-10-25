*! cge_microsim.ado  v0.9.6  2026-10-23
*! cge-stata: pass one or more simulations to household survey data
*! (model_spec.md, Section 11): consumption, prices, poverty, inequality and
*! incidence by household; welfare, the decomposition of the changes and
*! fiscal incidence; reweighting, survey-design standard errors and bands;
*! graphs of the results
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_microsim, rclass
    version 13.0
    * a standalone model has no SAM (from version 0.13.0)
    _cge_load
    mata: _cge_need_sam()
    syntax [if] [in] [pweight aweight fweight iweight], SIM(string) GROUP(varname)   ///
        CONSumption(varname numeric) [SIZE(varname numeric) INCome(string)          ///
        BUDget(string) LINE(string) QUANTiles(integer 10) GENerate(name) REPLACE     ///
        DETail DECompose MARKet(varname numeric) DTax(varlist numeric) TRANSfers(varlist numeric) ///
        ITax(varlist numeric) SUBsidies(varlist numeric) INKind(string) REWeight(string) SVY BANDs(name) ///
        CLEAR SAVing(string) NODisplay GRAPH(string) GNAME(name) GEXPORT(string) GOPTS(string asis) GCOLOR ///
        GLABels(string asis)]

    * Simulations: one or more (several from version 0.8.0)
    local sims `sim'
    local nsims : word count `sims'
    if `nsims' == 0 {
        display as error "sim(): give a simulation"
        exit 198
    }
    local dups : list dups sims
    if "`dups'" != "" {
        display as error "sim(): `dups' is given more than once"
        exit 198
    }

    * Poverty lines per person: positive numbers, or (from version 0.8.0)
    * numeric variables that give each household its line; without one, no
    * poverty measures are computed
    local lines ""
    local linevars ""
    foreach z of local line {
        if real("`z'") < . {
            if real("`z'") <= 0 {
                display as error "line() must be a positive poverty line per person"
                exit 198
            }
            local lines `lines' `z'
        }
        else {
            capture confirm numeric variable `z'
            if _rc {
                display as error "line(): `z' is neither a number nor a numeric variable"
                exit 198
            }
            unab z : `z', max(1)
            local lines `lines' `z'
            local linevars `linevars' `z'
        }
    }
    local dups : list dups lines
    if "`dups'" != "" {
        display as error "line(): `dups' is given more than once"
        exit 198
    }
    if `quantiles' < 2 | `quantiles' > 100 {
        display as error "quantiles() must be between 2 and 100"
        exit 198
    }

    * The results as a dataset (from version 0.8.0)
    local file ""
    local sreplace ""
    if `"`saving'"' != "" {
        gettoken file rest : saving, parse(",")
        local file = trim(`"`file'"')
        gettoken comma rest : rest, parse(",")
        if trim(`"`rest'"') == "replace" local sreplace replace
        else if trim(`"`rest'"') != "" {
            display as error "saving(): only the option replace is allowed"
            exit 198
        }
        if `"`file'"' == "" {
            display as error "saving(): give a file name"
            exit 198
        }
    }
    * Fiscal incidence (from version 0.8.2): market income and the instruments
    if "`market'" == "" & "`dtax'`transfers'`itax'`subsidies'`inkind'" != "" {
        display as error "give market() with the fiscal instruments"
        exit 198
    }
    if "`clear'" != "" & "`generate'" != "" {
        display as error "clear replaces the survey with the results; use saving() to keep the variables of generate()"
        exit 198
    }
    * Graphs of the results (from version 0.9.6), checked before the results
    * are computed
    local gtypes ""
    if `"`graph'"' != "" {
        local known gic incidence poverty groups shapley fiscal bands
        foreach g of local graph {
            if "`g'" == "all" {
                local gtypes `gtypes' gic incidence groups
                if "`line'" != "" local gtypes `gtypes' poverty
                if "`decompose'" != "" local gtypes `gtypes' shapley
                if "`market'" != "" local gtypes `gtypes' fiscal
                if "`bands'" != "" local gtypes `gtypes' bands
                continue
            }
            if !`: list g in known' {
                display as error "graph(): `g' is not a graph; give gic, incidence, poverty, groups, shapley, fiscal, bands or all"
                exit 198
            }
            if "`g'" == "poverty" & "`line'" == "" {
                display as error "graph(poverty) needs a poverty line, line()"
                exit 198
            }
            if "`g'" == "shapley" & "`decompose'" == "" {
                display as error "graph(shapley) needs decompose"
                exit 198
            }
            if "`g'" == "fiscal" & "`market'" == "" {
                display as error "graph(fiscal) needs fiscal incidence, market()"
                exit 198
            }
            if "`g'" == "bands" & "`bands'" == "" {
                display as error "graph(bands) needs bands()"
                exit 198
            }
            local gtypes `gtypes' `g'
        }
        local gtypes : list uniq gtypes
        if "`gname'" == "" local gname microsim
        if strlen("`gname'") > 21 {
            display as error "gname(): use a name of at most 21 characters"
            exit 198
        }
        local nlab : word count `glabels'
        if `nlab' > `nsims' {
            display as error "glabels(): give at most one label for each simulation of sim()"
            exit 198
        }
    }
    else if "`gname'`gexport'`gcolor'" != "" | `"`gopts'`glabels'"' != "" {
        display as error "gname(), gexport(), gopts(), glabels() and gcolor go with graph()"
        exit 198
    }

    marksample touse, novarlist
    * Survey weights of any type are used as proportional household weights
    local wvar ""
    if "`weight'" != "" {
        if "`svy'" != "" {
            display as error "with svy, the weights are those of svyset"
            exit 198
        }
        tempvar wvar
        quietly generate double `wvar' `exp' if `touse'
    }
    * The survey design (from version 0.8.3): one stage, strata and clusters,
    * as svyset declares them
    local stvar ""
    local suvar ""
    if "`svy'" != "" {
        quietly svyset
        if `"`r(settings)'"' == ", clear" {
            display as error "data not set up for svy; use svyset"
            exit 119
        }
        if "`r(stages)'" != "" & "`r(stages)'" != "1" {
            display as error "svy: only designs with one stage are supported"
            exit 459
        }
        if "`r(fpc1)'" != "" {
            display as error "svy: finite population corrections are not supported"
            exit 459
        }
        if "`r(vce)'" != "" & "`r(vce)'" != "linearized" {
            display as error "svy: only linearized variances are supported"
            exit 459
        }
        if "`r(wvar)'" != "" {
            if "`r(wtype)'" != "pweight" {
                display as error "svy: the weights of svyset must be pweights"
                exit 459
            }
            tempvar wvar
            quietly generate double `wvar' = `r(wvar)' if `touse'
        }
        local su1 "`r(su1)'"
        local st1 "`r(strata1)'"
        if "`st1'" != "" {
            tempvar stvar
            quietly egen long `stvar' = group(`st1') if `touse', missing
            markout `touse' `st1', strok
        }
        if "`su1'" != "" & "`su1'" != "_n" {
            tempvar suvar
            quietly egen long `suvar' = group(`su1') if `touse', missing
            markout `touse' `su1', strok
        }
    }
    markout `touse' `consumption' `wvar' `size' `linevars' `market' `dtax' `transfers' `itax' `subsidies'
    * Variables named in income() and budget() must exist and be numeric
    foreach spec in income budget inkind reweight {
        foreach pair of local `spec' {
            gettoken v : pair, parse(":")
            confirm numeric variable `v'
            markout `touse' `v'
        }
    }
    * The group as a string: the variable itself, its value labels, or its values
    tempvar gs
    capture confirm string variable `group'
    if !_rc quietly generate `gs' = `group'
    else {
        capture decode `group', generate(`gs')
        if _rc quietly generate `gs' = string(`group')
    }
    markout `touse' `gs', strok
    if "`generate'" != "" {
        * with several simulations the variables are numbered: prefix_nom1, ...
        local num ""
        if `nsims' > 1 local num `nsims'
        if strlen("`generate'") + strlen("`num'") > 26 {
            display as error "generate(): use a name of at most " 26 - strlen("`num'") " characters"
            exit 198
        }
        local gvars `generate'_q
        forvalues k = 1/`nsims' {
            local sfx ""
            if `nsims' > 1 local sfx `k'
            local sfxs nom price real pc ev cv
            if "`market'" != "" local sfxs `sfxs' ym yn yd yc yf
            if "`reweight'" != "" local sfxs `sfxs' w
            foreach suffix of local sfxs {
                local gvars `gvars' `generate'_`suffix'`sfx'
            }
        }
        foreach v of local gvars {
            capture confirm new variable `v'
            if _rc {
                if "`replace'" == "" {
                    display as error "variable `v' already exists; use replace"
                    exit 110
                }
                drop `v'
            }
        }
    }
    _cge_load
    mata: _cge_microsim("`sims'", "`touse'", "`gs'", "`consumption'", "`wvar'", "`size'", ///
        `"`income'"', `"`budget'"', "`lines'", `quantiles', "`generate'",              ///
        ("`nodisplay'" == ""), ("`detail'" != ""), ("`decompose'" != ""), "`market'", "`dtax'",       ///
        "`transfers'", "`itax'", "`subsidies'", `"`inkind'"', `"`reweight'"', ("`svy'" != ""),   ///
        "`stvar'", "`suvar'", "`bands'")
    return add

    * The graphs (from version 0.9.6), drawn from the results as a dataset
    if "`gtypes'" != "" {
        preserve
        drop _all
        mata: _cge_ms_post()
        _cge_ms_graphs, types(`gtypes') stub(`gname') sims(`sims') lines(`lines') ///
            export(`"`gexport'"') opts(`gopts') labels(`glabels') `=cond("`gcolor'" != "", "color", "")'
        local drawn `r(graphs)'
        restore
        return local graphs `drawn'
    }

    if "`clear'" != "" {
        drop _all
        mata: _cge_ms_post()
        if `"`file'"' != "" {
            save `"`file'"', `sreplace'
        }
    }
    else if `"`file'"' != "" {
        preserve
        drop _all
        mata: _cge_ms_post()
        save `"`file'"', `sreplace'
        restore
    }
    else mata: _cge_ms_drop()
end

* The graphs of cge_microsim (from version 0.9.6), from its results as a
* dataset in memory: the simulations in the order given, as are the lines.
* The style is that of figures in economics journals: a white background,
* axes on the left and below, light horizontal grid lines, no titles (a
* journal sets them in the caption), and series told apart in grey by shade
* and line pattern, or, with color, in the colours of Okabe and Ito, which
* readers with colour blindness can tell apart
program define _cge_ms_graphs, rclass
    syntax , types(string) stub(name) sims(string) [lines(string) export(string) opts(string asis) ///
        labels(string asis) COLOR]
    tempname simlab linelab chlab
    quietly generate byte _cge_sim = .
    local k 0
    local order ""
    foreach s of local sims {
        local ++k
        quietly replace _cge_sim = `k' if sim == "`s'"
        * the simulation's label in the legends: the one given, or its name
        gettoken lab labels : labels
        if `"`lab'"' == "" local lab `s'
        label define `simlab' `k' `"`lab'"', modify
        local order `order' `k' `"`lab'"'
    }
    label values _cge_sim `simlab'
    label variable _cge_sim "Simulation"
    local nsims `k'

    * the style: the colours of series and bars, the patterns of lines, the
    * markers, and the common options
    if "`color'" != "" {
        local c1 "0 114 178"
        local c2 "213 94 0"
        local c3 "0 158 115"
        local c4 "204 121 167"
        local c5 "230 159 0"
        local c6 "86 180 233"
        local f1 `c1'
        local f2 `c2'
        local f3 `c3'
        local f4 `c4'
        local f5 `c5'
        local f6 `c6'
    }
    else {
        local c1 black
        local c2 gs7
        local c3 gs10
        local c4 black
        local c5 gs7
        local c6 gs10
        local f1 gs3
        local f2 gs9
        local f3 gs13
        local f4 white
        local f5 gs6
        local f6 gs11
    }
    local p1 solid
    local p2 dash
    local p3 shortdash
    local p4 longdash_dot
    local p5 dot
    local p6 dash_dot
    local m1 O
    local m2 D
    local m3 T
    local m4 Oh
    local m5 Dh
    local m6 Th
    * 5 by 3.5 inches, unless gopts() gives the size: Stata allows it once
    local size xsize(5) ysize(3.5)
    if regexm(`"`opts'"', "(^|[ ,])[xy]size *[(]") local size ""
    local base scheme(s1mono) graphregion(color(white)) bgcolor(white) `size'
    local preg plotregion(color(white) lcolor(none) margin(small))
    local yaxis ylabel(, angle(0) labsize(medsmall) glcolor(gs14) glwidth(vthin) grid) yscale(lcolor(black) lwidth(thin))
    local xaxis xscale(lcolor(black) lwidth(thin))
    local zero yline(0, lcolor(gs5) lwidth(thin))
    local leg region(lcolor(none) fcolor(none)) size(medsmall) position(6) symxsize(*0.8) keygap(*0.7)
    * bars: one colour each, outlined
    local bars ""
    forvalues j = 1/6 {
        local bars `bars' bar(`j', fcolor("`f`j''") lcolor(black) lwidth(vthin))
    }
    local drawn ""
    foreach t of local types {
        local gn `stub'_`t'
        if "`t'" == "gic" {
            * one line for each simulation
            local plots ""
            forvalues j = 1/`nsims' {
                local s = mod(`j' - 1, 6) + 1
                local plots `plots' (line pct q if table == "gic" & group == "all" & _cge_sim == `j', sort ///
                    lcolor("`c`s''") lpattern(`p`s'') lwidth(medthin))
            }
            if `nsims' > 1 local lg legend(order(`order') rows(1) `leg')
            else local lg legend(off)
            twoway `plots', `base' `preg' `yaxis' `xaxis' `zero' `lg'                                     ///
                xlabel(0(10)100, labsize(medsmall) nogrid) xtitle("Percentile of consumption per person", size(medsmall)) ///
                ytitle("Change in consumption per person (percent)", size(medsmall)) name(`gn', replace) `opts'
        }
        else if inlist("`t'", "incidence", "groups") {
            if "`t'" == "incidence" {
                * deciles, quintiles or quantile groups
                quietly summarize q if table == "quantile", meanonly
                local qn = r(max)
                local qt = cond(`qn' == 10, "Decile", cond(`qn' == 5, "Quintile", cond(`qn' == 4, "Quartile", "Quantile group")))
                local sel table == "quantile" & measure == "mean" & group == "all"
                local cat q
                local bt "`qt' of base consumption per person (1 = poorest)"
            }
            else {
                local sel table == "summary" & measure == "mean" & group != "all"
                local cat group
                local bt "Household group"
            }
            local lg legend(off)
            if `nsims' > 1 local lg legend(rows(1) `leg')
            graph bar (asis) pct if `sel', over(_cge_sim) over(`cat', label(labsize(medsmall))) asyvars      ///
                `bars' bargap(8) `base' `preg' `yaxis' `zero' `lg'                                            ///
                ytitle("Change in consumption per person (percent)", size(medsmall))                          ///
                b1title("`bt'", size(medsmall)) name(`gn', replace) `opts'
        }
        else if "`t'" == "poverty" {
            * the change in the headcount rate, in percentage points, at each line
            quietly generate double _cge_y = 100 * change if table == "summary" & measure == "fgt0" & group == "all"
            quietly generate byte _cge_line = .
            local j 0
            foreach z of local lines {
                local ++j
                quietly replace _cge_line = `j' if line == "`z'" & !missing(_cge_y)
                label define `linelab' `j' "`z'", modify
            }
            label values _cge_line `linelab'
            local lg legend(off)
            if `nsims' > 1 local lg legend(rows(1) `leg')
            graph bar (asis) _cge_y if !missing(_cge_line), over(_cge_sim) over(_cge_line, label(labsize(medsmall))) ///
                asyvars `bars' bargap(8) `base' `preg' `yaxis' `zero' `lg'                                       ///
                ytitle("Change in headcount (percentage points)", size(medsmall))                    ///
                b1title("Poverty line", size(medsmall)) name(`gn', replace) `opts'
            drop _cge_y _cge_line
        }
        else if "`t'" == "shapley" {
            * the contribution of each channel to the change in the headcount at
            * the first line, or in mean consumption without a line
            gettoken z : lines
            if "`z'" != "" {
                quietly generate double _cge_y = 100 * change if table == "shapley" & group == "all" & measure == "fgt0" & line == "`z'"
                local yt "Contribution (percentage points)"
                local bt "Channels of the change in the headcount, line `z'"
            }
            else {
                quietly generate double _cge_y = pct if table == "shapley" & group == "all" & measure == "mean"
                local yt "Contribution (percent)"
                local bt "Channels of the change in mean consumption per person"
            }
            * the channels in the order of the results, with readable names
            quietly generate byte _cge_ch = .
            local j 0
            forvalues i = 1/`=_N' {
                if missing(_cge_y[`i']) | !missing(_cge_ch[`i']) continue
                local ++j
                local c = channel[`i']
                quietly replace _cge_ch = `j' if channel == "`c'" & !missing(_cge_y)
                if "`c'" == "taxsav" local c "Taxes and savings"
                else if "`c'" == "prices" local c "Prices"
                else if "`c'" == "group" local c "Group"
                else if "`c'" == "weights" local c "Weights"
                else local c "Income from `c'"
                label define `chlab' `j' "`c'", modify
            }
            label values _cge_ch `chlab'
            graph bar (asis) _cge_y if !missing(_cge_y), over(_cge_ch) over(_cge_sim, label(labsize(medsmall))) asyvars ///
                `bars' bargap(8) `base' `preg' `yaxis' `zero' legend(rows(2) `leg')                                  ///
                ytitle("`yt'", size(medsmall)) b1title("`bt'", size(medsmall)) name(`gn', replace) `opts'
            drop _cge_y _cge_ch
        }
        else if "`t'" == "fiscal" {
            * the Gini coefficient of each income concept, in the base and in
            * each simulation
            quietly generate byte _cge_con = .
            local j 0
            foreach c in market net_market disposable consumable final {
                local ++j
                quietly replace _cge_con = `j' if table == "fiscal" & measure == "gini" & group == "all" & channel == "`c'"
            }
            local xl 1 "Market" 2 "Net market" 3 "Disposable" 4 "Consumable" 5 "Final"
            local plots (connected base _cge_con if !missing(_cge_con) & _cge_sim == 1, sort lcolor("`c1'") ///
                lpattern(`p1') lwidth(medthin) mcolor("`c1'") msymbol(`m1') msize(small))
            local ford 1 "Base"
            forvalues j = 1/`nsims' {
                local s = mod(`j', 6) + 1
                local plots `plots' (connected value _cge_con if !missing(_cge_con) & _cge_sim == `j', sort ///
                    lcolor("`c`s''") lpattern(`p`s'') lwidth(medthin) mcolor("`c`s''") msymbol(`m`s'') msize(small))
                local ford `ford' `=`j' + 1' "`: label `simlab' `j''"
            }
            twoway `plots', `base' `preg' `yaxis' `xaxis' legend(order(`ford') rows(1) `leg')                ///
                xlabel(`xl', labsize(medsmall) nogrid) xscale(range(0.7 5.3))                                    ///
                xtitle("Income concept", size(medsmall)) ytitle("Gini coefficient", size(medsmall))              ///
                name(`gn', replace) `opts'
            drop _cge_con
        }
        else if "`t'" == "bands" {
            * the median and the 5th to 95th percentiles across the draws of the
            * per cent change in mean consumption, the headcount at each line and
            * the Gini coefficient, one row each
            quietly generate double _cge_y = pct if table == "bands" & group == "all"
            quietly generate double _cge_it = .
            local j 1
            local yl `"1 "Mean consumption""'
            quietly replace _cge_it = 1 if measure == "mean" & !missing(_cge_y)
            foreach z of local lines {
                local ++j
                quietly replace _cge_it = `j' if measure == "fgt0" & line == "`z'" & !missing(_cge_y)
                local yl `"`yl' `j' "Headcount, line `z'""'
            }
            local ++j
            quietly replace _cge_it = `j' if measure == "gini" & !missing(_cge_y)
            local yl `"`yl' `j' "Gini coefficient""'
            quietly bysort sim measure line: egen double _cge_lo = max(cond(channel == "p5", _cge_y, .))
            quietly bysort sim measure line: egen double _cge_hi = max(cond(channel == "p95", _cge_y, .))
            * several simulations side by side
            quietly summarize _cge_sim if !missing(_cge_it), meanonly
            quietly generate double _cge_x = _cge_it + 0.15 * (_cge_sim - (r(min) + r(max)) / 2)
            twoway (rcap _cge_lo _cge_hi _cge_x if channel == "p50" & !missing(_cge_it), horizontal          ///
                    lcolor("`c1'") lwidth(medthin) msize(medium))                                              ///
                (scatter _cge_x _cge_y if channel == "p50" & !missing(_cge_it), mcolor("`c1'") msymbol(O) msize(small)), ///
                `base' `preg' ylabel(`yl', angle(0) labsize(medsmall) noticks nogrid) yscale(reverse range(0.5 `j'.5) lcolor(black) lwidth(thin)) ///
                xlabel(, labsize(medsmall) glcolor(gs14) glwidth(vthin) grid) `xaxis'                              ///
                xline(0, lcolor(gs5) lwidth(thin)) ytitle("")                                                 ///
                legend(order(1 "5th to 95th percentile of the draws" 2 "Median") rows(1) `leg')             ///
                xtitle("Change (percent)", size(medsmall)) name(`gn', replace) `opts'
            drop _cge_y _cge_it _cge_lo _cge_hi _cge_x
        }
        * the graph as a file: the name given, with the graph's type before the
        * extension (.png if none is given); bitmaps 2,000 pixels wide
        if `"`export'"' != "" {
            if regexm(`"`export'"', "^(.*)(\.[A-Za-z]+)$") {
                local fbase = regexs(1)
                local fext = regexs(2)
            }
            else {
                local fbase `"`export'"'
                local fext .png
            }
            * the format from the extension: Stata would read it from the
            * first period of the file name
            local fmt = lower(substr("`fext'", 2, .))
            local wd ""
            if inlist("`fmt'", "png", "tif") local wd width(2000)
            quietly graph export `"`fbase'_`t'`fext'"', name(`gn') as(`fmt') replace `wd'
        }
        local drawn `drawn' `gn'
    }
    return local graphs `drawn'
end
