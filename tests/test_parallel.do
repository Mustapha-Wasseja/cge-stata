* test_parallel.do -- parallel scenario runs (version 0.19.0;
* docs/model_spec.md, Section 28): cge_loop, parallel() gives the
* sequential loop's results; in batch mode on Windows, Stata 16 and later
* start the processes through Python (from version 0.24.0, Section 33) and
* Stata 13 to 15 solve the scenarios in the session; first() numbers the
* scenarios; the helpers that write the processes' files; errors. Runs across
* processes from interactive Stata are checked outside the suite
* (docs/model_spec.md, Section 28).

version 13.0

quietly do setup_synthetic.do
* processes from batch mode on Windows: Stata 16 and later with Python
local pyok 0
if c(stata_version) >= 16 {
    capture python: import subprocess
    if !_rc local pyok 1
}
local inses = "`c(os)'" == "Windows" & "`c(mode)'" == "batch" & !`pyok'

* ---------------------------------------------------------------------
* 1. The same loop, sequential and with parallel(2)
* ---------------------------------------------------------------------
local ev welfare equivalent_variation hhd
cge_loop, name(seq) values(tm(com_man) = 0 0.05 0.1 0.15 0.2) measures(`ev')
matrix ms = r(measures)
assert r(parallel) == 1
cge_loop, name(par) values(tm(com_man) = 0 0.05 0.1 0.15 0.2) measures(`ev') parallel(2)
matrix mp = r(measures)
local np = r(parallel)
if `inses' assert `np' == 1
else assert `np' == 2
assert mreldif(ms, mp) < 1e-10
assert "`r(sims)'" == "par1 par2 par3 par4 par5"
* three processes for five scenarios: groups of one and two
cge_loop, name(p3) values(tm(com_man) = 0 0.05 0.1 0.15 0.2) measures(`ev') parallel(3)
matrix m3 = r(measures)
if `inses' assert r(parallel) == 1
else assert r(parallel) == 3
assert mreldif(ms, m3) < 1e-10
cge_results, sim(p35) nodisplay
assert r(converged) == 1

* ---------------------------------------------------------------------
* 2. first(): the number of the first scenario, for the names of the
*    simulations
* ---------------------------------------------------------------------
cge_loop, name(f) values(tm(com_man) = 0 0.1) first(5)
assert "`r(sims)'" == "f5 f6"
cge_results, sim(f6) nodisplay
assert r(converged) == 1

* ---------------------------------------------------------------------
* 3. The helpers: the Stata executable and an absolute ado-path
* ---------------------------------------------------------------------
mata: st_local("exe", _cge_stata_exe(""))
display as text "Stata executable: " as result "`exe'"
confirm file "`exe'"
mata: st_local("adop", _cge_abs_adopath())
display as text "ado-path for the processes: " as result `"`adop'"'
* every folder is absolute: none begins with ../ or ./
assert strpos(`"`adop'"', `""../"') == 0 & strpos(`"`adop'"', ";../") == 0 & substr(`"`adop'"', 1, 3) != "../"
capture noisily mata: _cge_stata_exe("C:/no/such/stata.exe")
assert _rc == 601

* ---------------------------------------------------------------------
* 4. Errors
* ---------------------------------------------------------------------
capture noisily cge_loop, name(e) values(tm(com_man) = 0 0.1) parallel(0)
assert _rc == 198
capture noisily cge_loop, name(e) values(tm(com_man) = 0 0.1) first(0)
assert _rc == 198
