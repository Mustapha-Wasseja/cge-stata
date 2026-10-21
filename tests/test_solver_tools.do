* test_solver_tools.do -- closure swaps, diagnostics and continuation
* (version 0.4.5; docs/model_spec.md, Section 6; cge_solve)

version 13.0
quietly do helpers_reference.do

* Results of two simulations: the largest relative difference, over every
* variable but the one named
capture program drop _simdiff
program define _simdiff, rclass
    args a b skip
    tempfile ta
    quietly cge_results, sim(`a') clear nodisplay
    quietly rename value va
    quietly save `ta'
    quietly cge_results, sim(`b') clear nodisplay
    quietly merge 1:1 variable element1 element2 using `ta', keepusing(va)
    quietly generate double d = abs(va - value) / max(1, abs(value))
    if "`skip'" != "" quietly replace d = 0 if variable == "`skip'"
    quietly summarize d
    return scalar maxdiff = r(max)
end

* ---------------------------------------------------------------------
* 1. Closure swaps, against the reference
* ---------------------------------------------------------------------
quietly do setup_synthetic.do
cge_closure, swap(GSAV GADJ)
assert r(N_swaps) == 1 & strpos("`r(closure)'", "swap:GSAV=GADJ")
cge_shock tm, value(0)
cge_solve, name(swap_gsav_gadj) tolerance(1e-12)
_compare_reference swap_gsav_gadj
cge_closure, swap(EXR CPI)
cge_solve, name(swap_exr_numeraire) tolerance(1e-12)
_compare_reference swap_exr_numeraire

* Swaps that reproduce closures of the menu: the fixed exchange rate, and
* unemployment at a fixed wage
quietly cge_closure, swap(EXR FSAV)
quietly cge_solve, name(s1) tolerance(1e-12)
quietly cge_closure, external(fixexr) swap(none)
quietly cge_solve, name(m1) tolerance(1e-12)
_simdiff s1 m1
assert r(maxdiff) < 1e-10
quietly cge_closure, external(flexexr)
quietly cge_shock, reset
cge_shock pwm, scale(1.1)
quietly cge_closure, swap(W(lab) QFS(lab))
quietly cge_solve, name(s2) tolerance(1e-12)
quietly cge_closure, factors(lab:unemployed) swap(none)
quietly cge_solve, name(m2) tolerance(1e-12)
_simdiff s2 m2
assert r(maxdiff) < 1e-10
* Government purchases of services fixed 10 per cent higher, with their
* scaling factor free: every purchase rises in proportion
quietly cge_closure, factors(lab:mobile)
quietly cge_shock, reset
quietly cge_closure, swap(QG(com_ser) GADJ)
cge_shock QG, elements(com_ser) scale(1.1)
quietly cge_solve, name(s3) tolerance(1e-12)
quietly cge_results, sim(s3) clear nodisplay
quietly summarize value if variable == "GADJ"
assert abs(r(mean) - 1.1) < 1e-10
quietly cge_closure, swap(none)
quietly cge_shock, reset
cge_shock qg, scale(1.1)
quietly cge_solve, name(m3) tolerance(1e-12)
_simdiff s3 m3 GADJ
assert r(maxdiff) < 1e-10

* Errors: a variable already fixed or not fixed, one computed from its
* definition, an odd list, an unknown variable, and a singular closure
quietly cge_shock, reset
capture noisily cge_closure, swap(FSAV EXR)
assert _rc == 459
capture noisily cge_closure, swap(GSAV EXR)
assert _rc == 459
capture noisily cge_closure, swap(QH(com_agr,hhd) GADJ)
assert _rc == 459
capture noisily cge_closure, swap(GSAV)
assert _rc == 198
capture noisily cge_closure, swap(XYZ GADJ)
assert _rc == 198
capture noisily cge_closure, swap(QG GADJ)
assert _rc == 198
capture noisily cge_closure, swap(QG(com_agr) MPSADJ)
assert _rc == 459
cge_closure
assert r(N_swaps) == 0

* Swaps are saved with the model, recorded with each simulation and kept by
* sensitivity analysis
quietly cge_closure, swap(GSAV GADJ)
tempfile saved
quietly cge_save using "`saved'", replace
quietly cge_use using "`saved'"
cge_closure
assert r(N_swaps) == 1
capture program drop _no_tariffs
program define _no_tariffs
    cge_shock tm, value(0)
end
cge_sensitivity, scenario(_no_tariffs) draws(2) seed(3) tables(macro) nodisplay
assert r(N_converged) == 2
cge_closure
assert r(N_swaps) == 1
program drop _no_tariffs
* The GAMS export fixes and frees the swapped variables
cge_shock tm, value(0)
quietly cge_solve, name(swapped) tolerance(1e-12)
tempfile g
cge_gams using "`g'_swap", sim(swapped) replace
mata: st_numscalar("okg", sum(cat(st_local("g") + "_swap/cge_shock_var.inc") :== "GSAV.fx = GSAV.l;") + ///
    sum(cat(st_local("g") + "_swap/cge_shock_var.inc") :== "GADJ.lo = -inf;"))
assert scalar(okg) == 2
quietly cge_closure, swap(none)
quietly cge_shock, reset

* ---------------------------------------------------------------------
* 2. Continuation
* ---------------------------------------------------------------------
* World import prices one hundred times higher: Newton and Powell's method
* fail from the base, and the shock is applied in steps
cge_shock pwm, scale(100)
capture noisily cge_solve, name(direct) steps(1)
assert _rc == 430
* the diagnostics name the equation with the largest residual
assert "`r(diag_block)'" != "" & r(diag_residual) < .
cge_solve, name(auto) tolerance(1e-12)
assert r(converged) == 1 & r(steps) == 4
cge_solve, name(eight) steps(8) tolerance(1e-12)
assert r(converged) == 1 & r(steps) == 8
_simdiff auto eight
assert r(maxdiff) < 1e-9
* in steps or directly, a solvable shock gives the same solution
quietly cge_shock, reset
cge_shock pwm, scale(3)
quietly cge_solve, name(d3) tolerance(1e-12)
assert r(steps) == 0
quietly cge_solve, name(c3) tolerance(1e-12) steps(5)
assert r(steps) == 5
_simdiff d3 c3
assert r(maxdiff) < 1e-10
capture noisily cge_solve, steps(-1)
assert _rc == 198

* ---------------------------------------------------------------------
* 3. Diagnostics
* ---------------------------------------------------------------------
* Government purchases ten times larger cannot be supplied
quietly cge_shock, reset
cge_shock qg, scale(10)
capture noisily cge_solve, name(toolarge)
assert _rc == 430 & r(converged) == 0
assert "`r(diag_block)'" == "I7" & r(diag_N_empty_rows) == 0
* on request, after a solve that converges
quietly cge_shock, reset
cge_shock tm, value(0)
cge_solve, name(fine) diagnose
assert r(converged) == 1 & r(diag_singular) == 0 & r(diag_pivot_ratio) > 0
