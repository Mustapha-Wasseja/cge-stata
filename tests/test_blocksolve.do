* test_blocksolve.do -- solving a standalone model block by block
* (version 0.35.0; docs/model_spec.md, Section 45): the same solution as
* the whole system for a model of five blocks, a long recursive chain with a
* simultaneous block at its end, and box pairs; the number of blocks and
* the largest; errors.

version 13.0

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

_cge_load
capture mata: mata drop _tbs_diff()
mata:
// The largest difference between simulations a and b, relative to the
// scale of each variable
real scalar _tbs_diff(string scalar a, string scalar b)
{
    struct cge_model scalar M
    M = _cge_load()
    return(max(abs(M.simx[., _cge_find(M.simname, a)] - M.simx[., _cge_find(M.simname, b)]) :/ M.xscale))
}
end

* ---------------------------------------------------------------------
* 1. Five blocks: e1, e2 and e3 in turn, e4 and e5 together, then e6
* ---------------------------------------------------------------------
cge_model new
forvalues k = 1/6 {
    quietly cge_variable X`k', value(1)
}
cge_equation e1: X1 = 1.5
cge_equation e2: X2 = X1^2 + 1
cge_equation e3: X3 = ln(X2) * 2
cge_equation e4: X4 + X5^3 = 3 + X3
cge_equation e5: exp(X4 / 4) - X5 = 1
cge_equation e6: X6 = X5 * X3
cge_solve, name(whole) tolerance(1e-12)
assert r(converged) == 1
cge_solve, name(blk) tolerance(1e-12) blocks
assert r(converged) == 1 & r(N_blocks) == 5 & r(largest_block) == 2
mata: st_numscalar("tbs_d", _tbs_diff("whole", "blk"))
display as text "five blocks: block by block against whole " as result %9.2e scalar(tbs_d)
assert scalar(tbs_d) < 1e-10

* ---------------------------------------------------------------------
* 2. A recursive chain of 600 variables, X(t) from X(t-1), then a block
*    of 20 that depends on the last
* ---------------------------------------------------------------------
cge_model new
local labs
forvalues k = 1/600 {
    local labs `labs' t`k'
}
cge_set t = `labs'
local labs
forvalues k = 1/20 {
    local labs `labs' j`k'
}
cge_set j = `labs'
cge_parameter a(t) = 1 + ord(t) / 600
cge_variable X(t), value(1)
cge_equation ex(t): X(t) = 0.5 * X(t-1) + sqrt(a(t)) + 0.01 * X(t-1)^2 / (1 + X(t-1))
cge_variable Y(j), value(1)
cge_equation ey(j): Y(j) * (1 + 0.1 * Y(j)) = X(t600) / 4 + 0.02 * sum(j2, Y(j2)) / card(j)
timer clear 1
timer on 1
cge_solve, name(whole) tolerance(1e-12)
timer off 1
assert r(converged) == 1
timer clear 2
timer on 2
cge_solve, name(blk) tolerance(1e-12) blocks
timer off 2
assert r(converged) == 1 & r(N_blocks) == 601 & r(largest_block) == 20
quietly timer list
mata: st_numscalar("tbs_d", _tbs_diff("whole", "blk"))
display as text "a chain of 600 and a block of 20: " as result %9.2e scalar(tbs_d) as text "; seconds, whole " r(t1) ", block by block " r(t2)
assert scalar(tbs_d) < 1e-10

* ---------------------------------------------------------------------
* 3. Box pairs among the equations, each its own block
* ---------------------------------------------------------------------
cge_model new
cge_variable A, value(1) fixed
cge_variable B, value(1) fixed
cge_variable C, value(1)
cge_equation ea: A - 3 = 0, perp(A) lower(0) upper(2)
cge_equation eb: B / 2 - 1 = 0, perp(B) lower(0) upper(5)
cge_equation ec: C = A + B
cge_solve, name(whole) tolerance(1e-12)
cge_solve, name(blk) tolerance(1e-12) blocks
assert r(converged) == 1 & r(N_blocks) == 3
mata: st_numscalar("tbs_d", _tbs_diff("whole", "blk"))
assert scalar(tbs_d) < 1e-10
quietly cge_results, sim(blk) clear nodisplay
quietly summarize value if variable == "C"
assert abs(r(mean) - 4) < 1e-10

* ---------------------------------------------------------------------
* 4. Errors
* ---------------------------------------------------------------------
* structurally singular
cge_model new
quietly cge_variable X1, value(1)
quietly cge_variable X2, value(1)
cge_equation f1: X1 = 1
cge_equation f2: X1 = 2
capture noisily cge_solve, blocks
assert _rc == 459
* a model from a SAM, and other options
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
capture noisily cge_solve, blocks
assert _rc == 198
cge_model new
quietly cge_variable X1, value(1)
cge_equation f1: X1 = 1
capture noisily cge_solve, blocks minimize(X1)
assert _rc == 198
capture noisily cge_solve, blocks steps(3)
assert _rc == 198
capture mata: mata drop _tbs_diff()
