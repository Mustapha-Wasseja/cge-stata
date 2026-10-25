* test_parallel.do -- parallel scenario runs (version 0.19.0;
* docs/model_spec.md, Section 28): cge_loop, parallel() gives the
* sequential loop's results; in batch mode on Windows, where Stata cannot
* start other processes, it solves the scenarios in the session; first()
* numbers the scenarios; the helpers that write the processes' files;
* errors. Runs across processes are checked outside batch mode
* (docs/model_spec.md, Section 28).

version 13.0

quietly do setup_synthetic.do

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
if "`c(os)'" == "Windows" & "`c(mode)'" == "batch" assert `np' == 1
else assert `np' == 2
assert mreldif(ms, mp) < 1e-10
assert "`r(sims)'" == "par1 par2 par3 par4 par5"

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
