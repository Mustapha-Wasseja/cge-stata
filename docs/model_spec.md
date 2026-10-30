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

- Activities and commodities as separate SAM accounts. From version 0.1.4 an
  activity may produce several commodities in fixed proportions (its yields),
  and a commodity may have several producers; each activity is paired with a
  primary commodity, used when rewriting national-accounts layouts.
- Two-level production: Leontief between value added and aggregate intermediate
  input (from version 0.1.12 optionally CES or Cobb-Douglas); CES (or
  Cobb-Douglas) value added over factors; Leontief intermediate inputs.
- CET transformation of output between exports and domestic sales; Armington
  CES aggregation of imports and domestic goods.
- One or more households with Cobb-Douglas consumption demand or, from
  version 0.1.11, linear expenditure system (LES) demand. Non-profit
  institutions serving households can be mapped as households.
- Enterprises (from version 0.1.2), which receive factor income and transfers,
  pay direct taxes, save, and transfer the rest of their income to other
  institutions and the rest of the world; they do not consume.
- Transfers among households and enterprises, and from them to the rest of the
  world, as fixed shares of the payer's income after direct taxes and savings.
- Government with direct, sales, import, export and activity taxes, transfers
  to households and enterprises, transfers within government and to the rest of
  the world, and fixed real consumption.
- Savings-investment and a rest-of-world account with foreign savings and
  transfers, including factor income received from abroad.
- Factor income distributed to households, enterprises, government and the rest
  of the world by fixed shares.
- Selectable closures for the external account, government, savings-investment,
  factor markets and the numeraire.
- From version 0.1.7: commodities that are imported but not produced in the
  country; trade and transport margins recorded in margin accounts that the
  commodities pay, entering the model as margin services per unit of composite
  supply; and a separate stock-change account, merged into savings-investment.
- From version 0.1.13: a social health insurance fund, financed by contributions
  on factor income, government transfers and transfers from abroad, which buys
  a fixed basket of health services with its revenue less a fixed share saved.
  (A donor-funded non-profit institution is mapped as a household that receives
  transfers from the rest of the world.)
- From version 0.2.0: recursive dynamics (Section 10): capital accumulation
  with investment allocated by relative rental rates, growth of other factors,
  of population and of exogenous flows, and efficiency growth given or
  calibrated to growth targets.
- From version 0.1.14: factors enter value added in efficiency units. Each
  factor has an exogenous efficiency (for example, lower labour productivity
  from illness) and, optionally, an efficiency that rises with the volume of
  health services consumed by households, the government and the health
  insurance fund, with an elasticity chosen for each factor.
- From version 0.1.8: exports drawn from composite supply, for commodities whose
  exports are at least their domestic output (re-exports, and exports supplied
  from inventories or valued at purchaser prices).

Deferred to later versions: margins that differ between domestic sales, imports
and exports.

## 2. Sets

| Set | Description |
|---|---|
| $A$ | activities |
| $C$ | commodities; $c(a)$ is the primary commodity of activity $a$ (activities and commodities are paired by position in the mapping; from version 0.1.7 commodities may outnumber activities, and the commodities after the last paired one have no paired activity) |
| $CX \subseteq C$ | commodities with domestic output (base output > 0); from version 0.1.7 the others, $C \setminus CX$, are imported only |
| $CR \subseteq C$ | commodities whose exports are drawn from composite supply: base exports are positive and at least domestic output (from version 0.1.8) |
| $CE \subseteq CX \setminus CR$ | commodities exported from domestic output (base exports > 0) |
| $CNE = CX \setminus CE$ | produced commodities not exported from domestic output |
| $CM \subseteq C$ | imported commodities (base imports > 0) |
| $CNM = C \setminus CM$ | non-imported commodities |
| $CXE \subseteq CE$ | export-only commodities: all domestic output is exported, with no domestic sales (from version 0.3.2, when chosen; Section 13.3) |
| $CED \subseteq CE$ | exported commodities that face a finite elasticity of export demand (from version 0.3.2; Section 13.2) |
| $FS \subseteq F$ | factors with days lost to illness: a base share of working time lost is given (from version 0.3.4; Section 15) |
| $FL \subseteq F$ | factors with a labour force: a base unemployment rate, or a minimum wage, is given (from version 0.3.3; Section 14) |
| $T^Q, T^D, T^M, T^E$ | margin accounts paid per unit of composite supply (the default), of domestic sales, of imports and of exports (from version 0.3.2; Section 13.4) |
| $T$ | margin accounts (may be empty; from version 0.1.7) |
| $HC \subseteq C$ | health services whose consumption raises factor efficiency (may be empty; from version 0.1.14) |
| $CT \subseteq C$ | margin commodities: the services that margin accounts buy |
| $F$ | factors |
| $H$ | households (including non-profit institutions mapped as households) |
| $E$ | enterprises (may be empty) |
| $D = H \cup E$ | domestic non-government institutions |
| $I = D \cup \{gov, row\}$ | institutions receiving factor income; from version 0.1.13 also the health insurance fund $shi$, when mapped |

## 3. Variables

Prices

| Variable | Description |
|---|---|
| $PA_a$ | activity price (gross revenue per unit of activity) |
| $PVA_a$ | price of value added |
| $PINTA_a$ | price of aggregate intermediate input |
| $PX_c$ | producer price of commodity output, $c \in CX$ |
| $PD_c$ | price of domestic output sold domestically, $c \in CX$ |
| $PE_c$ | export price received by producers, in local currency, $c \in CE$ |
| $PWE_c$ | world export price (foreign currency), $c \in CED$ (from version 0.3.2; elsewhere the parameter $pwe_c$) |
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
| $QX_c$ | output of commodity $c \in CX$ |
| $QD_c$ | domestic sales of domestic output, $c \in CX$ |
| $QE_c$ | exports, $c \in CE$ |
| $QM_c$ | imports, $c \in CM$ |
| $QQ_c$ | composite commodity supply |
| $QH_{ch}$ | consumption of $c$ by household $h$ |
| $LSW_f$, $LSM_f$ | slacks of the wage curve and of the minimum-wage condition, $f \in FL$: zero, and fixed, under the regime that uses the equation; free otherwise (from version 0.3.3) |
| $QHA_{ah}$ | home consumption by household $h$ of the output of activity $a$ (from version 0.3.2; Section 13.1) |
| $QG_c$ | government consumption |
| $QINV_c$ | investment demand |
| $QT_c$ | demand for margin services, $c \in CT$ |
| $QER_c$ | exports drawn from composite supply, $c \in CR$ |
| $QSHI_c$ | purchases of commodity $c$ by the health insurance fund |
| $QFS_f$ | supply of factor $f$ |

Incomes, rates and adjustment variables

| Variable | Description |
|---|---|
| $YF_f$ | income of factor $f$ |
| $YIF_{if}$ | income of institution $i$ from factor $f$ |
| $YI_d$ | income of domestic non-government institution $d$ |
| $EH_h$ | household consumption spending |
| $YG$, $EG$ | government revenue and spending |
| $YSHI$ | revenue of the health insurance fund (from version 0.1.13) |
| $SHIADJ$ | scaling factor of the fund's purchases |
| $GSAV$ | government savings |
| $FSAV$ | foreign savings (foreign currency) |
| $TINS_d$ | direct tax rate of institution $d$ |
| $MPS_d$ | marginal propensity to save of institution $d$ |
| $TINSADJ$ | direct tax scaling factor |
| $TQADJ$, $TMADJ$, $TVADJ$ | scaling factors of the sales tax, import tariff and VAT rates (from version 0.3.1; one unless the closure frees one of them, Section 12.1) |
| $MPSADJ$ | savings rate scaling factor |
| $IADJ$ | investment scaling factor |
| $GADJ$ | government consumption scaling factor |
| $WFDIST_{fa}$ | wage distortion factor for factor $f$ in activity $a$ |
| $EFF_f$ | efficiency of factor $f$ from health services (from version 0.1.14; one for a factor with $\eta_f = 0$) |
| $DW_f$ | days worked per worker of factor $f$, relative to the base (from version 0.3.4; one for $f \notin FS$) |
| $HS$ | volume of health services consumed by households, the government and the health insurance fund |
| $WALRAS$ | slack in the savings-investment balance; zero at a solution |
| $RM_c$, $RE_c$, $RA_a$ | premiums on imports and exports, per unit of the world price, and rents on activity output, per unit of the activity price (from version 0.4.4, Section 16.1); zero and fixed unless a constraint frees them |
| $QNA_{na}$, $PNA_{na}$ | quantity and price of nest $n$ of value added in activity $a$ (from version 0.5.1, Section 17.2) |
| $QXAC_{ac}$, $PXAC_{ac}$ | output of commodity $c$ by activity $a$ and its price, for commodities whose output is aggregated (from version 0.5.2, Section 17.3) |

## 4. Parameters

| Parameter | Description |
|---|---|
| $pwm_c$, $pwe_c$ | world import and export prices (foreign currency) |
| $tm_c$, $te_c$, $tq_c$, $ta_a$ | import, export, sales and activity tax rates |
| $tv_c$, $\kappa_a$ | VAT rate on commodity $c$, and the share of VAT on its inputs that activity $a$ recovers as a credit (from version 0.3.1; $tv_c = 0$ and $\kappa_a = 1$ without VAT; Section 12.2) |
| $DD$, $DF$, $r^d$, $r^f$, $hold_d$, $\phi$ | public debt held at home (local currency) and abroad (foreign currency) at the start of the period, their interest rates, the share of domestic interest received by institution $d$, and the share of new borrowing from abroad (from version 0.3.1; zero without debt; Section 12.3) |
| $\theta_{ac}$ | yield: output of commodity $c$ per unit of activity $a$ |
| $iva_a$, $inta_a$ | value added and aggregate intermediate input per unit of activity (Leontief top nest) |
| $aa_a$, $\delta^{a}_a$, $\rho^{a}_a$ | efficiency, value-added share and exponent of a CES or Cobb-Douglas top nest |
| $ica_{ca}$ | intermediate input $c$ per unit of aggregate intermediate input of $a$ |
| $icm_{c'c}$ | margin services of commodity $c' \in CT$ per unit of composite supply of $c$ |
| $icd_{c'c}$, $ici_{c'c}$, $ice_{c'c}$ | margin services per unit of domestic sales, imports and exports of $c$ (from version 0.3.2) |
| $\eta^{e}_c$, $\overline{qe}_c$ | elasticity of export demand and base exports, $c \in CED$ (from version 0.3.2) |
| $QLF_f$, $u^0_f$, $\epsilon^{w}_f$, $\overline{w}_f$, $\underline{w}_f$, $\mu$ | labour force, base unemployment rate, wage-curve elasticity, reference real wage of the wage curve, real minimum wage, and the smoothing parameter of the minimum-wage condition, $f \in FL$ (from version 0.3.3) |
| $\beta^{h}_{ah}$, $\gamma^{h}_{ah}$ | marginal budget share and subsistence quantity of home consumption of the output of activity $a$ by household $h$ (from version 0.3.2) |
| $ad_a$, $\delta^{va}_{fa}$, $\rho^{va}_a$ | value-added CES efficiency, share and exponent parameters |
| $af_f$ | exogenous efficiency of factor $f$ in every activity (one in the base; from version 0.1.14) |
| $\eta_f$, $HS^0$ | elasticity of the efficiency of factor $f$ with respect to health services, and the base volume of health services |
| $s^0_f$, $\sigma_f$, $\epsilon^{s}_f$ | base share of working time lost to illness, its current value (shocks), and its elasticity with respect to health services per head, $f \in FS$ (from version 0.3.4) |
| $m^0$, $\mu^{m}$, $\epsilon^{m}$, $POP$ | base crude death rate, its current value (shocks), its elasticity with respect to health services per head, and the population index (one in the base; from version 0.3.4) |
| $at_c$, $\delta^{t}_c$, $\rho^{t}_c$ | CET efficiency, share and exponent parameters |
| $aq_c$, $\delta^{q}_c$, $\rho^{q}_c$ | Armington efficiency, share and exponent parameters |
| $shif_{if}$ | share of factor $f$ income, after health insurance contributions, going to institution $i$ |
| $tshi_f$ | health insurance contribution rate on the income of factor $f$ |
| $\overline{qshi}_c$, $sshi$ | base purchases and savings rate of the health insurance fund |
| $trnsfr_{shi,gov}$, $trnsfr_{shi,row}$ | transfers to the fund from the government (real terms) and the rest of the world (foreign currency) |
| $\beta_{ch}$ | marginal budget share of $c$ for household $h$ (the budget share under Cobb-Douglas demand) |
| $\gamma_{ch}$ | subsistence quantity of $c$ for household $h$ (zero under Cobb-Douglas demand) |
| $\overline{tins}_d$, $\overline{mps}_d$ | base direct tax rate and savings rate of institution $d$ |
| $shii_{dd'}$ | share of institution $d'$'s income after direct taxes and savings transferred to institution $d$ |
| $shir_d$ | share of institution $d$'s income after direct taxes and savings transferred to the rest of the world |
| $hc_h$ | share of household $h$'s income after direct taxes and savings spent on consumption |
| $trnsfr_{d,gov}$, $trnsfr_{gov,gov}$ | government transfers to institution $d$ and within government (real terms) |
| $trnsfr_{d,row}$, $trnsfr_{f,row}$, $trnsfr_{gov,row}$ | transfers from the rest of the world to institution $d$, factor $f$ and the government (foreign currency) |
| $trnsfr_{row,gov}$ | government transfers to the rest of the world (foreign currency) |
| $\overline{qg}_c$, $\overline{qinv}_c$ | base government consumption and investment quantities |
| $\overline{qer}_c$ | base exports from composite supply, $c \in CR$ |
| $cwts_c$, $dwts_c$ | CPI and DPI weights |

Elasticities supplied by the user: $\sigma^{va}_a$ (substitution between
factors), optionally $\sigma^{a}_a$ (substitution between value added and
aggregate intermediate input, from version 0.1.12; 0, the default, is Leontief
and 1 Cobb-Douglas; $\rho^{a}_a = 1/\sigma^{a}_a - 1$), $\sigma^{t}_c$ (transformation between exports and domestic sales; for
$c \in CR$, the price elasticity of exports from composite supply, T9) and
$\sigma^{q}_c$ (substitution between imports and domestic goods). The exponents
are $\rho^{va}_a = 1/\sigma^{va}_a - 1$, $\rho^{t}_c = 1/\sigma^{t}_c + 1$ and
$\rho^{q}_c = 1/\sigma^{q}_c - 1$. All elasticities must be positive and finite.
$\sigma^{va}_a = 1$ selects the Cobb-Douglas form of value added (Q3', Q4').
From version 0.1.14 the user may also supply health elasticities $\eta_f \ge 0$
(default 0) with the set $HC$.
Version 0.1 has no Cobb-Douglas form of the Armington function, so
$\sigma^{q}_c \neq 1$ is required for imported commodities.

## 5. Equations

### 5.1 Price block

$$PM_c = pwm_c\,(1+tm_c\,TMADJ + RM_c)\,EXR + \sum_{c'} PQ_{c'}\,ici_{c'c}, \qquad c \in CM \tag{P1}$$

$$PE_c = PWE_c\,(1-te_c - RE_c)\,EXR - \sum_{c'} PQ_{c'}\,ice_{c'c}, \qquad c \in CE \tag{P2}$$

with $PWE_c = pwe_c$ for $c \notin CED$. The margin terms are zero without
margins by market (Section 13.4). The premiums $RM_c$ and $RE_c$ (from version
0.4.4, Section 16.1) are zero unless a quota or another constraint frees them.

$$PQ_c\,(1-tq_c\,TQADJ)\,QQ_c = PDD_c\,QD_c + PM_c\,QM_c + \sum_{c' \in CT} PQ_{c'}\,icm_{c'c}\,QQ_c \tag{P3}$$

where $PDD_c = PD_c + \sum_{c'} PQ_{c'}\,icd_{c'c}$ is the price that domestic
buyers pay for domestic output, including margins on domestic sales (from
version 0.3.2; $PDD_c = PD_c$ without them).

where the domestic term applies only for $c \in CX$, the import term only for
$c \in CM$, and the margin term only when $c$ pays margins.

$$PX_c\,QX_c = PD_c\,QD_c + PE_c\,QE_c, \qquad c \in CX \tag{P4}$$

where the export term applies only for $c \in CE$.

$$PA_a = \sum_c \theta_{ac}\,PX_c \tag{P5}$$

$$PINTA_a = \sum_{c} PQ_c\,\big(1 + tv_c\,TVADJ\,(1-\kappa_a)\big)\,ica_{ca} \tag{P6}$$

$$PA_a\,(1-ta_a - RA_a)\,QA_a = PVA_a\,QVA_a + PINTA_a\,QINTA_a \tag{P7}$$

with the rent $RA_a$ on activity output (from version 0.4.4, Section 16.1),
zero unless a capacity limit or another constraint frees it.

$$CPI = \sum_c cwts_c\,PH_c \tag{P8}$$

where $PH_c = PQ_c\,(1 + tv_c\,TVADJ)$ is the price paid by final users,
including VAT (from version 0.3.1; $PH_c = PQ_c$ without VAT). It is an
expression, not a variable.

$$DPI = \sum_c dwts_c\,PD_c \tag{P9}$$

### 5.2 Production block

Leontief top nest ($\sigma^{a}_a = 0$, the default):

$$QVA_a = iva_a\,QA_a \tag{Q1}$$

$$QINTA_a = inta_a\,QA_a \tag{Q2}$$

CES top nest (from version 0.1.12; $\sigma^{a}_a > 0$, $\sigma^{a}_a \neq 1$):

$$QA_a = aa_a\left[\delta^{a}_a\,QVA_a^{-\rho^{a}_a} + (1-\delta^{a}_a)\,QINTA_a^{-\rho^{a}_a}\right]^{-1/\rho^{a}_a} \tag{Q1C}$$

$$\frac{QVA_a}{QINTA_a} = \left[\frac{PINTA_a}{PVA_a}\cdot\frac{\delta^{a}_a}{1-\delta^{a}_a}\right]^{1/(1+\rho^{a}_a)} \tag{Q2C}$$

Cobb-Douglas top nest ($\sigma^{a}_a = 1$):

$$QA_a = aa_a\,QVA_a^{\delta^{a}_a}\,QINTA_a^{1-\delta^{a}_a}, \qquad PVA_a\,QVA_a\,(1-\delta^{a}_a) = PINTA_a\,QINTA_a\,\delta^{a}_a \tag{Q1C', Q2C'}$$

With a CES or Cobb-Douglas top nest, value added and intermediate inputs
substitute for each other as their prices change; P7 still sets the activity
price. An activity without intermediate inputs keeps the Leontief top nest.

From version 0.1.14 factors enter value added in efficiency units,
$\widetilde{QF}_{fa} = af_f\,EFF_f\,QF_{fa}$ (from version 0.3.4, $af_f\,EFF_f\,DW_f\,QF_{fa}$, Section 15.2). Factor quantities $QF_{fa}$,
supplies $QFS_f$ and wages $W_f$ remain in physical units, so a more efficient
factor earns more per unit. In the base $af_f = EFF_f = DW_f = 1$.

Value added, CES case ($\sigma^{va}_a \neq 1$):

$$QVA_a = ad_a\left[\sum_f \delta^{va}_{fa}\,\widetilde{QF}_{fa}^{-\rho^{va}_a}\right]^{-1/\rho^{va}_a} \tag{Q3}$$

$$W_f\,WFDIST_{fa} = PVA_a\,QVA_a\left[\sum_{f'} \delta^{va}_{f'a}\,\widetilde{QF}_{f'a}^{-\rho^{va}_a}\right]^{-1}\delta^{va}_{fa}\,\widetilde{QF}_{fa}^{-\rho^{va}_a-1}\,af_f\,EFF_f\,DW_f \tag{Q4}$$

Value added, Cobb-Douglas case ($\sigma^{va}_a = 1$):

$$QVA_a = ad_a \prod_f \widetilde{QF}_{fa}^{\delta^{va}_{fa}}, \qquad \sum_f \delta^{va}_{fa} = 1 \tag{Q3'}$$

$$W_f\,WFDIST_{fa}\,QF_{fa} = \delta^{va}_{fa}\,PVA_a\,QVA_a \tag{Q4'}$$

Health services and factor efficiency (from version 0.1.14), when $HC$ is not
empty and some $\eta_f > 0$, or, from version 0.3.4, a health outcome of
Section 15 has a non-zero elasticity:

$$HS = \sum_{c \in HC} \Big(\sum_h QH_{ch} + QG_c + QSHI_c\Big) \tag{H1}$$

$$EFF_f = \left(HS / HS^0\right)^{\eta_f}, \qquad \eta_f > 0 \tag{H2}$$

Health services are summed at base prices (one). With a fixed population the
ratio $HS/HS^0$ is also the ratio of health services per head to its base.
Otherwise $EFF_f = 1$.

$$QINT_{ca} = ica_{ca}\,QINTA_a \tag{Q5}$$

$$QX_c = \sum_a \theta_{ac}\,\Big(QA_a - \sum_h QHA_{ah}\Big), \qquad c \in CX \tag{Q6}$$

Output consumed at home by its producers (Section 13.1) does not reach the
commodity market; the yields $\theta_{ac}$ apply to marketed output.

Output of a commodity from different activities is a perfect substitute and
sells at one producer price $PX_c$.

### 5.3 Trade block

For exported commodities, $c \in CE$:

$$QX_c = at_c\left[\delta^{t}_c\,QE_c^{\rho^{t}_c} + (1-\delta^{t}_c)\,QD_c^{\rho^{t}_c}\right]^{1/\rho^{t}_c} \tag{T1}$$

$$\frac{QE_c}{QD_c} = \left[\frac{PE_c}{PD_c}\cdot\frac{1-\delta^{t}_c}{\delta^{t}_c}\right]^{1/(\rho^{t}_c-1)} \tag{T2}$$

For produced, non-exported commodities, $c \in CNE$:

$$QX_c = QD_c \tag{T3}$$

For export-only commodities, $c \in CXE$ (from version 0.3.2), which replace
T1 and T2:

$$QX_c = QE_c \tag{T3E}$$

Exports facing a finite elasticity of export demand, $c \in CED$ (from
version 0.3.2):

$$QE_c = \overline{qe}_c \left(\frac{PWE_c}{pwe_c}\right)^{-\eta^{e}_c} \tag{T10}$$

where $pwe_c$ now shifts the demand curve: at the base world price the
world buys $\overline{qe}_c$.

For imported commodities with domestic output, $c \in CM \cap CX$:

$$QQ_c = aq_c\left[\delta^{q}_c\,QM_c^{-\rho^{q}_c} + (1-\delta^{q}_c)\,QD_c^{-\rho^{q}_c}\right]^{-1/\rho^{q}_c} \tag{T4}$$

$$\frac{QM_c}{QD_c} = \left[\frac{PDD_c}{PM_c}\cdot\frac{\delta^{q}_c}{1-\delta^{q}_c}\right]^{1/(1+\rho^{q}_c)} \tag{T5}$$

For non-imported commodities, $c \in CNM$ (all of which have domestic output):

$$QQ_c = aq_c\,QD_c \tag{T6}$$

Here $aq_c = QQ^0_c / QD^0_c$ (Section 7.4). With all base prices normalised to
one, a sales tax on a non-imported commodity makes composite supply exceed
domestic sales in value units, $QQ^0_c = QD^0_c + SAM(tax_{sal}, c)$, so the
coefficient is not one. (Before version 0.1.4 this equation read
$QQ_c = QD_c$, which fails benchmark replication for non-imported commodities
with a sales tax.)

For commodities that are imported only, $c \in CM \setminus CX$ (from version
0.1.7), composite supply is imports alone:

$$QQ_c = aq_c\,QM_c \tag{T7}$$

with $aq_c = QQ^0_c / QM^0_c$, which exceeds one when the commodity pays a tariff,
sales tax or margins.

Demand for margin services (from version 0.1.7), $c \in CT$:

$$QT_c = \sum_{c'} \left(icm_{cc'}\,QQ_{c'} + icd_{cc'}\,QD_{c'} + ici_{cc'}\,QM_{c'} + ice_{cc'}\,QE_{c'}\right) \tag{T8}$$

Margins are a fixed quantity of services per unit of composite supply, and their
cost enters the composite price through P3. The SAMs this serves record one
margin payment per commodity, without a split between domestic sales, imports
and exports; margins are therefore attributed to composite supply, as sales
taxes are.

Exports drawn from composite supply (from version 0.1.8), $c \in CR$:

$$QER_c = \overline{qer}_c\left(\frac{PQ_c}{EXR\cdot pwe_c}\right)^{-\sigma^{t}_c} \tag{T9}$$

Some SAMs record exports that domestic output cannot supply: re-exports of
imported goods, exports from inventories (with a matching fall in stocks), or
exports valued at purchaser prices, including the sales taxes and margins on the
exported goods. For such a commodity the CET of T1 and T2 is not defined (its
domestic sales would be zero or negative). Its exports are instead drawn from
composite supply, like any other demand, and sold at the composite price
$PQ_c$, which includes taxes and margins as the SAM records them. The volume
exported falls as the composite price rises relative to the world price
$EXR\cdot pwe_c$, with elasticity $\sigma^{t}_c$, so these exports respond to
the exchange rate and to world prices. The commodity's domestic output, if
any, is sold domestically ($QX_c = QD_c$, T3).

### 5.4 Institution block

$$YF_f = \sum_a W_f\,WFDIST_{fa}\,QF_{fa} + trnsfr_{f,row}\,EXR + R_f \tag{I1}$$

where $R_\rho$ is the sum of the rents paid to recipient $\rho$ (from version
0.4.4, Section 16.1; zero without rents). It is also added to the incomes of
households and enterprises (I3), to government revenue (I8) and, for the rest
of the world, to payments abroad (S3).

$$YIF_{if} = shif_{if}\,(1-tshi_f)\,YF_f, \quad i \in I \setminus \{shi\}; \qquad YIF_{shi,f} = tshi_f\,YF_f \tag{I2}$$

Without a health insurance fund, $tshi_f = 0$.

$$YI_d = \sum_f YIF_{df} + \sum_{d' \in D} shii_{dd'}\,(1-MPS_{d'})(1-TINS_{d'})\,YI_{d'} + trnsfr_{d,gov}\,CPI + trnsfr_{d,row}\,EXR + hold_d\,r^d\,DD + R_d \tag{I3}$$

$$EH_h = hc_h\,(1-MPS_h)(1-TINS_h)\,YI_h \tag{I4}$$

Enterprises do not consume: for $e \in E$, $\sum_d shii_{de} + shir_e = 1$, so all
income after direct taxes and savings is transferred. For households,
$hc_h = 1 - \sum_d shii_{dh} - shir_h$. A transfer from an institution to itself
(a diagonal SAM cell) is allowed; it appears on both sides of its accounts.

$$PH_c\,QH_{ch} = PH_c\,\gamma_{ch} + \beta_{ch}\,SN_h \tag{I5}$$

$$PA_a\,QHA_{ah} = PA_a\,\gamma^{h}_{ah} + \beta^{h}_{ah}\,SN_h \tag{I5H}$$

with supernumerary spending $SN_h = EH_h - \sum_c PH_c\,\gamma_{ch} - \sum_a PA_a\,\gamma^{h}_{ah}$.
Home consumption (I5H, from version 0.3.2) is valued at the activity price
$PA_a$, without taxes or margins; the marginal shares of marketed and home
goods together sum to one.

With $\gamma_{ch} = 0$ this is Cobb-Douglas demand, the default. From version
0.1.11 the linear expenditure system (LES) is available: households first buy
subsistence quantities $\gamma_{ch}$ and spend the rest of their consumption
budget in fixed marginal shares $\beta_{ch}$, so that budget shares change with
income. The equivalent variation of household $h$ at base prices is
$EV_h = \sum_c PQ^0_c\gamma_{ch} + \left(EH_h - \sum_c PQ_c\gamma_{ch}\right)\prod_c (PQ^0_c/PQ_c)^{\beta_{ch}} - EH^0_h$,
which reduces to the Cobb-Douglas form when $\gamma_{ch} = 0$.

$$QINV_c = \overline{qinv}_c\,IADJ \tag{I6}$$

$$QG_c = \overline{qg}_c\,GADJ \tag{I7}$$

$$YG = \sum_d TINS_d\,YI_d + \sum_c tq_c\,TQADJ\,PQ_c\,QQ_c + \sum_{c \in CM} tm_c\,TMADJ\,pwm_c\,QM_c\,EXR + \sum_{c \in CE} te_c\,PWE_c\,QE_c\,EXR + \sum_a ta_a\,PA_a\,QA_a + VAT + \sum_f YIF_{gov,f} + trnsfr_{gov,row}\,EXR + trnsfr_{gov,gov}\,CPI + R_{gov} \tag{I8}$$

with VAT revenue (zero without VAT)

$$VAT = TVADJ \sum_c tv_c\,PQ_c \Big(\sum_h QH_{ch} + QG_c + QINV_c + QSHI_c + \sum_a (1-\kappa_a)\,QINT_{ca}\Big)$$

$$EG = \sum_c PH_c\,QG_c + \sum_d trnsfr_{d,gov}\,CPI + trnsfr_{gov,gov}\,CPI + trnsfr_{shi,gov}\,CPI + trnsfr_{row,gov}\,EXR + r^d\,DD + r^f\,DF\,EXR \tag{I9}$$

$$TINS_d = \overline{tins}_d\,TINSADJ \tag{I10}$$

$$MPS_d = \overline{mps}_d\,MPSADJ \tag{I11}$$

Health insurance fund (from version 0.1.13), when mapped:

$$YSHI = \sum_f YIF_{shi,f} + trnsfr_{shi,gov}\,CPI + trnsfr_{shi,row}\,EXR \tag{I12}$$

$$QSHI_c = \overline{qshi}_c\,SHIADJ \tag{I13}$$

$$\sum_c PH_c\,QSHI_c = (1 - sshi)\,YSHI \tag{I14}$$

The fund buys a fixed basket of health services, scaled so that it spends its
revenue less a fixed share saved. A higher contribution rate or larger transfers
therefore raise its purchases.

### 5.5 System constraints

$$\sum_a QF_{fa} = QFS_f \tag{S1}$$

$$QQ_c = \sum_a QINT_{ca} + \sum_h QH_{ch} + QG_c + QINV_c + QT_c + QER_c + QSHI_c \tag{S2}$$

where $QT_c$ applies only for $c \in CT$ and $QER_c$ only for $c \in CR$.

$$\sum_{c \in CM} pwm_c\,QM_c + \sum_f \frac{YIF_{row,f}}{EXR} + \sum_d \frac{shir_d\,(1-MPS_d)(1-TINS_d)\,YI_d}{EXR} + trnsfr_{row,gov} + r^f\,DF + \frac{R_{row}}{EXR} = \sum_{c \in CE} PWE_c\,QE_c + \sum_{c \in CR} \frac{PQ_c\,QER_c}{EXR} + \sum_d trnsfr_{d,row} + \sum_f trnsfr_{f,row} + trnsfr_{gov,row} + trnsfr_{shi,row} + FSAV \tag{S3}$$

$$YG = EG + GSAV \tag{S4}$$

$$\sum_d MPS_d\,(1-TINS_d)\,YI_d + GSAV + sshi\,YSHI + EXR\cdot FSAV = \sum_c PH_c\,QINV_c + WALRAS \tag{S5}$$

$$\text{numeraire: } CPI = \overline{CPI} \quad\text{or}\quad DPI = \overline{DPI} \tag{S6}$$

S6 is imposed by fixing the numeraire variable in the closure (Section 6). It
is not counted as a separate equation.

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
| | fixed government savings, direct tax rates adjust | $GSAV$, $GADJ$ | $TINSADJ$ |
| | fixed government savings, sales tax, import tariff or VAT rates adjust (from version 0.3.1) | $GSAV$, $GADJ$, $TINSADJ$ | $TQADJ$, $TMADJ$ or $TVADJ$ |
| Savings-investment | savings-driven (default) | $MPSADJ$ | $IADJ$ |
| | investment-driven | $IADJ$ | $MPSADJ$ |
| Factor $f$ | mobile, fully employed (default) | $QFS_f$, $WFDIST_{fa}$ | $W_f$, $QF_{fa}$ |
| | activity-specific | $W_f$, $QF_{fa}$ | $WFDIST_{fa}$, $QFS_f$ |
| | unemployment at a fixed wage | $W_f$, $WFDIST_{fa}$ | $QFS_f$, $QF_{fa}$ |
| | wage curve, $f \in FL$ (from version 0.3.3) | $WFDIST_{fa}$, $LSW_f$ | $W_f$, $QFS_f$, $QF_{fa}$ |
| | minimum wage, $f \in FL$ (from version 0.3.3) | $WFDIST_{fa}$, $LSM_f$ | $W_f$, $QFS_f$, $QF_{fa}$ |
| Numeraire | CPI (default) | $CPI$ | $DPI$ |
| | DPI | $DPI$ | $CPI$ |

$TQADJ$, $TMADJ$ and $TVADJ$ are fixed, at one in the base, except the one
that the government closure frees (Section 12.1). The rents $RM_c$, $RE_c$ and
$RA_a$ are fixed, at zero in the base, under every closure (from version
0.4.4). A constraint (Section 16) adds an equation and frees one variable
that the closure fixes, so the system stays square.

**Swaps** (from version 0.4.5). After the options above, a closure may fix
any free variable element provided it frees a fixed one: `swap(GSAV GADJ)`
fixes government savings and frees government consumption, `swap(EXR CPI)`
makes the exchange rate the numeraire. Variables computed from their
definitions in the reduced system (Section 4 of design.md) cannot be fixed.

Variable and equation counts must be checked for every closure: the number of
free variables must equal the number of equations. From version 0.4.5 a
closure is also rejected if an equation is left with no free variable, which
would make the Jacobian singular (a structural check over the pattern of
the Jacobian).

## 7. Calibration

Calibration reads the SAM, with cell $SAM(r, c)$ the payment from column account
$c$ to row account $r$. Base values carry a superscript 0.

### 7.0 SAM checks and supported flows

Before calibration the SAM must be square, with identical row and column labels,
balanced (each row total equals the column total within $10^{-8}$ times the
largest absolute cell), and every account with a non-zero flow must be mapped to
a role. Every non-zero cell must be one of the flows below. Any other flow stops
calibration with an error that names the paying and receiving accounts; the
Stata implementation lists every such flow, grouped by role, before stopping.
Reading, aggregating and balancing a SAM before it is mapped are described in
[sam_tools.md](sam_tools.md) (from version 0.3.0); they do not change the model.

| Paid by (column) | Received by (row) |
|---|---|
| commodity $c$ | activities (domestic output); rest of world (imports); import, sales and export tax accounts; margin accounts (margins, from version 0.1.7) |
| activity | commodities (intermediate inputs); factors; activity tax account |
| factor | households; enterprises; government; rest of world; health insurance fund (contributions, from version 0.1.13) |
| household | commodities; direct tax account; savings-investment; households and enterprises (transfers); rest of world (transfers) |
| enterprise | direct tax account; savings-investment; households and enterprises (transfers); rest of world (transfers) |
| government | commodities; households and enterprises (transfers); government (internal transfers); rest of world (transfers); savings-investment; health insurance fund (from version 0.1.13) |
| tax account | government |
| savings-investment | commodities (investment, including changes in inventories) |
| margin account | commodities (margin services, from version 0.1.7) |
| health insurance fund | commodities (purchases); savings-investment (from version 0.1.13) |
| rest of world | commodities (exports); households, enterprises and government (transfers); factors (factor income from abroad); savings-investment; health insurance fund (from version 0.1.13) |

Negative cells are allowed only in tax rows, the savings-investment row,
transfer cells (the flows labelled "transfers" above, and factor income from
abroad), tax-account payments to the government, investment demand (from
version 0.1.4, for a fall in inventories; investment demand, including
inventory changes, is scaled by $IADJ$) and sales of commodities by activities
(from version 0.1.4: a negative entry in the make matrix gives a negative yield;
the mapping report lists such cells as a note, and each activity's output and
each commodity's domestic output must still be positive). In version 0.1 every activity needs
positive output and value added. Every commodity needs domestic output or
imports. Before version 0.1.7 every commodity needed domestic sales, and before
version 0.1.8 exports could not exceed domestic output. An account with no
flows at all needs no role.

#### Layouts rewritten before the checks (from version 0.1.1)

National SAMs often record five kinds of flow differently. They are rewritten
into the standard layout before the checks above:

1. **Exports recorded as sales by activities.** A cell $SAM(a, row)$ is treated
   as exports of the commodity paired with $a$: it is added to $SAM(c(a), row)$
   and to $SAM(a, c(a))$, and set to zero. Activity $a$'s output and the rest of
   the world's spending are unchanged; the commodity's supply and demand both
   rise by the exports.
2. **Taxes paid directly to the government account.** A tax option of the
   mapping (direct, sales, import, export or activity tax) may name the
   government account itself. The government row's cells in the paying columns
   of that tax (households and enterprises for the direct tax, commodities for the sales,
   import and export taxes, activities for the activity tax) are then moved to
   a new internal tax account, whose column pays their total to the
   government. Government revenue is unchanged. At most one of the sales,
   import and export tax options may name the government account, because the
   cells would otherwise be ambiguous; when product taxes are recorded as one
   flow per product, they can only be treated as one tax.
3. **Margins netted out of margin activities (from version 0.1.3).** Some SAMs
   attribute trade and transport margins to the producing activities, as their
   purchases of trade and transport services, and net the margin revenue out of
   the trade and transport activities' output by recording a negative use of
   their own product, $SAM(c(a), a) < 0$. For each activity named in the
   mapping's margins option, the negative cell is moved to output: $-SAM(c(a), a)$
   is added to $SAM(a, c(a))$, and $SAM(c(a), a)$ is set to zero. The activity's
   output then equals its costs (intermediate inputs and value added), and the
   margins enter the model as the producing activities' fixed-coefficient
   purchases of trade and transport services, exactly as the SAM records them.
   Naming an activity without a negative use of its own product is an error.
   Only the net negative amount is recorded, so the activity's genuine use of
   its own product cannot be separated from the netted margins; after the
   rewrite that use is zero.
   Margins therefore scale with each producer's output rather than separately
   with domestic sales, imports and exports, and imports carry no margins unless
   the SAM attributes them; a margin mechanism by product and market requires
   margin data from supply-use tables.

4. **Territorial correction (from version 0.1.4).** National accounts move
   household consumption from the territory to the residents' concept with a
   correction account: residents' purchases abroad are recorded as its imports,
   non-residents' purchases in the country as its exports (sometimes in the row
   of a matching activity), and the net as a negative household consumption of
   the correction. For the commodity (and, optionally, activity) named in the
   mapping's territorial option, the activity's exports are first moved to the
   commodity (rewrite 1), and the activity must then have no flows. Let $IM$ be
   the commodity's imports, $EX$ its exports and $HC_h$ household $h$'s
   consumption of it, with $\sum_h HC_h = IM - EX$; the commodity may have no
   other flows. Each household's share is $s_h = HC_h / \sum_h HC_h$.
   Residents' purchases abroad become household payments to the rest of the
   world, $SAM(row, h) \mathrel{+}= s_h\,IM$, and non-residents' purchases become
   transfers from the rest of the world to households,
   $SAM(h, row) \mathrel{+}= s_h\,EX$; the correction's cells are then set to
   zero. Household consumption of other commodities, which includes
   non-residents' purchases, is unchanged.
5. **Stock-change account (from version 0.1.7).** Some SAMs record changes in
   inventories in a separate account, financed by savings-investment,
   $SAM(stk, sav)$, and buying commodities, $SAM(c, stk)$ (negative for a fall in
   inventories). For an account named in the mapping's stocks option, its
   payments are added to the savings-investment column and its row and column
   are set to zero, which removes savings-investment's payment to it. The
   account may receive payments only from savings-investment. Changes in
   inventories then form part of investment demand, scaled by $IADJ$.

Rewrites 1, 2, 4 and 5 leave every total that enters the model unchanged,
except that rewrite 4 replaces the correction's imports, exports and negative
consumption by transfers; rewrite 3 raises the margin activities' output and the
supply and demand of their products by the margins. The mapping report lists
the amounts rewritten.

Margin accounts (from version 0.1.7) are a role, not a rewrite. A margin account
collects margins from commodities, $SAM(t, c)$, and buys margin services,
$SAM(c', t)$; it may have no other flows.

### 7.1 Normalisation

All base prices are normalised: $PA^0_a = PX^0_c = PD^0_c = PE^0_c = PQ^0_c = PVA^0_a = 1$
($PX$ and $PD$ for $c \in CX$),
$EXR^0 = 1$, $pwm_c = 1$, $W^0_f = 1$ and $WFDIST^0_{fa} = 1$ unless factor
quantities are supplied (Section 7.7).

### 7.2 Taxes and trade

- $QM^0_c = SAM(row, c)$; $tm_c = SAM(tax_{imp}, c) / QM^0_c$; $PM^0_c = 1 + tm_c$.
- $QA^0_a$ = column total of activity $a$; $ta_a = SAM(tax_{act}, a) / QA^0_a$.
- Yields $\theta_{ac} = SAM(a, c) / QA^0_a$; $QX^0_c = \sum_a SAM(a, c)$. $CX$ is
  the set of commodities with $QX^0_c > 0$.
- Exports: a commodity with $SAM(c, row) > 0$ belongs to $CR$ if
  $SAM(c, row) - SAM(tax_{exp}, c) \geq QX^0_c$, and to $CE$ otherwise.
- For $c \in CE$: $te_c = SAM(tax_{exp}, c) / SAM(c, row)$;
  $QE^0_c = SAM(c, row) - SAM(tax_{exp}, c)$; $pwe_c = 1/(1 - te_c)$; and
  $QD^0_c = QX^0_c - QE^0_c$.
- For $c \in CR$: $\overline{qer}_c = QER^0_c = SAM(c, row)$, $pwe_c = 1$ and
  $QD^0_c = QX^0_c$. An export tax on such a commodity is an error.
- For other commodities, $QD^0_c = QX^0_c$.
- Margins paid by commodity $c$: $MG^0_c = \sum_{t \in T} SAM(t, c)$.
- $QQ^0_c = QD^0_c + PM^0_c\,QM^0_c + SAM(tax_{sal}, c) + MG^0_c$ and
  $tq_c = SAM(tax_{sal}, c) / QQ^0_c$. VAT is not part of $QQ^0_c$; with
  VAT, the uses of each commodity are quantities at $PQ^0_c = 1$ derived
  from the SAM values as in Section 12.2.
- Margin services: $QT^0_{c'} = \sum_{t \in T} SAM(c', t)$, and
  $icm_{c'c} = \sum_{t \in T} SAM(t, c)\,\dfrac{SAM(c', t)}{\sum_{c''} SAM(c'', t)} \Big/ QQ^0_c$,
  so that margins collected by account $t$ are spent on services in the
  proportions that $t$ buys them.

SAM balance implies that $QQ^0_c$ equals total demand for $c$ at purchaser
prices, other than exports from domestic output and VAT: the commodity row
total minus $QE^0_c$ and $SAM(vat, c)$, including purchases of margin services by margin accounts and exports
from composite supply. Calibration must verify this identity, not assume it.

### 7.3 Production

- $QINTA^0_a = \sum_c SAM(c, a)$; $ica_{ca} = SAM(c, a) / QINTA^0_a$.
- $QF^0_{fa} = SAM(f, a) / (W^0_f\,WFDIST^0_{fa})$; $QVA^0_a = \sum_f SAM(f, a)$.
- $iva_a = QVA^0_a / QA^0_a$; $inta_a = QINTA^0_a / QA^0_a$.
- CES top nest: with $r_a = (PVA^0_a/PINTA^0_a)\,(QVA^0_a/QINTA^0_a)^{1+\rho^{a}_a}$,
  $\delta^{a}_a = r_a/(1+r_a)$ and $1-\delta^{a}_a = 1/(1+r_a)$ (both stored);
  $aa_a = QA^0_a / \left[\delta^{a}_a\,(QVA^0_a)^{-\rho^{a}_a} + (1-\delta^{a}_a)\,(QINTA^0_a)^{-\rho^{a}_a}\right]^{-1/\rho^{a}_a}$.
- Cobb-Douglas top nest: $\delta^{a}_a = PVA^0_a\,QVA^0_a / (PVA^0_a\,QVA^0_a + PINTA^0_a\,QINTA^0_a)$
  and $aa_a = QA^0_a / \left[(QVA^0_a)^{\delta^{a}_a}\,(QINTA^0_a)^{1-\delta^{a}_a}\right]$.
- CES value added: with $w_{fa} = W^0_f\,WFDIST^0_{fa}$,
  $\delta^{va}_{fa} = w_{fa}\,(QF^0_{fa})^{1+\rho^{va}_a} / \sum_{f'} w_{f'a}\,(QF^0_{f'a})^{1+\rho^{va}_a}$
  and $ad_a = QVA^0_a / \left[\sum_f \delta^{va}_{fa}\,(QF^0_{fa})^{-\rho^{va}_a}\right]^{-1/\rho^{va}_a}$.
- Cobb-Douglas value added: $\delta^{va}_{fa} = SAM(f, a) / QVA^0_a$ and
  $ad_a = QVA^0_a / \prod_f (QF^0_{fa})^{\delta^{va}_{fa}}$.
- Factor efficiency (from version 0.1.14): $af_f = EFF^0_f = 1$, so the
  parameters above are unchanged;
  $HS^0 = \sum_{c \in HC} \left[\sum_h SAM(c, h) + SAM(c, gov) + SAM(c, shi)\right]$,
  which must be positive when some $\eta_f > 0$.

### 7.4 CET and Armington functions

- $\delta^{t}_c = 1 / \left[1 + (PD^0_c/PE^0_c)\,(QE^0_c/QD^0_c)^{\rho^{t}_c-1}\right]$;
  $at_c = QX^0_c / \left[\delta^{t}_c\,(QE^0_c)^{\rho^{t}_c} + (1-\delta^{t}_c)\,(QD^0_c)^{\rho^{t}_c}\right]^{1/\rho^{t}_c}$.
- $\delta^{q}_c = \dfrac{(PM^0_c/PD^0_c)\,(QM^0_c/QD^0_c)^{1+\rho^{q}_c}}{1 + (PM^0_c/PD^0_c)\,(QM^0_c/QD^0_c)^{1+\rho^{q}_c}}$;
  $aq_c = QQ^0_c / \left[\delta^{q}_c\,(QM^0_c)^{-\rho^{q}_c} + (1-\delta^{q}_c)\,(QD^0_c)^{-\rho^{q}_c}\right]^{-1/\rho^{q}_c}$
  for imported commodities with domestic output, $aq_c = QQ^0_c / QD^0_c$ for
  non-imported ones, and $aq_c = QQ^0_c / QM^0_c$ for those imported only.
- Implementation note: both implementations store the complements
  $1-\delta^{t}_c$ and $1-\delta^{q}_c$ as separate parameters, computed from the
  same ratio as the shares (for example $1-\delta^{t}_c = r/(1+r)$ with
  $\delta^{t}_c = 1/(1+r)$), and use them in T1, T2, T4 and T5. Computing
  $1-\delta$ by subtraction loses most significant digits when one share is
  close to one, as happens with a low CET elasticity and a small export share,
  and can leave a benchmark residual near $10^{-7}$.

### 7.5 Institutions

- $YF^0_f$ = row total of factor $f$; $tshi_f = SAM(shi, f) / YF^0_f$ (zero
  without a fund, and below one); $shif_{if} = SAM(i, f) / \left[(1-tshi_f)\,YF^0_f\right]$
  for $i \neq shi$.
- Health insurance fund: $YSHI^0$ = row total of $shi$; $\overline{qshi}_c = SAM(c, shi)$;
  $sshi = SAM(sav, shi) / YSHI^0$; $trnsfr_{shi,gov} = SAM(shi, gov)$,
  $trnsfr_{shi,row} = SAM(shi, row)$; $SHIADJ^0 = 1$.
- $YI^0_d$ = row total of institution $d \in D$;
  $\overline{tins}_d = SAM(tax_{dir}, d) / YI^0_d$.
- $\overline{mps}_d = SAM(sav, d) / \left[(1 - \overline{tins}_d)\,YI^0_d\right]$.
- Income after direct taxes and savings:
  $DY^0_d = YI^0_d - SAM(tax_{dir}, d) - SAM(sav, d)$. Calibration stops with an
  error if $DY^0_d = 0$ while $d$ makes transfers or consumes.
- $shii_{dd'} = SAM(d, d') / DY^0_{d'}$; $shir_d = SAM(row, d) / DY^0_d$.
- $EH^0_h = \sum_c SAM(c, h)$; $hc_h = EH^0_h / DY^0_h$; budget shares
  $w_{ch} = SAM(c, h) / EH^0_h$.
- Cobb-Douglas demand: $\beta_{ch} = w_{ch}$ and $\gamma_{ch} = 0$.
- LES demand (from version 0.1.11), given income elasticities $\varepsilon_c > 0$
  and a Frisch parameter $\phi_h < -1$ for each household:
  $\beta_{ch} = \varepsilon_c\,w_{ch} / \sum_{c'} \varepsilon_{c'}\,w_{c'h}$, so that the
  marginal shares sum to one (the income elasticities used are then
  $\beta_{ch}/w_{ch}$, proportional to those supplied), and
  $\gamma_{ch} = QH^0_{ch} + \beta_{ch}\,EH^0_h / (PH^0_c\,\phi_h)$. Supernumerary
  spending $EH^0_h - \sum_c PQ^0_c\gamma_{ch}$ is then $-EH^0_h/\phi_h$, positive
  and below total spending because $\phi_h < -1$. Household consumption must be
  non-negative.
- $trnsfr_{d,gov} = SAM(d, gov)$, $trnsfr_{gov,gov} = SAM(gov, gov)$,
  $trnsfr_{d,row} = SAM(d, row)$, $trnsfr_{f,row} = SAM(f, row)$,
  $trnsfr_{gov,row} = SAM(gov, row)$, $trnsfr_{row,gov} = SAM(row, gov)$.
- $\overline{qg}_c = SAM(c, gov)$, $\overline{qinv}_c = SAM(c, sav)$ (divided by
  $1 + tv_c$ with VAT, Section 12.2),
  $GSAV^0 = SAM(sav, gov)$, $FSAV^0 = SAM(sav, row)$.
- $TINSADJ^0 = MPSADJ^0 = IADJ^0 = GADJ^0 = 1$.
- $cwts_c = \sum_h SAM(c, h) / \left[(1+tv_c) \sum_{c'} \sum_h SAM(c', h)\right]$, so
  that $CPI^0 = 1$;
  $dwts_c = QD^0_c / \sum_{c'} QD^0_{c'}$.

SAM balance implies $hc_h = 1 - \sum_d shii_{dh} - shir_h$ for households and
$\sum_d shii_{de} + shir_e = 1$ for enterprises; calibration verifies both.

### 7.6 Tax accounts

Each tax is recorded in a tax account whose row collects the tax and whose
column pays only the government, either in the SAM itself (as in the synthetic
SAM) or as an internal account created when taxes are paid directly to the
government account (Section 7.0).

### 7.7 Factor quantities

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

In checks 3 and 5 a deviation is measured relative to the value concerned, with
a floor of one; for a variable whose base value is zero ($WALRAS$) it is
measured relative to the largest SAM entry, as in check 4. The checks then give
the same result whatever the units of the SAM.

## 9. Reporting (from version 0.1.15)

`cge_report` and the Python function `cge_ref.report()` compute the same
measures, at the base point and at each solution. Real measures are valued at
base prices $PQ^0_c$, $PVA^0_a$ and $EXR^0$, and trade at base world prices
$pwm^0_c$, $pwe^0_c$; nominal measures use current prices and parameters.

| Measure | Definition |
|---|---|
| Nominal GDP | $\sum_c PH_c\,(\sum_h QH_{ch} + QG_c + QINV_c + QSHI_c) + \sum_c PQ_c\,QER_c + EXR\sum_c pwe_c QE_c - EXR\sum_c pwm_c QM_c$, less premiums paid abroad (from version 0.4.4, Section 16.1) |
| Real GDP | the same at base prices ($PH^0_c$, $PQ^0_c$) and base world prices |
| GDP deflator | nominal GDP / real GDP |
| Real consumption, government consumption, investment, fund purchases | $\sum_c PH^0_c$ times $\sum_h QH_{ch}$, $QG_c$, $QINV_c$, $QSHI_c$ |
| Real exports, imports | $EXR^0\sum_c pwe^0_c QE_c + \sum_c PQ^0_c QER_c$; $EXR^0\sum_c pwm^0_c QM_c$ |
| Real value added | $\sum_a PVA^0_a QVA_a$ |
| Real exchange rate | $EXR / DPI$ |
| Private savings | $\sum_d MPS_d (1 - TINS_d) YI_d$ |
| Revenue by tax | direct $\sum_d TINS_d YI_d$; sales $\sum_c tq_c TQADJ\,PQ_c QQ_c$; import $EXR \sum_c tm_c TMADJ\,pwm_c QM_c$; export $EXR\sum_c te_c pwe_c QE_c$; activity $\sum_a ta_a PA_a QA_a$; VAT (I8) |
| Public debt (Section 12.3, when the model has debt) | interest paid at home $r^d DD$ and abroad $r^f DF\,EXR$; primary balance $GSAV + r^d DD + r^f DF\,EXR$; debt at the end of the period at home $DD + (1-\phi)(-GSAV)$ and abroad, in local currency, $\left[DF + \phi(-GSAV)/EXR\right] EXR$; their total, and the total in per cent of nominal GDP |
| Real wage | $W_f / CPI$ |
| Labour force, unemployment rate (Section 14, $f \in FL$) | $QLF_f$; $100\,(1 - QFS_f / QLF_f)$ |
| Exports of a commodity | $QE_c + QER_c$ |

Other measures are model variables: $CPI$, $DPI$, $EXR$, $FSAV$, $YG$, $EG$,
$GSAV$, $YI_d$, $EH_h$, $W_f$, $YF_f$, $QFS_f$, $QA_a$, $PA_a$, $QVA_a$, $QQ_c$,
$PQ_c$, $QX_c$, $QD_c$, $QM_c$, and, when the model has them, $HS$, $EFF_f$
(for $\eta_f > 0$), $YSHI$ and $SHIADJ$.

Welfare, for household $h$ with expenditure function
$E_h(PQ, u) = \sum_c PQ_c\gamma_{ch} + u\prod_c PQ_c^{\beta_{ch}}$
(Cobb-Douglas when $\gamma = 0$; with VAT, $PQ$ stands for $PH$ in these
formulas), base spending $EH^0_h$ and new spending
$EH_h$:

$$EV_h = \sum_c PQ^0_c\gamma_{ch} + \Big(EH_h - \sum_c PQ_c\gamma_{ch}\Big)\prod_c \Big(\frac{PQ^0_c}{PQ_c}\Big)^{\beta_{ch}} - EH^0_h$$

$$CV_h = EH_h - \sum_c PQ_c\gamma_{ch} - \Big(EH^0_h - \sum_c PQ^0_c\gamma_{ch}\Big)\prod_c \Big(\frac{PQ_c}{PQ^0_c}\Big)^{\beta_{ch}}$$

Both are positive for a gain and reported in per cent of $EH^0_h$. Rates in
per cent (public debt in per cent of GDP, unemployment rates) change by
$x - x^0$ percentage points (from version 0.3.3). Other percentage changes are
$100\,(x - x^0)/|x^0|$, and missing when $x^0 = 0$.

## 10. Recursive dynamics (from version 0.2.0)

A dynamic run solves the static model of Sections 5 to 7 for periods
$t = 0, 1, \dots, T$. Period 0 is the calibrated base. Agents do not look
ahead: each period is an equilibrium given the stocks and exogenous values of
that period, which are updated from the previous period's solution. The
updates follow the recursive dynamic extension of the standard model
(Thurlow 2004); the rates are chosen by the user, and none has a default
other than zero.

Before period $t \geq 1$, in this order:

1. **Capital.** For each capital factor $f \in K$, with depreciation rate
   $\delta_f$ and base gross rental rate $\rho_f$ (rental per unit of capital
   at base prices, so the base capital stock is $YF^0_f / \rho_f$), new
   capital in the factor's units is
   $$N_{f,t} = \rho_f\,\omega_f\,INV_{t-1}, \qquad INV_{t-1} = \sum_c PQ^0_c\,QINV_{c,t-1}, \qquad \omega_f = YF^0_f \Big/ \sum_{f' \in K} YF^0_{f'},$$
   real investment at base prices shared among capital factors by base
   income. If $f$ is specific to each activity,
   $$QF_{fa,t} = (1-\delta_f)\,QF_{fa,t-1} + N_{f,t}\,\eta_{fa,t},$$
   with allocation shares that favour activities whose rental rate is above
   the average,
   $$\eta_{fa,t} \propto \max\Big[0,\; s_{fa}\Big(1 + \beta\Big(\frac{R_{fa}}{\bar R_f} - 1\Big)\Big)\Big], \qquad s_{fa} = \frac{QF_{fa,t-1}}{\sum_{a'} QF_{fa',t-1}}, \quad R_{fa} = W_{f,t-1}\,WFDIST_{fa,t-1}, \quad \bar R_f = \sum_a s_{fa} R_{fa},$$
   normalised to sum to one; $\beta \geq 0$ is the sensitivity of
   investment to rental differences (default 1). If $f$ is mobile,
   $QFS_{f,t} = (1-\delta_f)\,QFS_{f,t-1} + N_{f,t}$. A capital factor may
   not be unemployed.
2. **Other factors.** $QFS_{f,t} = (1+g_f)\,QFS_{f,t-1}$ for a mobile factor;
   $QF_{fa,t} = (1+g_f)\,QF_{fa,t-1}$ for an activity-specific one. The
   supply of an unemployed factor is endogenous, so $g_f$ must be zero.
3. **Population.** $\gamma_{ch,t} = (1+g_P)\,\gamma_{ch,t-1}$ (and
   $\gamma^h_{ah}$ alike), $HS^0_t = (1+g_P)\,HS^0_{t-1}$ and the population
   index $POP_t = (1+g_P)\,POP_{t-1}$: subsistence consumption grows with the
   population, and the health link compares health services per head. With
   a mortality rate (from version 0.3.4), $g_P$ becomes $g_{P,t}$ of Section
   15.4, and factors that lose workers to deaths grow at $g_{f,t}$.
4. **Government and foreign flows.** $\overline{qg}_c$,
   $trnsfr_{d,gov}$, $trnsfr_{gov,gov}$ and $trnsfr_{shi,gov}$ grow at $g_G$;
   flows in foreign currency ($trnsfr_{d,row}$, $trnsfr_{f,row}$,
   $trnsfr_{gov,row}$, $trnsfr_{row,gov}$, $trnsfr_{shi,row}$, and $FSAV$ when
   it is fixed) grow at $g_W$. Other fixed values, including the numeraire,
   are unchanged.
5. **Public debt** (from version 0.3.1, when the model has debt). The
   deficit of period $t-1$, $-GSAV_{t-1}$, is borrowed, a share $\phi$
   abroad:
   $$DD_t = DD_{t-1} + (1-\phi)\,(-GSAV_{t-1}), \qquad DF_t = DF_{t-1} + \phi\,(-GSAV_{t-1}) / EXR_{t-1}.$$
   A surplus repays debt in the same shares. Interest in period $t$ is
   paid on these stocks (I3, I9, S3).
6. **Shocks** for period $t$, if any, are applied; they may change the
   debt stocks and interest rates.
7. **Efficiency.** $ad_{a,t} = \lambda_{a,t}\,ad_{a,t-1}$, with
   $\lambda_{a,t} = 1 + g^{ad}_a$; or a uniform $\lambda_t$ given by a
   baseline run; or, to calibrate a baseline to growth targets, the uniform
   $\lambda_t$ for which real value added at base prices,
   $\sum_a PVA^0_a\,QVA_{a,t}$, equals $(1+g^Y_t)$ times its value in
   $t-1$. That $\lambda_t$ is found by secant iterations starting from
   $\lambda = 1$ and $\lambda = 1 + g^Y_t$, to a relative gap of $10^{-13}$.

Period $t$ is then solved from the solution of $t-1$. Scenarios that change
policy should reuse the baseline's $\lambda_t$, so that efficiency does not
respond to the scenario.

### 10.6 Perfect foresight (from version 0.10.2)

`cge_dynamic, foresight` sets the exogenous path period by period first:
`_cge_fs_advance()` makes steps 2 to 4 without the effect of deaths, the shocks
program runs, and `_cge_fs_record()` makes step 7 with rates or a baseline and
keeps the parameters and fixed values of the period (`FS.P`, `FS.X`). The
states (`_cge_fs_states()`), kind 1 the capital stocks (`QF` by activity for a
specific factor, `QFS` for a mobile one), 2 and 3 the domestic and foreign
debt, 4 the efficiency index $\Lambda_t$ of growth targets, 5 the population
ratio $\rho_t$ and 6 the ratio $\mu_{f,t}$ of the workers of each death factor
to their exogenous path, enter the period through `_cge_fs_map()`: capital
stocks as fixed values, debt as `ddebt` and `fdebt`, $ad\,\Lambda_t$, $\gamma$,
$\gamma^h$, `hs0` and `pop` times $\rho_t$, and the death factors' fixed
supplies and `qlf` times $\mu_{f,t}$. `_cge_fs_phi()` gives the updates from
period $t-1$ with their derivatives: step 1, step 5, and
$\rho_t = \rho_{t-1}(1 + g_P + e_{t-1})/(1 + g_P)$,
$\mu_{f,t} = \mu_{f,t-1}(1 + g_f + \kappa e_{t-1})/(1 + g_f)$ with
$e_{t-1} = mort0 - mort\,(HS_{t-1}/hs0_{t-1})^{epsm}$ and
$\kappa = deathshare/workingage$. A shock in period $t$ to a capital or debt
state is $s_t = a_t + b_t \tilde s_t$ (`FS.sa`, `FS.sb`), found by
`_cge_fs_probe()` from two runs of the shocks program; with growth targets
`ad`, and with a death rate $\gamma$, $\gamma^h$, `hs0`, `pop` and the death
factors' supplies and `qlf`, may not be shocked, and the closure and
constraints stay fixed (`_cge_fs_shockcheck()`, error 198).

The stacked unknowns are the free variables of the full system of every
period (scaled) and the states of every period after the first (scaled by
their base value or 1); the equations are each period's scaled residuals
(`_cge_F()`, with `p.xlag`, `p.xlead` and `p.tinfo` set by `_cge_fs_build()`)
and the updates, $(s_t - a_t - b_t \Phi)/scale$, or for $\Lambda_t$ the target
$(VA_t - (1 + g^Y_t) VA_{t-1})/VA^0$. Beyond the last period $T$,
`lead(V, k)` is $V_T$ (constant), $V_T (V_T/V_{T-1})^{t+k-T}$ (growth, with a
factor of 1 where either value is zero) or the base. `_cge_fs_jac()` gives the
Jacobian: `_cge_jac_trip()` with the capital stocks as columns after the free
ones, the derivatives in states of kinds 2 to 6 (`_cge_fs_sder()`, exact
from version 0.32.0, Section 42; before, central differences), `_cge_fs_ucross()` for the user equations with respect to lagged and
later values (codes $pos + k\,n_x$ for lags and $pos + (4 + k)\,n_x$ for leads
in `_cge_u_dvalue()`), and the derivatives of the updates. `_cge_fs_newton()`
solves the stacked system with a line search and the sparse LU (external
`cge__slu_fs`), from a recursive run whose periods expect the next to repeat
the one before (`_cge_fs_warm()`) or from the base; constraints settle their
regimes by period as in Section 16.3. Each period is stored with method
`foresight`.

## 11. Link to household surveys (from version 0.2.2)

`cge_microsim` passes the results of a simulation to household survey data,
top-down and without feedback (Bourguignon, Bussolo and Pereira da Silva
2008). Each survey household $i$ belongs to a CGE household group $h(i)$ and
keeps its own income composition and, if given, budget shares. The CGE gives,
for each group $h$, the ratio of new to base values of each income source $k$,
with zero base values replaced by the ratio of the aggregate shown:

| Source | Ratio $\rho_{hk}$ | If the group's base value is zero |
|---|---|---|
| factor $f$ | $YIF_{hf} / YIF^0_{hf}$ | $YF_f / YF^0_f$ |
| government transfers (`gov`) | $trnsfr_{h,gov}\,CPI / (trnsfr^0_{h,gov}\,CPI^0)$ | $CPI / CPI^0$ |
| transfers from abroad (`row`) | $trnsfr_{h,row}\,EXR / (trnsfr^0_{h,row}\,EXR^0)$ | $EXR / EXR^0$ |
| transfers from other domestic institutions (`dom`) | $\sum_{d} shii_{hd}\,DY_d / \sum_{d} shii_{hd}\,DY^0_d$ | $CPI / CPI^0$ |
| indexed to prices (`cpi`) | $CPI / CPI^0$ | |
| unchanged (`fixed`) | 1 | |

With income components $y_{ik}$, the household's nominal consumption becomes
$$C^1_i = C^0_i\,\frac{\sum_k \rho_{h(i)k}\,y_{ik}}{\sum_k y_{ik}}\;\kappa_{h(i)}, \qquad \kappa_h = \frac{(1-MPS_h)(1-TINS_h)}{(1-MPS^0_h)(1-TINS^0_h)},$$
so that it follows its own income and its group's direct tax and savings
rates. A household with no income in the components given, or every
household when no components are given, follows its group's consumption:
$C^1_i = C^0_i\,EH_h/EH^0_h$. The household's price index is
$$P_i = \sum_c s_{ic}\,\frac{PH_c}{PH^0_c},$$
at the prices households pay, including VAT, with $s_{ic}$ its survey budget
shares when budget items are mapped to commodities, and the group's base
shares $PH^0_c\,QH^0_{ch}/EH^0_h$ otherwise (home consumption, Section 13.1,
enters the group's shares at $PA_a$).
Real consumption is $R_i = C^1_i / P_i$; this is a first-order (Laspeyres)
approximation for LES households. With household size $n_i$ and weight $w_i$,
poverty measures use consumption per person, $r_i = R_i/n_i$ (base
$C^0_i/n_i$), and person weights $w_i n_i$:
$$FGT_\alpha = \frac{\sum_i w_i n_i\,\mathbf{1}[r_i < z]\,\big((z - r_i)/z\big)^\alpha}{\sum_i w_i n_i}, \qquad \alpha = 0, 1, 2,$$
for a poverty line $z$, and the Gini coefficient is that of $r_i$ over persons.

**Distribution and incidence (from version 0.8.0).** `sim()` takes several
simulations; the base is the same for all. A poverty line may be a number or
a variable, $z_i$ for each household (regional or household-specific lines),
and several lines may be given; for each, FGT0 to FGT2 use $z_i$ in place of
$z$, and the number of poor is $\sum_i w_i n_i\,\mathbf{1}[r_i < z_i]$. With
$v_i = w_i n_i$, $\mu = \sum v_i r_i / \sum v_i$ and $s_i = r_i/\mu$, over the
persons with $v_i > 0$:
$GE(0) = -\sum v_i \ln s_i / \sum v_i$ (mean log deviation),
$GE(1) = \sum v_i s_i \ln s_i / \sum v_i$ (Theil),
$GE(2) = \sum v_i (s_i^2 - 1) / (2 \sum v_i)$;
Atkinson $A(\varepsilon) = 1 - \big(\sum v_i r_i^{1-\varepsilon}/\sum v_i\big)^{1/(1-\varepsilon)}/\mu$,
$A(1) = 1 - \exp(\sum v_i \ln r_i / \sum v_i)/\mu$, for $\varepsilon = 0.5, 1, 2$;
measures that need $\ln r_i$ or $r_i^{1-\varepsilon}$ with $\varepsilon \ge 1$ are
missing when some $r_i \le 0$. With $L(p)$ the Lorenz curve over persons,
linear between households, Palma $= (1 - L(0.9))/L(0.4)$ and
$S80/S20 = (1 - L(0.8))/L(0.2)$.
Persons are ranked by base consumption per person into `quantiles(#)` groups
(default 10) as `xtile` forms them: with the values sorted, $W(i)$ their
cumulative person weight and $P = W(n)\,p/100$, the $p$-th percentile is the
value of the first $i$ with $W(i) > P$, or the mean of values $i-1$ and $i$ when
$W(i-1) = P$ (the definition of `_pctile`), and group $k$ holds the values
above percentile $100(k-1)/K$ up to percentile $100k/K$. For each group, the
same persons before and after: its population share, mean base and simulated
consumption per person and its per cent change, its shares of total
consumption, and its share of the total change. The growth incidence curve
(Ravallion and Chen 2003) compares percentiles $p = 1, \dots, 99$ of the
base and simulated distributions, $g(p) = 100\,(r^1(p)/r^0(p) - 1)$.
`clear` or `saving()` give every result as a dataset: one observation per
simulation, table (`summary`, `quantile`, `gic`), group, measure, line and
quantile, with the base, the simulated value, the change and the per cent
change.

**Welfare and decomposition (from version 0.8.1).** With $\lambda_i =
C^0_i/EH^0_h$, prices households pay $p$ (PH and PA) and the group's LES
parameters, household $i$ has
$EV_i = \lambda_i p^0\gamma_h + (C^1_i - \lambda_i p^1\gamma_h)\prod_j (p^0_j/p^1_j)^{\beta_{jh}} - C^0_i$ and
$CV_i = C^1_i - \lambda_i p^1\gamma_h - (C^0_i - \lambda_i p^0\gamma_h)\prod_j (p^1_j/p^0_j)^{\beta_{jh}}$,
so that a household that follows its group has $\lambda_i$ times the group's
$EV_h$ and $CV_h$; with budget items, Cobb-Douglas in its own shares $s_{ik}$,
$G_i = \prod_k (p^1_{j(k)}/p^0_{j(k)})^{s_{ik}}$, $EV_i = C^1_i/G_i - C^0_i$ and
$CV_i = C^1_i - C^0_i G_i$. Results give $\sum_i w_i EV_i / \sum_i w_i n_i$
per person and $100 \sum_i w_i EV_i / \sum_i w_i C^0_i$.
`decompose` writes $r^1_i = r^0_i\,f_i(\text{income channels})/P_i$ and
evaluates every measure for all $2^K$ subsets $S$ of the $K$ channels, with
the channels in $S$ at their simulated values and the others at the base:
each source $k$ multiplies its component by $\rho_{hk}$, `taxsav` the
income ratio by $\kappa_h$, `group` gives $EH_h/EH^0_h$ to households
without mapped income, and `prices` divides by $P_i$ (without `income()`,
the channels are `income`, $EH_h/EH^0_h$, and `prices`). The Shapley value
of channel $j$ is $\sum_{S \not\ni j} \frac{|S|!\,(K-|S|-1)!}{K!}\,
[I(S \cup \{j\}) - I(S)]$ (Shorrocks 2013); the values add up to
$I(r^1) - I(r^0)$. For poverty, with $P(\mu, L)$ the measure of the
distribution with mean $\mu$ and Lorenz curve $L$, growth is
$\frac12[P(\mu^1, L^0) - P(\mu^0, L^0) + P(\mu^1, L^1) - P(\mu^0, L^1)]$ and
redistribution
$\frac12[P(\mu^0, L^1) - P(\mu^0, L^0) + P(\mu^1, L^1) - P(\mu^1, L^0)]$
(Datt and Ravallion 1992, in Shapley form), computed from $r^0 \mu^1/\mu^0$
and $r^1 \mu^0/\mu^1$.

**Fiscal incidence (from version 0.8.2).** With market income $y^m_i$ and
instruments $T_{ik}$ of five types (direct taxes $D$, direct transfers $B$,
indirect taxes $I$, indirect subsidies $S$, in-kind benefits $K$), the CEQ
income concepts (Lustig 2018) are net market $y^n = y^m - D$, disposable
$y^d = y^n + B$, consumable $y^c = y^d - I + S$ and final $y^f = y^c + K$, per
person over persons, ranked by $y^m_i/n_i$. In a simulation each changes,
before deflation by $P_i$: $y^m$ as the household's income components
($Y^1/Y^0$) or its group's income $YI_h/YI^0_h$; $D$ by that ratio times
$TINS_h/TINS^0_h$; $B$ by $\rho_{h,gov}$; $I$ by $C^1_i/C^0_i$ times
$\bar\tau^1_i/\bar\tau^0_i$, with $\bar\tau_i = \sum_j s_{ij} w_j$ the
household's tax wedge, $w_j = 1 - (1 - tq_j TQADJ)/(1 + tv_j TVADJ)$ (0 for
home consumption) and $s^1_{ij} = s_{ij}(p^1_j/p^0_j)/P_i$; $S$ by
$C^1_i/C^0_i$; $K$ by the ratio of $PQ_c QG_c$ for its target commodity $c$, or
of $\sum_c PQ_c QSHI_c$ for `shi`. The concentration coefficient of $t$ is
$2\sum_i v_i t_i (F_i - 1/2)/\sum_i v_i t_i$, with $F_i$ the mid-point of
person $i$'s cumulative weight in the ranking (tied values sharing their
mid-point); Kakwani $K_T = C_T - G_m$ for taxes and $G_m - C_T$ for benefits;
$RE = G_m - G_f$, $RS = G_m - C_f$, reranking $G_f - C_f$; the marginal
contribution of $T$ to $I$ is $I(y^f \pm T) - I(y^f)$; fiscal impoverishment
is the share of persons with $y^c_i < y^m_i$ and $y^c_i/n_i < z_i$ (Higgins
and Lustig 2016).

**Reweighting, standard errors and bands (from version 0.8.3).** With
household characteristics $X$ (non-negative) and targets $T_k = \rho_k \sum_i
w_i x_{ik}$, where $\rho_k$ is the model's ratio of the employment of a factor,
$\sum_a QF_{fa}/\sum_a QF^0_{fa}$, or of a factor in an activity,
$QF_{fa}/QF^0_{fa}$, or a given number, the simulation's weights minimise the
relative entropy $\sum_i w^1_i \ln(w^1_i/w_i)$ subject to $X'w^1 = T$:
$w^1_i = w_i \exp(x_i'\lambda)$, with $\lambda$ found by Newton's method (the
largest relative deviation below $10^{-12}$; above $10^{-9}$ is error 430).
Simulated measures use $w^1$, base measures $w$; `decompose` has a channel
`weights`. With `svy`, a measure $\theta = \sum_i w_i d_i y_i / \sum_i w_i
d_i n_i$ over domain $d$ (mean: $y_i = n_i r_i$; FGT$_\alpha$: $y_i = n_i
\mathbf{1}[r_i < z_i]((z_i - r_i)/z_i)^\alpha$) has linearised values $u_i =
w_i d_i (y_i - \theta n_i)/\sum_j w_j d_j n_j$, and variance $\sum_h
\frac{n_h}{n_h - 1}\sum_j (u_{hj} - \bar u_h)^2$ over strata $h$ and clusters
$j$ (single stage, with replacement; missing with a single cluster in a
stratum), for the base, the simulation ($w^1$) and the change ($u^1 - u^0$).
`cge_sensitivity, keep(name)` stores each converged draw $d$ as simulation
`name`$d$ with its solution and parameters; `bands(name)` computes every
measure for all households for draws $1, 2, \dots$ and reports their 5th,
50th and 95th percentiles (as `_pctile`) and standard deviation.

**Graphs (from version 0.9.6).** `cge_microsim, graph()` posts the results
dataset in a preserved copy of the data and draws each graph from it
(`_cge_ms_graphs` in cge_microsim.ado): `gic` from the table gic, `incidence`
from quantile/mean, `groups` from summary/mean by group, `poverty` from
summary/fgt0 (100 times the change), `shapley` from shapley (fgt0 at the first
line, or mean), `fiscal` from fiscal/gini by concept, `bands` from the p5, p50
and p95 rows of bands.

## 12. Fiscal instruments (from version 0.3.1)

### 12.1 Revenue-neutral tax replacement

The sales tax, import tariff and VAT rates are scaled by $TQADJ$, $TMADJ$
and $TVADJ$ (P1, P3, P6, P8, I8), as direct tax rates are scaled by
$TINSADJ$ (I10). All four are fixed at one, except under a closure that fixes
government savings and names one of them as the adjusting instrument:

| `government()` | Fixed | Free |
|---|---|---|
| `flexgsav` (default) | $TINSADJ$, $TQADJ$, $TMADJ$, $TVADJ$, $GADJ$ | $GSAV$ |
| `fixgsav` or `fixgsav direct` | $GSAV$, $TQADJ$, $TMADJ$, $TVADJ$, $GADJ$ | $TINSADJ$ |
| `fixgsav sales` | $GSAV$, $TINSADJ$, $TMADJ$, $TVADJ$, $GADJ$ | $TQADJ$ |
| `fixgsav import` | $GSAV$, $TINSADJ$, $TQADJ$, $TVADJ$, $GADJ$ | $TMADJ$ |
| `fixgsav vat` | $GSAV$, $TINSADJ$, $TQADJ$, $TMADJ$, $GADJ$ | $TVADJ$ |

The instrument scales every base rate of that tax in proportion, so rates
that are zero in the base stay zero; the tax must raise revenue in the base.
With $GADJ$ fixed, government consumption is unchanged in real terms, so the
closure keeps government savings at their base value: in real terms under the
CPI numeraire, in terms of domestic producer prices under the DPI numeraire.
It replaces lost revenue, for example from a tariff cut, with whichever tax
the user chooses, and the scaling factor shows the rise in rates required.
Under these closures a shock to the instrument's own rates, such as removing
tariffs while tariffs adjust, is not meaningful: the scaling factor offsets
it.

### 12.2 Value added tax with input credits

VAT is charged on sales of each commodity at the rate $tv_c$, on the price
$PQ_c$ before VAT. Final users (households, the government, investment and
the health insurance fund) pay $PH_c = PQ_c(1 + tv_c)$. An activity recovers
the share $\kappa_a$ of the VAT on its inputs as a credit, and so pays
$PQ_c\,(1 + tv_c\,(1-\kappa_a))$ (P6). $\kappa_a = 1$, the default, is a
registered activity with full credits; $\kappa_a = 0$ an exempt or
unregistered one, which bears VAT on its inputs. Exports, whether from
domestic output or from composite supply, and purchases of margin services
are zero-rated. Net VAT revenue (I8) is therefore the VAT on final demand
plus the VAT that activities cannot recover.

**SAM.** VAT is recorded in a VAT account whose row collects VAT from the
commodity columns, $SAM(vat, c)$, net of credits, and whose column pays the
government (`cge_map` option `vattax()`). When the SAM records VAT within
the sales tax account, the option `vatshare()` gives the VAT share of each
commodity's sales tax; that share of $SAM(tax_{sal}, c)$ is moved to an
internal account `_vatshare` before the checks (as for taxes paid directly to
the government, Section 7.0). VAT cells may be negative. The flows added to
Section 7.0 are commodity to VAT account, and VAT account to government.

**Calibration.** With $PQ^0_c = 1$, each use $u$ of commodity $c$ recorded in
the SAM at value $V_{cu}$ (purchaser prices) is a quantity
$V_{cu}/(1 + tv_c\,k_u)$, where the VAT liability $k_u$ is 1 for final users,
$1-\kappa_a$ for activity $a$ and 0 for exports and margin services. The rate
$tv_c$ solves

$$SAM(vat, c) = \sum_u V_{cu}\,\frac{tv_c\,k_u}{1 + tv_c\,k_u},$$

which is increasing in $tv_c$ when the uses are positive. It is solved by
Newton's method from $tv_c = SAM(vat, c) / \sum_u k_u V_{cu}$, to a relative
change of $10^{-15}$; $tv_c = 0$ when $SAM(vat, c) = 0$. A commodity with VAT
but no use that bears it is an error. Then

- $QINT^0_{ca} = SAM(c, a) / (1 + tv_c(1-\kappa_a))$, $QINTA^0_a = \sum_c QINT^0_{ca}$,
  $ica_{ca} = QINT^0_{ca} / QINTA^0_a$ and
  $PINTA^0_a = \sum_c SAM(c, a) / QINTA^0_a$;
- $QH^0_{ch}$, $\overline{qg}_c$, $\overline{qinv}_c$ and $\overline{qshi}_c$ are the SAM
  values divided by $1 + tv_c$, and $PH^0_c = 1 + tv_c$;
- $QQ^0_c$ (Section 7.2) equals the sum of these quantities, margin services
  and exports from composite supply; calibration verifies it.

Spending values, budget shares $\beta_{ch}$ and the government and fund
accounts are unchanged, because they are values at purchaser prices. Without
VAT every quantity equals its SAM value, as before. The VAT rate and credit
shares can be shocked ($tv$, $\kappa$).

### 12.3 Public debt and interest

National SAMs record interest on public debt within government transfers: to
domestic institutions, $SAM(d, gov)$, and to the rest of the world,
$SAM(row, gov)$. Given the debt stocks at the start of the base year, held at
home $DD^0$ (local currency) and abroad $DF^0$ (foreign currency, equal to
local currency at $EXR^0 = 1$), and their interest rates $r^d$ and $r^f$,
calibration separates the interest from the other transfers:

$$trnsfr_{d,gov} = SAM(d, gov) - hold_d\,r^d\,DD^0, \qquad trnsfr_{row,gov} = SAM(row, gov) - r^f\,DF^0,$$

where $hold_d$ is the share of domestic interest received by institution $d$.
By default it is proportional to $SAM(d, gov)$, so that interest is the same
share of every institution's transfers; the user may give other shares, which
must be non-negative and sum to one. A non-interest transfer that would be
negative is an error: the SAM's transfers are then too small for the stated
debt and rate. The base equilibrium is unchanged, since at base prices the
interest terms of I3, I9 and S3 equal the transfers they replace.

Interest is then paid in nominal terms, on domestic debt in local currency
and on foreign debt in foreign currency (I3, I9, S3), while other transfers
keep their indexation. A static simulation can change the interest rates or
the stocks, for example a rise in $r^f$ or debt relief that lowers $DF$.

In a dynamic run (Section 10, step 5) the deficit is borrowed, the share
$\phi$ abroad; by default $\phi$ is the foreign share of the base debt,
$DF^0 / (DD^0 + DF^0)$. Net borrowing is modelled, not gross borrowing and
amortisation separately: maturing debt is assumed to be refinanced. The
change in the stock of foreign debt measured in local currency is net
foreign borrowing plus a valuation change, $DF_{t-1}\,(EXR_t - EXR_{t-1})$.
Neither default risk nor a link from debt to interest rates is modelled; the
rates are exogenous and can be changed by shocks.

## 13. Trade and household extensions (from version 0.3.2)

### 13.1 Home consumption

Households in many African economies consume part of what they produce. A
SAM records this as a payment from the household's column to the activity's
row, $SAM(a, h)$, at producer prices. The model treats it as a separate good:

- the activity's output $QA_a$ is marketed output, which yields commodities
  through $\theta_{ac}$ (Q6), plus home consumption $\sum_h QHA_{ah}$;
- home consumption is valued at the activity price $PA_a$, so it bears no
  sales tax, VAT, import competition or margins;
- it enters household demand (I5H) with its own marginal budget share
  $\beta^{h}_{ah}$ and, with LES demand, subsistence quantity $\gamma^{h}_{ah}$;
  consumption spending $EH_h$ (I4) includes it.

**Calibration.** $QHA^0_{ah} = SAM(a, h)$ (with $PA^0_a = 1$); marketed
output is $QA^0_a - \sum_h SAM(a, h)$, which must be positive, and
$\theta_{ac} = SAM(a, c)$ divided by it. $EH^0_h$ includes home consumption;
$\beta^{h}_{ah} = SAM(a, h) / EH^0_h$. With LES demand, home consumption of
the output of activity $a$ takes the income elasticity of $a$'s paired
commodity, and $\gamma^{h}_{ah} = QHA^0_{ah} + \beta^{h}_{ah}\,EH^0_h / (PA^0_a\,\phi_h)$.
The CPI keeps its weights on marketed consumption; welfare measures (Section
9) use the full expenditure function, with $PA_a$ for home goods. GDP
includes home consumption at $PA_a$ (real: $PA^0_a$). Population growth in
dynamic runs scales $\gamma^{h}$ as it scales $\gamma$.

### 13.2 Export demand

By default the country is small in world markets: it sells any quantity at
the world price $pwe_c$. For commodities given an elasticity of export demand
$\eta^{e}_c > 0$ (`cge_calibrate, exportdemand()`), the world price is a
variable $PWE_c$, and exports fall as it rises (T10). The CET (T1, T2) still
determines how much producers offer at the export price $PE_c$ (P2). A larger
$\eta^{e}_c$ approaches the small-country case. A change in $pwe_c$ shifts
world demand. Export revenue (S3), export taxes (I8) and nominal GDP use
$PWE_c$; real exports remain valued at base world prices.

### 13.3 Export-only commodities

When a commodity's domestic output is all exported, the SAM shows exports
equal to domestic output (net of export taxes and export margins), and no
domestic sales from domestic output. Before version 0.3.2 such a commodity
falls into $CR$ (exports at least domestic output, Section 7.2): its output
goes to the domestic market and exports are drawn from composite supply at
$PQ_c$. With `cge_calibrate, exportonly()` its output is exported directly
instead: $QD_c$ and $PD_c$ do not exist, the CET is replaced by T3E, and the
export price $PE_c$ is the producer price. If the commodity is also imported,
its composite supply is imports alone (T7); otherwise it has no composite
supply, and $PQ_c$ and $QQ_c$ do not exist. Calibration lists the
commodities whose exports equal domestic output, so that the choice is
explicit. An export-only commodity may pay export taxes.

### 13.4 Margins by market

Margins may differ between domestic sales, imports and exports, as in the
IFPRI standard model (Lofgren, Harris and Robinson 2002). A margin account
can be declared as paid per unit of domestic sales (`cge_map,
domesticmargins()`), of imports (`importmargins()`) or of exports
(`exportmargins()`); accounts in `marginaccounts()` keep the per-unit-of-supply
treatment of Section 5.3. With $MG_{tc} = SAM(t, c)$ and the shares in which
account $t$ buys margin services, $s_{c't} = SAM(c', t) / \sum_{c''} SAM(c'', t)$:

- $icd_{c'c} = \sum_{t \in T^D} s_{c't}\,MG_{tc} / QD^0_c$: domestic buyers pay
  $PDD_c$ (P3, T5), producers receive $PD_c$;
- $ici_{c'c} = \sum_{t \in T^M} s_{c't}\,MG_{tc} / QM^0_c$: margins are part of
  the import price $PM_c$ (P1);
- $ice_{c'c} = \sum_{t \in T^E} s_{c't}\,MG_{tc} / QE^0_c$: exporters receive the
  world price, less export taxes, less margins (P2).

Export margins are part of the export value in the SAM, so
$QE^0_c = SAM(c, row) - SAM(tax_{exp}, c) - \sum_{t \in T^E} MG_{tc}$ and
$pwe_c = SAM(c, row) / QE^0_c$, so that $PE^0_c = 1$. Base prices are
$PDD^0_c = 1 + \sum_{c'} icd_{c'c}$ and $PM^0_c = 1 + tm_c + \sum_{c'} ici_{c'c}$, which
enter the Armington shares (Section 7.4) in place of $PD^0_c$ and $PM^0_c$.
Composite supply $QQ^0_c$ excludes export margins. A commodity that pays
domestic, import or export margins must have domestic sales, imports or
exports respectively.

## 14. Labour-market regimes (from version 0.3.3)

### 14.1 Labour force and unemployment

For a factor $f \in FL$ the user gives the base unemployment rate $u^0_f$
(`cge_calibrate, unemployment()`), which SAMs do not record. $QFS_f$ is then
employment, and the labour force is

$$QLF_f = QFS^0_f / (1 - u^0_f),$$

exogenous (it grows in dynamic runs at the factor's growth rate), so that the
unemployment rate is $U_f = 1 - QFS_f / QLF_f$. Two regimes link the real
wage $W_f / CPI$ to unemployment. Each has an equation for every $f \in FL$,
whatever the closure, with a slack variable that the regime's closure fixes
at zero; under other closures the slack is free and the equation is inert.
The number of equations therefore does not depend on the closure.

### 14.2 Wage curve

Real wages fall as unemployment rises (Blanchflower and Oswald 1994):

$$\frac{W_f}{CPI} = \overline{w}_f \left(\frac{U_f}{u^0_f}\right)^{-\epsilon^{w}_f} + LSW_f \tag{L1}$$

with $\overline{w}_f = W^0_f / CPI^0$ and the elasticity $\epsilon^{w}_f > 0$ given
by the user (`wagecurve()`); it needs $u^0_f > 0$. Under the closure
`factors(f:wagecurve)` both $W_f$ and $QFS_f$ are free and $LSW_f = 0$: a fall
in labour demand lowers both employment and the real wage. A small elasticity
approaches unemployment at a fixed real wage; a large one, full employment.

### 14.3 Minimum wage

The real wage may not fall below a floor $\underline{w}_f$, and unemployment may
not be negative; one of them binds:

$$U_f \geq 0, \qquad \frac{W_f}{CPI\,\underline{w}_f} - 1 \geq 0, \qquad U_f\left(\frac{W_f}{CPI\,\underline{w}_f} - 1\right) = 0.$$

This complementarity condition is solved, with the rest of the model, in the
Fischer-Burmeister form (Fischer 1992), smoothed as in Kanzow (1996):

$$a + b - \sqrt{a^2 + b^2 + 2\mu} = LSM_f, \qquad a = U_f, \quad b = \frac{W_f}{CPI\,\underline{w}_f} - 1 \tag{L2}$$

which with $LSM_f = 0$ holds exactly when $a > 0$, $b > 0$ and $ab = \mu$. With
the default $\mu = 10^{-10}$ (`smoothing()`), the wage is at the floor to
within $\mu / U_f$ when unemployment is positive, and unemployment is at most
$\mu / b$ when the floor does not bind: for example $7 \times 10^{-10}$ with 15 per
cent unemployment. The regime is found by the solver, not chosen in advance.

**Calibration.** With unemployment in the base, $u^0_f > 0$, the floor binds and
is the base real wage: $\underline{w}_f = \overline{w}_f / (1 + \mu / u^0_f)$
(`minwage(f:1)`, the default). With full employment, $u^0_f = 0$, the floor is
given as a share $r < 1$ of the base real wage (`minwage(f:r)`), so that
$\underline{w}_f = r\,\overline{w}_f$; the base then has the unemployment rate
$\mu / (1/r - 1)$, which defines the labour force. Under the closure
`factors(f:minwage)`, $W_f$ and $QFS_f$ are free and $LSM_f = 0$.

The tests check the smoothed solutions against the exact regimes: with the
floor binding, against unemployment at the fixed wage $\underline{w}_f$; without,
against full employment of the labour force.

### 14.4 Results and dynamics

Reports show the labour force and the unemployment rate of each $f \in FL$. In
dynamic runs the labour force grows at the factor's growth rate, so that
employment is endogenous under both regimes (and under unemployment at a fixed
wage). The reference wage $\overline{w}_f$ and the floor $\underline{w}_f$ stay
constant in real terms; shocks may change them (`wref`, `wmin`), and the
labour force (`qlf`).

## 15. Health outcomes, days worked and demography (from version 0.3.4)

### 15.1 Health services per head

Health outcomes respond to health services per head relative to the base,

$$R = HS / HS^0,$$

where $HS$ is the volume of health services bought by households, the
government and the health insurance fund (H1), and $HS^0$ its base value,
which grows with the population in dynamic runs (Section 10, step 3). Each
outcome has a constant elasticity with respect to $R$. These elasticities
are hypotheses about how services become health, to be taken from studies
of the country or region (for example, Bokhari, Gai and Gottret 2007;
Anyanwu and Erhijakpor 2009); the package supplies none. An outcome whose
elasticity is zero is constant unless shocked, and needs no health
commodities.

### 15.2 Days lost to illness

For a factor $f \in FS$ the user gives the base share of working time lost
to illness, $0 \leq s^0_f < 1$ (`cge_calibrate, sickdays()`), for example
from a labour force or household survey, and its elasticity $\epsilon^{s}_f$
with respect to $R$ (`sickelas()`; negative when more services mean fewer
days lost). The share lost is $S_f = \sigma_f R^{\epsilon^{s}_f}$, with
$\sigma_f = s^0_f$ unless shocked (`cge_shock sick`, for example an
epidemic), and days worked per worker, relative to the base, are

$$DW_f = \frac{1 - \sigma_f R^{\epsilon^{s}_f}}{1 - s^0_f}, \qquad f \in FS \tag{H3}$$

and $DW_f = 1$ otherwise. Days worked scale the factor's effective input in
production, $\widetilde{QF}_{fa} = af_f\,EFF_f\,DW_f\,QF_{fa}$ (Q3, Q4).
Factor quantities $QF_{fa}$ and $QFS_f$, the wage $W_f$ and unemployment
(Section 14) stay per worker. In real terms fewer days per worker are the
same as less labour measured in days: with $L$ workers and $D$ days each, a
wage $w$ per effective unit pays $w\,D\,L$ whether the factor is counted in
workers or in days. $EFF_f$ (5.2) measures output per day worked; $DW_f$
the days worked. $S_f$ must stay below one.

### 15.3 Mortality

The user may give the base crude death rate $m^0$, deaths per head per
period (`mortality()`), and its elasticity $\epsilon^{m}$ with respect to $R$
(`mortelas()`). The death rate is

$$MR = \mu^{m} R^{\epsilon^{m}},$$

with $\mu^{m} = m^0$ unless shocked (`cge_shock mort`). It is reported, and
does not enter the equations of a period: deaths in period $t$ change the
population and labour from period $t+1$ (15.4), so each period is solved
with its population given.

### 15.4 Population and labour in dynamic runs

The population growth rate $g_P$ given for a run (`population()`) is taken
to hold at the base death rate. With a death rate, population grows from
$t-1$ to $t$ at

$$g_{P,t} = g_P + \left(m^0 - MR_{t-1}\right),$$

which scales the subsistence quantities, $HS^0$ and the population index
$POP$ (step 3 of Section 10). For the factors named in `deathfactors()`
(labour, not capital), deaths at working ages change the supply:

$$g_{f,t} = g_f + \frac{\theta^{D}}{\alpha^{W}}\left(m^0 - MR_{t-1}\right),$$

where $\theta^{D}$ is the share of deaths at working ages (`deathshare()`)
and $\alpha^{W}$ the working-age share of the population (`workingage()`):
excess deaths per head of the population, $MR - m^0$, remove a share
$\theta^{D} (MR - m^0) / \alpha^{W}$ of the working-age population, and the
factor's workers in the same proportion. The labour force of such a factor
(Section 14) grows at the same rate. $MR_{t-1}$ uses the parameters and
health services of period $t-1$, including its shocks.

In a baseline, rising health services per head lower the death rate and
raise population growth above $g_P$; scenarios are therefore compared with a
baseline run with the same settings.

### 15.5 Reporting

The health table shows, when the model has them: health services per head
$R$; the share of working time lost, $100\,S_f$ (per cent), and days worked
$DW_f$ for $f \in FS$; the death rate per 1,000, $1000\,MR$; and the
population index $POP$. Shares and rates change in points.

## 16. Bounds and complementarity (from version 0.4.4)

A model with only equalities cannot represent a limit that binds in some
scenarios and not in others: an import quota, a capacity limit, a ceiling on
borrowing. From version 0.4.4 such limits are complementarity conditions,
solved with the rest of the model, so that the solver finds which limits
bind.

### 16.1 Rents

Three rent variables give quotas and capacity limits their price effect. Each
is zero in the base and fixed by every closure, unless a constraint frees it
(Section 16.2):

| Variable | Description |
|---|---|
| $RM_c$ | premium on imports of $c \in CM$, per unit of the world price in local currency |
| $RE_c$ | premium on exports of $c \in CE$, per unit of the world price |
| $RA_a$ | rent on the output of activity $a$, per unit of the activity price |

They enter three price equations:

$$PM_c = pwm_c (1 + tm_c\,TMADJ + RM_c)\,EXR + \textstyle\sum_{c'} ici_{c'c} PQ_{c'} \tag{P1}$$

$$PE_c = pwe_c (1 - te_c - RE_c)\,EXR - \textstyle\sum_{c'} ice_{c'c} PQ_{c'} \tag{P2}$$

$$PA_a (1 - ta_a - RA_a) QA_a = PVA_a QVA_a + PINTA_a QINTA_a \tag{P7}$$

A premium is a wedge between the world price and the domestic price, like a
tariff, but its revenue is a rent. The rent on each element,

$$R^M_c = RM_c\,pwm_c\,EXR\,QM_c, \qquad R^E_c = RE_c\,pwe_c\,EXR\,QE_c, \qquad R^A_a = RA_a\,PA_a\,QA_a,$$

is paid to one recipient $\rho$: the government (the default, as when quota
licences are auctioned), a household or enterprise, a factor, or the rest of
the world (as with a voluntary export restraint, whose rents foreign
exporters keep). Rents are added to the incomes in I1 (factors), I3
(households and enterprises) and I8 (government). Rents paid abroad are added
to the payments abroad in S3, at $R / EXR$. A premium fixed at a positive
value (`cge_shock RM`) acts as a tariff whose revenue goes to the recipient.

**GDP.** The income side adds the rents received at home and every
capacity rent, which is value added produced at home wherever it is paid. The
expenditure side values imports and exports net of the rents paid abroad.

### 16.2 Constraints

A constraint $k$ pairs a limited variable $Y_k$ (one element of a variable,
for example $QM_{com\_man}$) and its bound $b_k$ with an adjusting variable
$X_k$, which the closure fixes at $\bar{x}_k$ and which may move in one
direction only:

$$g_k = \sigma_k\,\frac{b_k - Y_k}{s^Y_k} \geq 0, \qquad h_k = \delta_k\,\frac{X_k - \bar{x}_k}{s^X_k} \geq 0, \qquad g_k\,h_k = 0,$$

with $\sigma_k = 1$ for an upper bound and $-1$ for a lower bound, and
$\delta_k = 1$ if $X_k$ may rise and $-1$ if it may fall. The scales $s$ are
the base magnitudes of the variables (one where the base value is zero).
Either $Y_k$ is at its bound and $X_k$ has moved from $\bar{x}_k$ to keep it
there, or $X_k$ is at $\bar{x}_k$ and $Y_k$ is within its bound. Each
constraint adds one equation (block B1) and frees one variable, so the system
stays square.

| Constraint | Limited variable | Adjusting variable | Effect when it binds |
|---|---|---|---|
| import quota | $QM_c \leq b$ | $RM_c$, up | the premium rises until imports equal the quota |
| export quota | $QE_c \leq b$ | $RE_c$, up | the premium rises until exports equal the quota |
| capacity | $QA_a \leq b$ | $RA_a$, up | the activity price rises above cost; the rent goes to the owners of the capacity |
| borrowing limit under a peg | $FSAV \leq b$ | $EXR$, up | the peg holds until foreign savings reach the limit; the currency then depreciates |
| deficit ceiling | $GSAV \geq b$ | $GADJ$, down | government consumption is cut once the deficit reaches the ceiling |
| deficit ceiling, taxes | $GSAV \geq b$ | $TINSADJ$, up | direct tax rates rise instead |
| nominal wage floor | $W_f \geq b$ | $QFS_f$, down | employment falls once the wage reaches the floor |

$Y_k$ must be free and $X_k$ fixed under the closure. With $X_k$ a rent
variable, the constraint and the rent's recipient are given together.

### 16.3 Solution

The conditions are solved in two stages:

1. **Smoothed.** Each condition is written in the smoothed Fischer-Burmeister
   form of Section 14.3, $g + h - \sqrt{g^2 + h^2 + 2\mu} = 0$ with
   $\mu = 10^{-8}$, and solved with the rest of the model. The solver finds
   the regime; none is chosen in advance.
2. **Exact.** Each constraint takes the regime of the smoothed solution:
   binding, $g_k = 0$, if $h_k > g_k$, and otherwise not binding,
   $h_k = 0$. The model is solved again with these equations. A constraint
   whose other condition then fails ($h_k < 0$ when binding, $g_k < 0$ when
   not) changes regime, and the model is solved again, for at most ten
   rounds.

The solution therefore satisfies the conditions exactly, to the solver's
tolerance. Three implementations check one another, each with its own
method:

- Stata: the two stages above;
- the Python reference: an active-set method, which starts from the solution
  without constraints;
- GAMS: a mixed complementarity problem, solved with PATH.

The minimum wage of Section 14.3 keeps its smoothed condition and its
calibration.

### 16.4 Reporting

`cge_solve` reports each constraint's regime, and the regimes are stored with
the simulation. The rent variables appear in the results like other
variables.

**Attributes of variables (from version 0.9.8).** `cge_bound VAR[(e)],
lower() upper() scale() level()` stores definitions in `M.bddef` (variable,
elements, lower, upper, scale, level, `relative`); `_cge_bd_sync()` applies
them in order, later ones replacing earlier ones and `-inf`/`inf` removing a
bound, to the positions and values `M.bdlp`/`M.bdlv`, `M.bdup`/`M.bduv` and
`M.bdsp`/`M.bdsv`, and writes the scales into `M.xscale` (positions in
`M.bdcp`, restored to `abs(x0)` or 1 when removed). It runs after calibration,
on loading and when user variables are removed, whose definitions are
dropped. The bounds are those of a CNS model: `_cge_F()` returns missing
values at a point outside them, so the line search keeps the iterates within
them; the base and the starting levels must lie within them, and a fixed
element outside them stops `cge_solve`. `cge_solve` starts from `x0` with the
starting levels of the free elements, notes free elements within `1e-9 s` of
a bound (`r(N_atbound)`) and, after a failure, the bounds nearest the last
point. `fix(#)` sets `M.xcur` for elements the closure fixes. `cge_gams`
writes `cge_bounds.inc` after the closure: `.lo`/`.up` of the free variables
other than the adjusting variables of constraints (none in an MCP scenario),
`.scale` with `scaleopt`, and `.l`.

The solution listing (`cge_listing, solution`) gives each variable element's
bounds (its level when fixed; the bounds above or ±infinity when free), each
equation element with every term on the left (bounds 0, level the residual,
no marginal, as in a CNS model), and each active constraint as a pair: level
$g_k = \sigma_k(b_k - Y_k)$, marginal $h_k = \delta_k(X_k - \bar x_k)$. In
GAMS, the pair is BND ⊥ SLK; from version 0.9.8, `cge_shock_var.inc` writes
the adjusting variables at $\bar x_k$ (not the solution), and
`cge_cons_write.inc` writes `(BND.l - BND.lo) s_Y` and `BND.m s_X`, which
`cge_gams, compare` checks against $g_k$ and $h_k$ (GAMS's MCP marginal of a
row is the level of its column).

## 17. Production and tax extensions (from version 0.5.0)

### 17.1 Taxes on factor use and on factor income

Two taxes of the IFPRI standard model (Lofgren, Harris and Robinson 2002) and
of the PEP models (Decaluwé et al. 2013) bear on factors:

- **Taxes on factor use**, such as payroll taxes on labour or taxes on
  capital, paid by activities to accounts mapped with
  `cge_map, factortax(account:factor)`. The rate on factor $f$ in activity
  $a$ is the tax over the factor payment,
  $tf_{fa} = SAM_{acc,a} / SAM_{fa}$. It raises the cost of the factor to the
  activity: the first-order conditions of Q4 hold with
  $W_f\,WFDIST_{fa}\,(1 + tf_{fa})$ in place of $W_f\,WFDIST_{fa}$, and value
  added at factor cost, $PVA_a\,QVA_a$, includes the tax. The shares of the
  value-added function are calibrated on the tax-inclusive factor costs.
- **Taxes on factor income**, paid by factors to the account mapped with
  `factorincometax(account)`. The rate $tfy_f$ is the tax over factor income
  $YF_f$, taken before the income is distributed, like the contributions to
  a health insurance fund:
  $YIF_{if} = shif_{if}\,(1 - tshi_f - tfy_f)\,YF_f$ (I2).

Both are government revenue (I8):

$$\ldots + \sum_{f,a} tf_{fa}\,W_f\,WFDIST_{fa}\,QF_{fa} + \sum_f tfy_f\,YF_f$$

Factor income $YF_f$ is net of taxes on use (I1 is unchanged). Shocks `tf`
(by factor, in every activity that uses it) and `tfy` change the rates; a
value introduces a tax where the SAM has none. Reports add the rows
`tax_factor_use` and `tax_factor_income` to the government table.

### 17.2 Nests of value added (from version 0.5.1)

Value added may combine nests of inputs, each a CES or Cobb-Douglas
aggregate with its own elasticity: labour as a combination of skill types,
such as doctors, nurses and other staff, as in the PEP models (Decaluwé et
al. 2013), or capital with energy, as in GTAP-E (Burniaux and Truong 2002).
The nests and their members, factors or commodities, are given at
calibration:

```stata
cge_calibrate, ... nests(labour: lab_hi lab_lo, ke: cap com_ene) sigmanest(labour:1.5 ke:0.4)
```

A factor or commodity belongs to at most one nest, and nests do not contain
other nests. A nest exists in an activity that uses at least one of its
members ($NA$). The top of value added in an activity combines its factors in
no nest and its nests, with the elasticity $\sigma^{va}_a$.

**Commodities in nests.** A commodity $c$ in nest $n$ bought by activity $a$
($c \in NE_a$) leaves intermediate input: $QINT_{ca}$ is set by the nest
(N3) instead of Q5, and is not part of $QINTA_a$ or of the shares $ica$.
$PVA_a\,QVA_a$ then includes its cost at the price the activity pays,
$p_{ca} = PQ_c\,(1 + tv_c\,TVADJ\,(1 - \kappa_a))$. Value added in reports
(by activity and in total, at base prices) and the income side of GDP leave
it out.

**Equations.** Each member $m$ of a nest has a quantity $x_{ma}$, a factor in
efficiency units $z_f\,QF_{fa}$ ($z_f = af_f\,EFF_f\,DW_f$) or a commodity
$QINT_{ca}$, and a cost $p_{ma}$: $W_f\,WFDIST_{fa}\,(1 + tf_{fa})$ for a
factor, $p_{ca}$ for a commodity. With $\rho_n = 1/\sigma_n - 1$ and the CES
sums

$$S_a = \sum_{f \notin N} \delta^{va}_{fa}\,(z_f\,QF_{fa})^{-\rho^{va}_a}
       + \sum_{n \in NA_a} \delta^{n}_{na}\,QNA_{na}^{-\rho^{va}_a}, \qquad
  S_{na} = \sum_{m \in n} \delta_{ma}\,x_{ma}^{-\rho_n},$$

value added and its nests are

$$QVA_a = ad_a\,S_a^{-1/\rho^{va}_a} \tag{Q3}$$

$$QNA_{na} = an_{na}\,S_{na}^{-1/\rho_n} \tag{N1}$$

$$PNA_{na} = \frac{PVA_a\,QVA_a}{S_a}\,\delta^{n}_{na}\,QNA_{na}^{-\rho^{va}_a - 1} \tag{N2}$$

and the demands for the members of a nest are

$$p_{fa} = \frac{PNA_{na}\,QNA_{na}}{S_{na}}\,\delta_{fa}\,(z_f\,QF_{fa})^{-\rho_n - 1}\,z_f \tag{Q4}$$

$$p_{ca} = \frac{PNA_{na}\,QNA_{na}}{S_{na}}\,\delta_{ca}\,QINT_{ca}^{-\rho_n - 1} \tag{N3}$$

Factors in no nest keep Q4 of Section 5.2, with $S_a$ in its denominator.
With $\sigma = 1$, a nest or the top of value added is Cobb-Douglas, as in
Q3' and Q4': $QNA_{na} = an_{na} \prod_m x_{ma}^{\delta_{ma}}$, and each
member's cost is its share of the nest's value,
$p_{ma}\,x_{ma} = \delta_{ma}\,PNA_{na}\,QNA_{na}$.

**Calibration.** In the base $PNA^0_{na} = 1$ and $QNA^0_{na}$ is the cost
of the nest's members: factor payments with taxes on use, and the SAM's
purchases of its commodities. The shares within a nest follow from the
members' costs and quantities as in Section 7.3,
$\delta_{ma} \propto p^0_{ma}\,(x^0_{ma})^{1 + \rho_n}$ (or the value shares
for Cobb-Douglas), and $an_{na}$ makes N1 hold. At the top of value added the
nests enter at a price of one with quantities $QNA^0_{na}$, and $QVA^0_a$
adds the cost of the commodities in nests.

A nest of factors whose elasticity equals that of value added gives the same
solution as no nest: a CES function of CES functions with one elasticity is
a CES function. The test suites check this.

**Parameters and results.** The parameters are $\delta^{n}_{na}$ (`dvn`),
$an_{na}$ (`an`), $\delta_{ca}$ (`dce`), $\sigma_n$ (`sgn`) and $\rho_n$
(`rhn`); within a nest, the shares of factors are kept in `dva`. Results
list $QNA$ and $PNA$. Sensitivity analysis keeps the nests' elasticities at
the values given.

### 17.3 Output of a commodity from several activities (from version 0.5.2)

When several activities produce a commodity, Q6 adds their outputs: the
outputs are perfect substitutes, sold at one price $PX_c$. The IFPRI standard
model (Lofgren, Harris and Robinson 2002) instead combines them by a CES
function, so that the output of different producers, such as public and
private health services, can be priced differently. `cge_calibrate,
sigmaac(com_man:2)` gives the elasticity of substitution for a commodity
($c \in CAC$), or one value for every commodity with more than one producing
activity; the others keep Q6. With $XAC_c$ the activities producing $c$ and
$\rho^{ac}_c = 1/\sigma^{ac}_c - 1$:

$$QXAC_{ac} = \theta_{ac}\,\Big(QA_a - \sum_h QHA_{ah}\Big), \qquad a \in XAC_c \tag{Q6B}$$

$$QX_c = aac_c\,\Big(\sum_{a \in XAC_c} \delta^{ac}_{ac}\,QXAC_{ac}^{-\rho^{ac}_c}\Big)^{-1/\rho^{ac}_c} \tag{Q6A}$$

$$PXAC_{ac} = \frac{PX_c\,QX_c}{\sum_{a'} \delta^{ac}_{a'c}\,QXAC_{a'c}^{-\rho^{ac}_c}}\,\delta^{ac}_{ac}\,QXAC_{ac}^{-\rho^{ac}_c - 1} \tag{P5A}$$

and each activity is paid its own price in P5,
$PA_a = \sum_c \theta_{ac}\,PXAC_{ac}$ for $c \in CAC$ and $\theta_{ac}\,PX_c$
otherwise. With $\sigma^{ac}_c = 1$ the aggregate is Cobb-Douglas,
$QX_c = aac_c \prod_a QXAC_{ac}^{\delta^{ac}_{ac}}$ and
$PXAC_{ac}\,QXAC_{ac} = \delta^{ac}_{ac}\,PX_c\,QX_c$. The value of commodity
output is the value of the activities' outputs, $PX_c\,QX_c = \sum_a
PXAC_{ac}\,QXAC_{ac}$, so GDP and the reports are unchanged.

**Calibration.** $PXAC^0_{ac} = 1$ and $QXAC^0_{ac} = SAM(a, c)$; the shares
are $\delta^{ac}_{ac} \propto (QXAC^0_{ac})^{1 + \rho^{ac}_c}$ (value shares
for Cobb-Douglas), and $aac_c$ makes Q6A hold. As $\sigma^{ac}_c$ grows the
aggregate tends to the sum of Q6: with $\sigma^{ac} = 10^8$ the solution
agrees with the model without aggregation to $10^{-6}$ in the test suites.
The parameters are $\sigma^{ac}_c$ (`sac`), $\rho^{ac}_c$ (`rac`), $aac_c$
(`aac`) and $\delta^{ac}_{ac}$ (`dac`).

## 18. Policy optimisation (from version 0.6.0)

`cge_optimize` chooses the values $u$ of a few instruments to maximise or
minimise a report measure $f$ (Section 9), or to reach targets $g_j(u) =
\bar g_j$ for report measures, with the model solved at every trial value:

$$\max_u\; f\big(x(u), u\big) \quad \text{subject to} \quad g_j\big(x(u), u\big) = \bar g_j, \qquad
  \underline u \le u \le \overline u,$$

where $x(u)$ solves the model (Section 5) under the current closure. An
instrument is one element of a parameter that `cge_shock` changes, or of a
variable the closure fixes.

**Algorithm.** Each trial solves the model by Newton's method from the
solution of the trial before. Instruments are measured as $u = u^0 + s\,z$,
with $s$ the scale of each instrument. With targets alone, as many as
instruments, the residuals $r_j = (g_j - \bar g_j)/|\bar g_j|$ are solved by
Newton's method, with a Jacobian from central differences (step $10^{-5}\max(1, |z_k|)$ in
$z$) and steps halved until the residuals fall. With an objective, a
projected Newton method maximises $f/\max(1, |f^0|)$: the gradient and
Hessian come from central differences, an instrument at a bound whose
gradient points outwards is held there, steps are projected on the bounds
and halved until the objective rises, and the iterations stop when the
gradient of the free instruments is below $10^{-8}$. Targets with an
objective are equality constraints, met by the augmented Lagrangian method:
the maximiser takes $f - \lambda' r - \tfrac{\rho}{2} r'r$, and $\lambda$
moves by $\rho\, r$ after each round, until $\max |r_j| < 10^{-10}$.

**Expressions and constraints (from version 0.9.4).** The objective and the
targets may be expressions of the user language (Section 19), compiled once
(`_cge_opt_parse()`: an argument of two or three words whose first is a report
table is a measure) and evaluated at each trial's solution
(`_cge_opt_item()`); the right side of a target or a constraint is a number or
an expression (`_cge_opt_rhs()`). Constraints $h_k \le \bar h_k$ or $\ge \bar
h_k$ have scaled slacks $s_k \ge 0$, appended to the target residuals, and enter
the maximiser as $-\frac{1}{2\rho}\sum_k(\max(0, \mu_k - \rho s_k)^2 - \mu_k^2)$
(Powell, Hestenes and Rockafellar), with $\mu_k \leftarrow \max(0, \mu_k - \rho
s_k)$ after each round, until the target gaps and $\max_k |\min(s_k,
\mu_k/\rho)|$ are below $10^{-10}$.

**Results.** The optimum is stored as a simulation and left as the current
shocks. The Python reference solves the same problems with scipy's SLSQP and
least squares; the test suites compare the instruments (to $10^{-5}$), the
objective (to $10^{-9}$) and the solution, and check that a target for
government savings reached by the direct tax rate reproduces the closure
`fixgsav` (to $10^{-10}$).

**The equation listing (from version 0.9.5).** `cge_listing` evaluates
`_cge_eq()` at a stored simulation, the base or the current point and lists
every element of the model, in the system or replaced by a user equation, with
its block and element (`_cge_eqlabel()`), its left and right sides, its
residual and its scaled residual, $(\ell - r)/\sigma$ with the scales of
`cge_solve`; an element in the system is infeasible above the tolerance
(default $10^{-8}$). `_cge_blockdom()`, the domains of the blocks that may be
replaced, is drawn from the same table (`_cge_eqinfo()`).

**Scenario loops (from version 0.9.9).** `cge_loop, name(n) values(t1 = v...;
t2 = v...) [grid scale cold]` (or `using`, a long dataset of scenario, target
and value) solves, for each scenario $s$, the model with the targets, read as
the instruments of Section 18 (`_cge_opt_instrument()`), at $v_s$ ($\theta^c
\odot v_s$ with `scale`; a target a scenario leaves out keeps its value in
place) and the other shocks in place (`_cge_opt_apply()`), from the solution of
scenario $s - 1$ (the base for $s = 1$, and with `cold`), then from the base and
by continuation in 4 and 16 steps (`_cge_continue()`) if that fails. The
scenarios are stored as simulations `n1`, `n2`, ... and recorded in
`M.loopdef` (name, simulations, targets); `M.p` and `M.xcur` are restored.
Measures are report measures or compiled expressions, as in Section 18.
`cge_gams, loop(n)` exports the scenarios as the periods of a dynamic run
(`_cge_gams_export_dyn()`), each with its changes from the one before.

**GDX files (from version 0.10.0).** `cge_gdx write` writes a GAMS program
with the accounts `AC` and the subsets `A`, `C`, `F`, `H` and `E`,
`SAM(AC, AC)` (`M.S`), `sim` (the base and the simulations), `LEVEL(sim, *,
*, *)` (each existing element of each variable, `-` for an index it does not
have) and `CAL(*, *, *)` (the parameters of `cge_parameters`), every number with
17 significant digits (`_cge_gnum17()`: Stata's own reading of decimals is not
always correctly rounded, so the shortest form that it reads back may not be
the one GAMS reads), and ends with `execute_unload`. `cge_gdx read` runs
`gdxdump` with `format=csv dFormat=hexponential CSVAllFields CSVSetText` and
reads each hexadecimal float `±0xh.hhhp±e` as `m * 2^(e - 4k)` with an exact
table of powers of two (`_cge_pow2()`; Mata's `2^k` is not exact); `Eps` is 0
and the infinities, `NA` and `Undf` are missing. GAMS's labels ignore case and
keep the case first written, so the levels come before the parameters.

**Sparse LU (from version 0.10.1).** With `M.linsolver` 1 (sparse) or 2 (auto,
from 1,000 equations), Newton's steps with the exact Jacobian use
`_cge_jac_trip()` (the entries of the scaled Jacobian of the system) and
`_cge_slu_update()`: rows with more than max(50, 10 x average) entries are set
apart; on the rest, `_cge_slu_analyse()` chooses pivots by Markowitz's rule
with threshold u = 0.1, among the active columns with the fewest entries in a
pool of 64 refreshed every 16 steps; a column whose active entries fall to
1e-10 of its largest entry in the rows not set apart (lost to rounding when
rows cancel) is left over. `_cge_slu_factor()` factorises the sparse block A11
= L U left-looking in that order and the dense block through S = A22 - A21
inv(A11) A12 (Mata's `_lud`), with A12 and A21 kept as entries and S formed a
group of columns at a time; `_cge_slu_solve()` solves with both. A later
Jacobian whose entries lie within the analysed pattern is factorised in the
same order unless a pivot falls below 1e-8 of its column of L or 1e-10 of its
column of A11; the analysis is kept in an external for later solves. Newton's
fallbacks with central or one-sided differences (modes 1 and 2) use the sparse
LU with `_cge_jac_cdtrip()`; Powell's method is left out above 10,000
equations.

## 19. User variables and equations (from version 0.6.1)

`cge_variable` and `cge_equation` add variables and equations to the
calibrated model, written in a small language:

- numbers, `+ - * / ^`, parentheses, `exp()`, `ln()` (or `log()`) and
  `sqrt()`;
- model and user variables, `VAR` or `VAR(e)` or `VAR(e1, e2)`, at an element
  or at the index of the equation or of a sum;
- parameters that `cge_shock` changes, `par(e)`, and user parameters,
  `upar`, `upar(e)` or `upar(e1, e2)` (from version 0.7.1), at their current
  values;
- `base(VAR(e))`, the base value of a variable;
- `sum(i, expression)`, over the set of index `i`: `a` activities, `c`
  commodities, `f` factors, `h` households, `d` households and enterprises,
  `i` institutions receiving factor income, `n` nests, or a user set by its
  name (from version 0.7.1), with digits allowed, as in `c2` or `goods2`;
- from version 0.9.7, `max()`, `min()`, `abs()`, `sqr()`, `log10()`,
  `ifthen()`, `prod()`, `smax()`, `smin()`, `card()` and macros (see
  *Functions and macros* below).

`cge_variable NAME(i) = expression` adds the variable $U_i$ and the equation
$U_i = e_i(x)$ for every element; its base value is $e_i(x^0)$.
`cge_variable NAME(i), value(v)` adds a free variable without an equation,
and `cge_equation NAME(i): lhs = rhs` an equation without a variable; each
must be paired, so that the closure stays square. A defined variable swapped
into the closure (`cge_closure, swap(NAME VAR)`) fixes the expression and
frees `VAR`: for example, real government savings $GSAV/CPI$ held at the base
with the direct tax rate adjusting, which under the CPI numeraire is the
closure `fixgsav` (the test suites check that the solutions agree to
$10^{-9}$).

**User sets and parameters (from version 0.7.1).** `cge_set name =
elements [, except()]` stores an ordered list of labels (`M.usdef`); model
set letters and other user sets in the list are written out. Its code in the
set fields of variables and parameters is `~name` (`_cge_nidx()`,
`_cge_setsize()`, `_cge_setlab()` and `_cge_dims()` read it). `cge_parameter
NAME[(i[,j])] = #` or with `values()` or `from() labels()` stores the
definition in `M.updef` (name, set codes) and the values, row by row, in
`p.upval`, after those of the parameters defined before; stored simulations
get the base values. A reference compiles to a postfix row of type 7 with
the position in `p.upval` (derivative 0). `cge_shock` changes elements
(labels of the first index, or `e1.e2`); `_cge_par_interp` moves them in
continuation; `cge_optimize` takes an element as an instrument of kind 3;
`cge_parameters` lists them; calibration keeps the base values. Benchmark
replication covers the model's own equations only (`_cge_maxres_part`):
user equations need not hold at the base, where they act as shocks.

**Conditions (from version 0.7.2).** `sum(i$(q), g)`, `g$(q)` and the
domains `NAME(i)$(q)` of user variables and equations restrict a sum, a term
or a domain to the elements for which the condition `q` is nonzero. `q` is
evaluated by `_cge_u_condval()` at the base point and base parameters
(`M.x0`, `M.p0`) when the definition is added and when the model is
calibrated again, so the terms and equation elements are the same in every
simulation. Conditions compile with comparisons (`> < >= <= == !=`, codes 6
to 11), `&` and `|` (12, 13) and `!` (postfix row type 8); a comparison with
a missing operand is missing, which is an error (459). Set membership
`set(e)` and `sameas(e1, e2)` compile to the constants 1 and 0, and
`ord(i)` is replaced by the position of the element when the index is
written out (`_cge_u_subst()`). Sums are written out from the outside in
(`_cge_u_expand()`), each element substituted before the sums within, so an
inner condition may use the index of an enclosing sum; conditional terms are
then replaced by themselves or 0 (`_cge_u_rdollar()`). The conditions are
stored in a seventh column of `M.uvdef` and a sixth of `M.uedef`
(`_cge_u_widen()` pads models saved before). Elements of a user variable
outside its domain have `M.exists` 0 and base value 0: they are not in the
system or the results, a reference to one is the constant 0, and `cge_gams`
fixes them at 0. Comparisons, membership and `sameas()` are errors outside
conditions; a domain that no element meets is error 459.

**Inequalities and bounds (from version 0.9.0).** `cge_equation NAME[(i)]:
lhs =l= rhs, perp(V[(i)][, down])` (or `<=`, and `=g=`, `>=`) adds a defined
user variable `_S_NAME`, $s = rhs - lhs$ (or $lhs - rhs$), and for each element
a constraint of Section 16 with $s$ bounded below at zero and $V$, which must
be fixed under the closure, as its adjusting variable, moving up (or down). The
definitions are kept in `M.uedef` (relation in column 7; the paired variable,
element and direction in column 8) and the constraints are made again from
them (`_cge_u_cons_sync`) when the model is calibrated, the closure changes or
`cge_constraint, clear` runs; one whose paired variable is free is left out
with a note. `cge_variable NAME, value(#) fixed` is exogenous (column 6
`fixed`, fixed by `_cge_u_fixed` in the closure); `lower(#)` or `upper(#)`
without a definition fixes it at that bound. A defined variable with bounds
(columns 8 and 9) has adjusters `_L_NAME` and `_U_NAME`, fixed at zero, added
to and subtracted from its definition, each paired with a bound on the
variable. The GAMS program fixes exogenous user variables (`.fx`) and writes
the constraints as in Section 16.

**Two indexes and sets of pairs (from version 0.9.1).** A user variable or
equation `NAME(i,j)[$(q)]` has the set code `S1|S2` (`_cge_setparts()`); its
elements are the pairs of elements of the two sets (`_cge_u_els()`), labelled
`e1.e2`, and both indexes are replaced in its definition (`_cge_u_subst2()`).
The two indexes must differ. `cge_set NAME(i,j) = e1.f1 ...` stores a set of
pairs in `M.usdef`, with the set codes of its indexes in a third column
(`_cge_us_widen()` pads models saved before); a set of pairs is not an index.
Before the sums are written out, `_cge_u_sumpairs()` rewrites
`sum((i,j)$(q), g)` as `sum(i, sum(j$(q), g))` and `sum(map(i,j)$(q), g)` as
`sum(i, sum(j$(map(i,j) & (q)), g))`; in a condition, `map(e,f)` is the
constant 1 or 0. Shocks give elements as `e1.e2`, results as `element1` and
`element2`, and `cge_gams` declares the variables over `(AC, AC)`, with the
pairs outside the domain fixed at 0.

**Lags (from version 0.9.2).** `lag(V[(e)][, k])`, $k$ from 1 to 4, compiles
to a postfix row of type 9 with the position of the element and the order
(`_cge_u_lag()`); its value is `p.xlag[pos, k]` (`_cge_u_lagval()`), with
derivative 0, and the base value `M.x0[pos]` when `p.xlag` has no such column,
as in a static simulation. `cge_dynamic` keeps the solutions of the last four
periods (`D.prevs`, the base before the first period) and sets
`M.p.xlag = D.prevs` before each period when a user equation has a lag
(`_cge_u_haslag()`), so each period's parameters store the values it used. At
the base (`_cge_u_build()`) a lagged value is the base value; a defined
variable that refers to its own lag is an error. `cge_gams` declares a
parameter `LAGk_V` for each lagged element at its base value, and each period
sets those that differ from the period before (`_cge_u_lags()`).

**Leads and the period (from version 0.10.2).** `lead(V[(e)][, k])`
compiles to a postfix row of type 11, its value `p.xlead[pos, k]`
(`_cge_u_leadval()`), the base without one; `tperiod`, `tfirst` and `tlast`
to type 12 with code 1 to 3, the value `p.tinfo[code]` (`_cge_u_tval()`), 0
without one. Within a period both have derivative 0; across the periods of a
run with foresight see Section 10.6. A recursive run with leads is error 198,
and so is the period in a condition, which is evaluated once, at the base.
`cge_gams` declares `LEADk_V` as it does `LAGk_V`, and the scalars `TPERIOD`,
`TFIRST` and `TLAST`; recursive runs set `p.tinfo` too.

**Replacing built-in equations (from version 0.9.3).** `cge_equation NAME[(i[,j])]:
lhs = rhs, replace(B)` (or `replace(B(e1[,e2]))` without an index) stores
`replace:B` in column 8 of `M.uedef`. `_cge_u_repcheck()` checks the block
against `_cge_blockdom()`, the domain of each block that may be replaced
(those with exact derivatives of their own, P7, P8, P9, I1, I8, I9, S1, S2,
S3 and S5, the constraints and the user equations may not), and the sets of
the equation's indexes against it. `_cge_u_build()` records the replaced
elements, block and labels, in `M.urep`; when the equation blocks are
recorded, `_cge_eq()` finds their rows (`_cge_u_reprows()`: row-major within a
block), checks that each is in the model and replaced once, and sets their
mask to 0 in every evaluation, so they leave the system, the pattern and the
reduced system. `cge_model.gms` declares `XRP(*, *, *)`, and every equation
that may be replaced leaves out the elements with `XRP(block, e1, e2) = 1`
(`'0'` for an index the block does not have), which `cge_user.inc` sets.

**Functions and macros (from version 0.9.7).** `max(a1, ..., am)` and
`min()` (two or more arguments), `abs(a)`, `sqr(a)`, `log10(a)` and
`ifthen(q, a, b)` compile to a postfix row of type 10 with the function's code
(1 min, 2 max, 3 abs, 4 sqr, 5 log10, 6 ifthen) and its number of arguments,
each argument compiled before it (`_cge_u_args()`). The condition of
`ifthen()` is compiled as a condition and may not contain variables (error
198): it uses parameters, user parameters, lags and numbers, so the branch is
given within a simulation. `_cge_u_fn()` gives the value, missing when an
argument is (except the branch `ifthen()` does not take), and `_cge_u_dvalue()`
the derivative: that of the argument `_cge_u_fnarg()` selects for min, max and
ifthen (the first of equal ones), `sign(a)` times that of `a` for abs, `2a`
for sqr and `1/(a ln 10)` for log10. `prod(i, g)`, `smax(i, g)` and
`smin(i, g)` are written out by `_cge_u_expand()` as `sum()` is, joined by `*`
or as the arguments of `max()` or `min()`, with the domains of `sum()`; an
empty product is 1, an empty maximum or minimum error 459, and a single term
is the term itself. Over two indexes or a set of pairs (`_cge_u_sumpairs()`),
the inner `smax#`/`smin#` is left out for an element of the first index without
a pair. `card(i)` is replaced by the number of elements of the set of `i`, or
of pairs (`_cge_u_card()`). Macros are stored in `M.umac` (name, parameters,
body) by `cge_macro` (`_cge_um_add()`); `_cge_u_macros()` replaces each use by
the body in parentheses, with each argument substituted for its parameter (in
parentheses unless it is one token), repeated up to 30 times, before `card()`
and before the indexes are written out (`_cge_u_pre()`), in `_cge_u_written()`,
`_cge_u_build()` and the domains. In the GAMS program the functions keep their
names, comparisons in `ifthen()` are written `eq`, `ne`, `and`, `or` and `not`,
and the macros are written out.

**Compilation.** Each equation is written out for every element of its set,
and each sum over the elements of its set, then compiled to postfix order:
numbers, variables (positions in the stacked vector), parameters, operators
and functions. Stata evaluates the postfix rows at every point; from
version 0.7.0 their derivatives are exact, by forward differentiation of the
postfix rows (`_cge_u_dvalue`), with respect to the variables each equation
element uses; from version 0.30.0 by reverse differentiation when an
element uses many variables (Section 40). The equations are a block `U`
of the system; they are saved with the model and compiled again when it is
calibrated again.

**GAMS.** `cge_gams` writes the user parameters (`UP_NAME`, declared over `*`
with their base values, changed by ratio in the scenario file), the user
variables (`U_NAME`, with their base levels) and one scalar equation per
element (`UE1`, `UE2`, ...) to
`cge_user.inc`, which `cge_model.gms` includes before the model statement,
and the results of the user variables to `cge_user_write.inc`. GAMS then
differentiates the same equations itself: the export check compares the
solutions.

## 20. Declared nests (from version 0.11.0)

`cge_nest begin|nest|input|output|end` keeps the block under construction in
the external `cge__nb` (`struct cge_nb`: name, index, set, condition, output
quantity and price, efficiency, the equation the top replaces, kind 1 cost or
2 revenue; nests with parent and elasticity; leaves with quantity, price,
units, nest and replaced equation). `_cge_nest_end()` writes the definitions
(`_cge_nest_text()`) and adds them with `_cge_u_addvar()` and
`_cge_u_addeq()`, the model restored (`cge__nb_model`) if one fails; the
declarations are kept in `M.unest`, which `cge_equation, clear` empties. For a
block B over index i, leaf j with quantity x, price p, units u and condition
$q_j$ = (x != 0) and the block's condition:
`B_wj(i)$(q_j) = (p)/(u)`, `B_xj(i)$(q_j) = (u)*(x)`; for each nest n, from
the innermost out, `B_P` or `B_n_P` = the CES or CET index over its children
with weights $V_c/V_n$, $V_j$ = `base(B_wj)*base(B_xj)` and $V_n$ the sum over
the leaves within n, each leaf's term with `$(q_j)`; for each inner nest m,
from the top in, `B_m_Q = V_m * R_parent * (P_parent/P_m)^s` (cost) or
`(P_m/P_parent)^t` (revenue), with $R_B$ = (Y/base(Y))/E (cost) or
(Y/base(Y))*E (revenue) and $R_m$ = `B_m_Q`/$V_m$; the equations
`B_dj(i)$(q_j): B_xj = base(B_xj) * R_n * (P_n/(B_wj/base(B_wj)))^s, replace(...)`
and `B_z(i): PY = base(PY) * B_P / E` (cost) or `* E` (revenue), replace(...).
At s = 1 the index is `exp(sum(theta * ln(rel)))` and the demand
`base * R * P / rel`; at s = 0 the index is `sum(theta * rel)` and the demand
`base * R`.

`replace(B(lab, a))` in an equation over a stores `B(lab,#1)`;
`_cge_u_repel()` puts the equation's element in place of `#1` (or `#2`).
`base(par(e))` compiles to the base value of a parameter that `cge_shock`
changes, a user parameter or `tf(f, a)` (`_cge_u_parbase()`, from `M.p0`);
`tf(f, a)` compiles to a postfix row of type 3 with the element
$(f - 1) n_A + a$, its value `_cge_u_parel(p.tf, el)`, row by row.

## 21. Linked regions (from version 0.12.0)

`cge_region add` keeps the model in memory, calibrated, as region *name* in
the external `cge__rg_name`; `struct cge_lk` (`cge__lk`) holds the regions,
their `units()` (world units per SAM unit), the region in memory, the routes
(`rs`, `rr`: exporter and importer positions, 0 for the rest of the world;
`rc` commodity; `rv` base value; `rt0`, `rt` base and current tariff), the
elasticities by commodity (`es` among sources, default 4; `eta` of the rest
of the world's demand, default `es`), the rest of the world's prices `pwrow`
and `pwrowe`, and the stored solutions (`sname`, route quantities `sq`,
prices `sp`, tariffs `st`). `_cge_rg_sync()` keeps the model in memory as its
region when its activities, commodities and factors are those of the region.

`cge_region trade` reads the routes; for each importer and commodity with
routes from other regions, the base imports $M^0 = pwm^0\,QM^0\,u$ less the
routes give the route from the rest of the world (an error if negative), with
the tariff $(tm^0 M^0 - \sum t^0_k V_k)/V_w$; missing route tariffs are $tm^0$.
For each exporter and commodity with routes to other regions, the base
exports $E^0 = pwe^0\,(QE^0 + QER^0)\,u$ less the routes give the route to the
rest of the world. Linked exports may not face a demand curve (`M.ced`).

`_cge_lk_setup()` lists the import pairs (region, commodity: link variables
$\pi^M = pwm/pwm^0$ and $tm$) and export pairs ($\pi^E = pwe/pwe^0$), and the
full system of each region (`_cge_sys_make(M, 0)`); `_cge_lk_par()` sets the
link variables into a copy of the region's parameters. For the routes $k$ into
an import pair, $x_k = \pi_k (1 + t_k)/(1 + t^0_k)$ with $\pi_k = \pi^E$ of the
exporter or `pwrow`, $\theta_k = V_k(1 + t^0_k)/\sum V(1 + t^0)$,
$P = (\sum \theta_k x_k^{1-\sigma})^{1/(1-\sigma)}$ (geometric at $\sigma = 1$),
$q_k = V_k (QM/QM^0)(P/x_k)^\sigma$; routes to the rest of the world
$q_k = V_k(\pi^E/pwrowe)^{-\eta}$ (`_cge_lk_routes()`). The link equations
(`_cge_lk_eqs()`) are $(\pi^M(1 + tm) - (1 + tm^0)P)/(1 + tm^0)$,
$(tm\,\pi^M M^0 QM/QM^0 - \sum t_k \pi_k q_k)/M^0$ and
$(E^0 (QE + QER)/(QE^0 + QER^0) - \sum q_k)/E^0$. `cge_region solve` stacks the
regions' scaled full systems and the link equations, starts from the base (or
from each region solved alone at the base links, `start(alone)`) and solves by
Newton's method with a line search and the sparse LU (`cge__slu_reg`): exact
Jacobians of the regions (`_cge_jac_trip()`) and, from version 0.31.0
(Section 41), exact derivatives of the regions' equations in their link
variables and of the link equations; before, central differences
($h = 10^{-6}\max(1,|v|)$) for those. Shocks of a region to `pwm`, `tm` or `pwe` of a linked
commodity are an error (198). Each region's solution is stored in its model
as simulation *name* with the link variables in its parameters (method
`linked`), through the external so that it shares nothing with the model's
own parameters; the routes are stored in `cge__lk`.

## 22. Standalone models and parameter assignments (from version 0.13.0)

`cge_model new` (`_cge_model_new()`) stores a fresh `struct cge_model` with
`standalone = 1`, `mapped = calibrated = 1`, empty model sets, no SAM and
empty definitions of user sets, parameters, variables and equations;
`_cge_sa(M)` is 1 for such a model (`standalone == 1`, so models saved
before, where the member is missing, are models from a SAM). In a standalone
model:

- the layout (`_cge_layout`) has only the user variables, in order, so their
  names may be those of model variables (`_cge_layout_std` gives the built-in
  ones otherwise);
- `_cge_eq` has two blocks, `B1` (the constraints of user inequalities and
  bounds) and `U` (the user equations); `_cge_pattern_sa` gives the pattern
  of their rows, with no rows of exact derivatives (`drow`, `drow2` empty) and
  no definitions left out (`dact` zero), so the reduced system is the full
  one; `_cge_jtrip_ub` gives their exact Jacobian, as in a model from a SAM;
  `_cge_dense`, `_cge_dense2` and `_cge_derive` do nothing;
- the closure (`_cge_closure_apply_sa`) fixes the user variables added
  `fixed`, then applies the swaps; the closure text is `standalone` and the
  swaps; `cge_closure` takes only `swap()`; `cge_solve` checks that the
  system is square;
- the letters `a c f h d i n` are not indexes (`_cge_u_set`,
  `_cge_u_isindex`, `_cge_u_newname`), the model's parameters are not names
  of the language (`_cge_u_compile`), and the labels of the model are those
  of the one-index user sets (`_cge_us_alllabels`); `cge_set` accepts new
  labels (`_cge_us_newlabel`: letters, digits and underscores, at most 32
  characters, not a reserved word or a name of a set, parameter or variable);
- `cge_shock` changes user parameters and fixed variables
  (`_cge_shock_var`), `cge_parameters` lists the user parameters, the
  optimiser and loops have no report measures (expressions only), `cge_gdx
  write` writes the labels as `AC`, `CAL` and `LEVEL`, and the commands that
  need a SAM stop with error 459 (`_cge_need(M, "sam")`, and
  `_cge_need_sam()` before options are read).

`cge_gams` writes a standalone model with a driver of its own
(`_cge_gams_export_sa`, `_cge_gams_driver_sa`): the labels as set `AC`
(`cge_data.inc`), the user parameters, variables and equations with the base
gaps times `UBASE` (`cge_user.inc`), models `cge`, `cgenlp`, `cgebase`, a
tolerance $10^{-13}\max(1, \max_k |x^0_k|)$ (at least $10^{-11}$), the base
solved and written (`cge_sa_write.inc`), then the scenario's parameter
changes (`UBASE = 0`), fixed values, swaps, constraints and bounds, solved
and written; `cge_solve.gms` is the package's.

`cge_parameter name(i[,j])[$(q)] = expression [, default(#)]`
(`_cge_up_add`, `_cge_up_assign`): for each element of the domain that meets
$q$ at the base, the expression with the indexes written out
(`_cge_u_subst2`, `_cge_u_written`) is compiled and evaluated with the base
parameters and variables; postfix rows of variables, lags, leads or the
period are an error (198), a missing value an error (459). The other
elements take `default()` (0), or keep their values when the parameter
exists, which is allowed over the same sets when no user variable, equation
or macro uses it (`_cge_up_used`); the new values replace the base and
current values, not those of stored simulations. `from(varlist)
labels(var)` for two indexes reads wide data: rows labelled by the first
index, one variable per element of the second, named as it (`_cge_unab`
writes out abbreviations and ranges). `cge_set name, from(var)` takes the
labels of a string variable in order of appearance. `cge_variable ...,
value(expression)` (`_cge_u_varopts`) gives each element's base value as a
definition does (`_cge_u_build` evaluates `uvdef[k, 3]` for every row). A
sum over an index that the domain already controls is an error (198), as
GAMS's "set already under control".

Tests (`tests/test_standalone.do`): an exchange economy against its closed
form ($P_2 = \sum_h \alpha_{h2} e_{h1} / \sum_h \alpha_{h1} e_{h2}$, to
3e-14) and after a shock; assignments, conditions, assignments again, sums
over two indexes, functions, `base()`, long and wide data and sets from data
against direct computations; assignments and `value()` expressions in a
model from a SAM; the standard model written in the user language
(`examples/standard_model.do`, 93 equations) against the built-in model at
the base and with tariffs removed, more labour, higher productivity and an
investment-driven closure with more government demand (106 values each, at
most 7.6e-13); `cge_model describe`; save and load; errors. GAMS
(`tools/gams/export_check.do`, cases `standalone` and `exchange`) solves both
models to 2.6e-12 and 6.7e-16.

## 23. Complementarity problems: the semismooth Newton method (from version 0.14.0)

With constraints in the system (Section 16: those of `cge_constraint` and
the inequalities of user equations), `_cge_solve_point` by default
(`M.mcpsolver` 0 or missing; `cge_options, mcp(semismooth)`) sets every
active constraint to regime 4, the Fischer-Burmeister function
$\phi(g, h) = g + h - \sqrt{g^2 + h^2}$ of the scaled $g$ and $h$ of 16.2
(`_cge_bres`), and `_cge_solve_sys` solves the system with `_cge_ssnewton`:
at each iterate the exact Jacobian as entries (`_cge_jac_trip`; the B1 rows
from `_cge_jtrip_ub`, with $\partial\phi/\partial g = 1 - g/r$,
$\partial\phi/\partial h = 1 - h/r$, $r = \sqrt{g^2 + h^2}$, and
$1 - 1/\sqrt 2$ for both at $r = 0$); the Newton step $d$ from the dense LU
(`_cge_trip_dense`) or the sparse LU of `cge_options`; if
$\nabla\psi' d \le -10^{-8}\lVert d\rVert^{2.1}$, with $\psi = f'f/2$ and
$\nabla\psi = J'f$ (`_cge_sumby`), a line search halving from 1 to
$10^{-12}$ accepts $\psi(z + t d) \le \max_{j<10} \psi_{k-j} + 10^{-4} t
\nabla\psi' d$ (non-monotone, memory 10); otherwise, or if it fails, the
steepest descent $-\nabla\psi$ with the same rule, halving from 1 to
$10^{-14}$; converged when the largest scaled residual is below the
tolerance. The regimes are then read from the solution (binding if $h > g$)
and the system solved again in them, the result kept if no regime's other
condition fails by more than $10^{-9}$. If the semismooth method fails, the
active-set method of 16.3 runs, as with `cge_options, mcp(activeset)`
(`M.mcpsolver` 1, saved with the model); `r(method)` is `semismooth` when
it solves. From 0.14.0 `cge_bound ..., level()` also sets the start of
variables that adjust for constraints and of exogenous user variables at a
bound (`_cge_bd_movable`, `_cge_bd_start`); their fixed levels stay the
bounds.

Tests (`tests/test_mcp.do`): MCPLIB josephy (unique solution
$(\sqrt6/2, 0, 0, 1/2)$) and kojshin (solutions $(\sqrt6/2, 0, 0, 1/2)$,
degenerate in $x_3$, and $(1, 0, 3, 0)$) from $x = 0$, and kojshin from
starts near each solution, to 1e-8; an economy in the form of MPSGE with two
technologies (zero profit against activity levels, factor markets against
factor prices) against the solution of its linear programme, with one
technology unused and with both used, to 1e-9; five constraints of the
standard model, four binding, against the active-set method, to 1e-8; the
setting saved and loaded; errors. GAMS (PATH, MCP; export check cases
mcpjosephy, mcptech and manycons) to 7.8e-13, 6.2e-15 and 1.2e-13, constraint
marginals included.

## 24. Exact derivatives and nonlinear programmes (from version 0.15.0)

**Exact derivatives in `cge_optimize`.** With `gradient(exact)`, the
default (`O.gmode` 0; `gradient(differences)` sets 1 and keeps the methods
of Section 18), `_cge_opt_point` solves the model at the scaled instruments
$z$ (`_cge_opt_solvep`) and `_cge_opt_grad` takes the derivatives of the
objective and of the residuals of the targets and constraints with respect
to them at the solution $x$: the exact Jacobian $J$ of the system solved
(`_cge_jac_trip`), factorised once by the dense LU (`_cge_trip_dense`,
`_lud`) or the sparse LU (`_cge_slu_update`); for each instrument $k$,
$\partial F/\partial u_k$ by central differences of `_cge_F` in $u_k$ with
$x$ held, step $10^{-6}\max(1, |u_k|)$, and $dx/du_k = -J^{-1}\,\partial
F/\partial u_k$ (the implicit function theorem); then the derivatives of the
objective and residuals along the tangent $(dx/du_k, 1)$ by central
differences of `_cge_opt_eval` on it, step $10^{-5}\max(1, |u_k|)$, with the
reduced system's definitions derived at each point (`_cge_derive`). No
derivative needs a solve. Targets alone use the exact Jacobian of the
targets in Newton's method (`_cge_opt_newton`), converged also when a step
does not reduce a gap already below $10^{-9}$, the precision of the solves. With an objective,
`_cge_opt_max` maximises the augmented objective of Section 18 with its
exact gradient; the Hessian of the free coordinates is the central
difference, step $10^{-4}$, of the gradient of the Lagrangian $f -
\lambda_t' r + m' s$ with $\lambda_t = \lambda + \rho r$ and $m = \max(0, \mu
- \rho s)$ held, less $\rho J_t' J_t$ and $\rho J_c' J_c$ over the binding
constraints; convergence when the largest free gradient is below $10^{-10}$
($10^{-8}$ with targets or binding constraints); a Newton step whose predicted rise
is below $10^{-12}\max(1, |F|)$ is taken if it reduces the largest free
gradient. Reduced costs use the exact gradient (`_cge_opt_redcost`).
`r(gradient)` returns the method.

**Nonlinear programmes.** `cge_solve, minimize(e)` or `maximize(e)` on a
standalone model (`_cge_solve(..., obj)`, obj `"min:e"` or `"max:e"`) calls
`_cge_nlp_run`, which stops with 198 unless the model is standalone and with
459 if it has constraints or inequalities paired with variables, compiles
the objective (`_cge_nlp_tok`: the user language, with its GAMS text) and
solves

$$\min_x\; \sigma f(x) \quad\text{s.t.}\quad c(x) = 0,\quad L \le x \le U$$

over the free variables, $\sigma = 1$ to minimise and $-1$ to maximise, with
the equations scaled as in `cge_solve` and the bounds of `cge_bound`
(`_cge_nlp_solve`). It stops with 459 when there are no more free variables
than equations or when a variable's bounds are equal. A start outside the
bounds of a free variable is allowed in a standalone model (`_cge_bd_valid`
notes it; `_cge_bd_start` clips it).

The method is a primal-dual interior point after Wächter and Biegler (2006),
in scaled variables $z = x/s$:

- the start pushed inside each bound $b$ by $\min(10^{-2}\max(1, |b|), (U -
  L)/4)$; the objective divided by $\max(1, \max_j |\partial f/\partial z_j|
  / 100)$ at the start (`_cge_nlp_eval`; its gradient by forward
  differentiation of the postfix rows, `_cge_nlp_f`); $\mu_0 = 0.1$;
  least-squares multipliers $\lambda$ (zero if above $10^3$); bound
  multipliers $\mu/\text{slack}$;
- the error $\max(\lVert r_d\rVert_\infty / s_d, \lVert c\rVert_\infty,
  \max(\text{slack} \cdot z) / s_d)$, $r_d = \nabla f + J'\lambda - z_L +
  z_U$, $s_d = \max(100, (\lVert\lambda\rVert_1 + \lVert z_L\rVert_1 +
  \lVert z_U\rVert_1)/\max(1, m + n_L + n_U))/100$; converged below the
  tolerance;
- $\mu \leftarrow \max(\text{tol}/10, \min(0.2\mu, \mu^{1.5}))$ while the
  barrier error is at most $10\mu$;
- the Hessian $W$ of the Lagrangian by central differences of its exact
  gradient, step $10^{-6}\max(1, |z_i|)$, one-sided toward the inside near a
  bound; $\Sigma = Z_L S_L^{-1} + Z_U S_U^{-1}$; $\delta = \max(0,
  10^{-8}\max(1, \max|\text{diag}(W + \Sigma)|) - \lambda_{\min}(Z'(W +
  \Sigma)Z))$ with $Z$ the null space of $J$ from `qrd(J')`;
- the step from the primal-dual system $[W + \Sigma + \delta I, J'; J,
  -\epsilon I]$ by LU, $\epsilon = 0$ and, if singular, $10^{-8} \cdot
  10^k$, $k = 2, 3, 4$, with $\delta$ raised;
- the bound multipliers' steps $\Delta z_L = \mu/s_L - z_L - (z_L/s_L)\Delta
  z$ and likewise for $z_U$; the fraction to the boundary $\tau = \max(0.99, 1
  - \mu)$ for the variables and, separately, the bound multipliers;
- backtracking from the largest step on the $\ell_1$ merit $\phi = f - \mu
  \sum\ln s + \nu\lVert c\rVert_1$, $\nu \leftarrow \max(\nu, \max|\lambda_+|
  + 1)$, with Armijo's condition $\phi_+ \le \phi + 10^{-4} a
  \min(\phi', 0) + 10^{-13}\max(1, |\phi|)$, halving to $10^{-12}$;
  $\lambda \leftarrow \lambda + a(\lambda_+ - \lambda)$;
- the bound multipliers kept within $[\mu/(10^{10}s), 10^{10}\mu/s]$.

The marginals, `r(marginals)`, are $-\sigma\,\text{osc}\,\lambda / e$ with
$e$ the scales of the equations: the change in the optimum per unit
increase in each right side, as GAMS's marginals. The solution is stored
with method `nlp` and its objective (`M.simobj`, saved with the model and
kept with the simulations, `_cge_sims_keep`); `r(objective)`, `r(N_dof)`
and `r(objective_expr)` are returned.

**GAMS.** `cge_gams, sim()` of an NLP simulation (`_cge_gams_isnlp`)
defaults to `type(nlp)` and `solver(ipopt)` and needs `type(nlp)`;
`_cge_gams_driver_sa` writes `OBJV`, `EOBJV.. OBJV =e= ` the objective's
GAMS text and `model cgeprog / cge, EOBJV /`, writes the base as the
starting levels with model status 0, applies the scenario's changes and
bounds and solves `cgeprog using nlp minimizing` (or `maximizing`) `OBJV`;
IPOPT's option file adds `bound_relax_factor 0`; `cge_sa_write.inc` writes
`__objective__`.

Tests (`tests/test_optgrad.do`, `tests/test_nlp.do`): a planner's choice on
the frontier $\sum X_i^2 = R^2$ with utility $\sum \alpha_i \ln X_i$, whose
optimum is $X_i = R\sqrt{\alpha_i}$, with three and ten goods, an instrument
at a bound and the same bound as a constraint, with their marginals, against
the closed form to $10^{-8}$; exact derivatives against differences on the
standard model (tariffs with a revenue target, the direct tax factor for a
savings target), in fewer solves; Hock and Schittkowski's problem 71 against
its published optimum, 17.0140173, with the marginals against central
differences of the optimum in the right sides to $10^{-5}$; Rosenbrock's
function from $(-1.2, 1)$; the frontier as an NLP in all variables, with
and without a binding bound added after the start, against the closed form
to $10^{-7}$ and its marginal $1/200$; a $3 \times 4$ matrix balanced by
cross entropy against RAS, to $1.1 \times 10^{-11}$; errors. GAMS (IPOPT,
NLP; export check cases nlphs071, nlpentropy and nlpfrontier) to 6.8e-13,
3.1e-13 and 3.9e-12.

## 25. Solver options and status codes (from version 0.16.0)

**Options.** `cge_options` sets, as GAMS's `option` statement, members of
the model saved with it: `M.opttol`, `M.optit` and `M.opttime`, the
tolerance, iteration limit and time limit (seconds) of `cge_solve`, and
`M.optjac`, the Jacobian of Newton's method (1 for central differences,
mode 1 of `_cge_newton`); missing means the default (1e-10, 100, none,
exact), and `reset` sets every option, `linsolver` and `mcpsolver` included,
to missing. `cge_solve` passes -1 for an option it is not given;
`_cge_opttol`, `_cge_optit` and `_cge_opttime` resolve the command's value,
then the model's, then the default, and `_cge_optmode` the mode, which
`_cge_solve_point` and `_cge_continue` pass on. A new model starts with the
defaults.

**Limits.** `_cge_deadline_set(t)` keeps the deadline, now plus $t$ seconds
by `clock(c("current_date") + " " + c("current_time"))` (to the second), in
the external `cge__deadline`, and clears `cge__stop`; `_cge_timeup()`, which
the loops of `_cge_newton`, `_cge_ssnewton` and `_cge_nlp_solve` call at each
iteration, returns 1 once it has passed and records code 3 in `cge__stop`;
a loop that reaches its iteration limit records 2 (`_cge_stop_set` keeps the
larger). `cge_solve` sets the deadline before the solve and clears it after,
also after an error (`capture` in the ado), so that it never reaches later
solves. A solve stopped by its time limit, or whose Newton iterations reach
the limit, takes none of the fallbacks of `_cge_solve_sys` (central
differences, Powell's method), the active-set method after the semismooth
one, or the continuation of `cge_solve`.

**Statuses.** GAMS's codes, from `_cge_status(conv, cons, nlp, feas, err)`:
converged, model status 16 (solved), 1 (optimal) with constraints in the
system (`_cge_cons_on`: any `bmode > 0`, as PATH reports an MCP) or 2
(locally optimal) for a nonlinear programme, solver status 1; a residual
that cannot be evaluated, 13 and 5; otherwise solver status 3 (time), 2
(iterations) or 4 (terminated by the solver), with model status 6
(intermediate infeasible) after a limit, 7 (feasible solution) for a
nonlinear programme stopped at a point whose scaled residuals are below
$\max(\text{tol}, 10^{-8})$, and 5 (locally infeasible) otherwise. The
optimiser gives 2 (16 for targets alone) when it converges, else 7 at a
solution of the model and 6 without one, with solver status 4. Each
simulation keeps its pair in `M.simstat` (`_cge_set_simstat`, defaults from
convergence in `_cge_store_sim`, aligned by `_cge_sims_keep`; missing for
simulations stored before 0.16.0), returned by `cge_solve`, `cge_optimize`,
`cge_results` (`r(modelstat)`, `r(solvestat)`) and, for the simulation
compared, `cge_gams, compare` (`r(stata_modelstat)`). Failures display
them.

Tests (`tests/test_status.do`): defaults and reset; statuses 16/1 after a
solve, 6/2 after `iterate(1)` from the command and from the options (Powell
no longer rescues it), 6/3 after `timelimit(0)` with no continuation, no
deadline left for a later solve or the optimiser; tolerance and differenced
Jacobian from the options (the same solution to 2.7e-14); 1/1 with a binding
quota; options and statuses saved and loaded, a model of version 0.3.0 with
the defaults, statuses kept when simulations are dropped; HS071 2/1, 6/2
after 2 iterations, 7/2 after 15 (primal error 4e-12, dual not yet), 6/3
after `timelimit(0)`; 13/5 for $\ln$ of a negative start; the optimiser
2/1; errors.

## 26. Named models (from version 0.17.0)

`cge_model define NAME = list` keeps (NAME, list) in `M.mdef`, as GAMS's
`model NAME / list /`; the list (spaces, commas or slashes) names user
equations, defined variables, inequalities, earlier models and `all`, and is
expanded when it is used (`_cge_mdef_expand`, recursively, cycles stopped at
depth 20), so that a model follows equations added later. A name may not be
an equation's or `all`, a model may not list itself, and a model another
lists cannot be dropped. Each element of block U belongs to the equation of
its label (`_cge_mdef_base`: the text before its index, without the prefixes
`_S_`, `_L_`, `_U_` of slacks and adjusters), each constraint to the equation
of the variable it limits.

`_cge_submodel(M, name, M2, usel)` builds the model's system: a copy `M2`
with the constraints of its inequalities only (`bY`, `bX`, `btype`, `bdir`
and the constraint states of `p` and `p0`), the masks and pattern recomputed
(`_cge_u_refresh`), the elements of U outside the model removed from `emask`
and the pattern made again (`_cge_pattern`); the free variables that appear
in no row of the pattern are fixed. `cge_solve, model()` (`_cge_solve_named`)
starts from the current levels or, with `from(sim)`, those of a stored
simulation for the free variables (`_cge_named_start`, `_cge_named_from`),
holds the variables of `hold()` at those levels (`_cge_hold`: whole
variables or `NAME(e)`, `NAME(e1,e2)`), requires a square system (459
otherwise) and solves it with `_cge_solve_point`; the simulation keeps the
model (`M.simmodel`, aligned as `simobj` and `simstat`) and its residual is
that of the model's equations. `minimize()` or `maximize()` with `model()`
solves the nonlinear programme of the model. `from()` and `hold()` also apply
to the whole model. `cge_model describe NAME` gives the statistics of the
model's system.

`cge_gams` exports a simulation of a named model with `model cgesub / UEk,
... /` (and `cgesubn` with `EOBJ` for type nlp), the free variables outside
it fixed at their levels (`.fx`); a named model with inequalities, or type
mcp, is refused.

Tests (`tests/test_models.do`): two markets with supply $2P^2$ and demand
$a/\sqrt P$ and the value of their sales as a defined variable; the markets
model gives the closed form $P = (a/2)^{2/5}$ to 9e-16 with the total at its
starting level; the total alone from the markets' solution with the prices
and quantities held gives the whole model's total; models that list models
and `all`; `from()` of a solution converges in no iteration; a shock; demand
alone with the quantities held gives $P = a^2$; non-square systems; save and
load; dropping; HS071 as a nonlinear programme of a submodel with an
equation outside it at its level; errors. GAMS (export check case
namedmodel) to 4.2e-16.

## 27. Integer variables and branch and bound (from version 0.18.0)

`cge_bound X[(e)], integer|binary|continuous` appends (name, elements, type)
to `M.intdef` (standalone models only); `binary` also appends the bounds 0
and 1 to `M.bddef`. `_cge_int_pos` gives the integer and binary positions,
the definitions applied in order (`continuous` resets), and `_cge_int_type`
their types for GAMS; `cge_bound X, clear` removes them. A system solve of a
model with integer variables stops with 459; a nonlinear programme with them
is solved by `_cge_bb`:

- the node stack holds bounds of the integer variables (columns of `SL`,
  `SU`), warm starts (`SX`) and the parent's relaxation value (`pb`), depth
  first;
- `_cge_bb_node` solves a node: bounds that meet fix the variable; with more
  free variables than equations the interior point (`_cge_nlp_solve`, soft:
  no stop on its preconditions), with as many Newton's method and a check of
  the bounds, with none a point whose residuals must vanish;
- a node is pruned when its relaxation, or its parent's, is no better than
  the incumbent less $\max(10^{-9}\max(1, |h|), \text{optcr}\,|h|)$, in the
  minimisation value $h$; an integral relaxation ($|x - \text{round}(x)| \le
  10^{-6}$) becomes the incumbent; otherwise the most fractional variable
  $x_j = v$ branches into $x_j \le \lfloor v \rfloor$ and $x_j \ge \lceil v
  \rceil$, the child nearer $v$ first;
- the incumbent is solved again with its integers fixed at their rounded
  values; the marginals are those of that solve;
- statuses: 1/1 for a complete search with an incumbent, 8 with an incumbent
  when the node limit (solver status 2) or the time limit (3) stops it, 10/1
  for a complete search without one, 14 when a limit stops it without one;
  `r(nodes)`, `r(bestbound)` (the incumbent, or the least bound of the nodes
  left), `r(gap)`; the simulation's method is `minlp`.

The interior point accepts a point it cannot improve before its iteration
limit when its scaled residuals are below $\max(\text{tol}, 10^{-8})$ and its
error below $\max(10^3\,\text{tol}, 10^{-7})$, as IPOPT's acceptable level
(a relaxation at a bound stalled at a dual error of 7e-10); from version
0.21.0 the best point met is accepted, to $\max(10^3\,\text{tol}, 10^{-6})$,
after a degenerate linear programme (Dantzig's transportation problem)
reached 1.4e-7 before a step of its multipliers spoiled it.

GAMS: `_cge_gams_user` declares a variable `integer variable` or `binary
variable` when all its elements are of that type (a mixture stops the
export), with `.lo = -inf` and `.up = inf` for integer elements before the
bounds of `cge_bound`; the driver solves `cgeprog using minlp` (or `mip`)
with `optcr = 0, optca = 0`, SCIP by default. Two fixes found by the export
check: a model without sets declares `set AC(*)`, and an integer constant
exponent is written `power(x, n)` (`_cge_gams_pow`), since GAMS's `x ** y`
needs $x > 0$.

Saving a model without simulations and loading it gave a 0 x 0 matrix of
simulations, to which a solution could not be joined; `_cge_store_sim` now
shapes it first.

Tests (`tests/test_mip.do`): a knapsack of eight items against enumeration
of the 256 choices (37, in 19 nodes); integer least squares against
enumeration (0.52 at (2, 1)); an equation among integers with a continuous
variable, whose leaves are square systems (4 at (3, 2, 3)); integer
infeasibility (status 10); a node limit of 1 (status 14); types reset by
`continuous` and kept by save and load; errors. GAMS with SCIP (export check
cases miknap, a knapsack with a unique optimum, and miils) to 6e-16 and
2.1e-11.

## 28. Parallel scenario runs (from version 0.19.0)

`cge_loop, parallel(P)` (`_cge_loop_par`) saves the model (`cge_save`),
splits the S scenarios, whose values are first completed with the targets'
values in place, into P contiguous groups ($a_k = \lfloor (k-1)S/P \rfloor +
1$, $b_k = \lfloor kS/P \rfloor$), and writes for each a do-file that sets
the session's ado-path with relative folders made absolute
(`_cge_abs_adopath`), loads the model, runs `cge_loop` with the group's
values as paired lists and `first(a_k)`, saves the model and writes its
return code to a file. The processes are started with `winexec` (Windows,
`/e`) or `shell ... -b ... &`, in the folder of Stata's temporary files,
where their logs go; the executable is that of the running edition
(`_cge_stata_exe`) or `stataexe()`. The session waits (`sleep 200`) for every
return code, at most 600 + 120 S seconds, stops with a process's error, and
merges the groups' simulations (`_cge_store_sim` with each simulation's
parameters, statuses kept), so that the names and results are those of one
run; the measures are computed in the session. Within a group, each scenario
starts from the solution of the one before. On Windows, Stata in batch mode
ignores `winexec`, so the scenarios are solved in the session with a note.
`first(f)` numbers the scenarios from f.

Tests (`tests/test_parallel.do`, in batch mode): parallel(2) gives the
sequential loop's measures to 1e-10 (solved in the session); first()
names the simulations; the executable and an absolute ado-path; errors. The
runs across processes were checked in an interactive session of StataNow
19.5: four scenarios in two processes give the sequential loop's measures to
5.7e-13, with the same names; the processes' start-up took 14 s against 0.1 s
for the four solves, so that parallel runs pay for scenarios that take longer.

## 29. Nash equilibria and leaders (from version 0.20.0)

`cge_nash player NAME, instruments() maximize()|minimize() [lower() upper()]`
keeps (name, instruments, sense, objective, bounds) in `M.nashdef`, saved
with the model; instruments are read as in `cge_optimize`
(`_cge_opt_instrument`), and an instrument belongs to one player. `cge_nash
solve, name()` iterates rounds of best responses (Gauss-Seidel): each player
in turn solves `cge_optimize` over its instruments with the others' at their
current values, which leaves its optimum as the current shocks (an
instrument at a bound first moves inside it, by 5 per cent of a finite range
or 1 per cent of its size, as `cge_optimize` starts within the bounds and
scales an instrument by its start, `_cge_nash_nudge`); the rounds
end when the largest change of an instrument, relative to $\max(1, |u|)$, is
below the tolerance (default 1e-8, at most `iterate()` rounds). The
equilibrium is solved and stored as the simulation; each player's objective
there is evaluated by `_cge_nash_value` (the parser of `cge_optimize` at a
stored simulation). `leader()` (`_cge_nash_leader`) maximises the leader's
objective $F(u_\ell)$ at the followers' equilibrium (`cge_nash solve,
exclude()` for each evaluation, `_cge_nash_leval`) by a projected Newton
method: gradient and Hessian from central differences of $F$ with steps
$10^{-3}$ times each instrument's scale, Newton's step where the Hessian is
negative definite and a scaled gradient step otherwise, halving until $F$
rises, converged when the largest free gradient, scaled, is below $10^{-6}$.

Tests (`tests/test_nash.do`): Cournot duopoly, $q = (a - c)/3b = 3$, to
1e-6, with profits of 9; Stackelberg, $q_\ell = 4.5$ and $q_f = 2.25$, to
1e-4, with the leader's profit $10.125$; three firms, $2.25$ each; a game on
the standard model (the direct tax factor bringing revenue to 2 per cent
above its base against a tariff chosen for welfare), where the tariff ends at
its lower bound and the government's own optimum confirms the tax factor;
save and load; errors. The exact maximiser of `cge_optimize` now requires a
rise in its line search to exceed $10^{-14}\max(1, |F|)$: near the flat
optimum of a best response, rises of rounding size had moved the point
without end at a gradient of 1.2e-10.

## 30. Model library and error positions (from version 0.21.0)

`cge_modlib` lists, describes, runs (`do`) and copies the models of the
library, do-files `cge_ml_NAME.do` (from version 0.27.1 installed as one
bundle, `cge_ml_library.txt`, Section 37); each begins with `*!` lines giving its
title, kind, reference and expected result, which `cge_modlib list` and
`describe` read. The models: an exchange economy ($P_2 = 8.2/5.4$), Robinson
Crusoe as a planner's NLP ($N = 10/3$), two markets solved block by block
with named models, HS071 (17.0140173), Dantzig's transportation problem as a
linear programme (153.675), cross-entropy balancing (the RAS solution), a
knapsack (43, a unique optimum) and Cournot and Stackelberg games (3; 4.5 and
2.25). `tests/test_modlib.do` runs each and checks its result.

The interior point keeps the best point it meets, by the error of the
optimality conditions, and accepts it when it stops short of its iteration
limit with that error below $\max(10^3\,\text{tol}, 10^{-6})$ and the equations
holding, as IPOPT's acceptable level: the transportation problem, a
degenerate linear programme, reached 1.4e-7 at its optimum before a step of
its multipliers raised the error to 15.

Error positions: the compiler of expressions, `_cge_u_compile`, reports its
syntax errors through `_cge_u_fail(t, k, msg, rc)`, which prints the tokens
read, separated by spaces, and a marker under token k (the end for an error
after the last token; the 80 characters before the place for a long
expression), then stops as `_cge_fail`.

## 31. Starts on bounds and a growth model (from version 0.22.0)

`cge_optimize` moves an instrument whose current value lies on or beyond a
bound inside it, by 5 per cent of a finite range or 1 per cent of the
bound's size, with a note, and scales the instruments by their starts after
the move (`_cge_optimize`); before, such a start stopped with error 459,
which a best response of `cge_nash` from a bound met (its nudge stays). The
library adds `ramsey`: a planner's choice of consumption over 30 years with
capital accumulation over the pairs of consecutive years (a set of pairs
`nx(t,t2)`; from version 0.26.0 the lead `K(t+1)`, Section 35), a terminal
capital at the steady state and the discounted sum
of $\ln C$; the Euler equation $C_{t+1}/C_t = \beta(1 - \delta + \alpha
K_{t+1}^{\alpha - 1})$ holds in every year to 1.7e-11.

Element labels equal to the names of indexes (labels `t2` in a set whose
alias index is `t2`) were substituted wrongly in equations over two indexes:
the first index was replaced by its label, which the second index's
substitution replaced again. From version 0.22.1 `_cge_u_subst2` puts the
first element in through a placeholder (`tests/test_models.do`, pairs of
consecutive years t1 to t3). Sums over an alias inside an equation met the
same collision until version 0.23.0 (Section 32); the model's years are
named `y1` to `y30`.

Tests: `tests/test_optimize.do` (a start on a bound reaches the optimum of a
start within it); `tests/test_modlib.do` (the Euler equation to 1e-8 and
the path of capital).

## 32. Labels named like indexes, and the optimiser's scales (from version 0.23.0)

An element put in for an index, in an equation, a defined variable, a
parameter's definition, a domain's condition or a sum, is marked with
`char(2)` when it is the name of an index (`_cge_u_mk`): label `g2` of a set
whose alias is `g2`. A sum over `g2` within then leaves it alone, and the
compiler (`_cge_u_compile`) removes the marks before it reads the
references (`_cge_u_um`). Before, in $X_g = \sum_{g_2} a_{g,g_2}$ with labels
`g1` to `g3`, the element `g2` of the equation became the sum's index, and
$X_{g2}$ was $\sum_j a_{j,j} = 36$ for $\sum_j a_{2,j} = 24$ (with $a_{i,j} =
i^2 j$); nested sums met the same collision through the outer sum's
elements. A sum over the equation's own index, `sum(g, ...)` in an equation
over `g`, is an error for such labels as for others (GAMS's "set already
under control"); before, it was a sum over the alias that the label names.
Labels that are not the names of indexes are not marked, so models without
them write the same tokens as before.

`cge_optimize` scales each instrument by its start, but by no less than 1
per cent of a finite range, 1 per cent of a single bound's size (at least 1),
or 0.01 without bounds; a free instrument that starts at zero is scaled by 1,
as before. Before, a start of $10^{-7}$ was its own scale: the gradient in
the scaled instruments, $10^{-7}$ times the gradient, met the tolerance far
from the optimum, and the optimal tariff of the synthetic model came out at
0.33 for 1.51 (0.0018 from $10^{-10}$).

`tools/gams/run_export_check.py` runs GAMS up to three times when it
returns 7, a licence error that the network licence gives now and then.

Tests: `tests/test_models.do` (sums over the aliases `g2` and `g3`, nested,
and a parameter, against $6i^2$ and $84i$; the sum over the equation's own
index); `tests/test_optimize.do` (starts of $10^{-4}$, $10^{-7}$ and
$10^{-10}$ within bounds and $10^{-7}$ without, to the optimum of the
base start within $10^{-6}$); the export case `labalias`.

## 33. Newton's method for Nash equilibria, multi-start and parallel runs from batch mode (from version 0.24.0)

`cge_nash solve, method(newton)` solves the players' first-order conditions
together. For instrument $i$ of player $p(i)$, with sense $s_p$ ($+1$ to
maximise) and objective $f_p$ scaled by its size at the start (at least 1),
$G_i(z) = s_{p(i)}\,\partial f_{p(i)}/\partial z_i$ in the scaled
instruments $z$ of `cge_optimize`. `_cge_optimize(..., setup)` sets up the
instruments and bounds of all the players and takes their objectives as
targets ($f_p = 0$), whose exact derivatives (Section 24) give every $G_i$
from one factorisation of the model's Jacobian at each point; central
differences of solved models replace them where they cannot be found. With
bounds $l \le z \le h$ the conditions are
$$F(z) = z - \mathrm{mid}(l, z + G(z), h) = 0,$$
which a semismooth Newton method solves: the Jacobian of $G$ by forward
differences of $G$ (step $10^{-5}$, backward at an upper bound), the rows
of $F$'s generalised Jacobian $-\partial G_i/\partial z$ where $z_i + G_i$
lies within the bounds and $e_i'$ where it does not, the step projected on
the bounds and halved until $\|F\|_2$ falls by a factor $1 - 10^{-4}t$. It
converges when $\max|F| <$ `tolerance()` (default $10^{-8}$). At the
equilibrium each player's block of $\partial G/\partial z$ over its
instruments within their bounds must be negative semidefinite (largest
eigenvalue of its symmetric part at most $10^{-4}$ of its size), as at a
maximum; otherwise a note says the point meets the first-order conditions
but may not be a best response, and `r(second_order)` is 0. A game whose
best responses $x_1 = 1 + 1.5x_2$ and $x_2 = 1 - 1.5x_1$ diverge when taken
in turn (each round multiplies the distance by 2.25) is solved in two
iterations to $(10/13, -2/13)$; the standard model's game of the direct tax
factor and the manufactures tariff in 9 iterations (47 solves), with the
tariff at its bound. `damping(#)` moves each player the share $\#$ of the
way to its best response, $u_p \leftarrow u_p + \#(BR_p - u_p)$; the game
above converges with damping 0.5 in 28 rounds. A leader's followers are
solved by the method given.

`cge_solve, starts(#)` runs the interior point from the start and from
$\# - 1$ other points of the free variables, drawn uniformly within their
bounds, or within $\max(1, |x|)$ of the start where a bound is missing, and
keeps the best solution that converges (`_cge_nlp_multi`). The points come
from a generator of its own (MINSTD, $x \leftarrow 48271x \bmod (2^{31} -
1)$, seed 20261025), so that Stata's random numbers are left alone and a
run repeats. With integer variables every relaxation of branch and bound is
multi-started. $f(x) = (x^2 - 1)^2 + 0.3x$ with $x = k/2$, $k \in [-4, 4]$
has a local minimum at 0.96, which the interior point reaches from $k = 2$,
and its global minimum at $-1.036$, which five starts find; with $k$ an
integer, branch and bound from $k = 2$ prunes the node $k \le 1$, whose
local minimum at its bound ($x = 0.5$, 0.71) exceeds the incumbent 0.3, and
five starts find $k = -2$ with $-0.3$.

`cge_loop, parallel()` in batch mode on Windows, where Stata ignores
`winexec`, starts the processes through Python's `subprocess` module on
Stata 16 and later (`python:`, which needs a Python installation; Stata's
`help python`), with no window. Stata 13 to 15 cannot start other processes
from batch mode, and solve the scenarios in the session with a note that
names the version and the requirement; so does Stata 16 or later without
Python. Parallel runs from batch mode therefore work only on some Stata
versions; interactive Stata of any version starts them as before. Each
process starts Stata and loads the model, about 14 seconds here, which no
change in the package removes.

Tests: `tests/test_nash.do` (the diverging game by Newton's method to
$10^{-10}$ and by damping to $10^{-6}$, best responses failing; a duopoly
with a firm at its bound by Newton's method; a leader with Newton's method
for its followers; the standard model's game against the Gauss-Seidel
equilibrium; errors); `tests/test_nlp.do` (the global minimum against the
roots of $4x^3 - 4x + 0.3$, to $10^{-8}$); `tests/test_mip.do` (one start
stops at $k = 2$, five find the best of the nine integers);
`tests/test_parallel.do` (two and three processes from batch mode on Stata
16 and later with Python, the sequential results to $10^{-10}$; the note
and the session's results on Stata 13).

## 34. Three or more indexes (from version 0.25.0)

User sets, parameters, variables and equations may have any number of
indexes, as GAMS's symbols do: `cge_parameter a(i,j,k) = ...`,
`cge_variable X(i,j,k)`, `cge_equation EX(i,j,k)$(m(i,j,k)): ...`. The
indexes must differ; two over the same set take digits, as `(i,j,k,i2)`.

Layout. A symbol over sets $S_1, \dots, S_n$ has the set code
`S1|S2|...|Sn` and is stored, as one with two indexes, as a matrix of
$|S_1|$ rows and $|S_2| \cdots |S_n|$ columns: the later sets form a
product whose labels are the tuples of their labels joined by periods, the
last index changing fastest (`_cge_setsize`, `_cge_setlab` and `_cge_nidx`
read codes of any length; `_cge_setparts` gives the first set and the
product). Element $(e_1, e_2, \dots, e_n)$ is therefore row $e_1$ and column
`e2.e3....`, so that everything written for two indexes (results, GAMS
labels in files, GDX records, positions) holds, the second label being a
tuple. Labels have no periods (letters, digits and underscores), so the
tuples are unambiguous.

Domains. `_cge_u_substd` puts in the labels of an element for the indexes of
the domain; with three or more it recovers the position of each index,
for `ord()`, from the position in the product, and puts in all but the last
through placeholders, each label marked as in Section 32.

Sums and sets of tuples. `sum((i,j,k)$(c), e)` is written as
`sum(i, sum(j, sum(k$(c), e)))`, and `sum(m(i,j,k)$(c), e)` over a set of
tuples (`cge_set m(i,j,k) = e1.e2.e3 ...`) as the same with the condition
`m(i,j,k) & (c)`; `prod`, `smax` and `smin` likewise. In a condition,
`m(e1,e2,e3)` is 1 for a tuple of the set. A set that a set of tuples is
over can no longer be removed while that set exists.

Data. `values(e1.e2.e3:#)` gives values by element; `from(v) labels(li lj
lk)` reads long data, one label variable per index; the wide form of
`from()` stays for two indexes. `cge_shock`, `cge_bound`, `cge_constraint`
and the results take an element as `e1.e2.e3`; messages and listings write
it `X(e1,e2,e3)`. The results dataset keeps two element columns, the second
holding the later labels joined by periods.

GAMS. Variables are declared over `(AC, AC, AC)`, parameters and lags over
`(*, *, *)`, and their elements written `('e1', 'e2', 'e3')`.

Tests: `tests/test_multiindex.do` (a three-index parameter, variable and
equation, $X_{ijk} = \sqrt{100i + 10j + k}$ to $10^{-12}$; sums over all,
two and one of the indexes against closed forms, 2058, $600i + 129$ and
$300i + 60 + 3k$; a set of triples in a sum, a domain and a condition
against enumeration; four indexes with an alias; `values()` and long
`from()`; shocks of a parameter and of a fixed variable; bounds; saving
and loading; errors); the export case `multiindex`.

## 35. Lags and leads on ordered sets (from version 0.26.0)

A user set is ordered, its elements in the order given, and an argument of
a reference may shift an index by a whole number, as GAMS's lags and leads
do: `K(t-1)` is the element before, `K(t+1)` the one after and `K(t+n)` $n$
places after; `K(t--1)` and `K(t++1)` count round the set (circular), so
that the element after the last is the first. An element beyond the set
does not exist, and its reference is 0, as in GAMS: in
`cge_variable L(t) = g(t-1)` the first element is 0. `base()` of such a
reference is 0 too. Conditions take `ord(t)` and `card(t)`, as
`$(ord(t) > 1)` and `$(ord(t) < card(t))`.

`_cge_u_substl` puts in an index with its shifts: with the labels of the
set, the shifted position $o \pm n$ gives a label (marked as in Section
32), or for a circular shift $((o \pm n - 1) \bmod |S|) + 1$; beyond the
set it gives the token `char(3)` + `none`. It serves the sums
(`_cge_u_expand`) and, through `_cge_u_substd`, every domain: equations,
defined variables, parameter assignments and their conditions, each index of
several. The compiler (`_cge_u_compile`) makes a reference that holds that
token 0 (`_cge_u_none`). Shifts are written out with the elements, so the
GAMS program has the labels and needs nothing of its own.

These shifts are within one model, over a set such as the years of an
intertemporal model; `lag()` and `lead()` (Section 19) refer to the periods
of a dynamic run instead. The library's Ramsey model now accumulates
capital with `K(t+1)` in every year but the last, in place of a set of pairs
of consecutive years; its solution is unchanged.

Tests: `tests/test_lagindex.do` (lags, leads, a shift by 2 and circular
shifts of $g_t = t$ against their values, with 0 beyond the set; a
telescoping sum, 4; a shift within a sum over an alias, $40t + 14$; capital
accumulated by a lag in an equation's domain and by a lead, against the
recursion $K_t = 0.9K_{t-1} + 10(t - 1)$; two indexes; base() of a lag in a
domain's condition; errors); `tests/test_modlib.do` (the Ramsey model's
Euler equation); the export case `lagindex`.

## 36. Links to SciPy through Python (from version 0.27.0; an experimental prototype)

On Stata 16 and later with Python and SciPy, the package can hand two tasks
to SciPy, through Stata's Python integration and the module
`ado/cge_scipy.py`, installed with the ado-files. Stata 13 to 15 have no
Python, and keep the package's own solvers: the options stop there with
error 198, and a model saved with `linsolver(python)` falls back to the
package's sparse LU with a note.

Data. Mata writes the data to binary files of little-endian doubles
(`bufio`, `_cge_binwrite`) and reads the results back (`_cge_binread`);
return codes and statistics come back as Stata scalars. sfi's `Mata.get` and
`Mata.toNPArray` took 2.8 s for the 161,000 entries of the Jacobian of a
40,190-equation model, the files 0.02 s. Python called from an ado-file
runs in a namespace of its own each time, so every call imports the module
again (`_cge_py_pre`); Python keeps the module, and the factors it holds,
once loaded.

`cge_options, linsolver(python)`: SciPy's SuperLU (Li 2005) factorises the
Jacobians of Newton's method in place of the package's sparse LU (Section
22): `_cge_slu_update` passes the entries to `cge_scipy.lu_factor`, which
keeps the factors under the key of the system (the model, the stacked
periods of a run with foresight, linked regions), and `_cge_slu_solve`
solves through them, the factors marked by `F.ok = 2`. On the 40,190
equations of the full system of the 250-activity benchmark SAM, one
factorisation took 16.4 s in Mata and 2.8 s in SuperLU, and the solutions
agreed to $10^{-15}$. Whole solves on StataNow 19.5
(`tools/bench/bench_results_0270_*_statanow19.csv`), the same iterations:

| Activities | Equations | Reduced, package (s) | Reduced, SuperLU (s) | Full, package (s) | Full, SuperLU (s) |
|---|---|---|---|---|---|
| 40 | 1,814 | 0.5 | 0.7 | 0.7 | 1.5 |
| 120 | 10,555 | 2.5 | 2.0 | 4.9 | 3.7 |
| 200 | 26,858 | 10.1 | 5.1 | 19.4 | 12.3 |
| 250 | 40,190 | 20.8 | 10.6 | 43.0 | 31.4 |
| 400 | 94,000 | 39.6 | 15.6 | 111.9 | 44.9 |

Below about 100 activities the calls to Python cost more than they save;
from 200 activities whole solves take 1.4 to 2.5 times less time, and what
remains is the Jacobian and the residuals, evaluated in Mata.

`cge_solve, minimize()|maximize() solver(highs)`: a linear or
mixed-integer linear programme of a standalone model by HiGHS (Huangfu and
Hall 2018), SciPy's `linprog` and `milp`. The equations and the objective
must be linear: their values at a second point, within the bounds, must
equal those at the start plus the derivatives times the step, to $10^{-8}$,
else error 459. In the variables' own units the programme is $\min
s\,g'x$ subject to $Ax = b$, $b = Ax_0 - c(x_0)$ with $c$ the scaled
residuals, $l \le x \le u$, and integer and binary variables flagged. A
linear programme returns the marginals of the equations,
$s\,y_k/e_k$ for HiGHS's dual $y_k$ and the scale $e_k$ of equation $k$, the
units of the interior point's. Statuses in GAMS's codes: 1 optimal, 3
unbounded, 4 infeasible, 10 integer infeasible, 14 no solution returned at
a limit. The simulation keeps the method `nlp` or `minlp`, so that
`cge_gams` exports it as before; `r(solver)` is `highs`.

Tests: `tests/test_scipy.do` (on Stata 16 and later: the synthetic model's
solutions with SuperLU against the package's sparse LU, reduced and full,
to $10^{-9}$, and the factorisations counted; a linear programme against
its closed form, 11 with marginal 2; the transportation problem against the
interior point, its optimum 153.675 and its marginals; a knapsack and an
assignment of six workers against enumeration; infeasible, unbounded and
nonlinear programmes; on Stata 13 to 15, the errors).

## 37. Package files (from version 0.27.1)

Stata's package files take at most 100 files: `net install` stops with
"package file too long" (error 640) beyond,
as it did for versions 0.21.0 to 0.27.0, whose `cge.pkg` listed 118 to 120.
The package now installs the fifteen SYNTHETIC SAMs, the nine models of the
library and the four files of the GAMS model as three bundles,
`cge_synthetic_sams.txt`, `cge_ml_library.txt` and `cge_gams_model.txt`,
text files of sections that begin with a line `@@@ name`; `cge_synthetic`,
`cge_modlib` and `cge_gams` take the section they need through
`_cge_bundle_get`. The files stay in the repository as the sources, which
`tools/bundle_files.py` writes into the bundles, and
`reference/tests/test_package.py`, run by CI, checks that `cge.pkg` lists at
most 100 files, that each exists and that the bundles are current. The
package now has 95 files.

In the same version, parallel runs of `cge_loop` (Section 28) wait for each
worker's complete status record, its return code followed by a final
marker, rather than for the file alone, which can exist before its
contents: a worker's status was intermittently read empty.

## 38. Exact second derivatives of nonlinear programmes (from version 0.28.0)

The interior point (Section 24) needs, at each iteration, the Hessian of the
Lagrangian $\mathcal{L}(z, \lambda) = s f(z)/\omega + \lambda'c(z)$ in the
scaled free variables $z$, with $s$ the sense, $\omega$ the scale of the
objective and $c$ the scaled residuals of the equations. Before, it came from
central differences of the exact gradient, $2n$ evaluations of the gradient
and of the Jacobian of the equations; from version 0.28.0 it is exact.

`_cge_u_hvalue` differentiates the postfix rows of an expression twice by
forward mode: each value on the stack carries its gradient and its Hessian,
both sparse (positions and values; triplets of both triangles), and each
operation combines those of its operands. For $u \cdot v$ the Hessian is
$vH_u + uH_v + \nabla u\nabla v' + \nabla v\nabla u'$; for $u/v$,
$H_u/v - (\nabla u\nabla v' + \nabla v\nabla u')/v^2 - uH_v/v^2 +
2u\nabla v\nabla v'/v^3$; for a function $\varphi(u)$ (exp, ln, sqrt, abs,
sqr, log10, $u^p$ with $p$ constant), $\varphi'H_u +
\varphi''\nabla u\nabla u'$; $u^v$ with $v$ variable is $\exp(v\ln u)$; min,
max and ifthen() take the derivatives of the argument they take.
Parameters, lags, leads and the period are constants. Duplicates are summed
when an outer product is formed and at the end, so that a sum of many
separable terms keeps a sparse Hessian.

`_cge_nlp_hess` assembles $W = (s/\omega)\nabla^2 f + \sum_k (\lambda_k/e_k)
(\nabla^2 L_k - \nabla^2 R_k)$ over the user equations $L_k = R_k$ with
scales $e_k$, in the units of $z$ ($\partial^2/\partial z_i\partial z_j =
\sigma_i \sigma_j \partial^2/\partial x_i \partial x_j$ for the
variables' scales $\sigma$). Every row of the system of a standalone model is
a user equation, a defined variable having its own; otherwise, or where a
value cannot be found, the method falls back to differences, as it does
under `cge_options, hessian(differences)` (member `opthess`, saved with the
model). `r(hessian)` reports which it used, with the counts
`r(N_hessian_exact)` and `r(N_hessian_differences)`; branch and bound and
multi-start use the same method.

The iterations are those of the differences (they solve the same Newton
systems to rounding); the time is not. On StataNow 19.5:

| Programme | Variables, equations | Iterations | Exact (s) | Differences (s) |
|---|---|---|---|---|
| Ramsey (library) | 60, 30 | 8 | 0.18 | 4.9 |
| Cross entropy, 20 x 20, SYNTHETIC | 400, 39 | 6 | 4.1 | 142.0 |

A fix in the same version: the interior point now stops at its best point
after fifteen iterations in a row with the error within $\max(10^3\,
\text{tol}, 10^{-6})$ and the equations holding, as IPOPT's acceptable level.
At a bound of a programme without equations the error of the dual
conditions stayed near $10^{-9}$, above the tolerance of $10^{-10}$, until
the iteration limit, so that branch and bound lost those nodes: integer
least squares without an equation found no integer solution.

Tests: `tests/test_hessian.do` (the Hessians of $x^2y$, Rosenbrock's
function and $e^{xy}$ against closed forms; three expressions that use every
operation and function against central differences of the exact gradient,
to $3.5\times10^{-10}$; the Lagrangian's Hessian of HS071, a frontier,
Rosenbrock's function and the Ramsey model against differences, to
$10^{-10}$; the same optima and iterations with exact Hessians and with
differences; branch and bound without equations; the setting saved with the
model; errors).

## 39. Set algebra (from version 0.29.0)

User sets (Section 19) were lists of labels written out, with `except()`
for a difference. From version 0.29.0 `cge_set` takes a domain and a set
expression, as GAMS's subsets and dynamic sets do:

```
cge_set name(i) = expression           a subset of the set of index i
cge_set name(i,j) = expression         a set of pairs (tuples with more)
cge_set name(i)$(condition) = expression
```

An expression combines factors with `+` (union; factors side by side are a
union too), `*` (intersection) and `-` (difference); `*` binds first, `+`
and `-` are read from left to right. A factor is a label (a tuple of labels
`e1.e2` in a domain of several indexes), a model set letter, a user set
(a set of pairs or tuples of the same number of indexes in such a domain),
`yes` or `no` (every element of the domain, none), an expression in
parentheses, or `not` and a factor (the complement in the domain), each
followed by any number of conditions `$(q)`. A condition on the name
applies to the whole expression.

Sets are ordered lists. With $A = (a_1, \dots, a_m)$, $B$ and $D$ the
elements of the domain in their order (a tuple's labels joined by periods,
the last index fastest, as the elements of user variables),

$$A + B = A \text{ followed by } (b \in B: b \notin A), \qquad
A * B = (a \in A: a \in B), \qquad A - B = (a \in A: a \notin B),$$

$$\texttt{not}\ A = (d \in D: d \notin A), \qquad
A\texttt{\$(}q\texttt{)} = (a \in A: q[i = a] \ne 0),$$

each element once. A list written out keeps the order given, as before; a
union keeps the order in which elements are first named. A condition is
evaluated for every element of $D$ by `_cge_u_domain`, as the domain of a
user variable (Section 20): the index written out, the condition compiled,
and its value taken at the base (`M.x0`, `M.p0`, lags and leads at the
base). The set is fixed when it is defined, as a GAMS assignment to a
dynamic set is fixed until the next assignment; it does not change with
later shocks or recalibration.

Every label must belong to the domain (GAMS's domain check), error 111
otherwise, and so must every element of a set named in the expression; the
domain may itself be a subset, `cge_set food(goods) = ...`. `not`, `yes`,
`no` and conditions need a domain. Without one, `+`, `*` and `-` combine
the model's labels and sets; in a standalone model new labels are written
out as a list, without operators. A set of pairs written out as before,
`cge_set map(a,c) = e1.f1 ...`, keeps its own path, `_cge_us_addpairs`, so
its messages and return codes do not change. A condition must be in
parentheses: Stata reads `$name` as a global macro, so `yes$odd(i)` reaches
the command as `yes(i)`.

The domain of a subset is stored in a fourth column of `M.usdef` (set code,
as `C` or `~goods`; empty for a list without a domain and for sets of pairs,
whose third column holds theirs). Models saved before version 0.29.0 have
three columns; `_cge_us_widen` adds the fourth when a set is added. Sets
stay lists of labels, so nothing changes in variables, equations, sums,
the solver or the GAMS program, which writes equations out element by
element.

GAMS's `loop`, `if` and `while` over assignments are Stata's own `foreach`,
`if` and `while` around `cge_set` and `cge_parameter`; `r(N_elements)` gives
the number of elements, as GAMS's `card()`.

Implementation (`ado/cge_mata.mata`): `_cge_us_add` (head, domain,
options), `_cge_us_lex` (tokens; a condition is one token), the recursive
descent `_cge_us_expr`, `_cge_us_term`, `_cge_us_factor`, `_cge_us_atom`,
`_cge_us_label`, the ordered operations `_cge_us_union`, `_cge_us_inter`,
`_cge_us_diff` (hash membership through `asarray`), `_cge_us_cond` and the
domain check `_cge_us_within`.

Tests: `tests/test_setalgebra.do` (every operation, precedence, `not`,
`yes`, `no`, conditions on the name, after factors and in sequence,
membership, `except()` with an expression, `card()`; subsets of subsets and
sets from variables; sets without a domain; sets of pairs and triples from
conditions against enumeration; the sets in variables, equations and sums of
a standalone model against closed forms; saving and loading, and models
saved with three columns; Stata loops around the command; errors and their
return codes; on a SAM-based model, the commodities with tariffs and the
pairs of factors and activities with large factor use against the model's
own base values, and a sum over them after a shock).

## 40. Reverse differentiation (from version 0.30.0)

The derivatives of the user language (user equations, definitions,
objectives of nonlinear programmes and of `cge_optimize`, and the rows of
runs with foresight) came from forward differentiation of the postfix rows
(Section 19, `_cge_u_dvalue`): each value on the stack carries a row of
derivatives with respect to the $m$ variables of the expression, so an
expression of $n$ rows costs $O(nm)$ in time and memory. A sum over many
elements, as a market-clearing row, an aggregate or the objective of a
cross-entropy problem, has $m$ proportional to $n$, and the cost grows as
$n^2$.

From version 0.30.0, `_cge_u_rvalue` differentiates in reverse. One pass
forward evaluates each row $r$ and records its operands (at most two; a
function of several arguments keeps the one it takes, as forward
differentiation does) with the partial derivatives $\partial v_r/\partial
v_{o}$; one pass backward, from the last row, adds to each operand's
adjoint the row's adjoint times the partial,
$$\bar v_o \mathrel{+}= \bar v_r\, \partial v_r/\partial v_o, \qquad \bar v_{\text{last}} = 1,$$
and the adjoint of a variable's row is its derivative. The cost is $O(n)$.
The partials are those of forward differentiation: $1, \pm1$ for sums and
differences, $b, a$ for $a b$, $1/b, -a/b^2$ for $a/b$, $b a^{b-1}$ for a
constant exponent, $a^b b/a$ and $a^b \ln a$ for a variable one, and the
derivatives of exp, ln, sqrt, abs, sqr and log10; comparisons and `!` have
none. A row that does not depend on the variables passes nothing back.

`_cge_u_dvalue` now chooses: reverse when an expression has at least
`_cge_u_rmin()` = RMIN variables, forward otherwise (`_cge_u_fvalue`). Mata
interprets each row of the reverse passes one statement at a time, while
the rows of forward differentiation are vector operations, so forward is as
fast or faster for short rows. Timed per gradient on StataNow 19.5, a sum of
$n$ terms in $m = n$ variables took (forward, reverse) 0.020 and 0.027
seconds at $m = 128$, 0.086 and 0.061 at 256, 0.33 and 0.15 at 512 and 1.08
and 0.26 at 1,024; forward differentiation of 10,000 variables would need a
matrix of about 190,000 by 10,000.

Fix, in the same version: forward differentiation gave missing derivatives
for a whole expression when a part of it that does not depend on the
variables had an undefined derivative, as `sqrt(par)` or `par^0.5` with
`par` = 0 (a row of zeros divided by zero), though the value was finite; a
Newton step then failed. Each value on the stack now carries whether it
depends on the variables, and constants keep a row of zeros, as in reverse
mode. A variable's own undefined derivative, as in `sqrt(X - 1)` at $X =
1$, remains missing.

Fix, also in version 0.30.0: `cge_equation, clear` in a standalone model,
whose variables are all user variables, stopped with error 3301 (an empty
range of the vector of variables); it now leaves a model without variables,
to which new ones may be added (`tests/test_standalone.do`).

Test hooks: `_cge_dmode(m)` sets the mode of `_cge_u_dvalue` (0 by the
number of variables, 1 forward, 2 reverse) and returns the number of reverse
passes since the last call.

Tests: `tests/test_reverse.do` (eight expressions over every operation and
function, reverse against forward to $10^{-13}$ and against central
differences; constants with undefined derivatives in both modes; an
expression of 300 variables and the choice of mode; a standalone model with
a dense row of 250 variables, a cross-entropy programme of 250 variables, a
SAM-based model with user equations (its exact Jacobian against
differences) and a run with foresight with lags and leads, each with the
same solutions and iterations in every mode).

## 41. Exact Jacobians of linked regions (from version 0.31.0)

The linked system of `cge_region` (Section 21) stacks each region's full
system and the link equations. Each region's Jacobian was exact; the columns
of the link variables in a region's equations and the link equations used
central differences, two evaluations of a region's whole system for each of
its link variables. From version 0.31.0 the whole Jacobian is exact.

**The regions' equations in their link variables.** A region's import pair
sets $pwm_c = pwm^0_c u$ and $tm_c = u'$, an export pair $pwe_c = pwe^0_c
u''$. `_cge_par_trip` gives the derivatives of the residuals $L - R$ of the
full system in $pwm_c$, $tm_c$ and $pwe_c$, scaled as the residuals, with
$t_c = tm_c\,TMADJ$, $\bar e_c = 1 - ced_c$ (the export price is $PWE$ for a
commodity with a demand curve) and $R^M$, $R^E$ the rents:

| Equation | $\partial/\partial pwm_c$ | $\partial/\partial tm_c$ | $\partial/\partial pwe_c$ |
|---|---|---|---|
| P1 (import price) | $-(1 + t_c + R^M_c)EXR$ | $-pwm_c\,TMADJ\,EXR$ | |
| P2 (export price) | | | $-\bar e_c(1 - te_c - R^E_c)EXR$ |
| T9 (exports from composite supply) | | | $-\sigma^t_c\,QER^{*}_c/pwe_c$ |
| T10 (exports on a demand curve) | | | $-\eta_c\,QE^{*}_c/pwe_c$ |
| I8 (government income) | $-t_c QM_c EXR$ | $-TMADJ\,pwm_c QM_c EXR$ | $-\bar e_c te_c QE_c EXR$ |
| S3 (balance of payments) | $QM_c$ | | $-\bar e_c QE_c$ |

with $QER^{*}$ and $QE^{*}$ the right-hand sides of T9 and T10; a rent on
imports, $R^M_c pwm_c QM_c EXR$, and on exports, $R^E_c \bar e_c pwe_c QE_c
EXR$, adds its derivative to the income equation of its recipient (I1 for a
factor, I3 for a household or enterprise, I8 for the government) or, divided
by $EXR$, to S3 for the rest of the world. User equations that use these
parameters are differentiated by their postfix rows (Section 40), with the
parameter element as a variable. Entries of one equation in one parameter
are summed. The chain rule gives the columns of the link variables, times
$pwm^0_c$, 1 and $pwe^0_c$.

**The link equations.** `_cge_lk_eqsd` evaluates the link equations with a
row of derivatives in the link variables and the regions' quantities for
every price and quantity: with $x_k = p_k(1 + t_k)/(1 + t^0_k)$ the price
with tariff of route $k$ into an import pair, $P$ its CES price index and
$R = QM/QM^0$,
$$dP = \sum_k \theta_k (P/x_k)^{\sigma} dx_k, \qquad
dq_k = v_k (P/x_k)^{\sigma} dR + \sigma q_k \left(\frac{dP}{P} -
\frac{dx_k}{x_k}\right),$$
also for $\sigma = 1$ (Cobb-Douglas), and for exports to the rest of the
world $dq_k = -\eta\, q_k\, dp_k/p_k$; the equations L1 to L3 follow from these.

`cge_region solve` uses the exact Jacobian; the iterations are those of the
differences or fewer, and the solutions agree with the Python reference as
before. On the two-region test model a Jacobian took 0.03 seconds against
0.07 with differences; the gain grows with the number of linked commodities.

Test hooks: `_cge_lk_jaccheck(perturb)` compares the linked Jacobian, exact
and with the differences, against central differences of the residuals
column by column, at the base links with every unknown moved by a pattern
of size `perturb` (and a tenth of that added, so that unknowns at zero, as
rents, move); `_cge_ptcheck(perturb)` compares `_cge_par_trip` for every
commodity of the model in memory against differences.

Tests: `tests/test_linkjac.do` (two regions with user equations that use
tariffs and world prices, free trade and an import quota paying rents; a
region with a demand curve for exports and margins by market; a region with
exports from composite supply, each at three points, to $10^{-6}$ of
central differences; and each model alone, `_cge_ptcheck`, with rents on
imports and exports to every kind of recipient, to $10^{-7}$).

## 42. Exact state derivatives in runs with foresight (from version 0.32.0)

The stacked system of a run with foresight (Section 10.6) has, after the
first period, the states of every period as unknowns. Capital stocks enter a
period as fixed variables, and their columns came from the period's exact
Jacobian; the other states enter through parameters and fixed values
(`_cge_fs_map`), and their columns were central differences of the period's
residuals, two evaluations of its system for each state. From version 0.32.0
`_cge_fs_sder` gives them exactly, from the equations that use them:

| State | Enters as | Equations, $\partial(L - R)/\partial s$ |
|---|---|---|
| domestic debt (2) | `ddebt` $= s$ | I3: $-hold_d\, r_d$; I9: $-r_d$ |
| foreign debt (3) | `fdebt` $= s$ | I9: $-r_f\, EXR$; S3: $r_f$ |
| efficiency of growth targets (4) | `ad` $= ad_t\, s$ | Q3: $-q3_a/s$ (value added is linear in `ad`) |
| population (5) | $\gamma$, $\gamma^h$, `hs0` $\times s$ | I5, I5H: $-(PH\,\gamma_t + \beta\, dSN)$, $dSN = -(PH'\gamma_t + PA'\gamma^h_t)$; H2: $\eta (HS/hs0)^{\eta}/s$; H3: $-sick\,\epsilon (HS/hs0)^{\epsilon}/(s(1 - sick_0))$ |
| labour force of a death factor (6) | `qlf` $\times s$ | L1, L2 through $u = 1 - QFS/qlf$, $du/ds = QFS/(qlf\, s)$ |

with the period's parameters $p(s)$ and point. User equations that use these
parameters are differentiated by their postfix rows (Section 40), each
reference to an element replaced by its coefficient times the state as a
variable (`_cge_fs_pvar`). The supplies of the factors that lose workers
to deaths are fixed values $x = X s$; their columns come from the period's
exact Jacobian, with those variables as extra columns as the capital stocks
are, times $X$. The external `cge__fsfd` set to 1 gives the differences of
before (a test hook).

Tests: `tests/test_foresight.do` (the stacked Jacobian against central
differences with debt, growth targets, deaths and population) and
`tests/test_fsjac.do` (the same with a labour force and a wage curve, health
efficiency, days lost to illness and user equations that use `ddebt`,
`fdebt`, `ad`, `hs0` and `qlf`, in both modes, to $10^{-6}$ of central
differences; runs in both modes agree to $10^{-10}$).

## 43. Equilibration of Newton's linear systems (from version 0.33.0)

The free variables are scaled by their base values ($z = x/s$, $s =
|x^0|$ or 1) and the equations by the larger side of each at the base
(`M.escale`), as CONOPT and PATH scale from the start point. Where these
scales are poor (a variable with a zero base that grows large, a base far
from the solution), the Jacobian's rows and columns may still differ by
many orders of magnitude.

`cge_options, scaling(ruiz)` (member `optscale`, saved with the model)
equilibrates each Jacobian $A$ of Newton's method and of the semismooth
method before it is factorised (Ruiz 2001): with $D_r = D_c = I$,

$$D_r \leftarrow D_r\, \mathrm{diag}(\|a_{i\cdot}\|_2)^{-1/2}, \qquad
D_c \leftarrow D_c\, \mathrm{diag}(\|a_{\cdot j}\|_2)^{-1/2},$$

each pass on the matrix scaled so far, ten passes at most or until every
norm is within 5 percent of 1; empty rows and columns keep 1. The factors
are those of $D_r A D_c$, and a solve gives $x = D_c (D_r A D_c)^{-1} D_r b$,
the same step in exact arithmetic. `_cge_ruiz` works on the entries of the
sparse LU (row and column panels sorted once, group sums by `panelsum`),
`_cge_ruizd` on a dense matrix; `_cge_slu_update` keeps the scales in the
factors and `_cge_slu_solve` undoes them, so every user of the sparse LU
(Newton's method, the semismooth method, runs with foresight, linked
regions, Broyden's updates) has them; `_cge_dsolve` does the same for the
dense LU. The setting is passed as the Python link's is, by
`_cge_sparse_on` (external `cge__ruiz`), and by runs with foresight and
linked regions (the first region's).

Test hook: `_cge_ruizcheck()` (the Jacobian of the model in memory at its
current point: condition numbers before and after, the norms of the scaled
rows and columns, and the agreement of the dense and sparse scales).

Tests: `tests/test_scaling.do` (the SYNTHETIC SAM, condition $3.0\times10^3$
to 64 with rows and columns of norm 0.86 to 1.14; a standalone model whose
variables enter every equation with coefficients from $10^{-5}$ to $10^5$,
$5.4\times10^8$ to 3.9; the same solutions with and without scaling, with
the dense and the sparse LU, for a tariff removal, that model, an import
quota by the semismooth method (one or two iterations fewer), a run with
foresight and linked regions; the setting saved, reset and checked).

## 44. Box pairs (from version 0.34.0)

A box pair is an equation paired with a variable between bounds, as PATH
and GAMS's MCP models write a mixed complementarity problem:

```
cge_equation NAME[(i)][$(c)]: lhs = rhs, perp(VAR[(e)]) [lower(#)] [upper(#)]
```

$F = lhs - rhs$ is perpendicular to $L \le X \le U$: $X$ between its bounds
where $F = 0$, $X = L$ where $F \ge 0$, $X = U$ where $F \le 0$. An
inequality paired with a variable (Section 19) is the case of one bound; the
quota of Section 16 with a cap on its rent is a tariff-rate quota.

**Stata.** Each element is a user equation in the natural residual form

$$X = \mathrm{mid}(L, U, X - cF), \qquad c = s_X / \max(|lhs^0|, |rhs^0|),$$

compiled as `max(L, min(U, X - c*((lhs) - (rhs))))` (`_cge_u_boxrow`), with
$s_X$ the scale of $X$ and $c$ fixed at the base; its solutions are those of
the pair for any $c > 0$. The paired variable must be fixed under the
closure and start within its bounds (`_cge_u_boxcheck`, error 459); the pair
frees it (`_cge_sys_make`, as the adjusting variables of constraints), so
the system stays square, and the closure's count includes it. Newton's method
solves the equation with the exact derivatives of `min()` and `max()` (the
argument taken, Section 40), so semismooth in effect. The pairs are kept in
`M.ubox` (row of each element among the user equations, the position of
$X$, $L$, $U$ and the scale of $F$), made again with the user equations.

**GAMS.** The base model leaves the pairs out ($X$ is fixed there). In the
scenario (`cge_constraints.inc`), each element is

```
variable BXVk;  BXVk.lo = L;  BXVk.up = U;
UBk..  ((lhs) - (rhs)) / sF =n= 0;
LBk..  X =e= BXVk;
```

with $X$ freed, and model `cgecon` adds `LBk, UBk.BXVk`; a model with box
pairs is exported with `type(mcp)` (the default for it) and solved by PATH.

Tests: `tests/test_boxpair.do` (one-variable boxes in each regime; a target
on government purchases met by GADJ within bounds, interior, above and below,
against GADJ fixed where it should be, to $10^{-13}$; a tariff-rate quota
against the quota as an inequality when the cap does not bind, and with the
cap binding, the rent at the cap and imports over the quota; listing, saving
and loading; the GAMS files; errors) and the export check's case `boxpair`
(PATH, model status 1, 117 values to $4.3\times10^{-13}$).

## 45. The structure of the system, and solving block by block (from version 0.35.0)

`cge_structure [, sim(name) base full top(#)]` analyses the system that
`cge_solve` solves under the closure (the reduced system for a model from a
SAM, the full one with `full`): its pattern is the set of nonzero entries of
the exact Jacobian at the point (`_cge_jac_trip`), rows of the system and
free columns. The pattern that `_cge_pattern` keeps for grouped differences
leaves out the dense rows, so it is not used.

**Matching.** A maximum matching of rows and columns (`_cge_st_match`):
each row, in increasing order of its number of entries, takes its first
unmatched column; from each row left unmatched, a depth-first search looks
for an augmenting path (rows and columns alternately, the last column
unmatched) and flips it. The structural rank is the number of rows matched;
the system is structurally singular when it is below the number of rows or
of columns, whatever the values of the entries.

**Dulmage-Mendelsohn parts** (`_cge_st_parts`). From the unmatched rows,
alternating paths (a row to all its columns, a column to the row matched to
it) reach the over-determined part: its rows outnumber its columns, so an
equation is redundant or a variable must be freed. From the unmatched
columns (a column to all its rows, a row to the column matched to it) they
reach the under-determined part: its columns outnumber its rows, so a
variable must be fixed or an equation added. The rest is the square part.

**Blocks** (`_cge_st_blocks`). In the square part, row $i$ points to row
$k$ when $i$ contains the column matched to $k$; the strongly connected
components of that graph, by Tarjan's algorithm without recursion, are the
blocks of the block-triangular form, in an order in which each depends only
on itself and on those before it (the order the algorithm finds them). On
the SYNTHETIC SAM the reduced system of 69 equations has 15 blocks, 14 of
one equation and one of 55 (the simultaneous core of prices and
quantities); the full system of 93 has 15, the largest of 79.

The report names the parts of a singular system (block and element of each
equation, as `cge_listing` gives them; each variable's label) and the
largest blocks; r() gives the counts and the labels of the parts.

**Solving block by block.** `cge_solve, blocks` (for a standalone model
without constraints) solves the blocks in that order (`_cge_blocksolve`):
for each, Newton's method on its own equations and their matched variables
(`_cge_blk_newton`), the residuals and exact Jacobian of each equation
evaluated alone from its postfix rows (`_cge_blk_F`, `_cge_blk_J`, through
`_cge_u_dvalue`), with a line search on the norm of the scaled residuals,
each block to a tenth of the tolerance; the other variables hold their
values, the solutions of the blocks before. The largest scaled residual of
the whole system is then checked, and Newton's method on the whole system
polishes the point if it is not within the tolerance (method
`blocks+newton`). A structurally singular system stops with error 459. In
the tests the solutions equal those of the whole system to
$1.3\times10^{-15}$ (five blocks; a recursive chain of 600 equations with a
block of 20 at its end, 0.42 seconds against 0.36 for the whole system on
Stata 13), and box pairs, each its own block, solve the same.

Tests: `tests/test_structure.do` (a standalone model of five blocks, one of
two equations; a singular one with known over- and under-determined parts;
an equation without a free variable and a variable in no equation; the SAM
model, reduced and full, at the current point, the base and a simulation; a
singular user addition named; errors) and `tests/test_blocksolve.do` (the
solutions block by block against the whole system; the blocks counted; box
pairs; errors).

## 46. Feasibility restoration and irreducible infeasible sets (from version 0.36.0)

**Restoration of the interior point.** `_cge_nlp_solve` enters restoration
(`_cge_nlp_resto`) at a point whose largest scaled residual exceeds
max(tol, 1e-8) where its KKT system cannot be solved even with the
regularisation, where the line search fails, or where the step it accepts
is too short to move, a times max|dz| at most 1e-10 max(1, max|z|). The last
is the stall of Wachter and Biegler's (2000) example, where the linearised
equations and the bounds cannot hold together and the fraction to the
boundary cuts every step to nearly nothing. There are at most ten attempts
in a solve.

Restoration (`_cge_nlp_restore`) minimises
phi(z) = (1/2)||c(z)||^2 + (zeta/2)||D(z - z0)||^2, D = diag(1/max(1, |z0|)),
by projected Levenberg-Marquardt steps: (J'J + zeta D'D + lambda I) d =
-grad phi over the variables not held at a bound (a variable is held where
it lies at the margin of a bound, 1e-6 relative, and the gradient points out
through it), the step projected into the bounds less that margin and halved
until phi falls; lambda falls by 3 after a success and rises by 10 after a
failure, to 1e10. The first phase has zeta = sqrt(mu), which keeps the point
near z0; the second, from where the first ends, zeta = 0. Restoration
succeeds when ||c|| falls to 0.9 of its value at z0, or max|c| below
max(tol, 1e-8). The method then goes on from that point pushed inside its
bounds as the start is, with the slacks started again, the bound
multipliers mu/s capped at 1e3 (IPOPT's reset), and least-squares
multipliers of the equations. Where it fails and the gradient of
(1/2)||c||^2, projected on the bounds, is within 1e-5 max(1, max|c|) of zero
at a point that does not satisfy the equations, the infeasibility has a
local minimum: the method stops, and the status is 5 (locally infeasible).
Otherwise the point is unchanged. `r(N_restorations)` counts the successes;
the external `cge__norest` set to 1 leaves restoration out (a test hook).

On Wachter and Biegler's example, min x1 subject to x1^2 = x2 + 1, x1 = x3 +
1/2, x2, x3 >= 0, from (-2, 3, 1), the method stalled at x1 = -1.22 (model
status 5); with restoration it reaches (1, 0, 1/2) after two, in 21
iterations. Written as x1^2 - x2 - 1 = 0 and x1 - x3 - 1/2 = 0, whose
scaled residuals (scaled by base values, Section 15) have a local minimum
near x1 = -1, the same start stalls at x1 = -0.98 and used every iteration;
with restoration it stops there after 10, locally infeasible. Over a grid of
seven starts and three forms (21 runs, 200 iterations), 3 solved without
restoration and 12 with it.
Some starts reach the feasible region near the solution and then converge
slowly, the bound multipliers far from the central path; that, and a
feasible start from which the reduced Hessian of a linear objective is
nearly singular, are left for later work. In branch and bound, relaxations
that cannot be satisfied end sooner: the knapsack of the Reference Manual
(cge_solve, Example 6) takes 294 iterations of the interior point instead of
340 on Stata 13, with the same 28 nodes and the same optimum.

**Irreducible infeasible sets.** `cge_iis [, tolerance(#) iterate(#) trace]`
applies the deletion filter of Chinneck and Dravnieks (1991) to the bounds
(cge_bound, lower then upper, in the order of `cge_bound, list`) and the
constraints (cge_constraint, and inequalities of cge_equation, with their
regimes reset): F(S), the scenario with the candidates S does not solve;
F(empty) must be false and F(C) true; then, from S = C, each c in turn is
dropped for good where F(S \ {c}). The result S has F(S) true and
F(S \ {c}) false for each c in it (Chinneck 2008). A try copies the model,
selects the bounds and constraints (`_cge_selcol`; constraints through
`_cge_cons_rebuild`), and solves from `_cge_bd_start`; a bound on a fixed
variable outside it fails without a solve. Each solve is at the first level
at which the scenario without candidates solves: 0, Newton's method alone
(the external `cge__nofb`, which `_cge_solve_sys` reads, leaves the
fallbacks out; `_cge_load` clears it at every command, so an error inside a
try does not leave it set); 1, with the fallbacks of `_cge_solve_sys`
(central differences, Powell's hybrid method); 2, with them and then in 4
and 16 steps (`_cge_continue`). On the SYNTHETIC SAM, a solve that fails on
a bound takes about a minute in the fallbacks and the search at level 0 0.65
seconds (10 solves).

Tests: `tests/test_restore.do` (Wachter and Biegler's example solved with
restoration and not without it, from three starts; the local minimum of the
infeasibility of the other form, against the iteration limit without
restoration; x + y = 5 with x, y <= 1, locally infeasible; a programme that
solves without restoration unchanged; on the SYNTHETIC SAM, one bound among
eight found in 10 solves, a scenario that solves, and a quota inequality
with a cap on its rent found together among three; errors).

## 47. Reports of standalone models, and the roles of their variables (from version 0.37.0)

`cge_model roles, groups(set) goods(set) prices(V) consumption(V)
[income(V)]` records in `M.sarole` (groups, goods, prices, consumption,
income or "") the sets of a standalone model's groups and goods and the
variables of the prices of the goods (indexed by the goods), of the
quantities each group buys of each good (indexed by goods and groups, in
either order) and of each group's income (indexed by the groups). The sets
must be user sets and the variables user variables with those indexes;
`_cge_roles_on` checks again at each report, since the model can change
after. `list` and `clear`; `cge_save`/`cge_use` keep the member.

`cge_report` on a standalone model builds its rows in place of
`_cge_report_rows`, in the same (table, measure, element) form, so that
display, `clear`, `saving()` and the Excel sheets are shared. Tables:
`variables` (every element of every user variable, internal ones starting
with `_` left out, or those in `variables()`; per cent change from the base
x0, missing where the base is 0), `items` (each `name = expression` of
`items()`, compiled once by `_cge_u_compile` and evaluated by
`_cge_u_value` at the base with p0 and at each simulation with its own
parameters), and, with roles, `groups` and `welfare`. `items()` and
`variables()` work for models from a SAM too, appended to the standard
tables. On screen a table shows at most 60 rows.

With prices P (goods) and consumption Q (goods x groups) at the base and at
a simulation, each group g has expenditure E = sum_c P_c Q_cg, base budget
shares s_cg = P0_c Q0_cg / E0_g, a Laspeyres index L = sum_c s_cg P1_c/P0_c,
a geometric index G = exp(sum_c s_cg ln(P1_c/P0_c)), real expenditure E1/G
and, with income Y, real income Y1/G. Its equivalent and compensating
variations are those of Cobb-Douglas preferences in the base shares,
EV = E1/G - E0 and CV = E1 - E0 G, reported as per cent of E0. They are
exact for Cobb-Douglas demands, as in the test model, where both groups
spend 30 per cent on a good whose price rises by sqrt(1.25): EV = 100
(1.25^-0.15 - 1) per cent for both.

Tests: `tests/test_report_sa.do` (Cobb-Douglas demands for three goods from
supplies with elasticities 1 and 0.5, two groups; a supply shock and an
income shock; expenditure, both price indexes, real income, EV and CV
against values computed in the test to 1e-10; items and variables; the same
results with consumption indexed (groups, goods); the report as a dataset,
a .dta file and an Excel workbook; roles saved and loaded; items and
variables in the report of the SYNTHETIC SAM model; errors).

## 48. Sensitivity of standalone models (from version 0.38.0)

`cge_sensitivity` on a standalone model draws its user parameters. `vary()`
names them (required); `_cge_sens_sa_init` records the positions of their
values in `p.upval` (`_cge_up_pos`), their central values and the factors of
every draw, from `_cge_sens_factors` in the order of `vary()` after the seed,
one per element or, with `common`, one per parameter. Each draw, in the ado:
`cge_use` of the model saved at the start; `_cge_sens_sa_apply` sets the
drawn values in p0 and p; the `calibrate()` program, if any, runs with the
external `cge__recal` set (`_cge_recal`), which lets `cge_parameter` assign
again a parameter that equations use; `cge_solve, name(_sensbase)` solves
the benchmark, without the scenario's shocks, and `_cge_sens_sa_rebase`
makes it the draw's x0 (and xcur); then the scenario program and
`cge_solve, name(_sens)`. A draw whose benchmark or scenario does not solve
is not converged. `_cge_sens_collect` records the rows of
`_cge_report_rows_sa` (variables, all or `variables()`; `items()`; groups and
welfare with roles), and the base of each draw (`G.sbase`, also kept for
models from a SAM, where it does not change). The dataset has `table`
`parameter` rows with each draw's values. `variables()` and `items()` work
for models from a SAM too, appended to the report rows.

Measuring each draw from its own benchmark keeps changes in the benchmark
out of the scenario's effect. In the test model, P(c)^(1+eta) =
sum(h, alpha ybar) / A(c): draws of ybar with A at its central value move
the base price of g2 to sqrt(0.3 (y1 + y2) / 45), yet the scenario's change
is sqrt(1.25) - 1 in every draw, as the model implies; with a `calibrate()`
program that assigns A again, the base stays at 1.

Tests: `tests/test_sens_sa.do` (20 draws of supply elasticities against the
price 1.25^(1/(1+eta)) and the variation 100 (P^-0.3 - 1) per cent each
implies, to 1e-8; separate and common factors; the same seed, the same
draws; draws of incomes measured from moving benchmarks; calibrate(); draws
kept as simulations; the model restored; errors, including a failing
calibrate() program and a parameter assigned again outside it; items and
variables in the sensitivity of the SYNTHETIC SAM model).

## 49. The link to household surveys for standalone models (from version 0.39.0)

`cge_microsim` on a standalone model needs the roles of `cge_model roles`
(`_cge_roles_on`). The household groups are the labels of the groups' set
and the commodities of `budget()` those of the goods' set. For each
simulation, `_cge_ms_sa` gives what the built-in model's variables give
otherwise: each group's base expenditure EH0 = sum_c P0_c Q0_cg and its
ratio, kappa = 1 (no separate direct taxes or savings: the incomes of the
sources are what consumption follows), the ratio of each income source for
each group (`_cge_ms_ratio_sa`: the group's element of a variable indexed by
the groups, a variable without index, or 1 for `fixed`; 1 where the base is
0), the price relatives P1/P0 of the goods and the base budget shares wg.
The rest of the command is shared: consumption, price indexes, poverty,
inequality, quantiles, the growth incidence curve, `svy`, `bands()` and the
decomposition, whose channels are the income sources and prices (the
channel of taxes and savings is left out: `ktax` 0). `_cge_ms_evcv_sa`
gives each household's variations, Cobb-Douglas in its own budget shares or
its group's base shares: EV = C1/G - C0, CV = C1 - C0 G, with G the
geometric price index. `market()` and the instruments, and `reweight()`,
stop with error 198.

Tests: `tests/test_microsim_sa.do` (a SYNTHETIC survey of 300 households
and the model of Section 47: each household's nominal consumption, price
index, real consumption per person, EV and CV against values computed in
the test, to 1e-10, with own income components and budget shares and with
the group's; the poverty headcount, base and simulated, against the
generated consumption; the Shapley decomposition adding up, channels Y,
PIDX and prices; bands from draws kept by cge_sensitivity; errors).

## References

Burniaux, J.-M. and T. P. Truong (2002). *GTAP-E: An Energy-Environmental
Version of the GTAP Model*. GTAP Technical Paper 16, Center for Global Trade
Analysis, Purdue University.

Bourguignon, F., M. Bussolo and L. A. Pereira da Silva, eds. (2008). *The
Impact of Macroeconomic Policies on Poverty and Income Distribution:
Macro-Micro Evaluation Techniques and Tools*. World Bank and Palgrave
Macmillan.

Thurlow, J. (2004). *A Dynamic Computable General Equilibrium (CGE) Model
for South Africa: Extending the Static IFPRI Model*. Trade and Industrial
Policy Strategies, Working Paper 1-2004.

Decaluwé, B., A. Lemelin, V. Robichaud and H. Maisonnave (2013). *PEP-1-1: The
PEP standard single-country, static CGE model*. Partnership for Economic Policy.

Lofgren, H., R. L. Harris and S. Robinson (2002). *A Standard Computable General
Equilibrium (CGE) Model in GAMS*. Microcomputers in Policy Research 5.
International Food Policy Research Institute.

Blanchflower, D. G. and A. J. Oswald (1994). *The Wage Curve*. MIT Press.

Fischer, A. (1992). A special Newton-type optimization method. *Optimization*
24(3-4): 269-284.

Hock, W. and K. Schittkowski (1981). *Test Examples for Nonlinear Programming
Codes*. Lecture Notes in Economics and Mathematical Systems 187. Springer.

Wächter, A. and L. T. Biegler (2006). On the implementation of an
interior-point filter line-search algorithm for large-scale nonlinear
programming. *Mathematical Programming* 106(1): 25-57.

Kanzow, C. (1996). Some noninterior continuation methods for linear
complementarity problems. *SIAM Journal on Matrix Analysis and Applications*
17(4): 851-868.

Anyanwu, J. C. and A. E. O. Erhijakpor (2009). Health expenditures and health
outcomes in Africa. *African Development Review* 21(2): 400-433.

Bokhari, F. A. S., Y. Gai and P. Gottret (2007). Government health
expenditures and health outcomes. *Health Economics* 16(3): 257-273.

Li, X. S. (2005). An overview of SuperLU: algorithms, implementation, and
user interface. *ACM Transactions on Mathematical Software* 31(3): 302-325.

Ruiz, D. (2001). *A Scaling Algorithm to Equilibrate Both Rows and Columns Norms in
Matrices*. Technical Report RAL-TR-2001-034, Rutherford Appleton Laboratory.

Huangfu, Q. and J. A. J. Hall (2018). Parallelizing the dual revised simplex
method. *Mathematical Programming Computation* 10(1): 119-142.
