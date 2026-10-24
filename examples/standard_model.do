* standard_model.do -- the standard model of cge-stata written whole in the
* user language, as a standalone model (version 0.13.0). The sets and the
* SAM come from the data in memory; the parameters are calibrated by
* assignments, as in a GAMS program; the variables start at their base
* values and the equations are those of the Reference Manual, Part II, for
* the synthetic SAM. Its solutions are those of the built-in model
* (tests/test_standalone.do compares them).

version 13.0

* The SAM as data: one row per account and one variable per account
cge_synthetic, clear

cge_model new
* Sets: the accounts, then the roles they play
cge_set ac, from(account)
cge_set a = act_agr act_man act_ser
cge_set c = com_agr com_man com_ser
cge_set f = lab cap
cge_set h = hhd
cge_set ins = hhd gov row
* The SAM as a parameter: sam(row account, column account)
cge_parameter sam(ac,ac2), from(act_agr-row) labels(account)

* Elasticities and the exponents of the CES and CET functions
cge_parameter sigmava = 0.8
cge_parameter sigmaq = 2
cge_parameter sigmat = 2
cge_parameter rva(a) = 1 / sigmava - 1
cge_parameter rq(c) = 1 / sigmaq - 1
cge_parameter rt(c) = 1 / sigmat + 1

* Base quantities (prices are one at the base) and tax rates
cge_parameter pwm(c) = 1
cge_parameter pwe(c) = 1
cge_parameter tm(c)$(sam(row, c) > 0) = sam(tax_imp, c) / sam(row, c)
cge_parameter te(c) = 0
cge_parameter QM0(c) = sam(row, c) / pwm(c)
cge_parameter QE0(c) = sam(c, row) / pwe(c)
cge_parameter QX0(c) = sum(a, sam(a, c))
cge_parameter QD0(c) = QX0(c) - QE0(c)
cge_parameter QINT0(c,a) = sam(c, a)
cge_parameter QH0(c,h) = sam(c, h)
cge_parameter qg(c) = sam(c, gov)
cge_parameter qinv(c) = sam(c, sav)
cge_parameter QQ0(c) = sum(a, QINT0(c,a)) + sum(h, QH0(c,h)) + qg(c) + qinv(c)
cge_parameter tq(c) = sam(tax_sal, c) / QQ0(c)
cge_parameter PM0(c) = pwm(c) * (1 + tm(c))

* Production: Leontief at the top, CES value added
cge_parameter QF0(f,a) = sam(f, a)
cge_parameter QVA0(a) = sum(f, QF0(f,a))
cge_parameter QINTA0(a) = sum(c, QINT0(c,a))
cge_parameter QA0(a) = QVA0(a) + QINTA0(a)
cge_parameter iva(a) = QVA0(a) / QA0(a)
cge_parameter inta(a) = QINTA0(a) / QA0(a)
cge_parameter ica(c,a) = QINT0(c,a) / QINTA0(a)
cge_parameter theta(a,c) = sam(a, c) / sum(c2, sam(a, c2))
cge_parameter dva(f,a) = QF0(f,a) ^ (1 + rva(a)) / sum(f2, QF0(f2,a) ^ (1 + rva(a)))
cge_parameter ad(a) = QVA0(a) / sum(f, dva(f,a) * QF0(f,a) ^ (-rva(a))) ^ (-1 / rva(a))

* Trade: CET between exports and domestic sales, Armington between imports
* and domestic goods
cge_parameter dt(c) = 1 / (1 + (QE0(c) / QD0(c)) ^ (rt(c) - 1))
cge_parameter dtc(c) = 1 - dt(c)
cge_parameter at(c) = QX0(c) / (dt(c) * QE0(c) ^ rt(c) + dtc(c) * QD0(c) ^ rt(c)) ^ (1 / rt(c))
cge_parameter dq(c) = (QM0(c) / QD0(c)) ^ (1 + rq(c)) * PM0(c) / (1 + (QM0(c) / QD0(c)) ^ (1 + rq(c)) * PM0(c))
cge_parameter dqc(c) = 1 - dq(c)
cge_parameter aq(c) = QQ0(c) / (dq(c) * QM0(c) ^ (-rq(c)) + dqc(c) * QD0(c) ^ (-rq(c))) ^ (-1 / rq(c))

* Institutions: factor income, direct taxes, savings and Cobb-Douglas demand
cge_parameter shif(ins,f) = sam(ins, f) / sum(ins2, sam(ins2, f))
cge_parameter YI0(h) = sum(f, sam(h, f)) + sam(h, gov) + sam(h, row)
cge_parameter tins0(h) = sam(tax_dir, h) / YI0(h)
cge_parameter mps0(h) = sam(sav, h) / ((1 - tins0(h)) * YI0(h))
cge_parameter EH0(h) = (1 - mps0(h)) * (1 - tins0(h)) * YI0(h)
cge_parameter beta(c,h) = QH0(c,h) / EH0(h)
cge_parameter trdg(h) = sam(h, gov)
cge_parameter trdr(h) = sam(h, row)
cge_parameter cwts(c) = sum(h, QH0(c,h)) / sum((c2,h), QH0(c2,h))
cge_parameter dwts(c) = QD0(c) / sum(c2, QD0(c2))

* Variables at their base values; the exogenous ones are fixed: foreign
* savings (a flexible exchange rate), government demand, tax and savings
* rates (flexible government savings, savings-driven investment), the
* consumer price index (the numeraire) and factor supplies and
* distortions (mobile factors)
cge_variable PA(a), value(1)
cge_variable PVA(a), value(1)
cge_variable PINTA(a), value(sum(c, ica(c,a)))
cge_variable PX(c), value(1)
cge_variable PD(c), value(1)
cge_variable PE(c), value(pwe(c) * (1 - te(c)))
cge_variable PM(c), value(PM0(c))
cge_variable PQ(c), value(1)
cge_variable W(f), value(1)
cge_variable EXR, value(1)
cge_variable CPI, value(1) fixed
cge_variable DPI, value(1)
cge_variable QA(a), value(QA0(a))
cge_variable QVA(a), value(QVA0(a))
cge_variable QINTA(a), value(QINTA0(a))
cge_variable QF(f,a), value(QF0(f,a))
cge_variable QINT(c,a), value(QINT0(c,a))
cge_variable QX(c), value(QX0(c))
cge_variable QD(c), value(QD0(c))
cge_variable QE(c), value(QE0(c))
cge_variable QM(c), value(QM0(c))
cge_variable QQ(c), value(QQ0(c))
cge_variable QH(c,h), value(QH0(c,h))
cge_variable QG(c), value(qg(c))
cge_variable QINV(c), value(qinv(c))
cge_variable QFS(f), value(sum(a, QF0(f,a))) fixed
cge_variable YF(f), value(sum(a, QF0(f,a)))
cge_variable YIF(ins,f), value(sam(ins, f))
cge_variable YI(h), value(YI0(h))
cge_variable EH(h), value(EH0(h))
cge_variable YG, value(sum(ac, sam(gov, ac)))
cge_variable EG, value(sum(c, qg(c)) + sum(h, trdg(h)))
cge_variable GSAV, value(sam(sav, gov))
cge_variable FSAV, value(sam(sav, row)) fixed
cge_variable TINS(h), value(tins0(h))
cge_variable MPS(h), value(mps0(h))
cge_variable TINSADJ, value(1) fixed
cge_variable MPSADJ, value(1) fixed
cge_variable IADJ, value(1)
cge_variable GADJ, value(1) fixed
cge_variable WFDIST(f,a), value(1) fixed
cge_variable WALRAS, value(0)

* Prices
cge_equation P1(c): PM(c) = pwm(c) * (1 + tm(c)) * EXR
cge_equation P2(c): PE(c) = pwe(c) * (1 - te(c)) * EXR
cge_equation P3(c): PQ(c) * (1 - tq(c)) * QQ(c) = PD(c) * QD(c) + PM(c) * QM(c)
cge_equation P4(c): PX(c) * QX(c) = PD(c) * QD(c) + PE(c) * QE(c)
cge_equation P5(a): PA(a) = sum(c, theta(a,c) * PX(c))
cge_equation P6(a): PINTA(a) = sum(c, ica(c,a) * PQ(c))
cge_equation P7(a): PA(a) * QA(a) = PVA(a) * QVA(a) + PINTA(a) * QINTA(a)
cge_equation P8: CPI = sum(c, cwts(c) * PQ(c))
cge_equation P9: DPI = sum(c, dwts(c) * PD(c))
* Production
cge_equation Q1(a): QVA(a) = iva(a) * QA(a)
cge_equation Q2(a): QINTA(a) = inta(a) * QA(a)
* the CES sum, as a macro; its sum runs over f2, an alias of f, because Q4
* runs over f itself
cge_macro cessum(j) = sum(f2, dva(f2,j) * QF(f2,j) ^ (-rva(j)))
cge_equation Q3(a): QVA(a) = ad(a) * cessum(a) ^ (-1 / rva(a))
cge_equation Q4(f,a): W(f) * WFDIST(f,a) = PVA(a) * QVA(a) / cessum(a) * dva(f,a) * QF(f,a) ^ (-rva(a) - 1)
cge_equation Q5(c,a): QINT(c,a) = ica(c,a) * QINTA(a)
cge_equation Q6(c): QX(c) = sum(a, theta(a,c) * QA(a))
* Trade
cge_equation T1(c): QX(c) = at(c) * (dt(c) * QE(c) ^ rt(c) + dtc(c) * QD(c) ^ rt(c)) ^ (1 / rt(c))
cge_equation T2(c): QE(c) = QD(c) * (PE(c) / PD(c) * dtc(c) / dt(c)) ^ (1 / (rt(c) - 1))
cge_equation T4(c): QQ(c) = aq(c) * (dq(c) * QM(c) ^ (-rq(c)) + dqc(c) * QD(c) ^ (-rq(c))) ^ (-1 / rq(c))
cge_equation T5(c): QM(c) = QD(c) * (PD(c) / PM(c) * dq(c) / dqc(c)) ^ (1 / (1 + rq(c)))
* Institutions
cge_equation I1(f): YF(f) = sum(a, W(f) * WFDIST(f,a) * QF(f,a))
cge_equation I2(ins,f): YIF(ins,f) = shif(ins,f) * YF(f)
cge_equation I3(h): YI(h) = sum(f, YIF(h,f)) + trdg(h) * CPI + trdr(h) * EXR
cge_equation I4(h): EH(h) = (1 - MPS(h)) * (1 - TINS(h)) * YI(h)
cge_equation I5(c,h): PQ(c) * QH(c,h) = beta(c,h) * EH(h)
cge_equation I6(c): QINV(c) = qinv(c) * IADJ
cge_equation I7(c): QG(c) = qg(c) * GADJ
cge_equation I8: YG = sum(h, TINS(h) * YI(h)) + sum(c, tq(c) * PQ(c) * QQ(c)) + sum(c, tm(c) * pwm(c) * QM(c)) * EXR + sum(c, te(c) * pwe(c) * QE(c)) * EXR + sum(f, YIF(gov,f))
cge_equation I9: EG = sum(c, PQ(c) * QG(c)) + sum(h, trdg(h)) * CPI
cge_equation I10(h): TINS(h) = tins0(h) * TINSADJ
cge_equation I11(h): MPS(h) = mps0(h) * MPSADJ
* System constraints
cge_equation S1(f): sum(a, QF(f,a)) = QFS(f)
cge_equation S2(c): QQ(c) = sum(a, QINT(c,a)) + sum(h, QH(c,h)) + QG(c) + QINV(c)
cge_equation S3: sum(c, pwm(c) * QM(c)) + sum(f, YIF(row,f)) / EXR = sum(c, pwe(c) * QE(c)) + sum(h, trdr(h)) + FSAV
cge_equation S4: YG = EG + GSAV
cge_equation S5: sum(h, MPS(h) * (1 - TINS(h)) * YI(h)) + GSAV + EXR * FSAV = sum(c, PQ(c) * QINV(c)) + WALRAS

* The size of the model, then the base, which the starting values solve
*>> std_describe
cge_model describe
cge_solve, name(base)
*<<
* Import tariffs removed
*>> std_tariff
cge_shock tm, value(0)
cge_solve, name(notariff)
cge_results, sim(notariff)
*<<
