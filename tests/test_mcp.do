* test_mcp.do -- complementarity problems (version 0.14.0; docs/model_spec.md,
* Section 23): the semismooth Newton method against problems of MCPLIB with
* known solutions (Josephy; Kojima and Shindo, with a degenerate solution), an
* economy in the form of MPSGE whose technologies are active or not against
* the solution of its linear programme, many constraints of the standard
* model at once against the active-set method, and the setting itself.

version 13.0

capture mata: mata drop _tm_x()
_cge_load
mata:
// The values of variable v in simulation s, in storage order
real colvector _tm_x(string scalar v, real scalar s)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.simx[_cge_vpos(M, _cge_vidx(M, v)), s])
}
end

* ---------------------------------------------------------------------
* 1. MCPLIB josephy and kojshin: x >= 0, F(x) >= 0, x'F(x) = 0, with each
*    x(i) at its lower bound 0, from which the inequality moves it up
* ---------------------------------------------------------------------
foreach prob in josephy kojshin {
    cge_model new
    cge_set i = x1 x2 x3 x4
    cge_variable X(i), lower(0)
    local c3 = cond("`prob'" == "josephy", 3, 10)
    local c9 = cond("`prob'" == "josephy", 3, 9)
    local c1 = cond("`prob'" == "josephy", 1, 9)
    cge_equation F1: 3 * X(x1)^2 + 2 * X(x1) * X(x2) + 2 * X(x2)^2 + X(x3) + 3 * X(x4) - 6 >= 0, perp(X(x1))
    cge_equation F2: 2 * X(x1)^2 + X(x1) + X(x2)^2 + `c3' * X(x3) + 2 * X(x4) - 2 >= 0, perp(X(x2))
    cge_equation F3: 3 * X(x1)^2 + X(x1) * X(x2) + 2 * X(x2)^2 + 2 * X(x3) + `c9' * X(x4) - `c1' >= 0, perp(X(x3))
    cge_equation F4: X(x1)^2 + 3 * X(x2)^2 + 2 * X(x3) + 3 * X(x4) - 3 >= 0, perp(X(x4))
    cge_solve, name(`prob')
    assert r(converged) == 1
    mata: x = _tm_x("X", 1)
    if "`prob'" == "josephy" {
        * the unique solution (sqrt(6)/2, 0, 0, 1/2)
        mata: st_numscalar("tm_d", max(abs(x - (sqrt(6) / 2 \ 0 \ 0 \ 0.5))))
    }
    else {
        * two solutions: (sqrt(6)/2, 0, 0, 1/2), degenerate in x3, and (1, 0, 3, 0)
        mata: st_numscalar("tm_d", min((max(abs(x - (sqrt(6) / 2 \ 0 \ 0 \ 0.5))), max(abs(x - (1 \ 0 \ 3 \ 0))))))
    }
    display as text "`prob': distance from a known solution " as result %9.2e scalar(tm_d)
    assert scalar(tm_d) < 1e-8
}
* the degenerate solution of kojshin from a start near it, and the other one
foreach st in "1.2 0 0.1 0.5" "1 0 2.9 0" {
    cge_model new
    cge_set i = x1 x2 x3 x4
    local k = 0
    foreach v of local st {
        local ++k
        local v`k' `v'
    }
    cge_variable X(i), lower(0)
    * the start, as GAMS's .l of the variables paired with the inequalities
    forvalues e = 1/4 {
        cge_bound X(x`e'), level(`v`e'')
    }
    cge_equation F1: 3 * X(x1)^2 + 2 * X(x1) * X(x2) + 2 * X(x2)^2 + X(x3) + 3 * X(x4) - 6 >= 0, perp(X(x1))
    cge_equation F2: 2 * X(x1)^2 + X(x1) + X(x2)^2 + 10 * X(x3) + 2 * X(x4) - 2 >= 0, perp(X(x2))
    cge_equation F3: 3 * X(x1)^2 + X(x1) * X(x2) + 2 * X(x2)^2 + 2 * X(x3) + 9 * X(x4) - 9 >= 0, perp(X(x3))
    cge_equation F4: X(x1)^2 + 3 * X(x2)^2 + 2 * X(x3) + 3 * X(x4) - 3 >= 0, perp(X(x4))
    cge_solve, name(ks)
    assert r(converged) == 1
    mata: x = _tm_x("X", 1)
    mata: st_numscalar("tm_d", min((max(abs(x - (sqrt(6) / 2 \ 0 \ 0 \ 0.5))), max(abs(x - (1 \ 0 \ 3 \ 0))))))
    assert scalar(tm_d) < 1e-8
}

* ---------------------------------------------------------------------
* 2. An economy in the form of MPSGE: one good made by two technologies from
*    labour and capital; activity levels against zero profits, factor prices
*    against factor markets, the good the numeraire. The equilibrium is the
*    solution of max Z1 + Z2 s.t. a1 Z1 + a2 Z2 <= L, b1 Z1 + b2 Z2 <= K, the
*    factor prices its duals.
* ---------------------------------------------------------------------
foreach case in corner interior {
    cge_model new
    cge_set j = t1 t2
    cge_parameter a(j), values(t1:1 t2:2)
    cge_parameter b(j), values(t1:2 t2:1)
    cge_parameter L = 10
    local kval = cond("`case'" == "corner", 30, 14)
    cge_parameter K = `kval'
    cge_variable Z(j), lower(0)
    cge_variable W, lower(0)
    cge_variable R, lower(0)
    cge_equation PROFIT(j): a(j) * W + b(j) * R - 1 >= 0, perp(Z(j))
    cge_equation LAB: L - sum(j, a(j) * Z(j)) >= 0, perp(W)
    cge_equation CAP: K - sum(j, b(j) * Z(j)) >= 0, perp(R)
    cge_variable Y = (W * L + R * K) / 1
    cge_solve, name(`case')
    assert r(converged) == 1
    mata: zz = _tm_x("Z", 1)
    mata: w = _tm_x("W", 1)
    mata: rr = _tm_x("R", 1)
    mata: y = _tm_x("Y", 1)
    if "`case'" == "corner" {
        * labour binds, capital is free: Z = (10, 0), W = 1, R = 0
        mata: st_numscalar("tm_d", max(abs((zz \ w \ rr) - (10 \ 0 \ 1 \ 0))))
    }
    else {
        * both bind: Z = (6, 2), W = R = 1/3
        mata: st_numscalar("tm_d", max(abs((zz \ w \ rr) - (6 \ 2 \ 1/3 \ 1/3))))
    }
    display as text "`case': distance from the linear programme's solution " as result %9.2e scalar(tm_d)
    assert scalar(tm_d) < 1e-9
    * income equals the value of output, as Walras's law requires
    mata: assert(abs(y - sum(zz)) < 1e-9)
}

* ---------------------------------------------------------------------
* 3. Many constraints of the standard model at once: capacity on every
*    activity and quotas on the imports of two commodities, under a demand
*    shock that makes some of them bind; the semismooth Newton method against
*    the active-set method
* ---------------------------------------------------------------------
quietly do setup_synthetic.do
foreach a in act_agr act_man act_ser {
    quietly cge_constraint QA, elements(`a') upper(1) scale adjust(RA `a') up
}
quietly cge_constraint QM, elements(com_agr) upper(0.98) scale adjust(RM com_agr) up
quietly cge_constraint QM, elements(com_man) upper(0.98) scale adjust(RM com_man) up
quietly cge_shock qinv, scale(1.5)
cge_options
assert "`r(mcp)'" == "semismooth"
cge_solve, name(ss)
assert r(converged) == 1 & "`r(method)'" == "semismooth"
local nb = r(N_binding)
* four of the five bind: the capacity of agriculture and manufacturing and both quotas
assert `nb' == 4
cge_options, mcp(activeset)
assert "`r(mcp)'" == "activeset"
cge_solve, name(as)
assert r(converged) == 1 & r(N_binding) == `nb'
mata: st_numscalar("tm_d", max(abs(_tm_x("QA", 1) - _tm_x("QA", 2)) :/ _tm_x("QA", 2)))
display as text "many constraints: " as result `nb' as text " binding; semismooth against active set " as result %9.2e scalar(tm_d)
assert scalar(tm_d) < 1e-9
_cge_load
mata:
real scalar _tm_all()
{
    struct cge_model scalar M
    M = _cge_load()
    return(max(abs(M.simx[., 1] - M.simx[., 2]) :/ M.xscale))
}
end
mata: st_numscalar("tm_d", _tm_all())
assert scalar(tm_d) < 1e-8
mata: mata drop _tm_all()
* the setting is saved with the model
tempfile f
quietly cge_save using `f', replace
quietly cge_use using `f'
cge_options
assert "`r(mcp)'" == "activeset"
cge_options, mcp(semismooth)
capture noisily cge_options, mcp(path)
assert _rc == 198

mata: mata drop _tm_x()
