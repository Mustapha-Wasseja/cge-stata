* test_linkjac.do -- exact Jacobians of linked regions (version 0.31.0;
* docs/model_spec.md, Section 41): the Jacobian of the linked system, with
* the derivatives of the regions' equations in their world prices and
* tariffs and of the link equations exact, against central differences of
* its residuals column by column and against the differences used before,
* at the base links and at moved points: two regions with user equations
* that use tariffs and world prices and an import quota that pays rents; a
* region with a demand curve for its exports; a region whose exports are
* drawn from composite supply. The solutions agree with those before.

version 13.0

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local instmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)             ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local trademap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser com_cash) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                     ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
local sutmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser com_fuel) ///
    factors(lab cap) households(hhd) government(gov) savinv(si) row(row)                       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) marginaccounts(trd trp) stocks(dstk)
local sigmas sigmava(0.8) sigmaq(2) sigmat(2)

* The Jacobian at the base links and at points moved by 2 and 5 percent
capture program drop _tl_check
program define _tl_check
    args what
    foreach pt in 0 0.02 0.05 {
        mata: _cge_lk_jaccheck(`pt')
        display as text "`what', point `pt': " r(N) " unknowns; exact against differences " ///
            as result %9.2e r(maxdiff) as text ", before " as result %9.2e r(maxdiff_fd)          ///
            as text "; seconds " r(t_exact) " and " r(t_fd)
        if r(maxdiff) >= 1e-6 display as error "row " r(row) ", column " r(col) ": exact " r(exact) ", differences " r(differences)
        assert r(maxdiff) < 1e-6
        assert r(maxdiff_ab) < 1e-6
    }
end

* ---------------------------------------------------------------------
* 1. Two regions; user equations with tm, pwm and pwe; an import quota
*    paying rents to the government
* ---------------------------------------------------------------------
capture noisily cge_region clear
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
cge_region add A
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, `instmap'
quietly cge_calibrate, `sigmas'
cge_variable TREV = sum(c, tm(c) * pwm(c) * QM(c) * EXR)
cge_variable XVAL = sum(c, pwe(c) * QE(c) * EXR) / (1 + tm(com_man))
cge_region add B, units(2)
clear
input str4 exporter str4 importer str8 commodity double value double tariff
A B com_agr 8 .
A B com_man 24 0.08
A B com_ser 6 .
B A com_agr 10 .
B A com_man 30 .
B A com_ser 5 0
end
cge_region trade, exporter(exporter) importer(importer) commodity(commodity) value(value) tariff(tariff)
_tl_check "two regions"
cge_region tariff, from(A B) to(A B) value(0)
quietly cge_region solve, name(fta)
local it_fta = r(iterations)
_tl_check "two regions, free trade"
* a quota on imports of manufactures in A, paying rents to the government
cge_region select A
cge_constraint QM, elements(com_man) upper(1.01) scale rents(gov)
quietly cge_region solve, name(quota)
local it_quota = r(iterations)
_tl_check "two regions, an import quota"
quietly cge_region select A
quietly cge_results, sim(quota) clear nodisplay
quietly summarize value if variable == "RM" & element1 == "com_man"
display as text "rent on imports of manufactures: " as result r(mean)
assert r(mean) > 0
cge_region select A
cge_constraint, clear
display as text "iterations: free trade `it_fta', quota `it_quota'"

* ---------------------------------------------------------------------
* 2. A region with a demand curve for its exports of manufactures (not
*    linked: the rest of the world buys them) and margins by market
* ---------------------------------------------------------------------
capture noisily cge_region clear
quietly cge_synthetic, clear trade
quietly cge_sam, labels(account)
quietly cge_map, `trademap' domesticmargins(mtrd) importmargins(mtrm) exportmargins(mtre)
quietly cge_calibrate, `sigmas' exportdemand(com_man:4)
cge_region add T
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
cge_region add S
clear
input str4 exporter str4 importer str8 commodity double value double tariff
T S com_ser 1 .
S T com_agr 2 .
S T com_man 2 0.05
end
cge_region trade, exporter(exporter) importer(importer) commodity(commodity) value(value) tariff(tariff)
_tl_check "export demand"
cge_region world, commodities(com_man) import(1.05)
quietly cge_region solve, name(world)
_tl_check "export demand, world price"

* ---------------------------------------------------------------------
* 3. A region whose exports of agriculture are drawn from composite supply
* ---------------------------------------------------------------------
capture noisily cge_region clear
quietly cge_synthetic, clear sut
quietly cge_sam, labels(account)
quietly cge_map, `sutmap'
quietly cge_calibrate, `sigmas'
cge_region add U
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, `sigmas'
cge_region add S
clear
input str4 exporter str4 importer str8 commodity double value double tariff
U S com_agr 2 .
U S com_man 1 0.05
S U com_man 2 .
S U com_agr 1 .
end
cge_region trade, exporter(exporter) importer(importer) commodity(commodity) value(value) tariff(tariff)
_tl_check "exports from composite supply"
cge_region tariff, from(U S) to(U S) value(0)
quietly cge_region solve, name(fta)
_tl_check "exports from composite supply, free trade"
capture noisily cge_region clear
program drop _tl_check

* ---------------------------------------------------------------------
* 4. Each model alone: the derivatives in pwm, tm and pwe of every
*    commodity against differences, over every equation that uses them
* ---------------------------------------------------------------------
capture program drop _tl_pt
program define _tl_pt
    args what
    foreach pt in 0 0.03 {
        mata: _cge_ptcheck(`pt')
        display as text "`what', point `pt': " r(N) " parameters, " r(nonzero) " entries; largest difference " as result %9.2e r(maxdiff)
        assert r(maxdiff) < 1e-7 & r(nonzero) > 0
    }
end
* export demand, margins by market, an export-only crop
quietly cge_synthetic, clear trade
quietly cge_sam, labels(account)
quietly cge_map, `trademap' domesticmargins(mtrd) importmargins(mtrm) exportmargins(mtre)
quietly cge_calibrate, `sigmas' exportonly(com_cash) exportdemand(com_man:4 com_cash:2)
_tl_pt "export demand"
* exports from composite supply
quietly cge_synthetic, clear sut
quietly cge_sam, labels(account)
quietly cge_map, `sutmap'
quietly cge_calibrate, `sigmas'
_tl_pt "exports from composite supply"
* rents on imports and exports to each kind of recipient, and user
* equations that use the parameters
quietly cge_synthetic, clear institutions
quietly cge_sam, labels(account)
quietly cge_map, `instmap'
quietly cge_calibrate, `sigmas'
cge_constraint QM, elements(com_man) upper(1.01) scale rents(gov)
cge_constraint QM, elements(com_agr) upper(1.01) scale rents(cap)
cge_constraint QE, elements(com_man) upper(1.01) scale rents(row)
cge_constraint QE, elements(com_agr) upper(1.01) scale rents(hhd)
cge_variable TREV = sum(c, tm(c) * pwm(c) * QM(c) * EXR)
cge_variable XVAL = sum(c, pwe(c) * QE(c) * EXR) / (1 + tm(com_man))
cge_variable PR(c) = PM(c) / (pwm(c) * EXR)
_tl_pt "rents and user equations"
quietly cge_constraint, clear
quietly cge_equation, clear
program drop _tl_pt
