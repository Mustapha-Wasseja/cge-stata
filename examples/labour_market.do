* labour_market.do -- worked example: unemployment, a wage curve and a minimum
* wage (docs/model_spec.md, Section 14)
*
* The synthetic SAM is constructed for testing and describes no country; the
* unemployment rates and elasticities are illustrative.

version 13.0
clear all

cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

* 1. Fifteen per cent of the labour force is unemployed in the base, and real
*    wages fall by 0.1 per cent for each per cent rise in the unemployment rate
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) unemployment(lab:0.15) wagecurve(lab:0.1)

* A 10 per cent rise in world import prices with employment fixed, on the wage
* curve, and at the minimum wage
cge_shock pwm, scale(1.1)
cge_closure, factors(lab:mobile)
cge_solve, name(fixed)
cge_closure, factors(lab:wagecurve)
cge_solve, name(curve)
cge_closure, factors(lab:minwage)
cge_solve, name(floor)
cge_shock, reset
cge_report, sims(fixed curve floor) tables(macro factors)

* 2. Full employment in the base, with a minimum wage at 95 per cent of the
*    base real wage: a moderate shock leaves the floor slack, a large one makes
*    it bind and creates unemployment
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) minwage(lab:0.95)
cge_closure, factors(lab:minwage)
cge_shock pwm, scale(1.1)
cge_solve, name(pwm10)
cge_shock, reset
cge_shock pwm, scale(1.5)
cge_solve, name(pwm50)
cge_shock, reset
cge_report, sims(pwm10 pwm50) tables(factors)

* 3. A labour force growing at 2 per cent a year with a wage curve: employment
*    grows with demand, and the unemployment rate follows
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2) unemployment(lab:0.15) wagecurve(lab:0.1)
cge_closure, factors(cap:specific lab:wagecurve)
cge_dynamic, name(grow) periods(0/4) capital(cap) depreciation(0.05) rental(0.15) ///
    growth(lab:0.02) tfp(0.01)
cge_report, run(grow) tables(factors)
