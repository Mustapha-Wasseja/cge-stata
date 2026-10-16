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
