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

program drop _compare_reference _standard_simulations
