* test_nash.do -- Nash equilibria and leaders (version 0.20.0;
* docs/model_spec.md, Section 29): Cournot duopoly and oligopoly against
* their closed forms; a Stackelberg leader against its closed form; a game of
* two instruments on the standard model, whose equilibrium each player's
* optimum confirms; saving and loading the players; errors.

version 13.0

capture program drop _cournot
program define _cournot
    args n
    cge_model new
    cge_parameter a = 10
    cge_parameter b = 1
    cge_parameter c = 1
    local qs
    forvalues i = 1/`n' {
        cge_variable Q`i', value(1) fixed
        local qs `qs' + Q`i'
    }
    cge_variable P = a - b * (0 `qs')
    forvalues i = 1/`n' {
        cge_nash player firm`i', instruments(Q`i') maximize((P - c) * Q`i') lower(Q`i':0)
    }
end

* ---------------------------------------------------------------------
* 1. Cournot duopoly: inverse demand P = a - b (q1 + q2), cost c; each
*    produces (a - c) / (3b) = 3 at a price of 4, with a profit of 9
* ---------------------------------------------------------------------
_cournot 2
cge_nash list
assert r(N_players) == 2 & "`r(players)'" == "firm1 firm2"
cge_nash solve, name(cournot)
assert r(converged) == 1 & r(N_players) == 2
matrix v = r(instruments)
matrix f = r(objectives)
local d = max(abs(v[1, 1] - 3), abs(v[1, 2] - 3))
display as text "duopoly: distance from the closed form " as result %9.2e `d' as text " after " as result r(rounds) as text " rounds"
assert `d' < 1e-6
assert abs(f[1, 1] - 9) < 1e-5 & abs(f[1, 2] - 9) < 1e-5
cge_results, sim(cournot) nodisplay
assert r(converged) == 1

* ---------------------------------------------------------------------
* 2. Stackelberg: firm 1 leads, (a - c) / (2b) = 4.5, and firm 2 follows,
*    (a - c) / (4b) = 2.25
* ---------------------------------------------------------------------
quietly cge_shock, reset
cge_nash solve, name(stack) leader(firm1)
assert r(converged) == 1
local lobj = r(objective)
matrix u = r(leader_instruments)
display as text "leader: " as result u[1, 1] as text " against 4.5"
assert abs(u[1, 1] - 4.5) < 1e-4
capture mata: mata drop _tn_val()
mata:
real scalar _tn_val(string scalar v, string scalar sim)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.simx[_cge_u_vpos(M, v, ""), _cge_sim_index(M, sim)])
}
end
mata: st_numscalar("tn_q2", _tn_val("Q2", "stack"))
display as text "follower: " as result scalar(tn_q2) as text " against 2.25"
assert abs(scalar(tn_q2) - 2.25) < 1e-4
* the leader's profit, (a - c)^2 / (8b) = 10.125, above its Cournot profit
assert abs(`lobj' - 10.125) < 1e-6

* ---------------------------------------------------------------------
* 3. Three firms: (a - c) / (4b) = 2.25 each
* ---------------------------------------------------------------------
_cournot 3
cge_nash solve, name(three)
matrix v = r(instruments)
local d = max(abs(v[1, 1] - 2.25), abs(v[1, 2] - 2.25), abs(v[1, 3] - 2.25))
display as text "three firms: distance from the closed form " as result %9.2e `d'
assert `d' < 1e-6

* ---------------------------------------------------------------------
* 4. The standard model: the government chooses the direct tax factor to
*    bring revenue to 2 per cent above its base, against a tariff chosen for
*    welfare; at the equilibrium each instrument is the player's optimum
*    given the other's
* ---------------------------------------------------------------------
quietly do setup_synthetic.do
cge_nash player gov, instruments(TINSADJ) minimize((YG - 1.02 * base(YG))^2) lower(TINSADJ:0.2) upper(TINSADJ:3)
cge_nash player trade, instruments(tm(com_man)) maximize(welfare equivalent_variation hhd) lower(tm(com_man):0) upper(tm(com_man):1)
cge_nash solve, name(game)
assert r(converged) == 1
matrix v = r(instruments)
* the tariff ends at its lower bound, 0, where the household's welfare is
* highest given the direct tax rates that keep revenue at its target; the
* government's own optimum from the equilibrium changes nothing
assert abs(v[1, 2]) < 1e-12
quietly cge_optimize, instruments(TINSADJ) minimize((YG - 1.02 * base(YG))^2) lower(TINSADJ:0.2) upper(TINSADJ:3)
matrix w = r(instruments)
assert abs(w[1, 1] - v[1, 1]) < 1e-6
* saving and loading keep the players
tempfile mf
quietly cge_save using "`mf'", replace
cge_nash clear
cge_nash list
assert r(N_players) == 0
quietly cge_use using "`mf'"
cge_nash list
assert r(N_players) == 2

* ---------------------------------------------------------------------
* 5. Errors
* ---------------------------------------------------------------------
capture noisily cge_nash player p3, instruments(tm(com_man)) maximize(macro gdp_real)
assert _rc == 198
capture noisily cge_nash player p4, instruments(TINSADJ) maximize(macro gdp_real) minimize(macro gdp_real)
assert _rc == 198
capture noisily cge_nash solve, name(x) leader(nobody)
assert _rc == 111
capture noisily cge_nash clear nobody
assert _rc == 111
cge_nash clear
capture noisily cge_nash solve, name(x)
assert _rc == 459
capture noisily cge_nash nothing
assert _rc == 198

program drop _cournot
mata: mata drop _tn_val()
scalar drop tn_q2
