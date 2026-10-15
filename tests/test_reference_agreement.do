* test_reference_agreement.do -- Stata results agree with the Python reference
* (docs/model_spec.md, validation check 7; expected files in tests/expected)

version 13.0

* Simulation results of the current model are compared with expected/<name>.csv
capture program drop _compare_reference
program define _compare_reference
    args sim
    tempfile stata
    quietly cge_results, sim(`sim') clear nodisplay
    quietly save `stata'
    quietly import delimited using "expected/`sim'.csv", varnames(1) case(preserve) ///
        stringcols(1 2 3) asdouble clear
    rename (base value) (ref_base ref_value)
    quietly merge 1:1 variable element1 element2 using `stata'
    assert _merge == 3
    quietly generate double reldiff = abs(value - ref_value) / max(1, abs(ref_value))
    quietly generate double basediff = abs(base - ref_base) / max(1, abs(ref_base))
    quietly summarize basediff
    assert r(max) < 1e-9
    quietly summarize reldiff
    display as text "`sim': " as result _N as text " values, largest relative difference " ///
        as result %9.2e r(max)
    assert r(max) < 1e-6
end

* The five standard simulations on the calibrated model in memory
* (an optional prefix selects the expected files, e.g. inst_ for inst_<name>.csv)
capture program drop _standard_simulations
program define _standard_simulations
    args prefix
    cge_shock, reset
    cge_shock tm, value(0)
    cge_solve, name(`prefix'tariff_removal) tolerance(1e-12)
    cge_shock, reset
    cge_shock pwm, scale(1.1)
    cge_solve, name(`prefix'import_price_up10) tolerance(1e-12)
    cge_shock, reset
    cge_shock QFS, elements(lab) scale(1.05)
    cge_solve, name(`prefix'labour_supply_up5) tolerance(1e-12)
    cge_shock, reset
    cge_shock FSAV, scale(0.8)
    cge_solve, name(`prefix'foreign_savings_down20) tolerance(1e-12)
    cge_shock, reset
    cge_shock ad, elements(act_agr) scale(1.05)
    cge_solve, name(`prefix'agri_productivity_up5) tolerance(1e-12)
    foreach sim in tariff_removal import_price_up10 labour_supply_up5 ///
        foreign_savings_down20 agri_productivity_up5 {
        _compare_reference `prefix'`sim'
    }
end

* Standard layout
quietly do setup_synthetic.do
_standard_simulations

* Sector-specific elasticities, including Cobb-Douglas value added in act_man
quietly do setup_synthetic.do "sigmava(0.5 1 1.5) sigmaq(0.6 3 1.2) sigmat(0.7 4 1)"
cge_shock tm, value(0)
cge_solve, name(mixed_tariff_removal) tolerance(1e-12)
_compare_reference mixed_tariff_removal

* Top nest: Leontief, CES and Cobb-Douglas (version 0.1.12)
quietly do setup_synthetic.do "sigmava(0.8) sigmaq(2) sigmat(2) sigmaa(0 0.5 1)"
_standard_simulations nest_

* LES household demand (version 0.1.11)
quietly do setup_synthetic.do "sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1 1.4) frisch(-2)"
_standard_simulations les_

* Government purchases of com_ser up 20 per cent (version 0.1.10)
quietly do setup_synthetic.do
cge_shock qg, elements(com_ser) scale(1.2)
cge_solve, name(gov_ser_up20) tolerance(1e-12)
_compare_reference gov_ser_up20

* National-accounts layout: exports in activity rows and taxes paid directly to
* government give the same model, so the same expected results apply
cge_synthetic, clear national
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(gov) saltax(gov) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
_standard_simulations

* Institutions layout: an enterprise and a non-profit institution
cge_synthetic, clear institutions
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)        ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
_standard_simulations inst_

* LES with two households (version 0.1.11)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) incelas(0.6 1 1.4) frisch(-2 -3)
cge_shock tm, value(0)
cge_solve, name(inst_les_tariff_removal) tolerance(1e-12)
_compare_reference inst_les_tariff_removal
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)

* Transfers from abroad to households and the enterprise halved (version 0.1.10)
cge_shock, reset
cge_shock trdr, scale(0.5)
cge_solve, name(inst_transfers_abroad_down50) tolerance(1e-12)
_compare_reference inst_transfers_abroad_down50

* Margins layout: margins netted out of act_ser are moved to its output
cge_synthetic, clear margins
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) margins(act_ser)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
_standard_simulations margins_

* Territorial-correction layout, with an inventory run-down
cge_synthetic, clear territorial
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) territorial(com_tc act_tc)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
_standard_simulations tc_

* Multi-product layout
cge_synthetic, clear multiproduct
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
_standard_simulations mp_

* Non-imported layout: a non-imported commodity with sales tax (equation T6)
cge_synthetic, clear nonimported
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
_standard_simulations cnm_

* Supply-use layout: margin accounts, a commodity imported only (com_fuel, listed
* after the paired commodities), a stock-change account and the label s-i
cge_synthetic, clear sut
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser com_fuel) ///
    factors(lab cap) households(hhd) government(gov) savinv(si) row(row)                 ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) marginaccounts(trd trp) stocks(dstk)
assert r(stocks_merged) == 3
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
assert r(N_equations) == 103
_standard_simulations sut_

* Health layout (version 0.1.13): health services and a social health insurance
* fund financed by contributions on labour income, government and donors
cge_synthetic, clear health
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
assert r(N_equations) == 117
_standard_simulations shi_
cge_shock, reset
cge_shock tshi, elements(lab) scale(1.5)
cge_solve, name(shi_contribution_up50) tolerance(1e-12)
_compare_reference shi_contribution_up50
cge_shock, reset
cge_shock trshi, scale(1.5)
cge_solve, name(shi_gov_transfer_up50) tolerance(1e-12)
_compare_reference shi_gov_transfer_up50

program drop _compare_reference _standard_simulations
