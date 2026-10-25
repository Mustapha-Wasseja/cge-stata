* test_lagindex.do -- lags and leads on ordered sets (version 0.26.0;
* docs/model_spec.md, Section 35): X(t-1), X(t+1), X(t+2) and the circular
* X(t++1) and X(t--2) against their values, 0 beyond the set as in GAMS; a
* telescoping sum; capital accumulation by a lag in an equation's domain and
* by a lead, against its recursion; two indexes, base() and a condition;
* errors.

version 13.0

capture mata: mata drop _tl_val()
_cge_load
mata:
// The value of element el of user variable v in the last simulation
real scalar _tl_val(string scalar v, string scalar el)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.simx[_cge_u_vpos(M, v, el), rows(M.simname)])
}
end

capture program drop _tl_check
program define _tl_check
    * _tl_check VAR value1 value2 ...: the values of VAR(y1), VAR(y2), ...
    gettoken v 0 : 0
    local k 0
    foreach w of local 0 {
        local ++k
        mata: st_local("x", strofreal(_tl_val("`v'", "y`k'"), "%21.15g"))
        if abs(`x' - `w') > 1e-10 {
            display as error "`v'(y`k') is `x', not `w'"
            exit 9
        }
    }
end

* ---------------------------------------------------------------------
* 1. Lags and leads of a parameter, g(t) = ord(t), over five years
* ---------------------------------------------------------------------
cge_model new
cge_set t = y1 y2 y3 y4 y5
cge_parameter g(t) = ord(t)
cge_variable L(t) = g(t-1)
cge_variable F(t) = g(t+1)
cge_variable F2(t) = g(t+2)
cge_variable C(t) = g(t++1)
cge_variable B(t) = g(t--2)
cge_variable D(t) = g(t+1) - g(t - 1)
* a telescoping sum: g(y5) - g(y1)
cge_variable S = sum(t$(ord(t) < card(t)), g(t+1) - g(t))
* over an alias, and as an argument after another
cge_parameter h(t,t2) = 10 * ord(t) + ord(t2)
cge_variable H(t) = sum(t2, h(t, t2+1))
cge_solve, name(lags)
assert r(converged) == 1
_tl_check L 0 1 2 3 4
_tl_check F 2 3 4 5 0
_tl_check F2 3 4 5 0 0
_tl_check C 2 3 4 5 1
_tl_check B 4 5 1 2 3
_tl_check D 2 2 2 2 -4
mata: st_local("x", strofreal(_tl_val("S", ""), "%21.15g"))
assert abs(`x' - 4) < 1e-12
* H(t) = sum over t2 = 1..4 of 10 t + t2 + 1 = 40 t + 14
_tl_check H 54 94 134 174 214

* ---------------------------------------------------------------------
* 2. Capital accumulation: K(y1) = 100, K(t) = 0.9 K(t-1) + inv(t-1), with
*    inv(t) = 10 ord(t), written with a lag and, for KF, with a lead
* ---------------------------------------------------------------------
cge_parameter inv(t) = 10 * ord(t)
cge_variable K(t), value(100)
cge_equation K0(t)$(ord(t) == 1): K(t) = 100
cge_equation KA(t)$(ord(t) > 1): K(t) = 0.9 * K(t-1) + inv(t-1)
cge_variable KF(t), value(100)
cge_equation KF1: KF(y1) = 100
cge_equation KFA(t)$(ord(t) < card(t)): KF(t+1) = 0.9 * KF(t) + inv(t)
cge_solve, name(capital)
assert r(converged) == 1
local k 100
local list 100
forvalues y = 2/5 {
    local k = 0.9 * `k' + 10 * (`y' - 1)
    local list `list' `k'
}
_tl_check K `list'
_tl_check KF `list'

* ---------------------------------------------------------------------
* 3. Two indexes, a lag in a condition and base() of a lag
* ---------------------------------------------------------------------
cge_set r = north south
cge_parameter w(r,t) = 100 * ord(r) + ord(t)
cge_variable V(r,t) = w(r,t-1) + w(r,t+1)
cge_variable G(t)$(g(t-1) > 1) = base(K(t-1))
cge_solve, name(two)
mata: st_local("x", strofreal(_tl_val("V", "south.y1"), "%21.15g"))
assert abs(`x' - 202) < 1e-12
mata: st_local("x", strofreal(_tl_val("V", "north.y3"), "%21.15g"))
assert abs(`x' - 206) < 1e-12
* G exists from y3, where g(t-1) = 2, at the base value of K, 100
mata: st_local("x", strofreal(_tl_val("G", "y3"), "%21.15g"))
assert abs(`x' - 100) < 1e-12

* ---------------------------------------------------------------------
* 4. Errors
* ---------------------------------------------------------------------
capture noisily cge_variable E1(t) = g(t+x)
assert _rc == 198
capture noisily cge_variable E2(t) = g(t+0.5)
assert _rc == 198
capture noisily cge_variable E3 = g(t-1)
assert _rc == 198

program drop _tl_check
mata: mata drop _tl_val()
