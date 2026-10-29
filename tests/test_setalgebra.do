* test_setalgebra.do -- set algebra (version 0.29.0; docs/model_spec.md,
* Section 39): unions, intersections, differences and complements of sets,
* yes and no, conditions on the elements and domains, subsets of subsets,
* sets of pairs and tuples from conditions, each against the elements
* worked out by hand or by enumeration; the sets in variables, equations and
* sums; sets from the base of a SAM-based model; saving and loading; models
* saved before the domains; Stata's own loops around the commands; errors.

version 13.0

capture mata: mata drop _tsa_dom()
capture mata: mata drop _tsa_val()
capture mata: mata drop _tsa_base()
capture mata: mata drop _tsa_tm()
capture mata: mata drop _tsa_narrow()
capture mata: mata drop _tsa_cols()
_cge_load
mata:
// The domain recorded for user set name: its set code, "" without one
string scalar _tsa_dom(string scalar name)
{
    struct cge_model scalar M
    real scalar k
    M = _cge_load()
    k = _cge_us_find(M, name)
    if (cols(M.usdef) < 4) return("")
    return(M.usdef[k, 4])
}

// The value of element el of variable v in the last simulation
real scalar _tsa_val(string scalar v, string scalar el)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.simx[_cge_u_vpos(M, v, el), rows(M.simname)])
}

// The base value of element el of variable v
real scalar _tsa_base(string scalar v, string scalar el)
{
    struct cge_model scalar M
    M = _cge_load()
    return(M.x0[_cge_u_vpos(M, v, el)])
}

// The commodities with a positive tariff at the base
string scalar _tsa_tm()
{
    struct cge_model scalar M
    string scalar s
    real scalar j
    M = _cge_load()
    s = ""
    for (j = 1; j <= rows(M.C); j++) if (M.p0.tm[j] > 0) s = s + (s == "" ? "" : " ") + M.C[j]
    return(s)
}

// The user sets as a model saved before version 0.29.0 holds them: three
// columns
void _tsa_narrow()
{
    struct cge_model scalar M
    M = _cge_load()
    M.usdef = M.usdef[., 1..3]
    _cge_store(M)
}

real scalar _tsa_cols()
{
    struct cge_model scalar M
    M = _cge_load()
    return(cols(M.usdef))
}
end

* ---------------------------------------------------------------------
* 1. Operations on subsets of a domain, against the elements by hand:
*    p = 4 1 6 2 9 3 on a1 ... a6
* ---------------------------------------------------------------------
cge_model new
cge_set i = a1 a2 a3 a4 a5 a6
cge_parameter p(i), values(a1:4 a2:1 a3:6 a4:2 a5:9 a6:3)
cge_set big(i) = yes$(p(i) > 2.5)
assert "`r(elements)'" == "a1 a3 a5 a6" & r(N_elements) == 4 & "`r(domain)'" == "i"
* a list keeps the order given; operations keep the order of the left
cge_set odd(i) = a5 a1 a3
assert "`r(elements)'" == "a5 a1 a3"
cge_set u(i) = big + odd
assert "`r(elements)'" == "a1 a3 a5 a6"
cge_set u2(i) = odd + big
assert "`r(elements)'" == "a5 a1 a3 a6"
cge_set n(i) = big * odd
assert "`r(elements)'" == "a1 a3 a5"
cge_set d(i) = big - odd
assert "`r(elements)'" == "a6"
cge_set cmp(i) = not odd
assert "`r(elements)'" == "a2 a4 a6"
* the symmetric difference; * binds before + and -
cge_set e(i) = (big + odd) - big * odd
assert "`r(elements)'" == "a6"
cge_set v1(i) = a1 + a2 * a3
assert "`r(elements)'" == "a1"
cge_set v2(i) = (a1 + a2) * (a2 + a3)
assert "`r(elements)'" == "a2"
* not applies to the factor after it
cge_set v3(i) = not a1 * not a2
assert "`r(elements)'" == "a3 a4 a5 a6"
cge_set v4(i) = not (big + odd)
assert "`r(elements)'" == "a2 a4"
* elements side by side are a union
cge_set j(i) = a4 a2 big
assert "`r(elements)'" == "a4 a2 a1 a3 a5 a6"
cge_set h(i) = no + a2
assert "`r(elements)'" == "a2"
* conditions: on the name, after elements, one after another, membership
cge_set f(i)$(p(i) < 5) = yes
assert "`r(elements)'" == "a1 a2 a4 a6"
cge_set g(i) = odd$(ord(i) > 1)
assert "`r(elements)'" == "a5 a3"
cge_set v5(i) = yes$(p(i) > 2)$(p(i) < 7)
assert "`r(elements)'" == "a1 a3 a6"
cge_set v6(i) = yes$(odd(i))
assert "`r(elements)'" == "a1 a3 a5"
cge_set v7(i) = yes$(!odd(i) & p(i) > 1.5)
assert "`r(elements)'" == "a4 a6"
cge_set v8(i) = (yes - big)$(p(i) >= 2)
assert "`r(elements)'" == "a4"
* except() takes a set expression too
cge_set v9(i) = yes, except(a1 big)
assert "`r(elements)'" == "a2 a4"
* card() of a set from a condition
cge_parameter nbig = card(big)
cge_parameter sbig = sum(big, p(big))
cge_variable CK = nbig + sbig
cge_solve, name(card)
mata: st_local("v", strofreal(_tsa_val("CK", ""), "%21.15g"))
assert abs(`v' - (4 + 22)) < 1e-12

* ---------------------------------------------------------------------
* 2. Subsets of subsets, sets from variables, and sets without a domain
* ---------------------------------------------------------------------
cge_set sub(big) = a6 a3
assert "`r(elements)'" == "a6 a3" & "`r(domain)'" == "big"
mata: st_local("dm", _tsa_dom("sub"))
assert "`dm'" == "~big"
mata: st_local("dm", _tsa_dom("big"))
assert "`dm'" == "~i"
mata: st_local("dm", _tsa_dom("i"))
assert "`dm'" == ""
cge_set sub2(sub) = not a3
assert "`r(elements)'" == "a6"
preserve
clear
input str4 lab
"a5"
"a3"
"a5"
end
cge_set fr(big), from(lab)
assert "`r(elements)'" == "a5 a3"
replace lab = "a2" in 1
capture noisily cge_set fr2(big), from(lab)
assert _rc == 111
restore
* without a domain, the operations on sets of the model and their labels
cge_set w = odd + big
assert "`r(elements)'" == "a5 a1 a3 a6" & "`r(domain)'" == ""
cge_set w2 = odd * big a2
assert "`r(elements)'" == "a5 a1 a3 a2"
cge_set w3 = big - odd
assert "`r(elements)'" == "a6"
* new labels of a standalone model are written out
cge_set z = z1 z3 z2
assert "`r(elements)'" == "z1 z3 z2"
cge_set z4 = z + i - big
assert "`r(elements)'" == "z1 z3 z2 a2 a4"
cge_set, list
assert r(N_sets) == 30

* ---------------------------------------------------------------------
* 3. Sets of pairs and triples from conditions, against enumeration
* ---------------------------------------------------------------------
cge_set k = b1 b2 b3
cge_parameter q(i,k) = ord(i) * ord(k)
cge_set m(i,k) = yes$(q(i,k) > 6)
local want
forvalues a = 1/6 {
    forvalues b = 1/3 {
        if `a' * `b' > 6 local want `want' a`a'.b`b'
    }
}
assert "`r(elements)'" == "`want'" & "`r(domain)'" == "i,k"
local nm = r(N_elements)
assert `nm' == 7
cge_set m2(i,k) = m - a6.b3
assert r(N_elements) == `nm' - 1 & strpos(" `r(elements)' ", " a6.b3 ") == 0
cge_set m3(i,k) = not m
assert r(N_elements) == 18 - `nm'
assert strpos(" `r(elements)' ", " a1.b1 ") > 0 & strpos(" `r(elements)' ", " a6.b3 ") == 0
cge_set m4(i,k)$(ord(i) == ord(k)) = yes
assert "`r(elements)'" == "a1.b1 a2.b2 a3.b3"
cge_set m5(i,k) = m * m4
assert "`r(elements)'" == "a3.b3"
cge_set m6(i,k) = m4 + m
assert r(N_elements) == `nm' + 2
* membership of single sets in the condition of a set of pairs
cge_set m7(i,k) = yes$(big(i) & odd(i) & ord(k) < 3)
assert "`r(elements)'" == "a1.b1 a1.b2 a3.b1 a3.b2 a5.b1 a5.b2"
* a set of pairs written out keeps the form of version 0.9.1
cge_set m8(i,k) = a2.b1 a1.b1
assert "`r(elements)'" == "a2.b1 a1.b1"
mata: st_local("dm", _tsa_dom("m8"))
assert "`dm'" == ""
cge_set l = c1 c2
cge_set t3(i,k,l) = yes$(ord(i) + ord(k) + ord(l) == 5)
local want
local nt 0
forvalues a = 1/6 {
    forvalues b = 1/3 {
        forvalues c = 1/2 {
            if `a' + `b' + `c' == 5 {
                local want `want' a`a'.b`b'.c`c'
                local ++nt
            }
        }
    }
}
assert "`r(elements)'" == "`want'" & r(N_elements) == `nt'
cge_set t4(i,k,l) = not t3 - a1.b1.c1
assert r(N_elements) == 36 - `nt' - 1

* ---------------------------------------------------------------------
* 4. The sets in variables, equations and sums of a standalone model:
*    X(big)^2 = p(big); S = sum over m of q = sum over the condition
* ---------------------------------------------------------------------
cge_variable X(big), value(1)
cge_equation EX(big): X(big)^2 = p(big)
cge_variable S1 = sum(m(i,k), q(i,k))
cge_variable S2 = sum((i,k)$(q(i,k) > 6), q(i,k))
cge_variable T3 = sum(t3(i,k,l), ord(l))
cge_variable XS = sum(sub, X(sub))
cge_solve, name(sets)
assert r(converged) == 1
mata: st_local("x", strofreal(_tsa_val("X", "a5"), "%21.15g"))
assert abs(`x' - 3) < 1e-10
mata: st_local("s1", strofreal(_tsa_val("S1", ""), "%21.15g"))
mata: st_local("s2", strofreal(_tsa_val("S2", ""), "%21.15g"))
local want 0
forvalues a = 1/6 {
    forvalues b = 1/3 {
        if `a' * `b' > 6 local want = `want' + `a' * `b'
    }
}
assert abs(`s1' - `want') < 1e-10 & abs(`s2' - `want') < 1e-10
local want 0
forvalues a = 1/6 {
    forvalues b = 1/3 {
        forvalues c = 1/2 {
            if `a' + `b' + `c' == 5 local want = `want' + `c'
        }
    }
}
mata: st_local("t", strofreal(_tsa_val("T3", ""), "%21.15g"))
assert abs(`t' - `want') < 1e-10
mata: st_local("xs", strofreal(_tsa_val("XS", ""), "%21.15g"))
assert abs(`xs' - (sqrt(3) + sqrt(6))) < 1e-10

* ---------------------------------------------------------------------
* 5. Saving and loading; a model saved before the domains
* ---------------------------------------------------------------------
tempfile f
quietly cge_save using "`f'", replace
quietly cge_use using "`f'"
mata: st_local("dm", _tsa_dom("sub"))
assert "`dm'" == "~big"
cge_set, list
assert r(N_sets) == 42
mata: _tsa_narrow()
mata: st_local("nc", strofreal(_tsa_cols()))
assert `nc' == 3
cge_set, list
cge_set late(big) = a1
mata: st_local("nc", strofreal(_tsa_cols()))
assert `nc' == 4
mata: st_local("dm", _tsa_dom("late"))
assert "`dm'" == "~big"

* ---------------------------------------------------------------------
* 6. Stata's own loops and conditions around the commands, as GAMS's
*    loop, if and while over assignments
* ---------------------------------------------------------------------
local nsets 0
foreach lim in 2 5 8 {
    cge_set over`lim'(i) = yes$(p(i) > `lim')
    if r(N_elements) >= 2 local ++nsets
}
assert `nsets' == 2
local lim 0
local n 6
while `n' > 3 {
    local ++lim
    cge_set top`lim'(i) = yes$(p(i) > `lim')
    local n = r(N_elements)
}
assert `lim' == 3 & `n' == 3

* ---------------------------------------------------------------------
* 7. Errors
* ---------------------------------------------------------------------
* outside the domain
capture noisily cge_set bad(big) = a2
assert _rc == 111
capture noisily cge_set bad(big) = i
assert _rc == 111
capture noisily cge_set bad(i,k) = a1.b9
assert _rc == 111
* not, yes and conditions need a domain
capture noisily cge_set bad = not odd
assert _rc == 198
capture noisily cge_set bad = yes
assert _rc == 198
capture noisily cge_set bad = odd$(ord(i) > 1)
assert _rc == 198
* a new label in an expression, a word of set expressions as a name
capture noisily cge_set bad = z9 + z1
assert _rc == 198
capture noisily cge_set no = a1
assert _rc == 198
* the form of the expression; a condition in parentheses
capture noisily cge_set bad(i) = (big + odd
assert _rc == 198
capture noisily cge_set bad(i) = big +
assert _rc == 198
capture noisily cge_set bad(i) = big $ p(i) > 1
assert _rc != 0
capture noisily cge_set bad(i) = $(p(i) > 1)
assert _rc == 198
capture noisily cge_set bad(i) = big / odd
assert _rc == 198
capture noisily cge_set bad(i) = yes$(p(i) > 100)
assert _rc == 198
* single sets in a set of pairs and the other way round
capture noisily cge_set bad(i,k) = odd
assert _rc == 198
capture noisily cge_set bad(i,k) = a1
assert _rc == 198
capture noisily cge_set bad(i,k) = t3
assert _rc == 198
capture noisily cge_set bad(i) = m
assert _rc == 198
capture noisily cge_set bad(i,k) = m, except(a1.b1)
assert _rc == 198
* the index of the domain
capture noisily cge_set bad(m) = yes
assert _rc == 198
capture noisily cge_set bad(nosuch) = yes
assert _rc == 198

* ---------------------------------------------------------------------
* 8. A SAM-based model: sets from tariffs and from the base, used in a
*    defined variable, against the model's own values
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                  ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
mata: st_local("want", _tsa_tm())
cge_set imp(c) = yes$(tm(c) > 0)
assert "`r(elements)'" == "`want'"
mata: st_local("dm", _tsa_dom("imp"))
assert "`dm'" == "C"
cge_set rest(c) = not imp + com_agr
local qmean 0
foreach f in lab cap {
    foreach a in act_agr act_man act_ser {
        mata: st_local("v", strofreal(_tsa_base("QF", "`f'.`a'"), "%21.15g"))
        local qmean = `qmean' + `v' / 6
    }
}
local want
foreach f in lab cap {
    foreach a in act_agr act_man act_ser {
        mata: st_local("v", strofreal(_tsa_base("QF", "`f'.`a'"), "%21.15g"))
        if `v' > `qmean' local want `want' `f'.`a'
    }
}
cge_set large(f,a) = yes$(QF(f,a) > `qmean')
assert "`r(elements)'" == strtrim("`want'")
cge_variable QLARGE = sum(large(f,a), QF(f,a))
cge_shock tm, value(0)
cge_solve, name(sam_sets) tolerance(1e-12)
assert r(converged) == 1
cge_set, list
local total 0
foreach f in lab cap {
    foreach a in act_agr act_man act_ser {
        mata: st_local("v", strofreal(_tsa_base("QF", "`f'.`a'"), "%21.15g"))
        if `v' > `qmean' {
            mata: st_local("x", strofreal(_tsa_val("QF", "`f'.`a'"), "%21.15g"))
            local total = `total' + `x'
        }
    }
}
mata: st_local("ql", strofreal(_tsa_val("QLARGE", ""), "%21.15g"))
display as text "sum over a set from the base, against its elements: " as result %9.2e abs(`ql' - `total')
assert abs(`ql' - `total') < 1e-9 * max(1, abs(`total'))
cge_equation, clear
cge_set, clear
