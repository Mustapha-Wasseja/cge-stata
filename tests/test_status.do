* test_status.do -- solver options and status codes (version 0.16.0;
* docs/model_spec.md, Section 25): the defaults of cge_options and their
* reset; the tolerance, iteration limit, time limit and Jacobian of
* cge_solve from the options or the command; GAMS's model and solver
* statuses for systems, complementarity problems, nonlinear programmes and
* the optimiser, after convergence, iteration and time limits and evaluation
* errors; statuses stored with simulations, saved and loaded; errors.

version 13.0

quietly do setup_synthetic.do

* ---------------------------------------------------------------------
* 1. The defaults, and a solve that converges: model status 16 (solved),
*    solver status 1 (normal completion)
* ---------------------------------------------------------------------
cge_options
assert r(tolerance) == 1e-10 & r(iterate) == 100 & r(timelimit) == . & "`r(jacobian)'" == "exact"
quietly cge_shock tm, value(0)
cge_solve, name(notariff)
assert r(converged) == 1 & r(modelstat) == 16 & r(solvestat) == 1
assert r(tolerance) == 1e-10 & r(iterate) == 100
local it0 = r(iterations)
cge_results, sim(notariff) nodisplay
assert r(modelstat) == 16 & r(solvestat) == 1 & r(converged) == 1

* ---------------------------------------------------------------------
* 2. The iteration limit: model status 6 (intermediate infeasible), solver
*    status 2 (iteration interrupt); from the command and from the options
* ---------------------------------------------------------------------
capture noisily cge_solve, name(it1) iterate(1) steps(1)
assert _rc == 430
assert r(converged) == 0 & r(modelstat) == 6 & r(solvestat) == 2
cge_options, iterate(1)
assert r(iterate) == 1
capture noisily cge_solve, name(it1b) steps(1)
assert _rc == 430 & r(modelstat) == 6 & r(solvestat) == 2 & r(iterate) == 1
* the command's limit takes precedence
cge_solve, name(it100) iterate(100)
assert r(converged) == 1 & r(iterate) == 100
cge_options, reset
assert r(iterate) == 100

* ---------------------------------------------------------------------
* 3. The time limit: at 0 seconds the first check stops the solve, with no
*    fallback and no continuation: solver status 3 (resource interrupt)
* ---------------------------------------------------------------------
capture noisily cge_solve, name(t0) timelimit(0)
assert _rc == 430
assert r(converged) == 0 & r(modelstat) == 6 & r(solvestat) == 3 & r(steps) == 0
* a limit that is not reached changes nothing
cge_solve, name(t100) timelimit(100)
assert r(converged) == 1 & r(modelstat) == 16 & r(iterations) == `it0'
* from the options; the deadline does not outlive the solve
cge_options, timelimit(0)
assert r(timelimit) == 0
capture noisily cge_solve, name(t0b)
assert _rc == 430 & r(solvestat) == 3
cge_options, reset
cge_solve, name(after)
assert r(converged) == 1 & r(solvestat) == 1
* a failed solve leaves no deadline for the optimiser
quietly cge_shock, reset
cge_optimize, instruments(TINSADJ) targets(government savings = 2) name(tsav)
assert r(converged) == 1 & r(modelstat) == 16 & r(solvestat) == 1

* ---------------------------------------------------------------------
* 4. The tolerance and the Jacobian from the options: central differences
*    give the same solution
* ---------------------------------------------------------------------
quietly cge_shock tm, value(0)
cge_options, tolerance(1e-12)
cge_solve, name(tight)
assert r(tolerance) == 1e-12 & r(max_residual) < 1e-12
cge_options, jacobian(differences)
assert "`r(jacobian)'" == "differences" & r(tolerance) == 1e-12
cge_solve, name(fd)
assert r(converged) == 1 & r(modelstat) == 16
capture mata: mata drop _ts_maxdiff()
mata:
real scalar _ts_maxdiff(string scalar a, string scalar b)
{
    struct cge_model scalar M
    real colvector x, y
    M = _cge_load()
    x = M.simx[., _cge_sim_index(M, a)]
    y = M.simx[., _cge_sim_index(M, b)]
    return(max(abs(x - y) :/ rowmax((J(rows(x), 1, 1), abs(x)))))
}
end
mata: st_numscalar("ts_d", _ts_maxdiff("tight", "fd"))
display as text "exact against differenced Jacobian: " as result %9.2e scalar(ts_d)
assert scalar(ts_d) < 1e-9
cge_options, reset
assert r(tolerance) == 1e-10 & "`r(jacobian)'" == "exact"

* ---------------------------------------------------------------------
* 5. Constraints that bind: a complementarity problem, model status 1
*    (optimal), as PATH reports it
* ---------------------------------------------------------------------
quietly cge_shock, reset
quietly cge_constraint QM, elements(com_man) upper(0.98) scale adjust(RM com_man) up
quietly cge_shock qinv, scale(1.5)
cge_solve, name(quota)
assert r(converged) == 1 & r(modelstat) == 1 & r(solvestat) == 1
quietly cge_constraint, clear
quietly cge_shock, reset

* ---------------------------------------------------------------------
* 6. Saving and loading keeps the options and the statuses
* ---------------------------------------------------------------------
cge_options, iterate(50) tolerance(1e-11)
tempfile mf
quietly cge_save using "`mf'", replace
cge_options, reset
quietly cge_use using "`mf'"
cge_options
assert r(iterate) == 50 & r(tolerance) == 1e-11
cge_results, sim(it1) nodisplay
assert r(modelstat) == 6 & r(solvestat) == 2
cge_results, sim(quota) nodisplay
assert r(modelstat) == 1
cge_options, reset
* a model saved before version 0.16.0 has no statuses and the default options
quietly cge_use using "data/model_v030.cgem"
cge_options
assert r(iterate) == 100 & r(tolerance) == 1e-10
* dropping simulations keeps each status with its simulation
quietly do setup_synthetic.do
quietly cge_shock tm, value(0)
capture noisily cge_solve, name(a1) iterate(1) steps(1)
quietly cge_solve, name(a2)
quietly cge_results, sim(a2) nodisplay
assert r(modelstat) == 16
capture mata: mata drop _ts_keep()
mata:
void _ts_keep()
{
    struct cge_model scalar M
    M = _cge_load()
    _cge_sims_keep(M, 2)
    _cge_store(M)
}
_ts_keep()
end
cge_results, sim(a2) nodisplay
assert r(modelstat) == 16 & r(solvestat) == 1

* ---------------------------------------------------------------------
* 7. Nonlinear programmes: locally optimal (2); stopped by the iteration
*    limit at a point that satisfies the equations, a feasible solution (7),
*    or one that does not, intermediate infeasible (6)
* ---------------------------------------------------------------------
cge_model new
cge_set i = x1 x2 x3 x4
cge_parameter x0(i), values(x1:1 x2:5 x3:5 x4:1)
cge_variable X(i), value(x0(i))
cge_variable S, value(0)
cge_equation G1: X(x1) * X(x2) * X(x3) * X(x4) - S = 25
cge_equation G2: sum(i, X(i)^2) = 40
cge_bound X, lower(1) upper(5)
cge_bound S, lower(0)
local f71 X(x1) * X(x4) * (X(x1) + X(x2) + X(x3)) + X(x3)
cge_solve, name(hs) minimize(`f71')
assert r(converged) == 1 & r(modelstat) == 2 & r(solvestat) == 1
* after 2 iterations the equations are far from holding; after 15 they hold
* to 1e-8 (the trace shows a primal error of 4e-12) but the dual conditions
* do not yet
capture noisily cge_solve, name(hs2) minimize(`f71') iterate(2)
assert _rc == 430 & r(solvestat) == 2 & r(modelstat) == 6
capture noisily cge_solve, name(hs15) minimize(`f71') iterate(15)
assert _rc == 430 & r(solvestat) == 2 & r(modelstat) == 7
capture noisily cge_solve, name(hst) minimize(`f71') timelimit(0)
assert _rc == 430 & r(solvestat) == 3
cge_results, sim(hs) nodisplay
assert r(modelstat) == 2

* ---------------------------------------------------------------------
* 8. An equation that cannot be evaluated at the start: model status 13
*    (error, no solution), solver status 5 (evaluation error limit)
* ---------------------------------------------------------------------
cge_model new
cge_variable Y, value(-1)
cge_equation EY: ln(Y) = 0
capture noisily cge_solve, name(bad) steps(1)
assert _rc == 430 & r(modelstat) == 13 & r(solvestat) == 5

* ---------------------------------------------------------------------
* 9. The optimiser: locally optimal with an objective
* ---------------------------------------------------------------------
cge_model new
cge_set g = g1 g2 g3
cge_set gi = g1 g2
cge_parameter alpha(g) = ord(g) / 6
cge_variable X(gi), value(10 / sqrt(3)) fixed
cge_variable XN = sqrt(100 - sum(gi, X(gi)^2))
cge_variable U = sum(gi, alpha(gi) * ln(X(gi))) + alpha(g3) * ln(XN)
cge_optimize, instruments(X(g1) X(g2)) maximize(U) name(opt)
assert r(converged) == 1 & r(modelstat) == 2 & r(solvestat) == 1
cge_results, sim(opt) nodisplay
assert r(modelstat) == 2

* ---------------------------------------------------------------------
* 10. Errors
* ---------------------------------------------------------------------
capture noisily cge_options, tolerance(0)
assert _rc == 198
capture noisily cge_options, iterate(0)
assert _rc == 198
capture noisily cge_options, timelimit(-2)
assert _rc == 198
capture noisily cge_options, jacobian(analytic)
assert _rc == 198
capture noisily cge_solve, tolerance(-3)
assert _rc == 198
capture noisily cge_solve, timelimit(-5)
assert _rc == 198
cge_options, reset

mata: mata drop _ts_maxdiff() _ts_keep()
scalar drop ts_d
