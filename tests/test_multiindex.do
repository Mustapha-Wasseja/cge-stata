* test_multiindex.do -- symbols with three or more indexes (version 0.25.0;
* docs/model_spec.md, Section 34): parameters, variables and equations over
* three and four indexes against closed forms; sums over tuples of indexes
* and over a set of triples against enumeration; ord() of each index; data
* in values() and in long form; shocks, bounds and results of elements;
* labels; saving and loading; errors.

version 13.0

capture mata: mata drop _tx_val()
capture mata: mata drop _tx_lab()
_cge_load
mata:
// The value of element el of user variable v in the last simulation
real scalar _tx_val(string scalar v, string scalar el)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.simx[_cge_u_vpos(M, v, el), rows(M.simname)])
}

// The label of element el of variable v, as messages and listings write it
string scalar _tx_lab(string scalar v, string scalar el)
{
    struct cge_model scalar M
    M = _cge_load()
    return(_cge_poslabel(M, _cge_u_vpos(M, v, el)))
}
end

* ---------------------------------------------------------------------
* 1. A parameter, a variable and an equation over three indexes:
*    a(i,j,k) = 100 ord(i) + 10 ord(j) + ord(k), and X(i,j,k)^2 = a(i,j,k)
* ---------------------------------------------------------------------
cge_model new
cge_set i = p1 p2
cge_set j = q1 q2 q3
cge_set k = r1 r2
cge_parameter a(i,j,k) = 100 * ord(i) + 10 * ord(j) + ord(k)
assert r(N_elements) == 12
cge_variable X(i,j,k), value(10)
assert r(N_elements) == 12
cge_equation EX(i,j,k): X(i,j,k)^2 = a(i,j,k)
assert r(N_elements) == 12
* sums over every index, over two of them and over one
cge_variable T = sum((i,j,k), a(i,j,k))
cge_variable S(i) = sum((j,k), X(i,j,k)^2)
cge_variable R(i,k) = sum(j, a(i,j,k))
cge_solve, name(three)
assert r(converged) == 1
local d 0
forvalues p = 1/2 {
    forvalues q = 1/3 {
        forvalues r = 1/2 {
            mata: st_local("x", strofreal(_tx_val("X", "p`p'.q`q'.r`r'"), "%21.15g"))
            local d = max(`d', abs(`x' - sqrt(100 * `p' + 10 * `q' + `r')))
        }
    }
}
display as text "X against sqrt(a): " as result %9.2e `d'
assert `d' < 1e-12
* T = 2058; S(i) = 600 i + 129; R(i,k) = 300 i + 60 + 3 k
mata: st_local("t", strofreal(_tx_val("T", ""), "%21.15g"))
assert abs(`t' - 2058) < 1e-9
forvalues p = 1/2 {
    mata: st_local("s", strofreal(_tx_val("S", "p`p'"), "%21.15g"))
    assert abs(`s' - (600 * `p' + 129)) < 1e-9
    forvalues r = 1/2 {
        mata: st_local("s", strofreal(_tx_val("R", "p`p'.r`r'"), "%21.15g"))
        assert abs(`s' - (300 * `p' + 60 + 3 * `r')) < 1e-9
    }
}
* the labels of an element, with commas
mata: st_local("lab", _tx_lab("X", "p2.q3.r1"))
assert "`lab'" == "X(p2,q3,r1)"

* ---------------------------------------------------------------------
* 2. A set of triples: a sum over it, a domain restricted to it, and its
*    membership in a condition
* ---------------------------------------------------------------------
cge_set m(i,j,k) = p1.q1.r1 p1.q2.r2 p2.q3.r1
assert r(N_elements) == 3
cge_variable M3 = sum(m(i,j,k), a(i,j,k))
cge_variable Y(i,j,k)$(m(i,j,k)) = 2 * a(i,j,k)
assert r(N_elements) == 3
cge_variable N3 = sum((i,j,k)$(m(i,j,k) & ord(k) == 1), a(i,j,k))
cge_solve, name(triples)
assert r(converged) == 1
mata: st_local("s", strofreal(_tx_val("M3", ""), "%21.15g"))
assert abs(`s' - (111 + 122 + 231)) < 1e-9
mata: st_local("s", strofreal(_tx_val("Y", "p1.q2.r2"), "%21.15g"))
assert abs(`s' - 244) < 1e-9
mata: st_local("s", strofreal(_tx_val("N3", ""), "%21.15g"))
assert abs(`s' - (111 + 231)) < 1e-9
cge_set, list

* ---------------------------------------------------------------------
* 3. Four indexes, with the alias of a set: b(i,j,k,i2) = a(i,j,k) * ord(i2)
*    and the sum over the alias
* ---------------------------------------------------------------------
cge_parameter b(i,j,k,i2) = a(i,j,k) * ord(i2)
assert r(N_elements) == 24
cge_variable W(i,j,k) = sum(i2, b(i,j,k,i2))
cge_solve, name(four)
mata: st_local("s", strofreal(_tx_val("W", "p2.q1.r2"), "%21.15g"))
assert abs(`s' - 3 * 212) < 1e-9

* ---------------------------------------------------------------------
* 4. Data: values() and long form with one label variable per index
* ---------------------------------------------------------------------
cge_parameter c(i,j,k), values(p1.q2.r1:5 p2.q3.r2:7) default(1)
preserve
clear
input str2 li str2 lj str2 lk double v
"p1" "q1" "r2" 3
"p2" "q2" "r1" 4
end
cge_parameter d(i,j,k), from(v) labels(li lj lk) default(0)
restore
cge_variable C2 = sum((i,j,k), c(i,j,k)) + 100 * sum((i,j,k), d(i,j,k))
cge_solve, name(data)
* c: ten elements at 1, then 5 and 7; d: 3 and 4
mata: st_local("s", strofreal(_tx_val("C2", ""), "%21.15g"))
assert abs(`s' - (10 + 5 + 7 + 700)) < 1e-9

* ---------------------------------------------------------------------
* 5. Shocks, bounds and fixed elements by e1.e2.e3
* ---------------------------------------------------------------------
cge_shock a, elements(p2.q3.r2) value(400)
cge_solve, name(shock)
mata: st_local("x", strofreal(_tx_val("X", "p2.q3.r2"), "%21.15g"))
assert abs(`x' - 20) < 1e-12
mata: st_local("x", strofreal(_tx_val("X", "p2.q3.r1"), "%21.15g"))
assert abs(`x' - sqrt(231)) < 1e-12
quietly cge_shock, reset
cge_variable Z(i,j,k), value(1) fixed
cge_shock Z, elements(p1.q1.r1) value(3)
cge_variable ZS = sum((i,j,k), Z(i,j,k))
cge_solve, name(fixed)
mata: st_local("s", strofreal(_tx_val("ZS", ""), "%21.15g"))
assert abs(`s' - 14) < 1e-12
quietly cge_shock, reset
cge_bound X, elements(p1.q1.r1) lower(0)
cge_bound, list

* ---------------------------------------------------------------------
* 6. Saving and loading keep the sets of triples and the parameters
* ---------------------------------------------------------------------
tempfile mf
quietly cge_save using "`mf'", replace
quietly cge_use using "`mf'"
cge_solve, name(again)
mata: st_local("s", strofreal(_tx_val("M3", ""), "%21.15g"))
assert abs(`s' - 464) < 1e-9

* ---------------------------------------------------------------------
* 7. Errors
* ---------------------------------------------------------------------
capture noisily cge_variable E1(i,i,k), value(1)
assert _rc == 198
capture noisily cge_variable E2(i,j,), value(1)
assert _rc == 198
capture noisily cge_variable E3 = X(p1, q1)
assert _rc == 198
capture noisily cge_variable E4 = a(p1, q1)
assert _rc == 198
capture noisily cge_set m2(i,j,k) = p1.q1
assert _rc == 198
capture noisily cge_set m3(i,j,k) = p1.q1.x9
assert _rc == 111
capture noisily cge_parameter e(i,j,k), values(p1.q1:2)
assert _rc == 198
capture noisily cge_shock a, elements(p1.q1) value(1)
assert _rc == 198
capture noisily cge_variable E5 = sum((i,j,k), a(i,j))
assert _rc == 198

mata: mata drop _tx_val() _tx_lab()
