* test_microsim.do -- link to household survey data (version 0.2.2;
* docs/model_spec.md, Section 11), on a synthetic survey

version 13.0

* Institutions layout: households hhd and npi, an enterprise, transfers
cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)                ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
quietly cge_solve, name(notariff) tolerance(1e-12)
cge_shock, reset
cge_shock CPI, value(2)
quietly cge_solve, name(double) tolerance(1e-12)
cge_shock, reset

* Group results the checks need: consumption ratios and group price indexes
quietly cge_results, sim(notariff) clear nodisplay
foreach h in hhd npi {
    quietly summarize value if variable == "EH" & element1 == "`h'"
    local eh1 = r(mean)
    quietly summarize base if variable == "EH" & element1 == "`h'"
    local ehr_`h' = `eh1' / r(mean)
}
foreach c in com_agr com_man com_ser {
    quietly summarize value if variable == "PQ" & element1 == "`c'"
    local pq_`c' = r(mean)
}
* Base budget shares in the SAM: hhd 70, 80, 70 (of 220); npi buys only com_ser
local p_hhd = (70 * `pq_com_agr' + 80 * `pq_com_man' + 70 * `pq_com_ser') / 220
local p_npi = `pq_com_ser'

* A synthetic survey: 600 households. The last two have exactly their group's
* base income components (hhd: labour 141, capital 27, government 15, abroad
* 10, from domestic institutions 61; npi: government 3, domestic 6) and budget
* shares.
clear
set seed 3
quietly set obs 602
generate str3 group = cond(_n <= 450 | _n == 601, "hhd", "npi")
generate double w = 0.5 + 1.5 * runiform()
generate double size = 1 + floor(6 * runiform())
generate double lab = (group == "hhd") * 120 * runiform()
generate double cap = (group == "hhd") * 40 * runiform()
generate double gov = 20 * runiform()
generate double rem = 15 * runiform()
generate double dom = 30 * runiform()
generate double cons = 0.9 * (lab + cap + gov + rem + dom)
generate double food = cons * (0.2 + 0.3 * runiform())
generate double manu = cons * (0.1 + 0.3 * runiform())
generate double serv = cons - food - manu
quietly replace lab = 141 in 601
quietly replace cap = 27 in 601
quietly replace gov = 15 in 601
quietly replace rem = 10 in 601
quietly replace dom = 61 in 601
quietly replace cons = 220 in 601
quietly replace food = 70 in 601
quietly replace manu = 80 in 601
quietly replace serv = 70 in 601
quietly replace lab = 0 in 602
quietly replace cap = 0 in 602
quietly replace gov = 3 in 602
quietly replace rem = 0 in 602
quietly replace dom = 6 in 602
quietly replace cons = 10 in 602
quietly replace food = 0 in 602
quietly replace manu = 0 in 602
quietly replace serv = 10 in 602
local inc income(lab:lab cap:cap gov:gov rem:row dom:dom)
local bud budget(food:com_agr manu:com_man serv:com_ser)

* 1. Doubling the numeraire changes nothing real
cge_microsim [pweight = w], sim(double) group(group) consumption(cons) size(size) `inc' `bud' ///
    line(10) generate(d) nodisplay
assert abs(d_real / cons - 1) < 1e-10
assert abs(d_price - 2) < 1e-10
assert r(fgt0_sim) == r(fgt0_base) & abs(r(gini_sim) - r(gini_base)) < 1e-12

* 2. A household with its group's base incomes and budget shares follows its
*    group's consumption and price index
cge_microsim [pweight = w], sim(notariff) group(group) consumption(cons) size(size) `inc' `bud' ///
    line(10) generate(n)
matrix T = r(table)
assert abs(n_nom[601] / cons[601] - `ehr_hhd') < 1e-10
assert abs(n_nom[602] / cons[602] - `ehr_npi') < 1e-10
assert abs(n_price[601] - `p_hhd') < 1e-10
assert abs(n_price[602] - `p_npi') < 1e-10

* 3. Poverty and inequality agree with direct computations
generate double pw = w * size
generate double r1 = n_pc
generate double poor = r1 < 10
quietly summarize poor [aweight = pw]
assert abs(r(mean) - T[1, 5]) < 1e-12
generate double gap = poor * (10 - r1) / 10
quietly summarize gap [aweight = pw]
assert abs(r(mean) - T[1, 7]) < 1e-12
generate double sev = gap^2
quietly summarize sev [aweight = pw]
assert abs(r(mean) - T[1, 9]) < 1e-12
sort r1
quietly generate double cw = sum(pw)
quietly replace cw = cw / cw[_N]
quietly generate double ci = sum(pw * r1)
quietly replace ci = ci / ci[_N]
quietly generate double trap = (cw - cond(_n == 1, 0, cw[_n - 1])) * (ci + cond(_n == 1, 0, ci[_n - 1]))
quietly summarize trap
assert abs((1 - r(sum)) - T[1, 11]) < 1e-12
* By group: the hhd row
quietly summarize poor [aweight = pw] if group == "hhd"
assert abs(r(mean) - T[2, 5]) < 1e-12

* 4. Without income components or budget items, households follow their group
cge_microsim, sim(notariff) group(group) consumption(cons) generate(g) nodisplay
assert abs(g_nom / cons - `ehr_hhd') < 1e-10 if group == "hhd"
assert abs(g_nom / cons - `ehr_npi') < 1e-10 if group == "npi"
assert abs(g_price - `p_hhd') < 1e-10 if group == "hhd"

* A numeric group variable with value labels
label define grp 1 "hhd" 2 "npi"
encode group, generate(gnum) label(grp)
cge_microsim, sim(notariff) group(gnum) consumption(cons) generate(g) replace nodisplay
assert abs(g_nom / cons - `ehr_hhd') < 1e-10 if group == "hhd"

* Errors
replace group = "xx" in 1
capture cge_microsim, sim(notariff) group(group) consumption(cons) nodisplay
assert _rc == 111
replace group = "hhd" in 1
capture cge_microsim, sim(notariff) group(group) consumption(cons) income(lab:zz) nodisplay
assert _rc == 198
capture cge_microsim, sim(notariff) group(group) consumption(cons) budget(food:com_zz) nodisplay
assert _rc == 111
capture cge_microsim, sim(notariff) group(group) consumption(cons) generate(g) nodisplay
assert _rc == 110
capture cge_microsim, sim(nosuchsim) group(group) consumption(cons) nodisplay
assert _rc == 111

* A poverty line must be positive (version 0.6.4)
capture noisily cge_microsim, sim(notariff) group(group) consumption(cons) line(0) nodisplay
assert _rc == 198
capture noisily cge_microsim, sim(notariff) group(group) consumption(cons) line(-1) nodisplay
assert _rc == 198
quietly cge_microsim, sim(notariff) group(group) consumption(cons) nodisplay
assert r(fgt0_base) == .

* ---------------------------------------------------------------------
* 5. Version 0.8.0: several simulations, the results as a dataset, several
*    poverty lines, inequality measures and incidence by quantile
* ---------------------------------------------------------------------
generate double z2 = cond(group == "hhd", 12, 8)
generate double r0 = cons / size
local ms [pweight = w], group(group) consumption(cons) size(size) `inc' `bud'
* One simulation, three lines: two numbers and a line by household
cge_microsim `ms' sim(notariff) line(10 20 z2) generate(a) nodisplay
matrix T1 = r(table)
matrix P1 = r(poverty)
matrix I1 = r(inequality)
matrix Q1 = r(quantiles)
matrix G1 = r(gic)
assert r(N_lines) == 3 & "`r(lines)'" == "10 20 z2" & r(N_quantiles) == 10 & r(N_sims) == 1
* the first line gives the table of a single line
cge_microsim `ms' sim(notariff) line(10) nodisplay
assert mreldif(T1, r(table)) < 1e-15
assert rowsof(P1) == 9 & colsof(P1) == 8 & rowsof(I1) == 3 & colsof(I1) == 18
assert rowsof(Q1) == 10 & rowsof(G1) == 99

* Poverty for each line, against direct computations (all households, hhd)
local l = 0
foreach z in 10 20 z2 {
    local ++l
    capture drop zl p1 g1 s1 np1
    generate double zl = `z'
    generate double p1 = a_pc < zl
    generate double g1 = p1 * (zl - a_pc) / zl
    generate double s1 = g1^2
    generate double np1 = pw * p1
    forvalues row = 1/2 {
        local cond ""
        if `row' == 2 local cond if group == "hhd"
        local k = (`l' - 1) * 3 + `row'
        quietly summarize p1 [aweight = pw] `cond'
        assert abs(r(mean) - P1[`k', 2]) < 1e-12
        quietly summarize g1 [aweight = pw] `cond'
        assert abs(r(mean) - P1[`k', 4]) < 1e-12
        quietly summarize s1 [aweight = pw] `cond'
        assert abs(r(mean) - P1[`k', 6]) < 1e-12
        quietly summarize np1 `cond', meanonly
        assert reldif(r(sum), P1[`k', 8]) < 1e-12
    }
}
capture drop zl p1 g1 s1 np1

* Inequality, against direct computations (all households, simulated)
quietly summarize a_pc [aweight = pw]
local mu = r(mean)
generate double t1 = (a_pc / `mu') * ln(a_pc / `mu')
quietly summarize t1 [aweight = pw]
assert reldif(r(mean), I1[1, 4]) < 1e-10
generate double m1 = ln(`mu' / a_pc)
quietly summarize m1 [aweight = pw]
assert reldif(r(mean), I1[1, 6]) < 1e-10
generate double e1 = ((a_pc / `mu')^2 - 1) / 2
quietly summarize e1 [aweight = pw]
assert reldif(r(mean), I1[1, 8]) < 1e-10
generate double h1 = sqrt(a_pc)
quietly summarize h1 [aweight = pw]
assert reldif(1 - r(mean)^2 / `mu', I1[1, 10]) < 1e-10
generate double l1 = ln(a_pc)
quietly summarize l1 [aweight = pw]
assert reldif(1 - exp(r(mean)) / `mu', I1[1, 12]) < 1e-10
generate double v1 = 1 / a_pc
quietly summarize v1 [aweight = pw]
assert reldif(1 - (1 / r(mean)) / `mu', I1[1, 14]) < 1e-10
assert reldif(I1[1, 1], T1[1, 10]) < 1e-15 & reldif(I1[1, 2], T1[1, 11]) < 1e-15
drop t1 m1 e1 h1 l1 v1

* Quantile groups as xtile forms them, and the growth incidence curve at the
* percentiles of _pctile, base and simulated
xtile qq = r0 [aweight = pw], nquantiles(10)
assert qq == a_q
_pctile r0 [aweight = pw], percentiles(1(1)99)
forvalues k = 1/99 {
    assert r(r`k') == G1[`k', 1]
}
_pctile a_pc [aweight = pw], percentiles(1(1)99)
forvalues k = 1/99 {
    assert r(r`k') == G1[`k', 2]
}
assert reldif(G1[50, 3], 100 * (G1[50, 2] / G1[50, 1] - 1)) < 1e-12

* Incidence by quantile, against direct computations
generate double pr0 = pw * r0
generate double pr1 = pw * a_pc
quietly summarize pw, meanonly
local P = r(sum)
quietly summarize pr0, meanonly
local S0 = r(sum)
quietly summarize pr1, meanonly
local S1 = r(sum)
forvalues k = 1/10 {
    quietly summarize pw if a_q == `k', meanonly
    local pk = r(sum)
    quietly summarize pr0 if a_q == `k', meanonly
    local s0 = r(sum)
    quietly summarize pr1 if a_q == `k', meanonly
    local s1 = r(sum)
    assert reldif(Q1[`k', 1], `pk' / `P') < 1e-12
    assert reldif(Q1[`k', 2], `s0' / `pk') < 1e-12
    assert reldif(Q1[`k', 3], `s1' / `pk') < 1e-12
    assert reldif(Q1[`k', 4], 100 * (`s1' / `s0' - 1)) < 1e-9
    assert reldif(Q1[`k', 5], `s0' / `S0') < 1e-12
    assert reldif(Q1[`k', 6], `s1' / `S1') < 1e-12
    assert reldif(Q1[`k', 7], (`s1' - `s0') / (`S1' - `S0')) < 1e-9
}
drop pr0 pr1 qq

* Several simulations in one call: r() holds the first; each simulation's
* variables are numbered
cge_microsim `ms' sim(notariff double) line(10 20 z2) generate(b) nodisplay
assert mreldif(r(table), T1) < 1e-15 & mreldif(r(inequality), I1) < 1e-15
assert r(N_sims) == 2 & "`r(sims)'" == "notariff double"
assert b_pc1 == a_pc & b_price1 == a_price & b_nom1 == a_nom & b_q == a_q
cge_microsim `ms' sim(double) line(10 20 z2) generate(c) nodisplay
matrix T2 = r(table)
matrix P2 = r(poverty)
assert b_pc2 == c_pc & b_real2 == c_real

* The results as a dataset: saving() and clear give the same data, and the
* data hold r() of every simulation
tempfile msres
cge_microsim `ms' sim(notariff double) line(10 20 z2) saving("`msres'") nodisplay
assert mreldif(r(table), T1) < 1e-15
preserve
cge_microsim `ms' sim(notariff double) line(10 20 z2) clear nodisplay
cf _all using "`msres'"
* each simulation: 3 rows (all, hhd, npi) of 1 + 4 x 3 + 9 measures, 10
* quantiles of 4 measures and 99 percentiles
quietly count if sim == "notariff"
assert r(N) == 3 * 22 + 40 + 99
quietly count
assert r(N) == 2 * (3 * 22 + 40 + 99)
quietly summarize base if sim == "notariff" & table == "summary" & group == "all" & measure == "fgt0" & line == "10"
assert r(N) == 1 & r(mean) == T1[1, 4]
quietly summarize value if sim == "double" & table == "summary" & group == "npi" & measure == "gini"
assert r(mean) == T2[3, 11]
quietly summarize value if sim == "double" & table == "summary" & group == "hhd" & measure == "npoor" & line == "z2"
assert r(mean) == P2[8, 8]
quietly summarize value if sim == "notariff" & table == "gic" & q == 50
assert r(mean) == G1[50, 2]
quietly summarize value if sim == "notariff" & table == "quantile" & q == 3 & measure == "inc_abs"
assert r(mean) == Q1[3, 7]
quietly summarize pct if sim == "notariff" & table == "quantile" & q == 3 & measure == "mean"
assert reldif(r(mean), Q1[3, 4]) < 1e-12
quietly summarize change if sim == "notariff" & table == "summary" & group == "all" & measure == "mean"
assert reldif(r(mean), T1[1, 2] - T1[1, 1]) < 1e-12
restore
capture noisily cge_microsim `ms' sim(notariff) saving("`msres'") nodisplay
assert _rc == 602
cge_microsim `ms' sim(notariff) saving("`msres'", replace) nodisplay

* A household whose line is missing is left out
replace z2 = . in 5
cge_microsim `ms' sim(notariff) line(z2) nodisplay
assert r(N) == 601
replace z2 = cond(group == "hhd", 12, 8) in 5

* The tables of detail
cge_microsim `ms' sim(notariff) line(10 z2) quantiles(5) detail
assert rowsof(r(quantiles)) == 5

* Errors
capture noisily cge_microsim `ms' sim(notariff) quantiles(1) nodisplay
assert _rc == 198
capture noisily cge_microsim `ms' sim(notariff) line(nosuch) nodisplay
assert _rc == 198
generate double zbad = 0
capture noisily cge_microsim `ms' sim(notariff) line(zbad) nodisplay
assert _rc == 459
capture noisily cge_microsim `ms' sim(notariff) line(10 10) nodisplay
assert _rc == 198
capture noisily cge_microsim `ms' sim(notariff notariff) nodisplay
assert _rc == 198
capture noisily cge_microsim `ms' sim(notariff nosuch) nodisplay
assert _rc == 111
capture noisily cge_microsim `ms' sim(notariff) generate(e) clear nodisplay
assert _rc == 198
capture noisily cge_microsim `ms' sim(notariff) generate(a) nodisplay
assert _rc == 110

* Palma, S80/S20 and the Gini coefficient for consumption 1 to 5, equal
* weights: the Lorenz curve is linear between households, so the top 10 per
* cent holds half of the richest household's consumption
preserve
clear
quietly set obs 5
generate str3 group = "hhd"
generate double cons = _n
cge_microsim, sim(double) group(group) consumption(cons) nodisplay
matrix I5 = r(inequality)
assert reldif(I5[1, 1], 4 / 15) < 1e-12
assert reldif(I5[1, 15], 2.5 / 3) < 1e-12
assert reldif(I5[1, 17], 5) < 1e-12
* doubling the numeraire changes no measure
forvalues k = 1(2)17 {
    assert reldif(I5[1, `k'], I5[1, `k' + 1]) < 1e-10
}
* the Theil index, by its formula
generate double t = (cons / 3) * ln(cons / 3)
quietly summarize t
assert reldif(I5[1, 3], r(mean)) < 1e-12
* with a household that consumes nothing, the measures that need logarithms
* of consumption are missing
quietly set obs 6
replace group = "hhd" in 6
replace cons = 0 in 6
cge_microsim, sim(double) group(group) consumption(cons) nodisplay
matrix I6 = r(inequality)
assert I6[1, 5] == . & I6[1, 11] == . & I6[1, 13] == .
assert I6[1, 3] < . & I6[1, 9] < . & I6[1, 1] < .
restore
