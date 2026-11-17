*! cge_nash.ado  v0.24.0  2026-10-25
*! cge-stata: Nash equilibria of players who each choose instruments to
*! maximise or minimise an outcome, and leaders who anticipate the others
*! (Reference Manual, cge_nash)
*!
*! Author: Mustapha Wasseja Mohammed
*! Requires: Stata 13+

program define cge_nash, rclass
    version 13.0
    gettoken sub rest : 0, parse(" ,")
    _cge_load
    if "`sub'" == "player" {
        gettoken pname rest : rest, parse(" ,")
        capture confirm name `pname'
        if _rc | "`pname'" == "," {
            display as error "cge_nash player: give the player's name, then its instruments and objective"
            exit 198
        }
        local 0 `"`rest'"'
        syntax , INSTruments(string) [MAXimize(string) MINimize(string) LOWer(string) UPper(string)]
        if (`"`maximize'"' != "") + (`"`minimize'"' != "") != 1 {
            display as error "cge_nash player: give maximize() or minimize(), one of them"
            exit 198
        }
        local sense = cond(`"`maximize'"' != "", "maximize", "minimize")
        mata: _cge_nash_add("`pname'", st_local("instruments"), "`sense'", st_local("`sense'"), st_local("lower"), st_local("upper"))
        return add
        exit
    }
    if "`sub'" == "list" {
        mata: _cge_nash_list()
        return add
        exit
    }
    if "`sub'" == "clear" {
        local rest = strtrim(`"`rest'"')
        mata: _cge_nash_clear(st_local("rest"))
        exit
    }
    if "`sub'" != "solve" {
        display as error "cge_nash: give player, solve, list or clear"
        exit 198
    }
    local 0 `"`rest'"'
    syntax , NAME(name) [LEADer(name) EXCLude(name) TOLerance(real 1e-8) ITERate(integer 50) TRACE ///
        METHod(name) DAMPing(real 1)]
    if `tolerance' <= 0 | `iterate' < 1 {
        display as error "cge_nash solve: tolerance() must be positive and iterate() at least 1"
        exit 198
    }
    * the method (from version 0.24.0): best responses in turn (gs), or
    * Newton's method on the players' first-order conditions (newton); and
    * the damping of the best responses
    if "`method'" == "" local method gs
    if !inlist("`method'", "gs", "newton") {
        display as error "cge_nash solve: method() takes gs or newton"
        exit 198
    }
    if !(`damping' > 0 & `damping' <= 1) {
        display as error "cge_nash solve: damping() must be above 0 and at most 1"
        exit 198
    }
    if "`method'" == "newton" & `damping' != 1 {
        display as error "cge_nash solve: damping() goes with method(gs)"
        exit 198
    }
    * a leader: its instruments chosen with the followers' equilibrium nested
    if "`leader'" != "" {
        mata: _cge_nash_leader("`leader'", "`name'", `tolerance', `iterate', ("`trace'" != ""), "method(`method') damping(`damping')")
        local lconv = r(leader_converged)
        local lobj = r(leader_objective)
        local neq = r(N_equilibria)
        tempname lins
        matrix `lins' = r(leader_instruments)
        quietly cge_solve, name(`name')
        mata: _cge_sims_drop(("_cgelead", "_cgenash"))
        display as text _n "Leader " as result "`leader'" as text ": " cond(`lconv', "converged", "{err}did not converge{txt}") ///
            " after " as result `neq' as text " equilibria of the followers"
        display as text "Leader's objective: " as result %16.10g `lobj'
        matrix list `lins', noheader
        return scalar converged = `lconv'
        return scalar objective = `lobj'
        return scalar N_equilibria = `neq'
        return matrix leader_instruments = `lins'
        return local name `name'
        return local leader `leader'
        if `lconv' != 1 exit 430
        exit
    }
    * Newton's method on the players' first-order conditions (from version
    * 0.24.0), which leaves the instruments at the equilibrium
    mata: _cge_nash_locals("`exclude'")
    local conv 0
    local it 0
    if "`method'" == "newton" {
        mata: _cge_nash_newton("`exclude'", `tolerance', `iterate', ("`trace'" != ""))
        local conv = r(converged)
        local it = r(iterations)
        local nsolves = r(N_solves)
        local soc = r(second_order)
        forvalues k = 1/`np' {
            tempname v`k'
            mata: st_matrix("`v`k''", _cge_nash_current(st_local("p`k'_ins"))')
        }
    }
    * the players' best responses in turn (Gauss-Seidel), each by cge_optimize
    * with the others' instruments at their current values, until a round
    * changes no instrument by more than the tolerance; with damping() below
    * 1, each player moves that share of the way to its best response
    while "`method'" == "gs" & `it' < `iterate' {
        local ++it
        local dmax 0
        forvalues k = 1/`np' {
            mata: st_matrix("cgenash_v0", _cge_nash_current(st_local("p`k'_ins"))')
            * an instrument at a bound starts just inside it
            mata: _cge_nash_nudge(st_local("p`k'_ins"), st_local("p`k'_lo"), st_local("p`k'_up"))
            capture quietly cge_optimize, instruments(`p`k'_ins') `p`k'_sense'(`p`k'_obj') lower(`p`k'_lo') upper(`p`k'_up') ///
                name(_cgenash)
            if _rc | r(converged) != 1 {
                display as error "cge_nash solve: the best response of player `p`k'_name' was not found (round `it')"
                capture matrix drop cgenash_v0
                exit 430
            }
            tempname v`k'
            matrix `v`k'' = r(instruments)
            forvalues j = 1/`=colsof(`v`k'')' {
                local d = abs(`v`k''[1, `j'] - cgenash_v0[1, `j']) / max(1, abs(cgenash_v0[1, `j']))
                if `d' > `dmax' local dmax = `d'
            }
            if `damping' < 1 {
                matrix `v`k'' = cgenash_v0 + `damping' * (`v`k'' - cgenash_v0)
                mata: _cge_nash_setcur(st_local("p`k'_ins"), st_matrix("`v`k''")')
            }
        }
        if "`trace'" != "" display as text "Round `it': largest change of an instrument " as result %9.3e `dmax'
        if `dmax' < `tolerance' {
            local conv 1
            continue, break
        }
    }
    capture matrix drop cgenash_v0
    quietly cge_solve, name(`name')
    mata: _cge_sims_drop("_cgenash")
    if "`exclude'" == "" {
        display as text _n "Nash equilibrium " as result "`name'" as text ": " cond(`conv', "converged", "{err}did not converge{txt}") ///
            " in " as result `it' as text cond("`method'" == "newton", " Newton iteration(s), " + "`nsolves'" + " solves", " round(s) of best responses")
        display as text "{hline 78}"
        display as text %-12s "Player" %-34s "  Instruments" %16s "Objective"
        display as text "{hline 78}"
    }
    tempname obj ins
    forvalues k = 1/`np' {
        mata: st_numscalar("cgenash_f", _cge_nash_value(st_local("p`k'_obj"), "`name'"))
        matrix `obj' = nullmat(`obj'), scalar(cgenash_f)
        matrix `ins' = nullmat(`ins'), `v`k''
        if "`exclude'" == "" {
            local vals
            forvalues j = 1/`=colsof(`v`k'')' {
                local vals `vals' `: display %10.6g `v`k''[1, `j']'
            }
            display as text %-12s "`p`k'_name'" "  " as result %-32s "`vals'" %16.10g scalar(cgenash_f)
        }
    }
    capture scalar drop cgenash_f
    if "`exclude'" == "" display as text "{hline 78}"
    return scalar converged = `conv'
    return scalar rounds = `it'
    return local method `method'
    if "`method'" == "newton" {
        return scalar N_solves = `nsolves'
        return scalar second_order = `soc'
    }
    return scalar N_players = `np'
    return matrix objectives = `obj'
    return matrix instruments = `ins'
    return local name `name'
    if `conv' != 1 exit 430
end
