* test_boxpair.do -- box pairs (version 0.34.0; docs/model_spec.md,
* Section 44): an equation paired with a variable between bounds, F
* perpendicular to l <= X <= u, as in PATH: one-variable boxes with known
* solutions; a target on government purchases met by GADJ within bounds,
* in each regime, against GADJ fixed where it should be; a tariff-rate
* quota, rents between zero and a cap, against the quota as an inequality
* when the cap does not bind; the listing, saving and loading, the GAMS
* program; errors.

version 13.0

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)

_cge_load
capture mata: mata drop _tbx_diff()
capture mata: mata drop _tbx_val()
mata:
// The largest difference between simulations a and b over the model's own
// variables, relative to the scale of each
real scalar _tbx_diff(string scalar a, string scalar b)
{
    struct cge_model scalar M
    real scalar n
    M = _cge_load()
    n = (M.nuv ? M.voff[rows(M.vname) - M.nuv + 1] : rows(M.x0))
    return(max(abs(M.simx[|1, _cge_find(M.simname, a) \ n, _cge_find(M.simname, a)|] -
                   M.simx[|1, _cge_find(M.simname, b) \ n, _cge_find(M.simname, b)|]) :/ M.xscale[|1 \ n|]))
}

// The value of element el of variable v in simulation s
real scalar _tbx_val(string scalar s, string scalar v, string scalar el)
{
    struct cge_model scalar M
    real scalar k
    M = _cge_load()
    k = _cge_vidx(M, v)
    return(M.simx[(el == "" ? _cge_vpos(M, k) : _cge_u_vpos(M, v, el)), _cge_find(M.simname, s)])
}
end

* ---------------------------------------------------------------------
* 1. One-variable boxes, F >= 0 at a lower bound and F <= 0 at an upper:
*    F(x) = x - 3 on [0, 2] stops at x = 2, x/2 - 1 on [0, 5] is interior
*    (x = 2), -1 - x on [0, 5] sits at the upper bound and x - 1 on [2, 5]
*    at the lower
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(1) fixed
cge_equation E: X - 3 = 0, perp(X) lower(0) upper(2)
cge_solve, name(up)
assert r(converged) == 1
mata: st_numscalar("tb_x", _tbx_val("up", "X", ""))
assert abs(scalar(tb_x) - 2) < 1e-10
cge_equation, clear
cge_variable X, value(1) fixed
cge_equation E: X / 2 - 1 = 0, perp(X) lower(0) upper(5)
cge_solve, name(interior)
mata: st_numscalar("tb_x", _tbx_val("interior", "X", ""))
assert abs(scalar(tb_x) - 2) < 1e-10
cge_equation, clear
cge_variable X, value(1) fixed
cge_equation E: -1 - X = 0, perp(X) lower(0) upper(5)
cge_solve, name(atup)
mata: st_numscalar("tb_x", _tbx_val("atup", "X", ""))
assert abs(scalar(tb_x) - 5) < 1e-10
cge_equation, clear
cge_variable X, value(3) fixed
cge_equation E: X - 1 = 0, perp(X) lower(2) upper(5)
cge_solve, name(atlo)
mata: st_numscalar("tb_x", _tbx_val("atlo", "X", ""))
assert abs(scalar(tb_x) - 2) < 1e-10
* one bound only
cge_equation, clear
cge_variable X, value(3) fixed
cge_equation E: X - 7 = 0, perp(X) lower(0)
cge_solve, name(lowonly)
mata: st_numscalar("tb_x", _tbx_val("lowonly", "X", ""))
assert abs(scalar(tb_x) - 7) < 1e-10
cge_equation, clear

* ---------------------------------------------------------------------
* 2. A target on government purchases of services, met by GADJ between
*    0.97 and 1.05, after a tariff removal: interior, above and below,
*    each against GADJ fixed where the box puts it
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
foreach case in "1.02 1.02 interior" "1.08 1.05 upper" "0.90 0.97 lower" {
    tokenize `case'
    quietly cge_shock, reset
    cge_equation gt: QG(com_ser) = `1' * base(QG(com_ser)), perp(GADJ) lower(0.97) upper(1.05)
    quietly cge_shock tm, value(0)
    quietly cge_solve, name(box_`3') tolerance(1e-12)
    assert r(converged) == 1
    mata: st_numscalar("tb_g", _tbx_val("box_`3'", "GADJ", ""))
    quietly cge_equation, clear
    quietly cge_shock GADJ, value(`2')
    quietly cge_solve, name(fix_`3') tolerance(1e-12)
    mata: st_numscalar("tb_d", _tbx_diff("box_`3'", "fix_`3'"))
    display as text "target `1': GADJ " as result %10.6f scalar(tb_g) as text " (`3'); against GADJ fixed at `2' " as result %9.2e scalar(tb_d)
    assert abs(scalar(tb_g) - `2') < 1e-9 & scalar(tb_d) < 1e-9
}
quietly cge_shock, reset

* ---------------------------------------------------------------------
* 3. A tariff-rate quota: rents on imports of manufactures between zero
*    and a cap; with a cap that does not bind, the quota as an inequality
* ---------------------------------------------------------------------
cge_equation trq: 0.98 * base(QM(com_man)) = QM(com_man), perp(RM(com_man)) lower(0) upper(10)
quietly cge_shock tm, value(0)
quietly cge_solve, name(trq_wide) tolerance(1e-12)
assert r(converged) == 1
cge_equation, list
quietly cge_equation, clear
cge_equation quota: QM(com_man) =l= 0.98 * base(QM(com_man)), perp(RM(com_man))
quietly cge_solve, name(quota) tolerance(1e-12)
assert r(converged) == 1
mata: st_numscalar("tb_d", _tbx_diff("trq_wide", "quota"))
mata: st_numscalar("tb_r", _tbx_val("quota", "RM", "com_man"))
display as text "quota as a box and as an inequality: " as result %9.2e scalar(tb_d) as text "; rent " scalar(tb_r)
assert scalar(tb_d) < 1e-9 & scalar(tb_r) > 0
local rent = scalar(tb_r)
quietly cge_equation, clear
* a cap below that rent: the rent stops at the cap, and imports exceed the quota
local cap = `rent' / 2
cge_equation trq: 0.98 * base(QM(com_man)) = QM(com_man), perp(RM(com_man)) lower(0) upper(`cap')
quietly cge_solve, name(trq_cap) tolerance(1e-12)
assert r(converged) == 1
mata: st_numscalar("tb_r", _tbx_val("trq_cap", "RM", "com_man"))
mata: st_numscalar("tb_q", _tbx_val("trq_cap", "QM", "com_man") / _tbx_val("trq_wide", "QM", "com_man"))
display as text "capped rent " scalar(tb_r) " (cap `cap'); imports over the quota by " as result %9.6f scalar(tb_q) - 1
assert abs(scalar(tb_r) - `cap') < 1e-10 & scalar(tb_q) > 1
* the listing, saving and loading
cge_equation, list
tempfile mf
quietly cge_save using "`mf'", replace
quietly cge_use using "`mf'"
quietly cge_solve, name(trq_cap2) tolerance(1e-12)
mata: st_numscalar("tb_d", _tbx_diff("trq_cap", "trq_cap2"))
assert scalar(tb_d) < 1e-10

* ---------------------------------------------------------------------
* 4. The GAMS program: the pair in the scenario's mixed complementarity
*    problem
* ---------------------------------------------------------------------
tempfile gd
local gdir "`gd'_box"
capture mkdir "`gdir'"
cge_gams using "`gdir'", sim(trq_cap) type(mcp) replace
file open fh using "`gdir'/cge_constraints.inc", read text
local found 0
file read fh line
while r(eof) == 0 {
    if strpos(`"`line'"', "UB1.BXV1") | strpos(`"`line'"', "BXV1.up = ") | regexm(`"`line'"', "^UB1\.\.") local ++found
    file read fh line
}
file close fh
assert `found' >= 3
capture noisily cge_gams using "`gdir'", sim(trq_cap) type(cns) replace
assert _rc == 198
quietly cge_equation, clear

* ---------------------------------------------------------------------
* 5. Errors
* ---------------------------------------------------------------------
capture noisily cge_equation e1: QM(com_man) = base(QM(com_man)), perp(RM(com_man))
assert _rc == 198
capture noisily cge_equation e1: QM(com_man) = base(QM(com_man)), perp(RM(com_man)) lower(1) upper(0.5)
assert _rc == 198
capture noisily cge_equation e1: QM(com_man) = base(QM(com_man)), perp(RM(com_man), up) lower(0)
assert _rc == 198
capture noisily cge_equation e1: QM(com_man) = base(QM(com_man)), lower(0)
assert _rc == 198
capture noisily cge_equation e1: QM(com_man) = base(QM(com_man)), perp(RM(com_man)) lower(zero)
assert _rc == 198
* a free variable, and a start outside the bounds
capture noisily cge_equation e1: QM(com_man) = base(QM(com_man)), perp(PQ(com_man)) lower(0)
assert _rc == 459
capture noisily cge_equation e1: QG(com_ser) = base(QG(com_ser)), perp(GADJ) lower(1.1) upper(2)
assert _rc == 459
* a variable paired twice: with an inequality, and with another box pair
cge_equation q2: QM(com_man) =l= base(QM(com_man)), perp(RM(com_man))
capture noisily cge_equation e1: QM(com_man) = base(QM(com_man)), perp(RM(com_man)) lower(0) upper(1)
assert _rc == 459
quietly cge_equation, clear
cge_equation b1: QM(com_agr) = base(QM(com_agr)), perp(RM(com_agr)) lower(0) upper(1)
capture noisily cge_equation b2: QD(com_agr) = base(QD(com_agr)), perp(RM(com_agr)) lower(0) upper(1)
assert _rc == 459
cge_equation, list
capture mata: mata drop _tbx_diff()
capture mata: mata drop _tbx_val()
