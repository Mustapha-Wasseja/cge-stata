* test_environment.do -- Stata version, Mata nonlinear solver and package loading

version 13.0
assert c(stata_version) >= 13

* solvenl() must solve a small nonlinear system: x1^2 + x2^2 = 2, x1 = x2
capture mata: mata drop _cge_test_system()
mata:
void _cge_test_system(real colvector x, real colvector y)
{
    y = J(2, 1, .)
    y[1] = x[1]^2 + x[2]^2 - 2
    y[2] = x[1] - x[2]
}
S = solvenl_init()
solvenl_init_evaluator(S, &_cge_test_system())
solvenl_init_type(S, "zero")
solvenl_init_technique(S, "newton")
solvenl_init_iter_log(S, "off")
solvenl_init_startingvals(S, (2 \ 0.5))
x = solvenl_solve(S)
st_numscalar("cge_test_converged", solvenl_result_converged(S))
st_numscalar("cge_test_error", max(abs(x :- 1)))
end

assert scalar(cge_test_converged) == 1
assert scalar(cge_test_error) < 1e-6
scalar drop cge_test_converged cge_test_error

* The package information command runs and reports a version
cge
assert "`r(version)'" != ""
