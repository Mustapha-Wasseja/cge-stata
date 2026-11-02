* test_build.do -- building user definitions (version 0.47.0;
* docs/model_spec.md, Section 57): the elements kept from one build to the
* next are those a full build compiles, in a model with conditions, sums,
* products, maxima, ord(), card(), macros, an element beyond its set and a
* box pair, built in turn with variables and equations; they are taken when
* the definition and the inputs of the build are as they were, and not after
* a change to the inputs; a dense model whose sums the faster writing out of
* terms takes, against its prices in closed form; no solve and no
* cge_options start Python unless linsolver(python) asks for it.

version 13.0

_cge_load
capture mata: mata drop _tbd_dump()
capture mata: mata drop _tbd_keep()
capture mata: mata drop _tbd_same()
capture mata: mata drop _tbd_poison()
capture mata: mata drop _tbd_has()
capture mata: mata drop _tbd_nkept()
mata:
// The compiled user definitions of the model in memory, and the base
// values and domains, as one string
string scalar _tbd_dump()
{
    struct cge_model scalar M
    M = _cge_load()
    return(invtokens(strofreal(vec(M.utok)', "%21.0g")) + "|" + invtokens(M.uelab') + "|" + invtokens(vec(M.uegams)') +
           "|" + invtokens(strofreal((M.ustart \ M.ulen \ M.ulen2)')) + "|" + invtokens(vec(M.urep)') + "|" +
           invtokens(strofreal(vec(M.ubox)', "%21.0g")) + "|" + invtokens(strofreal(M.x0', "%21.0g")) + "|" +
           invtokens(strofreal(M.exists')))
}
void _tbd_keep()
{
    pointer() scalar q
    if ((q = findexternal("tbd__dump")) == NULL) q = crexternal("tbd__dump")
    *q = _tbd_dump()
}
real scalar _tbd_same()
{
    return(_tbd_dump() == *findexternal("tbd__dump"))
}
// Changes the number in the first row of the kept elements of definition
// name, a number, to v; 1 if there is one
real scalar _tbd_poison(string scalar name, real scalar v)
{
    pointer(struct cge_ubm scalar) scalar q
    struct cge_model scalar M
    struct cge_ube scalar E
    string scalar key
    real scalar k
    M = _cge_load()
    q = findexternal("cge__ubmemo")
    if (q == NULL) return(0)
    k = _cge_find(M.uedef[., 1], name)
    key = _cge_u_ekey(M.uedef[k, .])
    if (!asarray_contains(q->A, key)) return(0)
    E = asarray(q->A, key)
    k = _cge_which(E.tok[., 1] :== 1)[1]
    E.tok[k, 2] = v
    asarray(q->A, key, E)
    return(1)
}
// 1 if the compiled user definitions hold the number v
real scalar _tbd_has(real scalar v)
{
    struct cge_model scalar M
    M = _cge_load()
    return(any((M.utok[., 1] :== 1) :& (M.utok[., 2] :== v)))
}
// The number of definitions whose elements are kept, less the number of
// equations of the model and of the definitions of its variables
real scalar _tbd_nkept()
{
    pointer(struct cge_ubm scalar) scalar q
    struct cge_model scalar M
    M = _cge_load()
    q = findexternal("cge__ubmemo")
    return((q == NULL ? 0 : asarray_elements(q->A)) - sum(M.uedef[., 7] :== "=" :| M.uedef[., 7] :== "box"))
}
end

* each command, with the kept elements removed first when $TBD_FULL is 1,
* so that every build compiles every definition
capture program drop _tbd_do
program define _tbd_do
    if "$TBD_FULL" == "1" capture mata: rmexternal("cge__ubmemo")
    `0'
end

* ---------------------------------------------------------------------
* 1. The kept elements are those a full build compiles
* ---------------------------------------------------------------------
capture program drop _tbd_model
program define _tbd_model
    _tbd_do cge_model new
    _tbd_do cge_set i = a b c d e
    _tbd_do cge_set j = x y z
    _tbd_do cge_set t = t1 t2 t3 t4
    _tbd_do cge_parameter w(i), values(a:1 b:2 c:0 d:4 e:5)
    _tbd_do cge_parameter s(i,j), values(a.x:1 a.y:2 b.x:3 c.z:4 d.y:5 e.z:6 e.x:0.5)
    _tbd_do cge_parameter g(t), values(t1:1 t2:1.1 t3:1.2 t4:1.3)
    _tbd_do cge_macro sq(v) = v * v
    _tbd_do cge_variable PJ(j), value(1)
    _tbd_do cge_variable Q(i), value(2)
    _tbd_do cge_equation EJ(j): PJ(j) = 1 + sq(0.1) * ord(j) / card(j)
    _tbd_do cge_variable TOT = sum(i$(w(i) > 0), w(i) * Q(i))
    _tbd_do cge_equation EQ(i): Q(i) = w(i) + sum(j$(s(i,j) > 0), s(i,j) * PJ(j)) / card(i)
    _tbd_do cge_variable K(t), value(1)
    _tbd_do cge_equation EK(t): K(t) = g(t) * (1 + 0.1 * K(t-1)$(ord(t) > 1))
    _tbd_do cge_variable Z(j) = prod(i$(s(i,j) > 0), PJ(j)^0.1) + smax(i, w(i)) * ord(j)
    _tbd_do cge_variable B, value(0.5) fixed
    _tbd_do cge_equation EB: B - 0.3 = 0, perp(B) lower(0) upper(1)
    _tbd_do cge_variable V(i,j)$(s(i,j) > 0) = s(i,j) * Q(i) * PJ(j)
    _tbd_do cge_variable VT = sum((i,j)$(s(i,j) > 0), V(i,j)) + exp(ln(TOT) / 2)
end
global TBD_FULL 0
quietly _tbd_model
mata: _tbd_keep()
mata: st_numscalar("tbd_n", _tbd_nkept())
assert scalar(tbd_n) == 0
global TBD_FULL 1
quietly _tbd_model
mata: st_numscalar("tbd_same", _tbd_same())
assert scalar(tbd_same) == 1
global TBD_FULL 0
cge_solve, name(full)
assert r(converged) == 1
display as result "test_build 1: kept elements as compiled: ok"

* ---------------------------------------------------------------------
* 2. Kept elements are taken while the definition and the inputs are as
*    they were, and not after a change to the inputs
* ---------------------------------------------------------------------
* a number in the kept elements of EQ changed: a new equation takes them
quietly _tbd_model
mata: st_numscalar("tbd_p", _tbd_poison("EQ", 7777.5))
assert scalar(tbd_p) == 1
quietly cge_equation ER: B = 0.3
mata: st_numscalar("tbd_h", _tbd_has(7777.5))
assert scalar(tbd_h) == 1
* a new variable changes the inputs: every definition compiled again
mata: st_numscalar("tbd_p", _tbd_poison("EQ", 7777.5))
assert scalar(tbd_p) == 1
quietly cge_variable R, value(1)
mata: st_numscalar("tbd_h", _tbd_has(7777.5))
assert scalar(tbd_h) == 0
display as result "test_build 2: kept elements taken while the inputs are as they were: ok"

* ---------------------------------------------------------------------
* 3. A dense model: Cobb-Douglas prices of 30 goods, each from every good
*    and two factors, against their values at the base
* ---------------------------------------------------------------------
cge_model new
local gl
forvalues k = 1/30 {
    local gl `gl' g`k'
}
quietly cge_set g = `gl'
cge_set f = lab cap
cge_parameter a(g,g2) = 0.5 / 30
cge_parameter b(f,g) = 0.25
cge_variable W(f), value(1)
cge_variable P(g), value(1)
cge_equation NUM: W(lab) = 1
cge_equation ZP(g): ln(P(g)) = sum(g2, a(g2,g) * ln(P(g2) / a(g2,g))) + sum(f, b(f,g) * ln(W(f) / b(f,g)))
cge_equation WC: W(cap) = W(lab)
cge_solve, name(dense)
assert r(converged) == 1
* every good has the same price p, with ln p = 0.5 ln p - 0.5 ln(0.5 / 30)
* - 0.5 ln(0.25): p = 240
local lnp = 2 * (-0.5 * ln(0.5 / 30) - 0.5 * ln(0.25))
quietly cge_results, sim(dense) clear nodisplay
quietly keep if variable == "P"
quietly count
assert r(N) == 30
quietly summarize value
assert abs(ln(r(min)) - `lnp') < 1e-9 & abs(ln(r(max)) - `lnp') < 1e-9
display as result "test_build 3: dense model: ok"

* ---------------------------------------------------------------------
* 4. No solve and no cge_options start Python unless linsolver(python)
*    asks for it (before, the first solve of each session in Stata 16 or
*    later imported SciPy)
* ---------------------------------------------------------------------
cge_model new
cge_variable X, value(1)
cge_variable Y, value(1)
cge_equation E: X^2 = 4
cge_equation F: Y = X + 1
capture mata: rmexternal("cge__pyok")
cge_options, linsolver(sparse)
cge_solve, name(nopy)
assert r(converged) == 1
cge_options, reset
cge_solve, name(nopy2)
mata: st_numscalar("tbd_py", findexternal("cge__pyok") == NULL)
assert scalar(tbd_py) == 1
display as result "test_build 4: no Python unless asked: ok"

macro drop TBD_FULL
scalar drop _all
