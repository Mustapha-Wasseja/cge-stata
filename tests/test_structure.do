* test_structure.do -- the structure of the system (version 0.35.0;
* docs/model_spec.md, Section 45): the blocks of a standalone model with a
* known structure; the over- and under-determined parts of a structurally
* singular one; a SAM-based model, its reduced and full systems, at the
* current point, the base and a simulation; a singular closure of it named;
* errors.

version 13.0

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)

* ---------------------------------------------------------------------
* 1. A standalone model in five blocks: e1, e2 and e3 in turn, e4 and e5
*    together, then e6
* ---------------------------------------------------------------------
cge_model new
forvalues k = 1/6 {
    quietly cge_variable X`k', value(1)
}
cge_equation e1: X1 = 1
cge_equation e2: X2 = X1 + 1
cge_equation e3: X3 = 2 * X2
cge_equation e4: X4 + X5 = 3
cge_equation e5: X4 - X5 = 1
cge_equation e6: X6 = X5 * X3
cge_structure
assert r(N_equations) == 6 & r(N_variables) == 6 & r(rank) == 6 & r(singular) == 0
assert r(N_blocks) == 5 & r(largest_block) == 2 & r(N_singletons) == 4 & r(N_square) == 6
cge_solve, name(tri)
assert r(converged) == 1

* ---------------------------------------------------------------------
* 2. Structurally singular: f1 and f2 both in X1 alone, f3 in X2 and X3
* ---------------------------------------------------------------------
cge_model new
forvalues k = 1/3 {
    quietly cge_variable X`k', value(1)
}
cge_equation f1: X1 = 1
cge_equation f2: 2 * X1 = 3
cge_equation f3: X2 + X3 = 1
cge_structure
assert r(rank) == 2 & r(singular) == 1
assert r(N_over_eq) == 2 & r(N_over_var) == 1 & r(N_under_var) == 2 & r(N_under_eq) == 1
assert "`r(over_equations)'" == "U(f1) U(f2)" & "`r(over_variables)'" == "X1"
assert "`r(under_variables)'" == "X2 X3" & "`r(under_equations)'" == "U(f3)"
assert r(N_square) == 0 & r(N_blocks) == 0
* an equation with no free variable, and a variable in no equation
cge_model new
quietly cge_variable A, value(1)
quietly cge_variable B, value(1)
quietly cge_variable C, value(2) fixed
cge_equation g1: A = 1
cge_equation g2: C = 2
cge_structure
assert r(rank) == 1 & r(singular) == 1
assert "`r(over_equations)'" == "U(g2)" & "`r(over_variables)'" == ""
assert "`r(under_variables)'" == "B" & "`r(under_equations)'" == ""
assert r(N_square) == 1 & r(N_blocks) == 1

* ---------------------------------------------------------------------
* 3. A SAM-based model: nonsingular, reduced and full, at the current
*    point, the base and a simulation
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
cge_structure
assert r(singular) == 0 & r(rank) == r(N_equations) & r(rank) == r(N_variables) & r(N_square) == r(N_equations)
local nred = r(N_equations)
local bred = r(N_blocks)
cge_structure, full
assert r(singular) == 0 & r(rank) == r(N_equations) & r(N_equations) > `nred'
assert r(N_blocks) >= `bred'
cge_structure, base
assert r(singular) == 0
quietly cge_shock tm, value(0)
quietly cge_solve, name(nt)
cge_structure, sim(nt) top(3)
assert r(singular) == 0 & r(N_equations) == `nred'

* ---------------------------------------------------------------------
* 4. A singular addition named: a user variable that no equation
*    determines and an equation in the numeraire alone
* ---------------------------------------------------------------------
cge_variable Z, value(1)
cge_equation ez: CPI = base(CPI)
cge_structure
assert r(singular) == 1
assert "`r(under_variables)'" == "Z" & "`r(over_equations)'" == "U(ez)"
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 5. Errors
* ---------------------------------------------------------------------
capture noisily cge_structure, sim(nt) base
assert _rc == 198
capture noisily cge_structure, top(0)
assert _rc == 198
capture noisily cge_structure, sim(nosuch)
assert _rc != 0
