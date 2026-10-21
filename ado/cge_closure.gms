* cge_closure.gms -- bounds, variables that do not exist, and the closure (Section 6)
* Included by cge_model.gms, by cge_scenario.gms (the check) and by the driver
* that cge_gams writes (cge_run.gms). Every variable is freed, then
* fixed where the model structure or the closure requires it, at its current level.

PA.lo(AC) = -inf;      PA.up(AC) = inf;      PVA.lo(AC) = -inf;     PVA.up(AC) = inf;
PINTA.lo(AC) = -inf;   PINTA.up(AC) = inf;   PX.lo(AC) = -inf;      PX.up(AC) = inf;
PD.lo(AC) = -inf;      PD.up(AC) = inf;      PE.lo(AC) = -inf;      PE.up(AC) = inf;
PM.lo(AC) = -inf;      PM.up(AC) = inf;      PQ.lo(AC) = -inf;      PQ.up(AC) = inf;
W.lo(AC) = -inf;       W.up(AC) = inf;       EXR.lo = -inf;         EXR.up = inf;
CPI.lo = -inf;         CPI.up = inf;         DPI.lo = -inf;         DPI.up = inf;
QA.lo(AC) = -inf;      QA.up(AC) = inf;      QVA.lo(AC) = -inf;     QVA.up(AC) = inf;
QINTA.lo(AC) = -inf;   QINTA.up(AC) = inf;   QF.lo(AC, ACP) = -inf; QF.up(AC, ACP) = inf;
QINT.lo(AC, ACP) = -inf; QINT.up(AC, ACP) = inf; QX.lo(AC) = -inf;  QX.up(AC) = inf;
QD.lo(AC) = -inf;      QD.up(AC) = inf;      QE.lo(AC) = -inf;      QE.up(AC) = inf;
QM.lo(AC) = -inf;      QM.up(AC) = inf;      QQ.lo(AC) = -inf;      QQ.up(AC) = inf;
QH.lo(AC, ACP) = -inf; QH.up(AC, ACP) = inf; QG.lo(AC) = -inf;      QG.up(AC) = inf;
QINV.lo(AC) = -inf;    QINV.up(AC) = inf;    QFS.lo(AC) = -inf;     QFS.up(AC) = inf;
YF.lo(AC) = -inf;      YF.up(AC) = inf;      YIF.lo(AC, ACP) = -inf; YIF.up(AC, ACP) = inf;
YI.lo(AC) = -inf;      YI.up(AC) = inf;      EH.lo(AC) = -inf;      EH.up(AC) = inf;
YG.lo = -inf;          YG.up = inf;          EG.lo = -inf;          EG.up = inf;
GSAV.lo = -inf;        GSAV.up = inf;        FSAV.lo = -inf;        FSAV.up = inf;
TINS.lo(AC) = -inf;    TINS.up(AC) = inf;    MPS.lo(AC) = -inf;     MPS.up(AC) = inf;
TINSADJ.lo = -inf;     TINSADJ.up = inf;     MPSADJ.lo = -inf;      MPSADJ.up = inf;
IADJ.lo = -inf;        IADJ.up = inf;        GADJ.lo = -inf;        GADJ.up = inf;
WFDIST.lo(AC, ACP) = -inf; WFDIST.up(AC, ACP) = inf; WALRAS.lo = -inf; WALRAS.up = inf;
QT.lo(AC) = -inf;      QT.up(AC) = inf;      QER.lo(AC) = -inf;     QER.up(AC) = inf;
YSHI.lo = -inf;        YSHI.up = inf;        SHIADJ.lo = -inf;      SHIADJ.up = inf;
QSHI.lo(AC) = -inf;    QSHI.up(AC) = inf;    EFF.lo(AC) = -inf;     EFF.up(AC) = inf;
HS.lo = -inf;          HS.up = inf;
TQADJ.lo = -inf;       TQADJ.up = inf;       TMADJ.lo = -inf;       TMADJ.up = inf;
TVADJ.lo = -inf;       TVADJ.up = inf;
PWEV.lo(AC) = -inf;     PWEV.up(AC) = inf;     QHA.lo(AC, ACP) = -inf; QHA.up(AC, ACP) = inf;
LSW.lo(AC) = -inf;      LSW.up(AC) = inf;      LSM.lo(AC) = -inf;      LSM.up(AC) = inf;
DW.lo(AC) = -inf;       DW.up(AC) = inf;
RM.lo(AC) = -inf;       RM.up(AC) = inf;       RE.lo(AC) = -inf;       RE.up(AC) = inf;
RA.lo(AC) = -inf;       RA.up(AC) = inf;
QNA.lo(NST, AC) = -inf; QNA.up(NST, AC) = inf; PNA.lo(NST, AC) = -inf; PNA.up(NST, AC) = inf;
PXAC.lo(AC, ACP) = -inf; PXAC.up(AC, ACP) = inf; QXAC.lo(AC, ACP) = -inf; QXAC.up(AC, ACP) = inf;

* Prices and quantities that are positive in the base stay positive; as a
* mixed complementarity problem (from version 0.4.4) every variable without a
* pair must be free or fixed, so these bounds are left out
if (mcpmode = 0,
PA.lo(A) = 1e-10;  PVA.lo(A) = 1e-10;  PQ.lo(C)$CQ(C) = 1e-10;  W.lo(F) = 1e-10;  EXR.lo = 1e-10;
CPI.lo = 1e-10;  DPI.lo = 1e-10;  QA.lo(A) = 1e-10;  QVA.lo(A) = 1e-10;  QQ.lo(C)$CQ(C) = 1e-10;
PWEV.lo(C)$CED(C) = 1e-10;
PINTA.lo(A)$(PINTA0(A) > 0) = 1e-10;  QINTA.lo(A)$(QINTA0(A) > 0) = 1e-10;
PX.lo(C)$CX(C) = 1e-10;  PD.lo(C)$CDO(C) = 1e-10;  QX.lo(C)$CX(C) = 1e-10;  QD.lo(C)$CDO(C) = 1e-10;
PE.lo(C)$CE(C) = 1e-10;  QE.lo(C)$CE(C) = 1e-10;  PM.lo(C)$CM(C) = 1e-10;  QM.lo(C)$CM(C) = 1e-10;
QF.lo(F, A)$FA(F, A) = 1e-10;  QT.lo(C)$CT(C) = 1e-10;  QER.lo(C)$CR(C) = 1e-10;
EFF.lo(F)$eta(F) = 1e-10;  HS.lo$linked = 1e-10;  DW.lo(F)$FS(F) = 1e-10;
QNA.lo(NST, A)$NNA(NST, A) = 1e-10;  PNA.lo(NST, A)$NNA(NST, A) = 1e-10;  QINT.lo(C, A)$NE(C, A) = 1e-10;
PXAC.lo(A, C)$XAC(A, C) = 1e-10;  QXAC.lo(A, C)$XAC(A, C) = 1e-10;
* the wage curve needs positive unemployment
QFS.up(F)$(FL(F) and epsw(F) > 0) = qlf(F) * (1 - 1e-12);
);

* Variables that do not exist are held at their base values
PE.fx(C)$(not CE(C)) = PE.l(C);        QE.fx(C)$(not CE(C)) = QE.l(C);
PM.fx(C)$(not CM(C)) = PM.l(C);        QM.fx(C)$(not CM(C)) = QM.l(C);
PX.fx(C)$(not CX(C)) = PX.l(C);        PD.fx(C)$(not CDO(C)) = PD.l(C);
QX.fx(C)$(not CX(C)) = QX.l(C);        QD.fx(C)$(not CDO(C)) = QD.l(C);
PQ.fx(C)$(not CQ(C)) = PQ.l(C);        QQ.fx(C)$(not CQ(C)) = QQ.l(C);
PWEV.fx(C)$(not CED(C)) = PWEV.l(C);     QHA.fx(A, H)$(not betah(A, H)) = 0;
QF.fx(F, A)$(not FA(F, A)) = 0;        WFDIST.fx(F, A)$(not FA(F, A)) = WFDIST.l(F, A);
QT.fx(C)$(not CT(C)) = 0;              QER.fx(C)$(not CR(C)) = 0;
QINT.fx(C, A)$(not QIX(C, A)) = 0;     QH.fx(C, H)$(not beta(C, H)) = 0;
QSHI.fx(C)$(not qshibar(C)) = 0;       EFF.fx(F)$(not eta(F)) = EFF.l(F);
YSHI.fx$(not fund) = YSHI.l;           SHIADJ.fx$(not fund) = SHIADJ.l;
HS.fx$(not linked) = HS.l;
LSW.fx(F)$(not FL(F)) = 0;             LSM.fx(F)$(not FL(F)) = 0;
DW.fx(F)$(not FS(F)) = 1;
* Rents (16.1) are fixed unless a constraint frees them
RM.fx(C) = RM.l(C);                     RE.fx(C) = RE.l(C);
RA.fx(A) = RA.l(A);
* Nests of value added (17.2) exist only where an activity uses them
QNA.fx(NST, A)$(not NNA(NST, A)) = 0;   PNA.fx(NST, A)$(not NNA(NST, A)) = 0;
* Output by activity (17.3) exists only for the commodities aggregated
PXAC.fx(A, C)$(not XAC(A, C)) = 0;      QXAC.fx(A, C)$(not XAC(A, C)) = 0;

* Closure
GADJ.fx = GADJ.l;
if (clext = 1, FSAV.fx = FSAV.l; else EXR.fx = EXR.l;);
* Government (12.1): the tax scaling factors are fixed except the instrument
if (clgov > 1, GSAV.fx = GSAV.l;);
if (clgov <> 2, TINSADJ.fx = TINSADJ.l;);
if (clgov <> 3, TQADJ.fx = TQADJ.l;);
if (clgov <> 4, TMADJ.fx = TMADJ.l;);
if (clgov <> 5, TVADJ.fx = TVADJ.l;);
if (clsi = 1, MPSADJ.fx = MPSADJ.l; else IADJ.fx = IADJ.l;);
if (clnum = 1, CPI.fx = CPI.l; else DPI.fx = DPI.l;);
QFS.fx(F)$(fclo(F) = 1) = QFS.l(F);
WFDIST.fx(F, A)$(fclo(F) = 1 or fclo(F) >= 3) = WFDIST.l(F, A);
W.fx(F)$(fclo(F) = 2 or fclo(F) = 3) = W.l(F);
QF.fx(F, A)$(fclo(F) = 2) = QF.l(F, A);
* 14: the regime's slack is fixed
LSW.fx(F)$(fclo(F) = 4) = LSW.l(F);
LSM.fx(F)$(fclo(F) = 5) = LSM.l(F);
