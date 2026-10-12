# Model specification: standard static CGE (version 0.1)

This document is the single reference for the equations that `cge-stata`
implements in version 0.1. The Stata/Mata implementation and the Python
reference implementation in `reference/` must both follow it exactly. Any change
to the model is made here first.

The model is a single-country, static, SAM-calibrated computable general
equilibrium model in the tradition of the IFPRI standard model (Lofgren,
Harris and Robinson, 2002) and the PEP-1-1 model (Decaluwé, Lemelin, Robichaud
and Maisonnave, 2013), simplified for a first release. Only the model
structure is taken from that literature; no data from either source are used.

## 1. Scope of version 0.1

Included:

- Activities and commodities as separate SAM accounts, with each activity
  producing exactly one commodity and each commodity produced by exactly one
  activity.
- Two-level production: Leontief between value added and aggregate intermediate
  input; CES (or Cobb-Douglas) value added over factors; Leontief intermediate
  inputs.
- CET transformation of output between exports and domestic sales; Armington
  CES aggregation of imports and domestic goods.
- One or more households with Cobb-Douglas consumption demand.
- Government with direct, sales, import, export and activity taxes, transfers
  to households and fixed real consumption.
- Savings-investment and a rest-of-world account with foreign savings and
  transfers.
- Factor income distributed to households, government and the rest of the
  world by fixed shares.
- Selectable closures for the external account, government, savings-investment,
  factor markets and the numeraire.

Deferred to later versions: multi-product activities and commodities with
several producers; commodities that are not produced domestically, or that are
produced but not sold domestically; linear expenditure system (LES) demand;
inter-household transfers and enterprises; recursive dynamics.

## 2. Sets

| Set | Description |
|---|---|
| $A$ | activities |
| $C$ | commodities; $c(a)$ is the commodity produced by activity $a$, and $a(c)$ the activity producing $c$ |
| $CE \subseteq C$ | exported commodities (base exports > 0) |
| $CNE = C \setminus CE$ | non-exported commodities |
| $CM \subseteq C$ | imported commodities (base imports > 0) |
| $CNM = C \setminus CM$ | non-imported commodities |
| $F$ | factors |
| $H$ | households |
| $I = H \cup \{gov, row\}$ | institutions receiving factor income |

## 3. Variables

Prices

| Variable | Description |
|---|---|
| $PA_a$ | activity price (gross revenue per unit of activity) |
| $PVA_a$ | price of value added |
| $PINTA_a$ | price of aggregate intermediate input |
| $PX_c$ | producer price of commodity output |
| $PD_c$ | price of domestic output sold domestically |
| $PE_c$ | export price in local currency, $c \in CE$ |
| $PM_c$ | import price in local currency, $c \in CM$ |
| $PQ_c$ | composite commodity price, including sales tax |
| $W_f$ | average price of factor $f$ |
| $EXR$ | exchange rate (local currency per unit of foreign currency) |
| $CPI$ | consumer price index |
| $DPI$ | producer price index for domestic sales |

Quantities

| Variable | Description |
|---|---|
| $QA_a$ | level of activity |
| $QVA_a$ | aggregate value added |
| $QINTA_a$ | aggregate intermediate input |
| $QF_{fa}$ | demand for factor $f$ by activity $a$ |
| $QINT_{ca}$ | intermediate use of commodity $c$ by activity $a$ |
| $QX_c$ | output of commodity $c$ |
| $QD_c$ | domestic sales of domestic output |
| $QE_c$ | exports, $c \in CE$ |
| $QM_c$ | imports, $c \in CM$ |
| $QQ_c$ | composite commodity supply |
| $QH_{ch}$ | consumption of $c$ by household $h$ |
| $QG_c$ | government consumption |
| $QINV_c$ | investment demand |
| $QFS_f$ | supply of factor $f$ |

Incomes, rates and adjustment variables

| Variable | Description |
|---|---|
| $YF_f$ | income of factor $f$ |
| $YIF_{if}$ | income of institution $i$ from factor $f$ |
| $YH_h$ | household income |
| $EH_h$ | household consumption spending |
| $YG$, $EG$ | government revenue and spending |
| $GSAV$ | government savings |
| $FSAV$ | foreign savings (foreign currency) |
| $TINS_h$ | direct tax rate of household $h$ |
| $MPS_h$ | marginal propensity to save of household $h$ |
| $TINSADJ$ | direct tax scaling factor |
| $MPSADJ$ | savings rate scaling factor |
| $IADJ$ | investment scaling factor |
| $GADJ$ | government consumption scaling factor |
| $WFDIST_{fa}$ | wage distortion factor for factor $f$ in activity $a$ |
| $WALRAS$ | slack in the savings-investment balance; zero at a solution |

## 4. Parameters

| Parameter | Description |
|---|---|
| $pwm_c$, $pwe_c$ | world import and export prices (foreign currency) |
| $tm_c$, $te_c$, $tq_c$, $ta_a$ | import, export, sales and activity tax rates |
| $iva_a$, $inta_a$ | value added and aggregate intermediate input per unit of activity |
| $ica_{ca}$ | intermediate input $c$ per unit of aggregate intermediate input of $a$ |
| $ad_a$, $\delta^{va}_{fa}$, $\rho^{va}_a$ | value-added CES efficiency, share and exponent parameters |
| $at_c$, $\delta^{t}_c$, $\rho^{t}_c$ | CET efficiency, share and exponent parameters |
| $aq_c$, $\delta^{q}_c$, $\rho^{q}_c$ | Armington efficiency, share and exponent parameters |
| $shif_{if}$ | share of factor $f$ income going to institution $i$ |
| $\beta_{ch}$ | Cobb-Douglas budget share of $c$ for household $h$ |
| $\overline{tins}_h$, $\overline{mps}_h$ | base direct tax rate and savings rate |
| $trnsfr_{h,gov}$, $trnsfr_{h,row}$, $trnsfr_{gov,row}$ | transfers (government transfers in real terms, foreign transfers in foreign currency) |
| $\overline{qg}_c$, $\overline{qinv}_c$ | base government consumption and investment quantities |
| $cwts_c$, $dwts_c$ | CPI and DPI weights |

Elasticities supplied by the user: $\sigma^{va}_a$ (substitution between
factors), $\sigma^{t}_c$ (transformation between exports and domestic sales) and
$\sigma^{q}_c$ (substitution between imports and domestic goods). The exponents
are $\rho^{va}_a = 1/\sigma^{va}_a - 1$, $\rho^{t}_c = 1/\sigma^{t}_c + 1$ and
$\rho^{q}_c = 1/\sigma^{q}_c - 1$.

## 5. Equations

### 5.1 Price block

$$PM_c = pwm_c\,(1+tm_c)\,EXR, \qquad c \in CM \tag{P1}$$

$$PE_c = pwe_c\,(1-te_c)\,EXR, \qquad c \in CE \tag{P2}$$

$$PQ_c\,(1-tq_c)\,QQ_c = PD_c\,QD_c + PM_c\,QM_c \tag{P3}$$

where the import term applies only for $c \in CM$.

$$PX_c\,QX_c = PD_c\,QD_c + PE_c\,QE_c \tag{P4}$$

where the export term applies only for $c \in CE$.

$$PA_a = PX_{c(a)} \tag{P5}$$

$$PINTA_a = \sum_{c} PQ_c\,ica_{ca} \tag{P6}$$

$$PA_a\,(1-ta_a)\,QA_a = PVA_a\,QVA_a + PINTA_a\,QINTA_a \tag{P7}$$

$$CPI = \sum_c cwts_c\,PQ_c \tag{P8}$$

$$DPI = \sum_c dwts_c\,PD_c \tag{P9}$$

### 5.2 Production block

$$QVA_a = iva_a\,QA_a \tag{Q1}$$

$$QINTA_a = inta_a\,QA_a \tag{Q2}$$

Value added, CES case ($\sigma^{va}_a \neq 1$):

$$QVA_a = ad_a\left[\sum_f \delta^{va}_{fa}\,QF_{fa}^{-\rho^{va}_a}\right]^{-1/\rho^{va}_a} \tag{Q3}$$

$$W_f\,WFDIST_{fa} = PVA_a\,QVA_a\left[\sum_{f'} \delta^{va}_{f'a}\,QF_{f'a}^{-\rho^{va}_a}\right]^{-1}\delta^{va}_{fa}\,QF_{fa}^{-\rho^{va}_a-1} \tag{Q4}$$

Value added, Cobb-Douglas case ($\sigma^{va}_a = 1$):

$$QVA_a = ad_a \prod_f QF_{fa}^{\delta^{va}_{fa}}, \qquad \sum_f \delta^{va}_{fa} = 1 \tag{Q3'}$$

$$W_f\,WFDIST_{fa}\,QF_{fa} = \delta^{va}_{fa}\,PVA_a\,QVA_a \tag{Q4'}$$

$$QINT_{ca} = ica_{ca}\,QINTA_a \tag{Q5}$$

$$QX_{c(a)} = QA_a \tag{Q6}$$

### 5.3 Trade block

For exported commodities, $c \in CE$:

$$QX_c = at_c\left[\delta^{t}_c\,QE_c^{\rho^{t}_c} + (1-\delta^{t}_c)\,QD_c^{\rho^{t}_c}\right]^{1/\rho^{t}_c} \tag{T1}$$

$$\frac{QE_c}{QD_c} = \left[\frac{PE_c}{PD_c}\cdot\frac{1-\delta^{t}_c}{\delta^{t}_c}\right]^{1/(\rho^{t}_c-1)} \tag{T2}$$

For non-exported commodities, $c \in CNE$:

$$QX_c = QD_c \tag{T3}$$

For imported commodities, $c \in CM$:

$$QQ_c = aq_c\left[\delta^{q}_c\,QM_c^{-\rho^{q}_c} + (1-\delta^{q}_c)\,QD_c^{-\rho^{q}_c}\right]^{-1/\rho^{q}_c} \tag{T4}$$

$$\frac{QM_c}{QD_c} = \left[\frac{PD_c}{PM_c}\cdot\frac{\delta^{q}_c}{1-\delta^{q}_c}\right]^{1/(1+\rho^{q}_c)} \tag{T5}$$

For non-imported commodities, $c \in CNM$:

$$QQ_c = QD_c \tag{T6}$$

### 5.4 Institution block

$$YF_f = \sum_a W_f\,WFDIST_{fa}\,QF_{fa} \tag{I1}$$

$$YIF_{if} = shif_{if}\,YF_f, \qquad i \in I \tag{I2}$$

$$YH_h = \sum_f YIF_{hf} + trnsfr_{h,gov}\,CPI + trnsfr_{h,row}\,EXR \tag{I3}$$

$$EH_h = (1-MPS_h)(1-TINS_h)\,YH_h \tag{I4}$$

$$PQ_c\,QH_{ch} = \beta_{ch}\,EH_h \tag{I5}$$

$$QINV_c = \overline{qinv}_c\,IADJ \tag{I6}$$

$$QG_c = \overline{qg}_c\,GADJ \tag{I7}$$

$$YG = \sum_h TINS_h\,YH_h + \sum_c tq_c\,PQ_c\,QQ_c + \sum_{c \in CM} tm_c\,pwm_c\,QM_c\,EXR + \sum_{c \in CE} te_c\,pwe_c\,QE_c\,EXR + \sum_a ta_a\,PA_a\,QA_a + \sum_f YIF_{gov,f} + trnsfr_{gov,row}\,EXR \tag{I8}$$

$$EG = \sum_c PQ_c\,QG_c + \sum_h trnsfr_{h,gov}\,CPI \tag{I9}$$

$$TINS_h = \overline{tins}_h\,TINSADJ \tag{I10}$$

$$MPS_h = \overline{mps}_h\,MPSADJ \tag{I11}$$

### 5.5 System constraints

$$\sum_a QF_{fa} = QFS_f \tag{S1}$$

$$QQ_c = \sum_a QINT_{ca} + \sum_h QH_{ch} + QG_c + QINV_c \tag{S2}$$

$$\sum_{c \in CM} pwm_c\,QM_c + \sum_f \frac{YIF_{row,f}}{EXR} = \sum_{c \in CE} pwe_c\,QE_c + \sum_h trnsfr_{h,row} + trnsfr_{gov,row} + FSAV \tag{S3}$$

$$YG = EG + GSAV \tag{S4}$$

$$\sum_h MPS_h\,(1-TINS_h)\,YH_h + GSAV + EXR\cdot FSAV = \sum_c PQ_c\,QINV_c + WALRAS \tag{S5}$$

$$\text{numeraire: } CPI = \overline{CPI} \quad\text{or}\quad DPI = \overline{DPI} \tag{S6}$$

By Walras's law one equation is redundant. The variable $WALRAS$ makes the
system square and must be zero, to solver tolerance, at every solution.

## 6. Closures

The default closure is listed first in each row. A closure fixes one variable of
each pair and leaves the other free.

| Block | Option | Fixed | Free |
|---|---|---|---|
| External account | flexible exchange rate (default) | $FSAV$ | $EXR$ |
| | fixed exchange rate | $EXR$ | $FSAV$ |
| Government | flexible government savings (default) | $TINSADJ$, $GADJ$ | $GSAV$ |
| | fixed government savings | $GSAV$, $GADJ$ | $TINSADJ$ |
| Savings-investment | savings-driven (default) | $MPSADJ$ | $IADJ$ |
| | investment-driven | $IADJ$ | $MPSADJ$ |
| Factor $f$ | mobile, fully employed (default) | $QFS_f$, $WFDIST_{fa}$ | $W_f$, $QF_{fa}$ |
| | activity-specific | $W_f$, $QF_{fa}$ | $WFDIST_{fa}$, $QFS_f$ |
| | unemployment at a fixed wage | $W_f$, $WFDIST_{fa}$ | $QFS_f$, $QF_{fa}$ |
| Numeraire | CPI (default) | $CPI$ | $DPI$ |
| | DPI | $DPI$ | $CPI$ |

Variable and equation counts must be checked for every closure: the number of
free variables must equal the number of equations.

## 7. Calibration

Calibration reads the SAM, with cell $SAM(r, c)$ the payment from column account
$c$ to row account $r$. Base values carry a superscript 0.

Normalisation: $PA^0_a = PX^0_c = PD^0_c = PE^0_c = PQ^0_c = PVA^0_a = 1$,
$EXR^0 = 1$, $pwm_c = 1$, $W^0_f = 1$ and $WFDIST^0_{fa} = 1$ unless factor
quantities are supplied (Section 7.6).

### 7.1 Taxes and trade

- $QM^0_c = SAM(row, c)$; $tm_c = SAM(tax_{imp}, c) / QM^0_c$; $PM^0_c = 1 + tm_c$.
- $te_c = SAM(tax_{exp}, c) / SAM(c, row)$; $QE^0_c = SAM(c, row) - SAM(tax_{exp}, c)$;
  $pwe_c = 1/(1 - te_c)$.
- $QA^0_a$ = column total of activity $a$; $ta_a = SAM(tax_{act}, a) / QA^0_a$.
- $QX^0_{c(a)} = QA^0_a$ and $QD^0_c = QX^0_c - QE^0_c$.
- $QQ^0_c = QD^0_c + PM^0_c\,QM^0_c + SAM(tax_{sal}, c)$ and
  $tq_c = SAM(tax_{sal}, c) / QQ^0_c$.

SAM balance implies that $QQ^0_c$ equals total domestic demand for $c$ at
purchaser prices (the commodity row total minus exports). Calibration must
verify this identity, not assume it.

### 7.2 Production

- $QINTA^0_a = \sum_c SAM(c, a)$; $ica_{ca} = SAM(c, a) / QINTA^0_a$.
- $QF^0_{fa} = SAM(f, a) / (W^0_f\,WFDIST^0_{fa})$; $QVA^0_a = \sum_f SAM(f, a)$.
- $iva_a = QVA^0_a / QA^0_a$; $inta_a = QINTA^0_a / QA^0_a$.
- CES value added: with $w_{fa} = W^0_f\,WFDIST^0_{fa}$,
  $\delta^{va}_{fa} = w_{fa}\,(QF^0_{fa})^{1+\rho^{va}_a} / \sum_{f'} w_{f'a}\,(QF^0_{f'a})^{1+\rho^{va}_a}$
  and $ad_a = QVA^0_a / \left[\sum_f \delta^{va}_{fa}\,(QF^0_{fa})^{-\rho^{va}_a}\right]^{-1/\rho^{va}_a}$.
- Cobb-Douglas value added: $\delta^{va}_{fa} = SAM(f, a) / QVA^0_a$ and
  $ad_a = QVA^0_a / \prod_f (QF^0_{fa})^{\delta^{va}_{fa}}$.

### 7.3 CET and Armington functions

- $\delta^{t}_c = 1 / \left[1 + (PD^0_c/PE^0_c)\,(QE^0_c/QD^0_c)^{\rho^{t}_c-1}\right]$;
  $at_c = QX^0_c / \left[\delta^{t}_c\,(QE^0_c)^{\rho^{t}_c} + (1-\delta^{t}_c)\,(QD^0_c)^{\rho^{t}_c}\right]^{1/\rho^{t}_c}$.
- $\delta^{q}_c = \dfrac{(PM^0_c/PD^0_c)\,(QM^0_c/QD^0_c)^{1+\rho^{q}_c}}{1 + (PM^0_c/PD^0_c)\,(QM^0_c/QD^0_c)^{1+\rho^{q}_c}}$;
  $aq_c = QQ^0_c / \left[\delta^{q}_c\,(QM^0_c)^{-\rho^{q}_c} + (1-\delta^{q}_c)\,(QD^0_c)^{-\rho^{q}_c}\right]^{-1/\rho^{q}_c}$.

### 7.4 Institutions

- $shif_{if} = SAM(i, f) / \sum_{i'} SAM(i', f)$.
- $YH^0_h$ = row total of household $h$; $\overline{tins}_h = SAM(tax_{dir}, h) / YH^0_h$.
- $\overline{mps}_h = SAM(sav, h) / \left[(1 - \overline{tins}_h)\,YH^0_h\right]$.
- $EH^0_h = \sum_c SAM(c, h)$; $\beta_{ch} = SAM(c, h) / EH^0_h$.
- $trnsfr_{h,gov} = SAM(h, gov)$, $trnsfr_{h,row} = SAM(h, row)$,
  $trnsfr_{gov,row} = SAM(gov, row)$.
- $\overline{qg}_c = SAM(c, gov)$, $\overline{qinv}_c = SAM(c, sav)$,
  $GSAV^0 = SAM(sav, gov)$, $FSAV^0 = SAM(sav, row)$.
- $TINSADJ^0 = MPSADJ^0 = IADJ^0 = GADJ^0 = 1$.
- $cwts_c = \sum_h SAM(c, h) / \sum_{c'} \sum_h SAM(c', h)$;
  $dwts_c = QD^0_c / \sum_{c'} QD^0_{c'}$.

In version 0.1 a household column may pay only commodities, the direct tax
account and savings. Calibration stops with an error if the SAM contains any
other household payment.

### 7.5 Tax accounts

Taxes may be recorded in separate tax accounts (as in the synthetic SAM) or as
direct payments to the government account. The account mapping declares which
row holds each tax. A tax account's column must pay only the government.

### 7.6 Factor quantities

If the user supplies base factor quantities $QF^0_{fa}$ (for example
employment), then $W^0_f = \sum_a SAM(f, a) / \sum_a QF^0_{fa}$ and
$WFDIST^0_{fa} = SAM(f, a) / (W^0_f\,QF^0_{fa})$. Otherwise
$W^0_f = WFDIST^0_{fa} = 1$.

## 8. Validation

Every implementation must pass these checks on the synthetic SAM and on any SAM
it calibrates:

1. **SAM balance.** Every row total equals its column total within tolerance.
2. **Benchmark replication.** At calibrated parameters and base values, every
   equation residual is below tolerance, and the solver started at the base
   returns the base.
3. **Homogeneity.** Doubling the numeraire doubles every price and nominal
   value and leaves every quantity unchanged (default closure).
4. **Walras's law.** $WALRAS$ is zero, to tolerance, in every solution.
5. **Robust start.** The solver started from base values perturbed by up to
   ±10 per cent returns the base.
6. **Closure square.** Each closure gives as many free variables as
   equations, and each reproduces the base.
7. **Cross-implementation agreement.** The Stata and Python implementations
   agree to a relative tolerance of 1e-6 on a fixed set of simulations: removal
   of import tariffs; a 10 per cent rise in world import prices; a 5 per cent
   rise in labour supply; a 20 per cent fall in foreign savings; and a 5 per cent
   productivity gain in agriculture.

## References

Decaluwé, B., A. Lemelin, V. Robichaud and H. Maisonnave (2013). *PEP-1-1: The
PEP standard single-country, static CGE model*. Partnership for Economic Policy.

Lofgren, H., R. L. Harris and S. Robinson (2002). *A Standard Computable General
Equilibrium (CGE) Model in GAMS*. Microcomputers in Policy Research 5.
International Food Policy Research Institute.
