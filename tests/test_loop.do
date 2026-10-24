* test_loop.do -- scenario loops, cge_loop (version 0.9.9). Each scenario is
* checked against the same shocks solved on their own; tools/gams checks the
* loop exported to GAMS, which solves each scenario from the one before

version 13.0
quietly do helpers_reference.do

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

* the largest difference between two simulations, relative to the scales
capture mata: mata drop _tl_diff() _tl_nsim()
mata:
real scalar _tl_diff(string scalar a, string scalar b)
{
    struct cge_model scalar M
    M = _cge_load()
    return(max(abs(M.simx[., _cge_sim_index(M, a)] - M.simx[., _cge_sim_index(M, b)]) :/ M.xscale))
}
// the number of stored simulations
real scalar _tl_nsim()
{
    struct cge_model scalar M
    M = _cge_load()
    return(rows(M.simname))
}
end

* ---------------------------------------------------------------------
* 1. A list of values: each scenario is the shock solved on its own
* ---------------------------------------------------------------------
cge_loop, name(tl) values(tm(com_man) = 0 0.05 0.1 0.2)
assert r(N_scenarios) == 4 & r(N_converged) == 4 & r(N_failed) == 0
assert "`r(sims)'" == "tl1 tl2 tl3 tl4"
matrix V = r(values)
assert V[1, 1] == 0 & V[2, 1] == 0.05 & V[4, 1] == 0.2
local k 0
foreach v in 0 0.05 0.1 0.2 {
    local ++k
    quietly cge_shock, reset
    quietly cge_shock tm, elements(com_man) value(`v')
    quietly cge_solve, name(own`k') tolerance(1e-12)
    mata: st_numscalar("d", _tl_diff("tl`k'", "own`k'"))
    display as text "scenario `k' against its own solve: " as result %9.2e d
    assert d < 1e-9
}
quietly cge_shock, reset
* from the base each time: the same solutions
cge_loop, name(tc) values(tm(com_man) = 0 0.05 0.1 0.2) cold
assert r(N_converged) == 4
forvalues k = 1/4 {
    mata: st_numscalar("d", _tl_diff("tl`k'", "tc`k'"))
    assert d < 1e-9
}

* ---------------------------------------------------------------------
* 2. A grid of two targets, multiples of the values in place, a fixed
*    variable, and the shocks in place kept as the loop's start
* ---------------------------------------------------------------------
cge_loop, name(tg) values(tm(com_man) = 0 0.1; tm(com_agr) = 0 0.05 0.1) grid
assert r(N_scenarios) == 6
matrix V = r(values)
assert V[1, 1] == 0 & V[1, 2] == 0 & V[2, 2] == 0.05 & V[3, 2] == 0.1 & V[4, 1] == 0.1 & V[4, 2] == 0
quietly cge_shock tm, elements(com_man) value(0.1)
quietly cge_shock tm, elements(com_agr) value(0.05)
quietly cge_solve, name(own5) tolerance(1e-12)
mata: st_numscalar("d", _tl_diff("tg5", "own5"))
assert d < 1e-9
quietly cge_shock, reset
* multiples: government purchases of services and the labour supply
cge_loop, name(ts) values(qg(com_ser) = 1 1.1 1.2; QFS(lab) = 1 1 1.05) scale
assert r(N_converged) == 3
quietly cge_results, sim(ts3) clear nodisplay
quietly summarize value if variable == "QG" & element1 == "com_ser"
local qg3 = r(mean)
quietly summarize base if variable == "QG" & element1 == "com_ser"
assert reldif(`qg3', 1.2 * r(mean)) < 1e-12
quietly summarize value if variable == "QFS" & element1 == "lab"
local q3 = r(mean)
quietly summarize base if variable == "QFS" & element1 == "lab"
assert reldif(`q3', 1.05 * r(mean)) < 1e-14
* a shock in place is the start of every scenario, and is kept after the loop
cge_shock tm, elements(com_agr) value(0)
cge_loop, name(tk) values(tm(com_man) = 0 0.2)
quietly cge_shock tm, elements(com_man) value(0.2)
quietly cge_solve, name(own6) tolerance(1e-12)
mata: st_numscalar("d", _tl_diff("tk2", "own6"))
assert d < 1e-9
quietly cge_shock, reset
quietly cge_shock tm, elements(com_agr) value(0)
quietly cge_solve, name(own7) tolerance(1e-12)
cge_loop, name(tk2) values(tm(com_man) = 0)
quietly cge_solve, name(after) tolerance(1e-12)
mata: st_numscalar("d", _tl_diff("own7", "after"))
assert d < 1e-12
quietly cge_shock, reset

* ---------------------------------------------------------------------
* 3. Measures and the dataset of results
* ---------------------------------------------------------------------
cge_loop, name(tm) values(tm(com_man) = 0 0.1 0.3) keep(QM PQ) ///
    measures(YG, welfare equivalent_variation hhd, sum(c, PQ(c) * QG(c))) clear
matrix R = r(measures)
assert rowsof(R) == 3 & colsof(R) == 3
assert _N == 3 * 6
assert reldif(t1, 0.1) < 1e-14 if s == 2
preserve
forvalues k = 1/3 {
    quietly cge_results, sim(tm`k') clear nodisplay
    quietly summarize value if variable == "YG"
    assert reldif(R[`k', 1], r(mean)) < 1e-12
    quietly generate double pq = value if variable == "PQ"
    quietly generate double qg = value if variable == "QG"
    quietly bysort element1 (pq): replace pq = pq[1]
    quietly bysort element1 (qg): replace qg = qg[1]
    quietly egen byte one = tag(element1) if !missing(pq) & !missing(qg)
    quietly generate double sp = pq * qg if one
    quietly summarize sp
    assert reldif(R[`k', 3], r(sum)) < 1e-12
    quietly cge_report, sims(tm`k') tables(welfare) clear nodisplay
    quietly summarize value if measure == "equivalent_variation" & element == "hhd"
    assert reldif(R[`k', 2], r(mean)) < 1e-10
}
restore
* the values in the dataset are those of the simulations
tempfile lp res
quietly save `lp'
quietly cge_results, sim(tm3) clear nodisplay
quietly keep if inlist(variable, "QM", "PQ")
rename value v_res
quietly save `res'
use `lp', clear
quietly keep if s == 3
quietly merge 1:1 variable element1 element2 using `res'
assert _merge == 3 & _N == 6
assert value == v_res
* without storing: no simulations are added
mata: st_numscalar("ns0", _tl_nsim())
cge_loop, name(tn) values(tm(com_man) = 0 0.1) nostore measures(YG)
mata: st_numscalar("ns1", _tl_nsim())
assert scalar(ns0) == scalar(ns1)
assert "`r(sims)'" == ""

* ---------------------------------------------------------------------
* 4. Scenarios from a dataset: one observation per scenario and target; a
*    target that a scenario leaves out keeps its value in place
* ---------------------------------------------------------------------
preserve
clear
quietly input str10 scenario str14 target double value
"low"   "tm(com_man)"  0
"low"   "qg(com_ser)"  1.1
"mid"   "tm(com_man)"  0.5
"high"  "qg(com_ser)"  0.9
end
tempfile sc
quietly save `sc'
restore
* multiples of the values in place
cge_loop using `sc', name(td) scale
assert r(N_scenarios) == 3
matrix V = r(values)
assert V[1, 1] == 0 & reldif(V[2, 1], 0.05) < 1e-15 & reldif(V[3, 2], 0.9 * V[2, 2]) < 1e-15
quietly cge_shock, reset
quietly cge_shock tm, elements(com_man) value(0)
quietly cge_shock qg, elements(com_ser) scale(1.1)
quietly cge_solve, name(own8) tolerance(1e-12)
mata: st_numscalar("d", _tl_diff("td1", "own8"))
assert d < 1e-9
quietly cge_shock, reset
quietly cge_shock tm, elements(com_man) value(0.05)
quietly cge_solve, name(own9) tolerance(1e-12)
mata: st_numscalar("d", _tl_diff("td2", "own9"))
assert d < 1e-9
quietly cge_shock, reset
quietly cge_shock qg, elements(com_ser) scale(0.9)
quietly cge_solve, name(own10) tolerance(1e-12)
mata: st_numscalar("d", _tl_diff("td3", "own10"))
assert d < 1e-9
quietly cge_shock, reset
* the dataset of scenarios is left in memory as it was
quietly sysuse auto, clear
cge_loop using `sc', name(td2) nostore
assert _N == 74

* ---------------------------------------------------------------------
* 5. A scenario that does not solve: recorded, and the loop goes on
* ---------------------------------------------------------------------
cge_bound QM(com_man), upper(61)
cge_loop, name(tf) values(tm(com_man) = 0.2 0 0.15)
assert r(N_converged) == 2 & r(N_failed) == 1
matrix C = r(converged)
assert C[1, 1] == 1 & C[2, 1] == 0 & C[3, 1] == 1
cge_bound, clear

* ---------------------------------------------------------------------
* 6. The GAMS program of a loop: each scenario's changes from the one
*    before, solved in order
* ---------------------------------------------------------------------
tempfile gd
cge_gams using "`gd'_l", loop(tl) replace
assert r(N_periods) == 4
mata:
d = cat(st_local("gd") + "_l/cge_run.gms")
p2 = cat(st_local("gd") + "_l/cge_tl2_par.inc")
st_numscalar("okl", (sum(d :== char(36) + "include cge_tl2_par.inc") == 1) +
             (sum(d :== char(36) + "include cge_bounds.inc") == 4) +
             (sum(strpos(p2, "tm('com_man')") :> 0) == 1) + (sum(strpos(d, "loop tl") :> 0) >= 1))
end
assert scalar(okl) == 4
capture noisily cge_gams using "`gd'_l", loop(tf) replace
assert _rc == 459
capture noisily cge_gams using "`gd'_l", loop(nosuch) replace
assert _rc == 111

* ---------------------------------------------------------------------
* 7. Errors
* ---------------------------------------------------------------------
capture noisily cge_loop, name(e1) values(tm(com_man) 0 0.1)
assert _rc == 198
capture noisily cge_loop, name(e1) values(tm(com_man) = 0 0.1; tm(com_agr) = 0 0.1 0.2)
assert _rc == 198
capture noisily cge_loop, name(e1) values(QA(act_man) = 100 110)
assert _rc == 459
capture noisily cge_loop, name(e1) values(xx(com_man) = 1)
assert _rc == 198
capture noisily cge_loop, name(e1) values(tm(com_man) = 0; tm(com_man) = 0.1)
assert _rc == 198
capture noisily cge_loop, name(e1) values(tm(com_man) = a b)
assert _rc == 198
capture noisily cge_loop, name(e1)
assert _rc == 198
capture noisily cge_loop using `sc', name(e1) values(tm(com_man) = 0)
assert _rc == 198
capture noisily cge_loop, name(e1) values(tm(com_man) = 0) keep(QXX)
assert _rc == 198
capture noisily cge_loop, name(e1) values(tm(com_man) = 0) measures(macro nothing)
assert _rc == 111
preserve
clear
quietly input str5 scenario double value
"a" 1
end
tempfile bad
quietly save `bad'
restore
capture noisily cge_loop using `bad', name(e1)
assert _rc == 111
quietly cge_shock, reset
mata: mata drop _tl_diff() _tl_nsim()
