* test_models.do -- named models over subsets of equations (version 0.17.0;
* docs/model_spec.md, Section 26): a model of two markets and a total, whose
* submodel of the markets gives the whole model's prices and quantities
* while the total stays at its level; the total solved from the markets'
* solution with from(); models that list models and all; a nonlinear
* programme of a submodel; statistics of a model; saving and loading;
* errors.

version 13.0

capture mata: mata drop _tm_val()
_cge_load
mata:
// The value of element el of user variable v in simulation s
real scalar _tm_val(string scalar v, string scalar el, real scalar s)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.simx[_cge_u_vpos(M, v, el), s])
}
end

* ---------------------------------------------------------------------
* 1. Two markets, supply 2 P^2 against demand a / sqrt(P), and the value of
*    the markets as a defined variable: P = (a / 2)^(2/5)
* ---------------------------------------------------------------------
cge_model new
cge_set g = g1 g2
cge_parameter a(g), values(g1:10 g2:20)
cge_variable P(g), value(1)
cge_variable Q(g), value(1)
cge_equation DEM(g): Q(g) = a(g) / sqrt(P(g))
cge_equation SUP(g): Q(g) = 2 * P(g)^2
cge_variable TOT = sum(g, P(g) * Q(g))
cge_model define markets = DEM SUP
assert r(N_eq_blocks) == 2 & "`r(equations)'" == "DEM SUP"
cge_model define whole = markets TOT
assert r(N_eq_blocks) == 3
cge_model define every = all
assert r(N_eq_blocks) == 3
cge_model list
assert r(N_models) == 3 & "`r(models)'" == "markets whole every"

* the statistics of the submodel: four equations, four free variables
cge_model describe markets
assert r(N_equations) == 4 & r(N_free) == 4 & r(square) == 1 & "`r(model)'" == "markets"
cge_model describe
assert r(N_equations) == 5 & r(N_free) == 5 & r(N_models) == 3

* the whole model
cge_solve, name(full)
assert r(converged) == 1
* the markets alone: the same prices and quantities; TOT stays at its level, 2
cge_solve, name(mk) model(markets)
assert r(converged) == 1 & "`r(model)'" == "markets" & r(N_solved) == 4 & r(N_free) == 4
assert r(modelstat) == 16
local d = 0
foreach el in g1 g2 {
    local pex = (cond("`el'" == "g1", 10, 20) / 2)^(2/5)
    mata: st_local("p", strofreal(_tm_val("P", "`el'", 2), "%21.15g"))
    mata: st_local("pf", strofreal(_tm_val("P", "`el'", 1), "%21.15g"))
    local d = max(`d', abs(`p' - `pex'), abs(`pf' - `pex'))
}
display as text "markets: prices against the closed form " as result %9.2e `d'
assert `d' < 1e-10
mata: st_numscalar("tm_t", _tm_val("TOT", "", 2))
assert abs(scalar(tm_t) - 2) < 1e-12
* the total alone, from the markets' solution, as GAMS's levels carry over;
* the prices and quantities appear in it and are free, so that it is not
* square until they are held at their levels, as GAMS's P.fx = P.l
cge_model define total = TOT
capture noisily cge_solve, name(tt) model(total) from(mk)
assert _rc == 459
cge_solve, name(tt) model(total) from(mk) hold(P Q)
assert r(converged) == 1 & r(N_solved) == 1 & r(N_free) == 1 & "`r(from)'" == "mk" & "`r(hold)'" == "P Q"
mata: st_numscalar("tm_d", abs(_tm_val("TOT", "", 3) - _tm_val("TOT", "", 1)))
display as text "total from the markets' solution against the whole model: " as result %9.2e scalar(tm_d)
assert scalar(tm_d) < 1e-10
* models that list models and all solve the whole model
cge_solve, name(wh) model(whole)
assert r(converged) == 1 & r(N_solved) == 5
cge_solve, name(ev) model(every)
assert r(converged) == 1 & r(N_solved) == 5
mata: st_numscalar("tm_d", abs(_tm_val("TOT", "", 4) - _tm_val("TOT", "", 1)) + abs(_tm_val("TOT", "", 5) - _tm_val("TOT", "", 1)))
assert scalar(tm_d) < 1e-10
* the whole model from a stored solution converges at once
cge_solve, name(again) from(full)
assert r(converged) == 1 & r(iterations) == 0
cge_results, sim(mk) nodisplay
assert "`r(model)'" == "markets"
cge_results, sim(full) nodisplay
assert "`r(model)'" == ""

* a shock to the submodel's parameter
cge_shock a, elements(g1) value(40)
cge_solve, name(mk40) model(markets)
mata: st_numscalar("tm_d", abs(_tm_val("P", "g1", 7) - (40 / 2)^(2/5)))
assert scalar(tm_d) < 1e-10
cge_shock, reset
* demand alone with the quantities held at their starting levels, 1: P = a^2
cge_model define dem = DEM
cge_solve, name(pd) model(dem) hold(Q)
assert r(converged) == 1 & r(N_solved) == 2 & r(N_free) == 2
mata: st_numscalar("tm_d", abs(_tm_val("P", "g1", 8) - 100) + abs(_tm_val("P", "g2", 8) - 400))
assert scalar(tm_d) < 1e-9
* elements held: with Q(g1) held too, DEM(g1) determines P(g1) and the
* quantities of market g2 stay free, so that the system is not square
capture noisily cge_solve, name(bad) model(dem) hold(Q(g1))
assert _rc == 459
capture noisily cge_solve, name(bad) model(markets) hold(P)
assert _rc == 459
capture noisily cge_solve, name(bad) model(markets) hold(NOSUCH)
assert _rc == 111
capture noisily cge_solve, name(bad) model(markets) hold(P(g9))
assert _rc == 111
cge_model drop dem

* ---------------------------------------------------------------------
* 2. A model that is not square as a system
* ---------------------------------------------------------------------
cge_model define demand = DEM
capture noisily cge_solve, name(dd) model(demand)
assert _rc == 459

* ---------------------------------------------------------------------
* 3. Saving and loading keeps the models and each simulation's model
* ---------------------------------------------------------------------
tempfile mf
quietly cge_save using "`mf'", replace
cge_model new
cge_model list
assert r(N_models) == 0
quietly cge_use using "`mf'"
cge_model list
assert r(N_models) == 5
cge_results, sim(tt) nodisplay
assert "`r(model)'" == "total"
* dropping: a model another lists stays
capture noisily cge_model drop markets
assert _rc == 459
cge_model drop whole
cge_model drop markets
cge_model list
assert r(N_models) == 3
cge_model drop _all
cge_model list
assert r(N_models) == 0

* ---------------------------------------------------------------------
* 4. A nonlinear programme of a submodel: problem 71 of Hock and
*    Schittkowski with an equation outside the model, which stays at its
*    level
* ---------------------------------------------------------------------
cge_model new
cge_set i = x1 x2 x3 x4
cge_parameter x0(i), values(x1:1 x2:5 x3:5 x4:1)
cge_variable X(i), value(x0(i))
cge_variable S, value(0)
cge_equation G1: X(x1) * X(x2) * X(x3) * X(x4) - S = 25
cge_equation G2: sum(i, X(i)^2) = 40
cge_variable W = X(x1) + X(x2)
cge_bound X, lower(1) upper(5)
cge_bound S, lower(0)
cge_model define hs = G1 G2
local f71 X(x1) * X(x4) * (X(x1) + X(x2) + X(x3)) + X(x3)
cge_solve, name(hs) model(hs) minimize(`f71')
assert r(converged) == 1 & abs(r(objective) - 17.0140173) < 1e-7 & "`r(model)'" == "hs" & r(N_dof) == 3
mata: st_numscalar("tm_w", _tm_val("W", "", 1))
assert abs(scalar(tm_w) - 6) < 1e-12

* ---------------------------------------------------------------------
* 5. Errors
* ---------------------------------------------------------------------
capture noisily cge_model define m = NOSUCH
assert _rc == 111
capture noisily cge_model define G1 = G2
assert _rc == 110
capture noisily cge_model define all = G1
assert _rc == 198
capture noisily cge_model define m3
assert _rc == 198
capture noisily cge_model define m3 = m3
assert _rc == 198
capture noisily cge_solve, model(nosuch)
assert _rc == 111
capture noisily cge_solve, model(hs) from(nosuch)
assert _rc == 111
capture noisily cge_model drop nosuch
assert _rc == 111
capture noisily cge_model describe nosuch
assert _rc == 111
quietly do setup_synthetic.do
capture noisily cge_model define m = all
assert _rc == 198
capture noisily cge_solve, model(m)
assert _rc == 198

mata: mata drop _tm_val()
scalar drop tm_t tm_d tm_w
