* test_optgrad.do -- exact derivatives in cge_optimize (version 0.15.0;
* docs/model_spec.md, Section 24): a planner's choice on a frontier, whose
* optimum has a closed form, with instruments free, at a bound and under a
* constraint; ten instruments; the exact and the differenced derivatives
* against each other; a target with an objective in the standard model.

version 13.0

* The frontier sum_i X(i)^2 = R^2, with X(n) determined by it and the others
* instruments, and the utility sum_i alpha(i) ln X(i): the optimum is
* X(i) = R sqrt(alpha(i)), and with X(1) <= 3 binding, X(i) = sqrt(alpha(i) /
* sum_{j>1} alpha(j)) sqrt(R^2 - 9) for the others.
capture program drop _frontier
program define _frontier
    args n
    cge_model new
    local els
    forvalues i = 1/`n' {
        local els `els' g`i'
    }
    cge_set g = `els'
    local ins
    forvalues i = 1/`=`n' - 1' {
        local ins `ins' g`i'
    }
    cge_set gi = `ins'
    cge_parameter R = 10
    * alpha(i) proportional to i
    cge_parameter alpha(g) = ord(g) / (card(g) * (card(g) + 1) / 2)
    cge_variable X(gi), value(R / sqrt(card(g))) fixed
    cge_variable XN = sqrt(R^2 - sum(gi, X(gi)^2))
    cge_variable U = sum(gi, alpha(gi) * ln(X(gi))) + alpha(g`n') * ln(XN)
end

* ---------------------------------------------------------------------
* 1. Three goods: the optimum against the closed form, with exact and with
*    differenced derivatives
* ---------------------------------------------------------------------
_frontier 3
foreach gm in exact differences {
    quietly cge_shock, reset
    cge_optimize, instruments(X(g1) X(g2)) maximize(U) name(f_`gm') gradient(`gm')
    assert r(converged) == 1 & "`r(gradient)'" == "`gm'"
    matrix v = r(instruments)
    local ev_`gm' = r(N_evaluations)
    local d = max(abs(v[1, 1] - 10 * sqrt(1/6)), abs(v[1, 2] - 10 * sqrt(2/6)))
    display as text "`gm': distance from the closed form " as result %9.2e `d' as text ", " as result `ev_`gm'' as text " solves"
    if "`gm'" == "exact" assert `d' < 1e-8
    else assert `d' < 1e-5
}
assert `ev_exact' < `ev_differences'

* an instrument at a bound: X(g1) <= 3, the optimum of the others in closed form
quietly cge_shock, reset
* the instrument starts within its bound
quietly cge_shock X, elements(g1) value(2)
cge_optimize, instruments(X(g1) X(g2)) maximize(U) upper(X(g1):3) name(f_bound)
assert r(converged) == 1
matrix v = r(instruments)
matrix mg = r(instrument_marginals)
local d = max(abs(v[1, 1] - 3), abs(v[1, 2] - sqrt(2/5) * sqrt(91)))
display as text "at a bound: distance from the closed form " as result %9.2e `d'
assert `d' < 1e-8
* the marginal of the bound: dU/dX(g1) at the optimum, alpha1/X1 - alpha3 X1/XN^2
local mexact = (1/6) / 3 - (3/6) * 3 / (91 - (2/5) * 91)
display as text "its marginal " as result %12.8f mg[1, 1] as text ", closed form " as result %12.8f `mexact'
assert abs(mg[1, 1] - `mexact') < 1e-8
* the same as a constraint of the optimiser, with its marginal
quietly cge_shock, reset
cge_optimize, instruments(X(g1) X(g2)) maximize(U) constraints(X(g1) <= 3) name(f_cons)
assert r(converged) == 1 & r(N_binding) == 1
matrix v = r(instruments)
matrix cm = r(constraint_marginals)
local d = max(abs(v[1, 1] - 3), abs(v[1, 2] - sqrt(2/5) * sqrt(91)))
display as text "as a constraint: distance " as result %9.2e `d' as text ", marginal " as result %12.8f cm[1, 1]
assert `d' < 1e-7
assert abs(cm[1, 1] - `mexact') < 1e-6

* ---------------------------------------------------------------------
* 2. Ten goods, nine instruments: the closed form, in few solves
* ---------------------------------------------------------------------
_frontier 10
local ins
forvalues i = 1/9 {
    local ins `ins' X(g`i')
}
cge_optimize, instruments(`ins') maximize(U) name(f10)
assert r(converged) == 1
matrix v = r(instruments)
local d = 0
forvalues i = 1/9 {
    local d = max(`d', abs(v[1, `i'] - 10 * sqrt(`i' / 55)))
}
display as text "ten goods: distance from the closed form " as result %9.2e `d' as text ", " ///
    as result r(N_evaluations) as text " solves"
assert `d' < 1e-8

* ---------------------------------------------------------------------
* 3. The standard model: tariffs that maximise welfare with tariff revenue as
*    a target, both derivatives; and the targets alone
* ---------------------------------------------------------------------
quietly do setup_synthetic.do
local ev welfare equivalent_variation hhd
foreach gm in exact differences {
    quietly cge_shock, reset
    cge_optimize, instruments(tm(com_agr) tm(com_man)) maximize(`ev') targets(government tax_import = 8) ///
        name(r_`gm') gradient(`gm')
    assert r(converged) == 1
    matrix v_`gm' = r(instruments)
    local ev_`gm' = r(N_evaluations)
}
local d = max(abs(v_exact[1, 1] - v_differences[1, 1]), abs(v_exact[1, 2] - v_differences[1, 2]))
display as text "revenue target: exact against differences " as result %9.2e `d' as text "; solves " ///
    as result `ev_exact' as text " against " as result `ev_differences'
assert `d' < 1e-6
assert `ev_exact' < `ev_differences'
* targets alone: government savings at 2, with the direct tax rate's scaling
* factor as the instrument
quietly cge_shock, reset
cge_optimize, instruments(TINSADJ) targets(government savings = 2) name(t_exact)
assert r(converged) == 1
matrix a = r(instruments)
quietly cge_shock, reset
cge_optimize, instruments(TINSADJ) targets(government savings = 2) name(t_diff) gradient(differences)
assert r(converged) == 1
matrix b = r(instruments)
assert abs(a[1, 1] - b[1, 1]) < 1e-10
capture noisily cge_optimize, instruments(TINSADJ) targets(government savings = 2) gradient(analytic)
assert _rc == 198
program drop _frontier
