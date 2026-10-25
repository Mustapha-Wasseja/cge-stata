* test_modlib.do -- the model library (version 0.21.0; docs/model_spec.md,
* Section 30): every model of cge_modlib runs and gives its expected result;
* the list, descriptions and copies; error positions in equations; errors.

version 13.0

capture mata: mata drop _tl_val()
_cge_load
mata:
// The value of element el of user variable v in simulation sim
real scalar _tl_val(string scalar v, string scalar el, string scalar sim)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.simx[_cge_u_vpos(M, v, el), _cge_sim_index(M, sim)])
}
end

cge_modlib list
assert r(N_models) == 8
cge_modlib describe transport
assert "`r(kind)'" == "nlp" & strpos("`r(expect)'", "153.675")

* the exchange economy
quietly cge_modlib run exchange
mata: st_numscalar("tl_d", abs(_tl_val("P", "g2", "exchange") - 8.2 / 5.4))
assert scalar(tl_d) < 1e-10

* Robinson Crusoe: N = 10/3
quietly cge_modlib run crusoe
mata: st_numscalar("tl_d", abs(_tl_val("N", "", "crusoe") - 10 / 3) + abs(_tl_val("C", "", "crusoe") - 2 * sqrt(10 / 3)))
display as text "crusoe: distance from the closed form " as result %9.2e scalar(tl_d)
assert scalar(tl_d) < 1e-7

* two markets solved block by block
quietly cge_modlib run markets
mata: st_numscalar("tl_d", abs(_tl_val("P", "g1", "markets") - 5^(2/5)) + abs(_tl_val("TOT", "", "total") - _tl_val("TOT", "", "whole")))
assert scalar(tl_d) < 1e-9

* Hock and Schittkowski's problem 71
quietly cge_modlib run hs071
mata: st_numscalar("tl_d", abs(_tl_val("X", "x2", "hs071") - 4.7429994))
assert scalar(tl_d) < 1e-6

* Dantzig's transportation problem: 153.675
quietly cge_modlib run transport
quietly cge_results, sim(transport) nodisplay
assert r(modelstat) == 2
capture mata: mata drop _tl_cost()
mata:
real scalar _tl_cost()
{
    real scalar c
    c = 0.09 * (2.5 * _tl_val("X", "seattle.new_york", "transport") + 1.7 * _tl_val("X", "seattle.chicago", "transport") +
        1.8 * _tl_val("X", "seattle.topeka", "transport") + 2.5 * _tl_val("X", "san_diego.new_york", "transport") +
        1.8 * _tl_val("X", "san_diego.chicago", "transport") + 1.4 * _tl_val("X", "san_diego.topeka", "transport"))
    return(c)
}
end
mata: st_numscalar("tl_c", _tl_cost())
display as text "transport: minimum cost " as result %10.6f scalar(tl_c) as text " (153.675)"
assert abs(scalar(tl_c) - 153.675) < 1e-5

* balancing by cross entropy
quietly cge_modlib run ras
mata: st_numscalar("tl_d", abs(_tl_val("X", "r1.c1", "ras") + _tl_val("X", "r1.c2", "ras") + _tl_val("X", "r1.c3", "ras") + _tl_val("X", "r1.c4", "ras") - 30))
assert scalar(tl_d) < 1e-9

* the knapsack: items 2, 3, 4, 6 and 8
quietly cge_modlib run knapsack
local d = 0
foreach k in 1 5 7 {
    mata: st_local("x", strofreal(_tl_val("X", "i`k'", "knapsack"), "%21.15g"))
    local d = max(`d', abs(`x'))
}
foreach k in 2 3 4 6 8 {
    mata: st_local("x", strofreal(_tl_val("X", "i`k'", "knapsack"), "%21.15g"))
    local d = max(`d', abs(`x' - 1))
}
assert `d' < 1e-9

* Cournot and Stackelberg
quietly cge_modlib run cournot
mata: st_numscalar("tl_d", abs(_tl_val("Q1", "", "cournot") - 3) + abs(_tl_val("Q1", "", "stackelberg") - 4.5) + ///
    abs(_tl_val("Q2", "", "stackelberg") - 2.25))
display as text "cournot and stackelberg: distance from the closed forms " as result %9.2e scalar(tl_d)
assert scalar(tl_d) < 1e-4

* a copy in the current folder (the ado-path of the suite is relative to it)
capture erase cge_ml_ras.do
cge_modlib copy ras
confirm file cge_ml_ras.do
capture noisily cge_modlib copy ras
assert _rc == 602
cge_modlib copy ras, replace
erase cge_ml_ras.do

* ---------------------------------------------------------------------
* Error positions: a syntax error in an equation shows the expression with a
* marker at the place, as GAMS's $ errors do
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(1)
capture noisily cge_equation E: X + * 2 = 1
assert _rc == 198
capture noisily cge_equation E: (X + 2 = 1
assert _rc == 198
capture noisily cge_equation E: X X = 1
assert _rc == 198

* ---------------------------------------------------------------------
* Errors
* ---------------------------------------------------------------------
capture noisily cge_modlib run nosuch
assert _rc == 198
capture noisily cge_modlib nothing ras
assert _rc == 198

mata: mata drop _tl_val() _tl_cost()
scalar drop tl_d tl_c
