$title cge-stata model in GAMS: an independent check of docs/model_spec.md
$ontext
Independent implementation of the static model of docs/model_spec.md
(Sections 5 to 7), written from the specification rather than from the Stata
or Python code. It calibrates from the SAM in the include file %data%, which
is in the standard layout (after the layout rewrites of Section 7.0), solves
the base as a constrained nonlinear system (CNS) with PATH, writes the base
solution to %out%, and saves a work file from which cge_scenario.gms solves
each scenario.

Run by tools/gams/run_gams_check.py, for example:
  gams cge_model.gms --data=data.inc --out=base.csv s=work
$offtext

$if not set data $abort "set --data=<include file>"
$if not set out $set out base.csv

* ---------------------------------------------------------------------
* Data: sets of accounts by role, the SAM and the model settings
* ---------------------------------------------------------------------
$onempty
$include "%data%"
$offempty

alias (AC, ACP), (C, CP), (F, FP), (A, AP);
set D(AC) "households and enterprises";
D(H) = yes;
D(E) = yes;
alias (D, DP);
set INS(AC) "institutions receiving factor income";
INS(D) = yes;
INS(GOVS) = yes;
INS(ROWS) = yes;
INS(SHIS) = yes;

scalar tol "tolerance for structural zeros";
tol = 1e-9 * max(1, smax((AC, ACP), abs(SAM(AC, ACP))));
scalar fund "1 when a health insurance fund is mapped";
fund = 1$(card(SHIS) > 0);

* ---------------------------------------------------------------------
* 7.2 Taxes and trade
* ---------------------------------------------------------------------
sets CM(AC) "imported", CX(AC) "with domestic output", CR(AC) "exports from composite supply",
     CE(AC) "exports from domestic output", CT(AC) "margin services";
parameters QM0(AC), tm(AC), exports(AC), etax(AC), QA0(AC), ta(AC), theta(AC, AC), QX0(AC),
     te(AC), QE0(AC), QER0(AC), pwe(AC), pwm(AC), QD0(AC), PM0(AC), stax(AC), MG(AC), QQ0(AC), tq(AC),
     QT0(AC), spend(AC), icm(AC, AC), qerbar(AC);
QM0(C) = sum(ROWS, SAM(ROWS, C));
CM(C) = yes$(QM0(C) > tol);
tm(C)$CM(C) = sum(MTAXS, SAM(MTAXS, C)) / QM0(C);
exports(C) = sum(ROWS, SAM(C, ROWS));
etax(C) = sum(ETAXS, SAM(ETAXS, C));
QA0(A) = sum(AC, SAM(AC, A));
ta(A) = sum(ATAXS, SAM(ATAXS, A)) / QA0(A);
theta(A, C) = SAM(A, C) / QA0(A);
QX0(C) = sum(A, SAM(A, C));
CX(C) = yes$(QX0(C) > tol);
CR(C) = yes$(exports(C) > tol and QX0(C) - (exports(C) - etax(C)) <= tol);
CE(C) = yes$(exports(C) > tol and not CR(C));
te(C)$CE(C) = etax(C) / exports(C);
QE0(C)$CE(C) = exports(C) - etax(C);
QER0(C)$CR(C) = exports(C);
qerbar(C) = QER0(C);
pwe(C) = 1 / (1 - te(C));
pwm(C) = 1;
QD0(C)$CX(C) = QX0(C) - QE0(C);
PM0(C)$CM(C) = 1 + tm(C);
stax(C) = sum(STAXS, SAM(STAXS, C));
MG(C) = sum(T, SAM(T, C));
QQ0(C) = QD0(C) + PM0(C) * QM0(C) + stax(C) + MG(C);
tq(C) = stax(C) / QQ0(C);
QT0(C) = sum(T, SAM(C, T));
CT(C) = yes$(QT0(C) > tol);
spend(T) = sum(C, SAM(C, T));
icm(CP, C) = sum(T$(spend(T) > tol), SAM(CP, T) / spend(T) * SAM(T, C)) / QQ0(C);

* ---------------------------------------------------------------------
* 12.2 VAT: each use of a commodity is a quantity at PQ = 1, its SAM value
* divided by 1 + tv k, with k = 1 for final users and 1 - kappa for
* activities. tv solves SAM(vat, c) = sum of V tv k / (1 + tv k) (Newton).
* ---------------------------------------------------------------------
parameters kappa(AC) "VAT credit share", vatc(AC) "net VAT by commodity", tv(AC) "VAT rate",
     vbase(AC), vf(AC), vdf(AC), vstep(AC), qhv(AC, AC);
kappa(A) = kappain(A);
vatc(C) = sum(VTAXS, SAM(VTAXS, C));
vbase(C) = sum(A, SAM(C, A) * (1 - kappa(A))) + sum(H, SAM(C, H)) + sum(GOVS, SAM(C, GOVS))
           + sum(SAVS, SAM(C, SAVS)) + sum(SHIS, SAM(C, SHIS));
tv(C)$(abs(vatc(C)) > tol) = vatc(C) / vbase(C);
scalar it;
for (it = 1 to 60,
    vf(C)$tv(C) = sum(A, SAM(C, A) * tv(C) * (1 - kappa(A)) / (1 + tv(C) * (1 - kappa(A))))
                  + (sum(H, SAM(C, H)) + sum(GOVS, SAM(C, GOVS)) + sum(SAVS, SAM(C, SAVS))
                     + sum(SHIS, SAM(C, SHIS))) * tv(C) / (1 + tv(C)) - vatc(C);
    vdf(C)$tv(C) = sum(A, SAM(C, A) * (1 - kappa(A)) / sqr(1 + tv(C) * (1 - kappa(A))))
                   + (sum(H, SAM(C, H)) + sum(GOVS, SAM(C, GOVS)) + sum(SAVS, SAM(C, SAVS))
                      + sum(SHIS, SAM(C, SHIS))) / sqr(1 + tv(C));
    vstep(C)$tv(C) = vf(C) / vdf(C);
    tv(C)$tv(C) = tv(C) - vstep(C);
);
abort$(smax(C, abs(vstep(C))) > 1e-13) "VAT rates did not converge";

* ---------------------------------------------------------------------
* 7.3 Production (W0 = WFDIST0 = 1: no factor quantities are supplied)
* ---------------------------------------------------------------------
sets FA(AC, AC) "factor used by activity", CDV(AC) "Cobb-Douglas value added",
     LT(AC) "Leontief top nest", CDA(AC) "Cobb-Douglas top nest";
parameters QINTA0(AC), ica(AC, AC), QF0(AC, AC), QVA0(AC), iva(AC), inta(AC), rva(AC), dva(AC, AC),
     ad(AC), PINTA0(AC), rha(AC), ratioa(AC), dla(AC), dlac(AC), aa(AC), valuea(AC);
parameter QINT0(AC, AC) "intermediate input quantities";
QINT0(C, A) = SAM(C, A) / (1 + tv(C) * (1 - kappa(A)));
QINTA0(A) = sum(C, QINT0(C, A));
ica(C, A)$(QINTA0(A) > 0) = QINT0(C, A) / QINTA0(A);
FA(F, A) = yes$(SAM(F, A) > tol);
QF0(F, A)$FA(F, A) = SAM(F, A);
QVA0(A) = sum(F, SAM(F, A));
iva(A) = QVA0(A) / QA0(A);
inta(A) = QINTA0(A) / QA0(A);
CDV(A) = yes$(abs(sigva(A) - 1) < 1e-12);
rva(A)$(not CDV(A)) = 1 / sigva(A) - 1;
dva(F, A)$(FA(F, A) and CDV(A)) = SAM(F, A) / QVA0(A);
ad(A)$CDV(A) = QVA0(A) / prod(F$FA(F, A), QF0(F, A)**dva(F, A));
dva(F, A)$(FA(F, A) and not CDV(A)) = QF0(F, A)**(1 + rva(A))
                                       / sum(FP$FA(FP, A), QF0(FP, A)**(1 + rva(A)));
ad(A)$(not CDV(A)) = QVA0(A) / sum(F$FA(F, A), dva(F, A) * QF0(F, A)**(-rva(A)))**(-1 / rva(A));
* Top nest: Leontief (siga = 0, or no intermediate inputs), Cobb-Douglas (1) or CES
PINTA0(A) = sum(C, ica(C, A) * (1 + tv(C) * (1 - kappa(A))));
LT(A) = yes$(siga(A) = 0 or QINTA0(A) <= 0);
CDA(A) = yes$(not LT(A) and abs(siga(A) - 1) < 1e-12);
rha(A)$(not LT(A) and not CDA(A)) = 1 / siga(A) - 1;
ratioa(A)$(not LT(A)) = (1 / PINTA0(A)) * (QVA0(A) / QINTA0(A))**(1 + rha(A));
dla(A)$(not LT(A)) = ratioa(A) / (1 + ratioa(A));
dlac(A)$(not LT(A)) = 1 / (1 + ratioa(A));
valuea(A) = QVA0(A) + PINTA0(A) * QINTA0(A);
dla(A)$CDA(A) = QVA0(A) / valuea(A);
dlac(A)$CDA(A) = PINTA0(A) * QINTA0(A) / valuea(A);
aa(A) = 1;
aa(A)$CDA(A) = QA0(A) / (QVA0(A)**dla(A) * QINTA0(A)**dlac(A));
aa(A)$(not LT(A) and not CDA(A)) = QA0(A) / (dla(A) * QVA0(A)**(-rha(A))
                                      + dlac(A) * QINTA0(A)**(-rha(A)))**(-1 / rha(A));

* ---------------------------------------------------------------------
* 7.4 CET and Armington functions (complements of the shares stored)
* ---------------------------------------------------------------------
parameters rt(AC), ratiot(AC), dt(AC), dtc(AC), at(AC), rq(AC), ratioq(AC), dq(AC), dqc(AC), aq(AC);
rt(C) = 1 / sigt(C) + 1;
dt(C) = 0.5;
dtc(C) = 0.5;
at(C) = 1;
ratiot(C)$CE(C) = (QE0(C) / QD0(C))**(rt(C) - 1);
dt(C)$CE(C) = 1 / (1 + ratiot(C));
dtc(C)$CE(C) = ratiot(C) / (1 + ratiot(C));
at(C)$CE(C) = QX0(C) / (dt(C) * QE0(C)**rt(C) + dtc(C) * QD0(C)**rt(C))**(1 / rt(C));
rq(C) = 1 / sigq(C) - 1;
dq(C) = 0.5;
dqc(C) = 0.5;
aq(C)$CX(C) = QQ0(C) / QD0(C);
aq(C)$(CM(C) and not CX(C)) = QQ0(C) / QM0(C);
ratioq(C)$(CM(C) and CX(C)) = PM0(C) * (QM0(C) / QD0(C))**(1 + rq(C));
dq(C)$(CM(C) and CX(C)) = ratioq(C) / (1 + ratioq(C));
dqc(C)$(CM(C) and CX(C)) = 1 / (1 + ratioq(C));
aq(C)$(CM(C) and CX(C)) = QQ0(C) / (dq(C) * QM0(C)**(-rq(C)) + dqc(C) * QD0(C)**(-rq(C)))**(-1 / rq(C));

* ---------------------------------------------------------------------
* 7.5 Institutions
* ---------------------------------------------------------------------
parameters YF0(AC), YIF0(AC, AC), tshi(AC), shif(AC, AC), trfr(AC), YI0(AC), dtx(AC), dsv(AC),
     tins0(AC), mps0(AC), DY0(AC), safe(AC), shii(AC, AC), shir(AC), QH0(AC, AC), EH0(AC), hc(AC),
     beta(AC, AC), gamma(AC, AC), bb(AC, AC), trdg(AC), trdr(AC), qgbar(AC), qinvbar(AC), qshibar(AC),
     cwts(AC), dwts(AC);
scalars trgr, trrg, trgg, YSHI0, sshi, trshi, trshir, YG0, EG0, GSAV0, FSAV0;
YF0(F) = sum(AC, SAM(F, AC));
YIF0(INS, F) = SAM(INS, F);
tshi(F) = sum(SHIS, SAM(SHIS, F)) / YF0(F);
shif(INS, F)$(not SHIS(INS)) = YIF0(INS, F) / ((1 - tshi(F)) * YF0(F));
trfr(F) = sum(ROWS, SAM(F, ROWS));
YI0(D) = sum(AC, SAM(D, AC));
dtx(D) = sum(DTAXS, SAM(DTAXS, D));
dsv(D) = sum(SAVS, SAM(SAVS, D));
tins0(D) = dtx(D) / YI0(D);
mps0(D) = dsv(D) / ((1 - tins0(D)) * YI0(D));
DY0(D) = YI0(D) - dtx(D) - dsv(D);
safe(D) = DY0(D)$(abs(DY0(D)) > tol) + 1$(abs(DY0(D)) <= tol);
shii(D, DP) = SAM(D, DP) / safe(DP);
shir(D) = sum(ROWS, SAM(ROWS, D)) / safe(D);
QH0(C, H) = SAM(C, H) / (1 + tv(C));
EH0(H) = sum(C, SAM(C, H));
hc(H) = EH0(H) / safe(H);
beta(C, H)$(EH0(H) > 0) = SAM(C, H) / EH0(H);
gamma(C, H) = 0;
if (les,
* LES: marginal shares in proportion to the income elasticities supplied
    bb(C, H) = incel(C) * beta(C, H);
    beta(C, H) = bb(C, H) / sum(CP, bb(CP, H));
    gamma(C, H) = QH0(C, H) + beta(C, H) * EH0(H) / frisch(H) / (1 + tv(C));
);
trdg(D) = sum(GOVS, SAM(D, GOVS));
trdr(D) = sum(ROWS, SAM(D, ROWS));
trgr = sum((GOVS, ROWS), SAM(GOVS, ROWS));
trrg = sum((ROWS, GOVS), SAM(ROWS, GOVS));
trgg = sum(GOVS, SAM(GOVS, GOVS));
qgbar(C) = sum(GOVS, SAM(C, GOVS)) / (1 + tv(C));
qinvbar(C) = sum(SAVS, SAM(C, SAVS)) / (1 + tv(C));
qshibar(C) = sum(SHIS, SAM(C, SHIS)) / (1 + tv(C));
YSHI0 = sum((SHIS, AC), SAM(SHIS, AC));
sshi = 0;
sshi$fund = sum((SAVS, SHIS), SAM(SAVS, SHIS)) / YSHI0;
trshi = sum((SHIS, GOVS), SAM(SHIS, GOVS));
trshir = sum((SHIS, ROWS), SAM(SHIS, ROWS));
cwts(C) = sum(H, SAM(C, H)) / sum((CP, H), SAM(CP, H)) / (1 + tv(C));
dwts(C) = QD0(C) / sum(CP, QD0(CP));
YG0 = sum((GOVS, AC), SAM(GOVS, AC));
EG0 = sum((C, GOVS), SAM(C, GOVS)) + sum(D, trdg(D)) + trgg + trrg + trshi;

* 12.3 Public debt: interest on the stated debt is separated from the
* government's transfers to domestic institutions (shares hold) and abroad
parameters hold(AC) "share of domestic interest received";
scalars ddebt, fdebt, rd, rf, phi;
ddebt = ddebtin;  fdebt = fdebtin;  rd = rdin;  rf = rfin;
hold(D) = holdin(D);
hold(D)$(debtin and not holdgiven and sum(DP, max(trdg(DP), 0)) > 0)
    = max(trdg(D), 0) / sum(DP, max(trdg(DP), 0));
phi = phiin;
phi$(debtin and not phigiven and ddebt + fdebt > 0) = fdebt / (ddebt + fdebt);
trdg(D) = trdg(D) - hold(D) * rd * ddebt;
trrg = trrg - rf * fdebt;
abort$(smin(D, trdg(D)) < -tol) "transfers smaller than interest";
GSAV0 = sum((SAVS, GOVS), SAM(SAVS, GOVS));
FSAV0 = sum((SAVS, ROWS), SAM(SAVS, ROWS));

* Health link (from version 0.1.14) and factor efficiency
parameters af(AC);
scalars linked, hs0;
af(F) = 1;
linked = 1$(sum(F$(eta(F) <> 0), 1) > 0);
hs0 = 1;
hs0$linked = sum(C$HCOM(C), sum(H, QH0(C, H)) + qgbar(C) + qshibar(C));

* ---------------------------------------------------------------------
* Variables and equations (Section 5)
* ---------------------------------------------------------------------
variables PA(AC), PVA(AC), PINTA(AC), PX(AC), PD(AC), PE(AC), PM(AC), PQ(AC), W(AC), EXR, CPI, DPI,
     QA(AC), QVA(AC), QINTA(AC), QF(AC, AC), QINT(AC, AC), QX(AC), QD(AC), QE(AC), QM(AC), QQ(AC),
     QH(AC, AC), QG(AC), QINV(AC), QFS(AC), YF(AC), YIF(AC, AC), YI(AC), EH(AC), YG, EG, GSAV, FSAV,
     TINS(AC), MPS(AC), TINSADJ, MPSADJ, IADJ, GADJ, WFDIST(AC, AC), WALRAS, QT(AC), QER(AC), YSHI,
     SHIADJ, QSHI(AC), EFF(AC), HS, TQADJ, TMADJ, TVADJ;

equations EP1(AC), EP2(AC), EP3(AC), EP4(AC), EP5(AC), EP6(AC), EP7(AC), EP8, EP9,
     EQ1(AC), EQ2(AC), EQ1C(AC), EQ2C(AC), EQ1D(AC), EQ2D(AC), EQ3C(AC), EQ3D(AC), EQ4C(AC, AC),
     EQ4D(AC, AC), EQ5(AC, AC), EQ6(AC), EH1, EH2(AC),
     ET1(AC), ET2(AC), ET3(AC), ET4(AC), ET5(AC), ET6(AC), ET7(AC), ET8(AC), ET9(AC),
     EI1(AC), EI2(AC, AC), EI3(AC), EI4(AC), EI5(AC, AC), EI6(AC), EI7(AC), EI8, EI9, EI10(AC), EI11(AC),
     EI12, EI13(AC), EI14, ES1(AC), ES2(AC), ES3, ES4, ES5;

* 5.1 Prices
EP1(C)$CM(C)..  PM(C) =e= pwm(C) * (1 + tm(C) * TMADJ) * EXR;
EP2(C)$CE(C)..  PE(C) =e= pwe(C) * (1 - te(C)) * EXR;
EP3(C)..        PQ(C) * (1 - tq(C) * TQADJ) * QQ(C) =e= (PD(C) * QD(C))$CX(C) + (PM(C) * QM(C))$CM(C)
                + sum(CP$CT(CP), PQ(CP) * icm(CP, C)) * QQ(C);
EP4(C)$CX(C)..  PX(C) * QX(C) =e= PD(C) * QD(C) + (PE(C) * QE(C))$CE(C);
EP5(A)..        PA(A) =e= sum(C$theta(A, C), theta(A, C) * PX(C));
EP6(A)..        PINTA(A) =e= sum(C$ica(C, A), PQ(C) * (1 + tv(C) * TVADJ * (1 - kappa(A))) * ica(C, A));
EP7(A)..        PA(A) * (1 - ta(A)) * QA(A) =e= PVA(A) * QVA(A) + PINTA(A) * QINTA(A);
EP8..           CPI =e= sum(C$cwts(C), cwts(C) * PQ(C) * (1 + tv(C) * TVADJ));
EP9..           DPI =e= sum(C$dwts(C), dwts(C) * PD(C));

* 5.2 Production; factors in efficiency units af * EFF * QF
EQ1(A)$LT(A)..  QVA(A) =e= iva(A) * QA(A);
EQ2(A)$LT(A)..  QINTA(A) =e= inta(A) * QA(A);
EQ1C(A)$(not LT(A) and not CDA(A))..
    QA(A) =e= aa(A) * (dla(A) * QVA(A)**(-rha(A)) + dlac(A) * QINTA(A)**(-rha(A)))**(-1 / rha(A));
EQ2C(A)$(not LT(A) and not CDA(A))..
    QVA(A) =e= QINTA(A) * ((PINTA(A) / PVA(A)) * dla(A) / dlac(A))**(1 / (1 + rha(A)));
EQ1D(A)$CDA(A)..  QA(A) =e= aa(A) * QVA(A)**dla(A) * QINTA(A)**dlac(A);
EQ2D(A)$CDA(A)..  PVA(A) * QVA(A) * dlac(A) =e= PINTA(A) * QINTA(A) * dla(A);
EQ3C(A)$(not CDV(A))..
    QVA(A) =e= ad(A) * sum(F$FA(F, A), dva(F, A) * (af(F) * EFF(F) * QF(F, A))**(-rva(A)))**(-1 / rva(A));
EQ3D(A)$CDV(A)..
    QVA(A) =e= ad(A) * prod(F$FA(F, A), (af(F) * EFF(F) * QF(F, A))**dva(F, A));
EQ4C(F, A)$(FA(F, A) and not CDV(A))..
    W(F) * WFDIST(F, A) =e= PVA(A) * QVA(A)
        / sum(FP$FA(FP, A), dva(FP, A) * (af(FP) * EFF(FP) * QF(FP, A))**(-rva(A)))
        * dva(F, A) * (af(F) * EFF(F) * QF(F, A))**(-rva(A) - 1) * af(F) * EFF(F);
EQ4D(F, A)$(FA(F, A) and CDV(A))..  W(F) * WFDIST(F, A) * QF(F, A) =e= dva(F, A) * PVA(A) * QVA(A);
EQ5(C, A)$ica(C, A)..  QINT(C, A) =e= ica(C, A) * QINTA(A);
EQ6(C)$CX(C)..  QX(C) =e= sum(A$theta(A, C), theta(A, C) * QA(A));
EH1$linked..    HS =e= sum(C$HCOM(C), sum(H$beta(C, H), QH(C, H)) + QG(C) + QSHI(C)$qshibar(C));
EH2(F)$eta(F).. EFF(F) =e= (HS / hs0)**eta(F);

* 5.3 Trade
ET1(C)$CE(C)..  QX(C) =e= at(C) * (dt(C) * QE(C)**rt(C) + dtc(C) * QD(C)**rt(C))**(1 / rt(C));
ET2(C)$CE(C)..  QE(C) =e= QD(C) * ((PE(C) / PD(C)) * dtc(C) / dt(C))**(1 / (rt(C) - 1));
ET3(C)$(CX(C) and not CE(C))..  QX(C) =e= QD(C);
ET4(C)$(CM(C) and CX(C))..
    QQ(C) =e= aq(C) * (dq(C) * QM(C)**(-rq(C)) + dqc(C) * QD(C)**(-rq(C)))**(-1 / rq(C));
ET5(C)$(CM(C) and CX(C))..  QM(C) =e= QD(C) * ((PD(C) / PM(C)) * dq(C) / dqc(C))**(1 / (1 + rq(C)));
ET6(C)$(CX(C) and not CM(C))..  QQ(C) =e= aq(C) * QD(C);
ET7(C)$(CM(C) and not CX(C))..  QQ(C) =e= aq(C) * QM(C);
ET8(C)$CT(C)..  QT(C) =e= sum(CP$icm(C, CP), icm(C, CP) * QQ(CP));
ET9(C)$CR(C)..  QER(C) =e= qerbar(C) * (PQ(C) / (EXR * pwe(C)))**(-sigt(C));

* 5.4 Institutions
EI1(F)..  YF(F) =e= sum(A$FA(F, A), W(F) * WFDIST(F, A) * QF(F, A)) + trfr(F) * EXR;
EI2(INS, F)..  YIF(INS, F) =e= (shif(INS, F) * (1 - tshi(F)) * YF(F))$(not SHIS(INS))
                               + (tshi(F) * YF(F))$SHIS(INS);
EI3(D)..  YI(D) =e= sum(F, YIF(D, F)) + sum(DP$shii(D, DP), shii(D, DP) * (1 - MPS(DP)) * (1 - TINS(DP)) * YI(DP))
                    + trdg(D) * CPI + trdr(D) * EXR + hold(D) * rd * ddebt;
EI4(H)..  EH(H) =e= hc(H) * (1 - MPS(H)) * (1 - TINS(H)) * YI(H);
EI5(C, H)$beta(C, H)..
    PQ(C) * (1 + tv(C) * TVADJ) * QH(C, H) =e= PQ(C) * (1 + tv(C) * TVADJ) * gamma(C, H)
        + beta(C, H) * (EH(H) - sum(CP$gamma(CP, H), PQ(CP) * (1 + tv(CP) * TVADJ) * gamma(CP, H)));
EI6(C)..  QINV(C) =e= qinvbar(C) * IADJ;
EI7(C)..  QG(C) =e= qgbar(C) * GADJ;
EI8..     YG =e= sum(D, TINS(D) * YI(D)) + sum(C, tq(C) * TQADJ * PQ(C) * QQ(C))
                 + sum(C$CM(C), tm(C) * TMADJ * pwm(C) * QM(C)) * EXR + sum(C$CE(C), te(C) * pwe(C) * QE(C)) * EXR
                 + sum(A, ta(A) * PA(A) * QA(A))
                 + TVADJ * sum(C$tv(C), tv(C) * PQ(C) * (sum(H$beta(C, H), QH(C, H)) + QG(C) + QINV(C)
                       + QSHI(C)$qshibar(C) + sum(A$ica(C, A), (1 - kappa(A)) * QINT(C, A))))
                 + sum((GOVS, F), YIF(GOVS, F)) + trgr * EXR + trgg * CPI;
EI9..     EG =e= sum(C, PQ(C) * (1 + tv(C) * TVADJ) * QG(C)) + (sum(D, trdg(D)) + trgg + trshi) * CPI
                 + trrg * EXR + rd * ddebt + rf * fdebt * EXR;
EI10(D).. TINS(D) =e= tins0(D) * TINSADJ;
EI11(D).. MPS(D) =e= mps0(D) * MPSADJ;
EI12$fund..  YSHI =e= sum((SHIS, F), YIF(SHIS, F)) + trshi * CPI + trshir * EXR;
EI13(C)$qshibar(C)..  QSHI(C) =e= qshibar(C) * SHIADJ;
EI14$fund..  sum(C$qshibar(C), PQ(C) * (1 + tv(C) * TVADJ) * QSHI(C)) =e= (1 - sshi) * YSHI;

* 5.5 System constraints (S6 through the closure)
ES1(F)..  sum(A$FA(F, A), QF(F, A)) =e= QFS(F);
ES2(C)..  QQ(C) =e= sum(A$ica(C, A), QINT(C, A)) + sum(H$beta(C, H), QH(C, H)) + QG(C) + QINV(C)
                    + QT(C)$CT(C) + QER(C)$CR(C) + QSHI(C)$qshibar(C);
ES3..     sum(C$CM(C), pwm(C) * QM(C)) + (sum((ROWS, F), YIF(ROWS, F))
              + sum(D, shir(D) * (1 - MPS(D)) * (1 - TINS(D)) * YI(D))) / EXR + trrg + rf * fdebt
          =e= sum(C$CE(C), pwe(C) * QE(C)) + sum(C$CR(C), PQ(C) * QER(C)) / EXR + sum(D, trdr(D))
              + sum(F, trfr(F)) + trgr + trshir + FSAV;
ES4..     YG =e= EG + GSAV;
ES5..     sum(D, MPS(D) * (1 - TINS(D)) * YI(D)) + GSAV + sshi * YSHI + EXR * FSAV
          =e= sum(C, PQ(C) * (1 + tv(C) * TVADJ) * QINV(C)) + WALRAS;

model cge / all /;

* ---------------------------------------------------------------------
* Base values (Section 7.1: base prices normalised to one)
* ---------------------------------------------------------------------
PA.l(A) = 1;  PVA.l(A) = 1;  PINTA.l(A) = PINTA0(A);  PX.l(C) = 1;  PD.l(C) = 1;
PE.l(C) = 1$CE(C);  PM.l(C) = PM0(C);  PQ.l(C) = 1;  W.l(F) = 1;  EXR.l = 1;
CPI.l = sum(C, cwts(C) * (1 + tv(C)));  DPI.l = sum(C, dwts(C));
QA.l(A) = QA0(A);  QVA.l(A) = QVA0(A);  QINTA.l(A) = QINTA0(A);  QF.l(F, A) = QF0(F, A);
QINT.l(C, A) = QINT0(C, A);  QX.l(C) = QX0(C);  QD.l(C) = QD0(C);  QE.l(C) = QE0(C);
QM.l(C) = QM0(C)$CM(C);  QQ.l(C) = QQ0(C);  QH.l(C, H) = QH0(C, H);  QG.l(C) = qgbar(C);
QINV.l(C) = qinvbar(C);  QFS.l(F) = sum(A, QF0(F, A));  YF.l(F) = YF0(F);  YIF.l(INS, F) = YIF0(INS, F);
YI.l(D) = YI0(D);  EH.l(H) = EH0(H);  YG.l = YG0;  EG.l = EG0;  GSAV.l = GSAV0;  FSAV.l = FSAV0;
TINS.l(D) = tins0(D);  MPS.l(D) = mps0(D);  TINSADJ.l = 1;  MPSADJ.l = 1;  IADJ.l = 1;  GADJ.l = 1;
WFDIST.l(F, A) = 1;  WALRAS.l = 0;  QT.l(C) = QT0(C);  QER.l(C) = QER0(C);  YSHI.l = YSHI0;
SHIADJ.l = 1;  QSHI.l(C) = qshibar(C);  EFF.l(F) = 1;  HS.l = hs0;
TQADJ.l = 1;  TMADJ.l = 1;  TVADJ.l = 1;

* Closure (Section 6): 1 = the default of each block
scalars clext "1 flexible exchange rate, 2 fixed",
        clgov "1 flexible government savings; fixed, with 2 direct, 3 sales, 4 import or 5 VAT rates adjusting",
        clsi "1 savings-driven, 2 investment-driven", clnum "1 CPI numeraire, 2 DPI";
parameter fclo(AC) "factor closure: 1 mobile, 2 activity-specific, 3 unemployed";
clext = 1;  clgov = 1;  clsi = 1;  clnum = 1;  fclo(F) = 1;

$include closure.gms

* PATH's convergence tolerance is absolute: scale it to the size of the SAM,
* within what double precision allows
scalar ptol;
ptol = max(1e-11, 1e-13 * smax((AC, ACP), abs(SAM(AC, ACP))));
file pathopt / path.opt /;
* put files print numbers below .nz as zero (default 1e-5)
pathopt.nz = 0;
pathopt.nr = 2;
pathopt.nd = 3;
putclose pathopt 'convergence_tolerance ', ptol:0:3 /;
cge.optfile = 1;
option cns = path, limrow = 0, limcol = 0, solprint = off;
solve cge using cns;

file res / '%out%' /;
$batinclude write.gms res __base__
