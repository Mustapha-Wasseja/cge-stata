* fiscal_instruments.do -- worked example: VAT, revenue-neutral tax
* replacement and public debt (docs/model_spec.md, Section 12)
*
* The synthetic SAMs are constructed for testing and describe no country; the
* elasticities, VAT credit shares, debt stocks and interest rates are
* illustrative.

version 13.0
clear all
local map activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

* 1. A SAM with a VAT account; agriculture is exempt (no input credits) and
*    services recover half of the VAT on their inputs
cge_synthetic, clear vat
cge_sam, labels(account)
cge_map, `map' vattax(tax_vat)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) vatcredit(act_agr:0 act_ser:0.5)
cge_parameters, clear
list element1 value if parameter == "tv", noobs

* 2. Tariffs removed: with flexible government savings, and with VAT rates
*    adjusting so that government savings are unchanged
cge_shock tm, value(0)
cge_solve, name(notariff)
cge_closure, government(fixgsav vat)
cge_solve, name(notariff_vat)
cge_results, sim(notariff_vat)
cge_report, sims(notariff notariff_vat) tables(government welfare)

* 3. Extending full input credits to every activity
cge_shock, reset
cge_closure, government(flexgsav)
cge_shock kappa, value(1)
cge_solve, name(credits)
cge_report, sims(credits) tables(macro government)

* 4. Public debt: 100 held at home at 5 per cent and 40 abroad at 3 per cent,
*    with interest separated from the SAM's transfers
cge_synthetic, clear institutions
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd npi) enterprises(ent) government(gov)        ///
    savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) debt(domestic:100 foreign:40) ///
    interest(domestic:0.05 foreign:0.03)

* A doubling of the interest rate on foreign debt
cge_shock rf, scale(2)
cge_solve, name(rate_up)
cge_report, sims(rate_up) tables(government debt)
cge_shock, reset

* 5. Deficits borrowed over five periods, with half the foreign debt
*    cancelled in period 2
cge_closure, factors(cap:specific)
local common capital(cap) depreciation(0.05) rental(0.15) growth(lab:0.02) population(0.02) ///
    govgrowth(0.03) foreigngrowth(0.01) tfp(0.01)
cge_dynamic, name(base) periods(0/4) `common'
program define debt_relief
    args t
    if `t' == 2 cge_shock fdebt, scale(0.5)
end
cge_dynamic, name(relief) periods(0/4) `common' shocks(debt_relief)
cge_report, run(relief) tables(debt)
cge_dynresults, run(relief) baseline(base) clear
