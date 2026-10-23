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
* each simulation: 3 rows (all, hhd, npi) of 1 + 2 + 4 x 3 + 9 measures
* (with EV and CV from version 0.8.1), 10 quantiles of 5 measures and 99
* percentiles
quietly count if sim == "notariff"
assert r(N) == 3 * 24 + 50 + 99
quietly count
assert r(N) == 2 * (3 * 24 + 50 + 99)
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

* ---------------------------------------------------------------------
* 6. Version 0.8.1: equivalent and compensating variations by household,
*    and the decomposition of the changes by channel
* ---------------------------------------------------------------------
* The groups' welfare changes, per cent of base consumption (cge_report)
preserve
quietly cge_report, sims(notariff) tables(welfare) clear nodisplay
foreach h in hhd npi {
    quietly summarize pct if measure == "equivalent_variation" & element == "`h'"
    local evp_`h' = r(mean)
    quietly summarize pct if measure == "compensating_variation" & element == "`h'"
    local cvp_`h' = r(mean)
}
restore
* Households that follow their group, without income components or budget
* items, have their group's welfare change in proportion to their consumption
cge_microsim [pweight = w], sim(notariff) group(group) consumption(cons) size(size) generate(f) nodisplay
matrix W = r(welfare)
local row = 1
foreach h in hhd npi {
    local ++row
    generate double evr = 100 * f_ev / cons if group == "`h'"
    generate double cvr = 100 * f_cv / cons if group == "`h'"
    quietly summarize evr
    assert abs(r(min) - `evp_`h'') < 1e-9 & abs(r(max) - `evp_`h'') < 1e-9
    quietly summarize cvr
    assert abs(r(min) - `cvp_`h'') < 1e-9 & abs(r(max) - `cvp_`h'') < 1e-9
    assert abs(W[`row', 2] - `evp_`h'') < 1e-9 & abs(W[`row', 4] - `cvp_`h'') < 1e-9
    drop evr cvr
}
* r(welfare): EV per person over persons
generate double wev = w * f_ev
quietly summarize wev, meanonly
local sev = r(sum)
quietly summarize pw, meanonly
assert reldif(W[1, 1], `sev' / r(sum)) < 1e-12
drop wev

* With budget items, Cobb-Douglas in the household's own budget shares, at
* the prices households pay (PQ: there is no VAT in this SAM)
preserve
quietly cge_results, sim(notariff) clear nodisplay
foreach c in com_agr com_man com_ser {
    quietly summarize value if variable == "PQ" & element1 == "`c'"
    local pq1 = r(mean)
    quietly summarize base if variable == "PQ" & element1 == "`c'"
    local lp_`c' = ln(`pq1' / r(mean))
}
restore
cge_microsim `ms' sim(notariff) generate(cd) nodisplay
generate double G = exp((food * `lp_com_agr' + manu * `lp_com_man' + serv * `lp_com_ser') / (food + manu + serv))
assert abs(cd_ev - (cd_nom / G - cons)) < 1e-9 * cons
assert abs(cd_cv - (cd_nom - cons * G)) < 1e-9 * cons
assert abs(cd_cv - G * cd_ev) < 1e-9 * cons
* the exact measure is at least the first-order one (G is at most the
* Laspeyres index)
assert cd_ev >= cd_real - cons - 1e-9 * cons
drop G
* Doubling the numeraire changes no household's welfare
cge_microsim `ms' sim(double) generate(dd) nodisplay
assert abs(dd_ev) < 1e-9 * cons & abs(dd_cv) < 1e-9 * cons
* EV by quantile: per person, and per cent of base consumption
cge_microsim `ms' sim(notariff) nodisplay
matrix Q2 = r(quantiles)
matrix W2 = r(welfare)
generate double wev = w * cd_ev
generate double wc0 = w * cons
quietly summarize wev if a_q == 1, meanonly
local s1 = r(sum)
quietly summarize pw if a_q == 1, meanonly
assert reldif(Q2[1, 8], `s1' / r(sum)) < 1e-12
quietly summarize wc0 if a_q == 1, meanonly
assert reldif(Q2[1, 9], 100 * `s1' / r(sum)) < 1e-12
drop wev wc0

* The Shapley decomposition: the contributions of the channels add up to the
* change in every measure
cge_microsim `ms' sim(notariff) line(10 z2) decompose nodisplay
matrix SH = r(shapley)
matrix GR = r(growthred)
assert "`r(channels)'" == "lab cap gov row dom taxsav prices"
assert rowsof(SH) == 1 + 2 * 4 + 9 & colsof(SH) == 9
mata: S_ = st_matrix("SH"); st_numscalar("dmax", max(abs(rowsum(S_[., 1..(cols(S_) - 1)]) - S_[., cols(S_)]) :/ (1 :+ abs(S_[., cols(S_)]))))
assert dmax < 1e-12
* base and simulated values are those of the summary
matrix I3 = r(inequality)
matrix P3 = r(poverty)
matrix T3 = r(table)
assert reldif(SH[1, 1], T3[1, 1]) < 1e-15 & reldif(SH[1, 9], T3[1, 2]) < 1e-15
assert reldif(SH[2, 9], P3[1, 2]) < 1e-15 & reldif(SH[10, 9], I3[1, 2]) < 1e-15
* growth and redistribution add up to the change in poverty
mata: G_ = st_matrix("GR"); st_numscalar("dmax", max(abs(G_[., 1] + G_[., 2] + G_[., 3] - G_[., 4])))
assert dmax < 1e-12
* the growth component, by its formula: the distribution scaled to the new mean
quietly summarize r0 [aweight = pw]
local mu0 = r(mean)
quietly summarize a_pc [aweight = pw]
local mu1 = r(mean)
generate double h00 = r0 < 10
generate double h11 = a_pc < 10
generate double h10 = r0 * `mu1' / `mu0' < 10
generate double h01 = a_pc * `mu0' / `mu1' < 10
foreach v in h00 h11 h10 h01 {
    quietly summarize `v' [aweight = pw]
    local `v' = r(mean)
}
assert abs(GR[1, 2] - ((`h10' - `h00') + (`h11' - `h01')) / 2) < 1e-12
assert abs(GR[1, 3] - ((`h01' - `h00') + (`h11' - `h10')) / 2) < 1e-12
drop h00 h11 h10 h01
* A channel that changes nothing contributes nothing: income indexed to the
* CPI, the numeraire
generate double misc = 5
cge_microsim [pweight = w], group(group) consumption(cons) size(size) `bud' sim(notariff) line(10) ///
    income(lab:lab cap:cap gov:gov rem:row dom:dom misc:cpi) decompose nodisplay
assert "`r(channels)'" == "lab cap gov row dom cpi taxsav prices"
matrix SC = r(shapley)
mata: S_ = st_matrix("SC"); st_numscalar("dmax", max(abs(S_[., 7])))
assert dmax < 1e-12
drop misc

* Two channels, by the formula: the mean, the headcount and the poverty gap
cge_microsim [pweight = w], sim(notariff) group(group) consumption(cons) size(size) line(10) ///
    generate(t2) decompose nodisplay
assert "`r(channels)'" == "income prices"
matrix S2 = r(shapley)
generate double ri = r0 * t2_nom / cons
generate double rp = r0 / t2_price
local k = 0
foreach v in r0 ri rp t2_pc {
    local ++k
    quietly summarize `v' [aweight = pw]
    local m`k' = r(mean)
    capture drop pp gg
    generate double pp = `v' < 10
    generate double gg = pp * (10 - `v') / 10
    quietly summarize pp [aweight = pw]
    local h`k' = r(mean)
    quietly summarize gg [aweight = pw]
    local g`k' = r(mean)
}
assert reldif(S2[1, 2], ((`m2' - `m1') + (`m4' - `m3')) / 2) < 1e-10
assert reldif(S2[1, 3], ((`m3' - `m1') + (`m4' - `m2')) / 2) < 1e-10
assert abs(S2[2, 2] - ((`h2' - `h1') + (`h4' - `h3')) / 2) < 1e-12
assert abs(S2[3, 3] - ((`g3' - `g1') + (`g4' - `g2')) / 2) < 1e-12
drop ri rp pp gg

* In the results dataset: the rows of shapley and growthred
preserve
cge_microsim `ms' sim(notariff) line(10 z2) decompose clear nodisplay
quietly count if table == "shapley"
assert r(N) == 7 * 18
quietly count if table == "growthred"
assert r(N) == 2 * 8
quietly summarize change if table == "shapley" & measure == "gini", meanonly
assert reldif(r(sum), SH[10, 9] - SH[10, 1]) < 1e-10
quietly summarize value if table == "summary" & group == "all" & measure == "ev"
assert reldif(r(mean), W2[1, 1]) < 1e-12
restore

* The tables of detail and decompose
cge_microsim `ms' sim(notariff) line(10) detail decompose

* Households that follow their group under LES demand: their welfare change
* is their group's, in proportion to consumption
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1 1.4) frisch(-2)
cge_shock tm, value(0)
quietly cge_solve, name(les) tolerance(1e-12)
cge_shock, reset
preserve
quietly cge_report, sims(les) tables(welfare) clear nodisplay
foreach h in hhd npi {
    quietly summarize pct if measure == "equivalent_variation" & element == "`h'"
    local evp_`h' = r(mean)
    quietly summarize pct if measure == "compensating_variation" & element == "`h'"
    local cvp_`h' = r(mean)
}
restore
cge_microsim [pweight = w], sim(les) group(group) consumption(cons) size(size) generate(ls) nodisplay
foreach h in hhd npi {
    generate double evr = 100 * ls_ev / cons if group == "`h'"
    generate double cvr = 100 * ls_cv / cons if group == "`h'"
    quietly summarize evr
    assert abs(r(min) - `evp_`h'') < 1e-9 & abs(r(max) - `evp_`h'') < 1e-9
    quietly summarize cvr
    assert abs(r(min) - `cvp_`h'') < 1e-9 & abs(r(max) - `cvp_`h'') < 1e-9
    drop evr cvr
}

* ---------------------------------------------------------------------
* 7. Version 0.8.2: fiscal incidence (CEQ income concepts, concentration,
*    Kakwani, Reynolds-Smolensky, coverage, marginal contributions) and
*    in-kind health benefits
* ---------------------------------------------------------------------
* The model is calibrated again with Cobb-Douglas demand
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
quietly cge_solve, name(notariff) tolerance(1e-12)
cge_shock, reset
cge_shock CPI, value(2)
quietly cge_solve, name(double) tolerance(1e-12)
cge_shock, reset
* market income, direct taxes, transfers (gov), indirect taxes, subsidies on
* food and in-kind services
generate double ym = lab + cap + rem + dom
generate double dtx = 0.1 * (lab + cap)
generate double itx = 0.05 * cons
generate double sbs = 0.02 * food
set seed 11
generate double svc = cond(runiform() < 0.5, 8 * runiform(), 0)
local fis market(ym) dtax(dtx) transfers(gov) itax(itx) subsidies(sbs) inkind(svc:com_ser)
cge_microsim `ms' sim(notariff) line(10) `fis' generate(fz) nodisplay
matrix FC = r(concepts)
matrix FI = r(instruments)
matrix FR = r(redistribution)
matrix FS = r(fshare)
assert "`r(instlist)'" == "dtx gov itx sbs svc"
assert rowsof(FC) == 5 & colsof(FC) == 14 & rowsof(FI) == 5 & colsof(FI) == 16

* the concepts in the base, per person
generate double c1 = ym / size
generate double c2 = (ym - dtx) / size
generate double c3 = (ym - dtx + gov) / size
generate double c4 = (ym - dtx + gov - itx + sbs) / size
generate double c5 = (ym - dtx + gov - itx + sbs + svc) / size
forvalues k = 1/5 {
    quietly summarize c`k' [aweight = pw]
    assert reldif(r(mean), FC[`k', 1]) < 1e-12
}
* the Gini coefficient of market income, and concentration coefficients in
* market income, by their formula: 2 cov(t, F) / mean(t), F the mid-rank
sort c1
quietly summarize pw, meanonly
local W = r(sum)
generate double F = (sum(pw) - pw / 2) / `W'
foreach v in c1 c5 {
    quietly summarize `v' [aweight = pw]
    local m = r(mean)
    generate double z_`v' = pw * `v' * (F - 0.5)
    quietly summarize z_`v', meanonly
    local cc_`v' = 2 * r(sum) / (`m' * `W')
}
assert reldif(`cc_c1', FC[1, 3]) < 1e-12 & reldif(`cc_c1', FC[1, 5]) < 1e-12
assert reldif(`cc_c5', FC[5, 5]) < 1e-12
generate double tg = gov / size
quietly summarize tg [aweight = pw]
local m = r(mean)
generate double z_tg = pw * tg * (F - 0.5)
quietly summarize z_tg, meanonly
local cc_tg = 2 * r(sum) / (`m' * `W')
assert reldif(`cc_tg', FI[2, 5]) < 1e-12
* Kakwani: for taxes the concentration less the Gini of market income, for
* benefits the reverse
assert reldif(FI[1, 7], FI[1, 5] - FC[1, 3]) < 1e-12
assert reldif(FI[2, 7], FC[1, 3] - FI[2, 5]) < 1e-12
* redistributive effect, Reynolds-Smolensky, reranking
assert reldif(FR[1, 1], FC[1, 3] - FC[5, 3]) < 1e-12
assert reldif(FR[2, 1], FC[1, 3] - FC[5, 5]) < 1e-12
assert reldif(FR[3, 1], FC[5, 3] - FC[5, 5]) < 1e-12
assert abs(FR[1, 1] - (FR[2, 1] - FR[3, 1])) < 1e-14
* total, per cent of market income, coverage and coverage of the poor
generate double wsv = w * svc
quietly summarize wsv, meanonly
assert reldif(FI[5, 1], r(sum)) < 1e-12
local tsv = r(sum)
generate double wym = w * ym
quietly summarize wym, meanonly
assert reldif(FI[5, 3], 100 * `tsv' / r(sum)) < 1e-12
generate double cov = svc > 0
quietly summarize cov [aweight = pw]
assert reldif(FI[5, 9], r(mean)) < 1e-12
quietly summarize cov [aweight = pw] if c1 < 10
assert reldif(FI[5, 11], r(mean)) < 1e-12
* marginal contribution of direct taxes to the Gini of final income, and of
* the transfer to the headcount
capture program drop _gini_pp
program define _gini_pp, rclass
    args v wt
    tempvar cw cl tr
    sort `v'
    quietly summarize `wt', meanonly
    local W = r(sum)
    quietly generate double `cw' = sum(`wt') / `W'
    quietly generate double `cl' = sum(`wt' * `v')
    quietly replace `cl' = `cl' / `cl'[_N]
    quietly generate double `tr' = (`cw' - cond(_n == 1, 0, `cw'[_n - 1])) * (`cl' + cond(_n == 1, 0, `cl'[_n - 1]))
    quietly summarize `tr', meanonly
    return scalar gini = 1 - r(sum)
end
_gini_pp c5 pw
local g5 = r(gini)
assert reldif(`g5', FC[5, 3]) < 1e-12
generate double wo = c5 + dtx / size
_gini_pp wo pw
assert reldif(FI[1, 13], r(gini) - `g5') < 1e-10
replace wo = c5 - gov / size
generate double p5 = c5 < 10
generate double pwo = wo < 10
quietly summarize p5 [aweight = pw]
local h5 = r(mean)
quietly summarize pwo [aweight = pw]
assert abs(FI[2, 15] - (r(mean) - `h5')) < 1e-12
* fiscal impoverishment: poor in consumable income and worse off than with
* market income
generate double fimp = (c4 < c1) & (c4 < 10)
quietly summarize fimp [aweight = pw]
assert abs(FR[4, 1] - r(mean)) < 1e-12
* the shares of each instrument by decile of market income add up to 1
mata: st_numscalar("dmax", max(abs(colsum(st_matrix("FS")) :- 1)))
assert dmax < 1e-12
drop c1-c5 F z_* tg wsv wym cov wo p5 pwo fimp
* in the simulation: transfers fixed in real terms are deflated by the
* household's price index
assert abs((fz_yd - fz_yn) - gov / fz_price) < 1e-9 * cons
* Doubling the numeraire changes no real income or instrument
cge_microsim `ms' sim(double) line(10) `fis' nodisplay
matrix FC2 = r(concepts)
matrix FI2 = r(instruments)
mata: A_ = st_matrix("FC2"); st_numscalar("dmax", max(abs(A_[., (1, 3, 5, 7, 9, 11, 13)] - A_[., (2, 4, 6, 8, 10, 12, 14)]) :/ (1 :+ abs(A_[., (1, 3, 5, 7, 9, 11, 13)]))))
assert dmax < 1e-10
mata: A_ = st_matrix("FI2"); st_numscalar("dmax", max(abs(A_[., (1, 3, 5, 7, 9, 11, 13, 15)] - A_[., (2, 4, 6, 8, 10, 12, 14, 16)]) :/ (1 :+ abs(A_[., (1, 3, 5, 7, 9, 11, 13, 15)]))))
assert dmax < 1e-10
* the dataset: tables fiscal and fiscalq
preserve
cge_microsim `ms' sim(notariff) line(10) `fis' clear nodisplay
quietly count if table == "fiscal"
assert r(N) == 5 * (3 + 4) + 5 * 8 + 4
quietly count if table == "fiscalq"
assert r(N) == 5 * 10 * 2
quietly summarize base if table == "fiscal" & measure == "kakwani" & channel == "gov"
assert r(mean) == FI[2, 7]
restore
* the table
cge_microsim `ms' sim(notariff) line(10) `fis'
* Errors
capture noisily cge_microsim `ms' sim(notariff) transfers(gov) nodisplay
assert _rc == 198
capture noisily cge_microsim `ms' sim(notariff) market(ym) nodisplay
assert _rc == 198
capture noisily cge_microsim `ms' sim(notariff) market(ym) transfers(gov) itax(gov) nodisplay
assert _rc == 198
capture noisily cge_microsim `ms' sim(notariff) market(ym) inkind(svc:com_xx) nodisplay
assert _rc == 111
capture noisily cge_microsim `ms' sim(notariff) market(ym) inkind(svc:shi) nodisplay
assert _rc == 459
replace sbs = -1 in 3
capture noisily cge_microsim `ms' sim(notariff) market(ym) subsidies(sbs) nodisplay
assert _rc == 459
replace sbs = 0.02 * food in 3
drop ym dtx itx sbs svc

* In-kind health benefits follow the model's health spending: government
* purchases of health services, and the health insurance fund's purchases
cge_synthetic, clear health
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) ///
    imptax(tax_imp) insurance(shi)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock qg, elements(com_hlt) scale(1.3)
quietly cge_solve, name(hlt) tolerance(1e-12)
preserve
quietly cge_results, sim(hlt) clear nodisplay
foreach v in PQ QG {
    quietly summarize value if variable == "`v'" & element1 == "com_hlt"
    local `v'1 = r(mean)
    quietly summarize base if variable == "`v'" & element1 == "com_hlt"
    local `v'0 = r(mean)
}
restore
* the insurance fund's purchases at the prices of the scenario
preserve
quietly cge_results, sim(hlt) clear nodisplay
keep if inlist(variable, "PQ", "QSHI")
keep variable element1 base value
quietly reshape wide base value, i(element1) j(variable) string
generate double n1 = valuePQ * valueQSHI
generate double n0 = basePQ * baseQSHI
quietly summarize n1, meanonly
local shi1 = r(sum)
quietly summarize n0, meanonly
local shi0 = r(sum)
restore
clear
set seed 5
quietly set obs 300
generate str3 group = "hhd"
generate double size = 1 + floor(5 * runiform())
generate double ym = 50 + 100 * runiform()
generate double cons = 0.9 * ym
generate double hb = cond(runiform() < 0.6, 10 * runiform(), 0)
generate double ins = cond(runiform() < 0.3, 6 * runiform(), 0)
cge_microsim, sim(hlt) group(group) consumption(cons) size(size) market(ym) inkind(hb:com_hlt ins:shi) ///
    generate(h) nodisplay
matrix HI = r(instruments)
assert abs((h_yf - h_yc) - (hb * (`PQ1' * `QG1') / (`PQ0' * `QG0') + ins * `shi1' / `shi0') / h_price) < 1e-9 * ym
* benefits per person by decile, and their concentration in market income
assert HI[1, 1] < . & HI[1, 5] < . & HI[2, 5] < .

* ---------------------------------------------------------------------
* 8. Version 0.8.3: reweighting to the model's targets, standard errors from
*    the survey design, and bands across draws of the elasticities
* ---------------------------------------------------------------------
cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)                ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
quietly cge_solve, name(nt) tolerance(1e-12)
cge_shock, reset
* employment of labour by activity, base and simulated
preserve
quietly cge_results, sim(nt) clear nodisplay
foreach a in act_agr act_man {
    quietly summarize value if variable == "QF" & element1 == "lab" & element2 == "`a'"
    local q1 = r(mean)
    quietly summarize base if variable == "QF" & element1 == "lab" & element2 == "`a'"
    local rq_`a' = `q1' / r(mean)
}
restore
clear
set seed 21
quietly set obs 400
generate str3 group = cond(_n <= 300, "hhd", "npi")
generate double w = 50 + 100 * runiform()
generate double size = 1 + floor(5 * runiform())
generate double lab = (group == "hhd") * 100 * runiform()
generate double gov = 20 * runiform()
generate double cons = 0.9 * (lab + gov) + 5
generate double wagr = (runiform() < 0.4) * (1 + floor(2 * runiform()))
generate double wman = runiform() < 0.3
generate double one = 1
local mm [pweight = w], sim(nt) group(group) consumption(cons) size(size) income(lab:lab gov:gov)
cge_microsim `mm' line(30) nodisplay
matrix T0 = r(table)

* A uniform target scales every weight, and leaves every mean and share
cge_microsim `mm' line(30) reweight(one:1.05) generate(ra) nodisplay
assert reldif(ra_w, 1.05 * w) < 1e-12
assert mreldif(r(table), T0) < 1e-12
assert r(rw_deviation) < 1e-12
* A single indicator: its households' weights rise by the ratio, the others'
* are unchanged
cge_microsim `mm' reweight(wman:1.2) generate(rb) nodisplay
assert reldif(rb_w, w * cond(wman, 1.2, 1)) < 1e-12
* Employment of labour by activity, as the model says
cge_microsim `mm' line(30) reweight(wagr:lab.act_agr wman:lab.act_man) generate(rc) nodisplay
matrix RW = r(reweight)
matrix TC = r(table)
assert reldif(RW[1, 4], `rq_act_agr') < 1e-12 & reldif(RW[2, 4], `rq_act_man') < 1e-12
assert reldif(RW[1, 3], RW[1, 2]) < 1e-10 & reldif(RW[2, 3], RW[2, 2]) < 1e-10
generate double xw = rc_w * wagr
quietly summarize xw, meanonly
local s1 = r(sum)
generate double x0 = w * wagr
quietly summarize x0, meanonly
assert reldif(`s1', r(sum) * `rq_act_agr') < 1e-10
* the simulated measures use the new weights, the base the survey's
generate double pw1 = rc_w * size
quietly summarize rc_pc [aweight = pw1]
assert reldif(r(mean), TC[1, 2]) < 1e-12
assert reldif(TC[1, 1], T0[1, 1]) < 1e-15
* a ratio of 1 leaves the weights as they were
cge_microsim `mm' reweight(one:1) generate(rd) nodisplay
assert reldif(rd_w, w) < 1e-14
* the weights are a channel of the decomposition; a uniform change of
* weights contributes nothing, except to the number of poor, counted in
* units of the weights (row 5)
cge_microsim `mm' line(30) reweight(one:1.05) decompose nodisplay
assert "`r(channels)'" == "lab gov taxsav prices weights"
matrix SW = r(shapley)
mata: S_ = st_matrix("SW"); st_numscalar("dmax", max(abs(S_[(1 \ 2 \ 3 \ 4 \ (6::rows(S_))), 6])))
assert dmax < 1e-12
assert dmax < 1e-12
mata: st_numscalar("dmax", max(abs(rowsum(S_[., 1..(cols(S_) - 1)]) - S_[., cols(S_)]) :/ (1 :+ abs(S_[., cols(S_)]))))
assert dmax < 1e-12
* errors: an unknown target, no positive total, conflicting targets
capture noisily cge_microsim `mm' reweight(wman:lab.act_xx) nodisplay
assert _rc == 111
generate double zero = 0
capture noisily cge_microsim `mm' reweight(zero:1.1) nodisplay
assert _rc == 459
generate double wman2 = wman
capture noisily cge_microsim `mm' reweight(wman:1.1 wman2:1.3) nodisplay
assert _rc == 430
drop xw x0 pw1 zero wman2

* Standard errors from the survey design, against svy: ratio
generate long cl = ceil(_n / 4)
generate long str = mod(cl, 5)
svyset cl [pweight = w], strata(str)
cge_microsim, sim(nt) group(group) consumption(cons) size(size) income(lab:lab gov:gov) line(30) ///
    svy generate(sv) nodisplay
matrix SE = r(se)
assert rowsof(SE) == 4 & colsof(SE) == 3
generate double nr0 = cons
generate double nr1 = sv_real
generate double np0 = size * (cons / size < 30)
generate double np1 = size * (sv_pc < 30)
generate double ng0 = size * (cons / size < 30) * (30 - cons / size) / 30
generate double ng1 = size * (sv_pc < 30) * (30 - sv_pc) / 30
quietly svy: ratio (m0: nr0/size) (m1: nr1/size)
matrix VV = e(V)
assert reldif(sqrt(VV[1, 1]), SE[1, 1]) < 1e-10 & reldif(sqrt(VV[2, 2]), SE[1, 2]) < 1e-10
quietly lincom _b[m1] - _b[m0]
assert reldif(r(se), SE[1, 3]) < 1e-10
quietly svy: ratio (h0: np0/size) (h1: np1/size)
matrix VV = e(V)
assert reldif(sqrt(VV[1, 1]), SE[2, 1]) < 1e-10 & reldif(sqrt(VV[2, 2]), SE[2, 2]) < 1e-10
quietly lincom _b[h1] - _b[h0]
assert reldif(r(se), SE[2, 3]) < 1e-10
quietly svy: ratio (g0: ng0/size) (g1: ng1/size)
matrix VV = e(V)
assert reldif(sqrt(VV[1, 1]), SE[3, 1]) < 1e-10 & reldif(sqrt(VV[2, 2]), SE[3, 2]) < 1e-10
* a group as a subpopulation, in the results dataset
preserve
cge_microsim, sim(nt) group(group) consumption(cons) size(size) income(lab:lab gov:gov) line(30) ///
    svy clear nodisplay
quietly summarize se_value if table == "summary" & group == "npi" & measure == "mean"
local se_npi = r(mean)
quietly summarize se_change if table == "summary" & group == "all" & measure == "fgt0"
assert reldif(r(mean), SE[2, 3]) < 1e-12
restore
quietly svy, subpop(if group == "npi"): ratio (m1: nr1/size)
matrix VV = e(V)
assert reldif(sqrt(VV[1, 1]), `se_npi') < 1e-10
* errors: weights given with svy, and data not svyset
capture noisily cge_microsim [pweight = w], sim(nt) group(group) consumption(cons) svy nodisplay
assert _rc == 198
svyset, clear
capture noisily cge_microsim, sim(nt) group(group) consumption(cons) svy nodisplay
assert _rc == 119
drop nr0 nr1 np0 np1 ng0 ng1

* Bands across draws of the elasticities: the draws kept as simulations
capture program drop _scen_nt
program define _scen_nt
    cge_shock tm, value(0)
end
cge_sensitivity, scenario(_scen_nt) draws(4) seed(7) keep(dr) nodisplay
cge_microsim `mm' line(30) bands(dr) nodisplay
matrix BD = r(bands)
assert r(N_draws) == 4
* the central value is that of sim(); the bands are the percentiles of the draws
assert reldif(BD[1, 2], T0[1, 2]) < 1e-15 & reldif(BD[2, 2], T0[1, 5]) < 1e-15
preserve
cge_microsim [pweight = w], sim(dr1 dr2 dr3 dr4) group(group) consumption(cons) size(size) income(lab:lab gov:gov) line(30) clear nodisplay
foreach m in mean fgt0 gini {
    quietly _pctile value if table == "summary" & group == "all" & measure == "`m'", percentiles(5 50 95)
    local k = cond("`m'" == "mean", 1, cond("`m'" == "fgt0", 2, 6))
    assert reldif(r(r1), BD[`k', 3]) < 1e-12 & reldif(r(r2), BD[`k', 4]) < 1e-12 & reldif(r(r3), BD[`k', 5]) < 1e-12
}
restore
* draw 0 is the scenario at the central elasticities
cge_microsim [pweight = w], sim(dr0) group(group) consumption(cons) size(size) income(lab:lab gov:gov) line(30) nodisplay
assert mreldif(r(table), T0) < 1e-9
* the table of the bands
cge_microsim `mm' line(30) bands(dr)
capture noisily cge_microsim `mm' bands(nosuch) nodisplay
assert _rc == 111
program drop _scen_nt
