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
| $HS$ | volume of health services consumed by households, the government and the health insurance fund |
| $WALRAS$ | slack in the savings-investment balance; zero at a solution |

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
| $\beta^{h}_{ah}$, $\gamma^{h}_{ah}$ | marginal budget share and subsistence quantity of home consumption of the output of activity $a$ by household $h$ (from version 0.3.2) |
| $ad_a$, $\delta^{va}_{fa}$, $\rho^{va}_a$ | value-added CES efficiency, share and exponent parameters |
| $af_f$ | exogenous efficiency of factor $f$ in every activity (one in the base; from version 0.1.14) |
| $\eta_f$, $HS^0$ | elasticity of the efficiency of factor $f$ with respect to health services, and the base volume of health services |
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

$$PM_c = pwm_c\,(1+tm_c\,TMADJ)\,EXR + \sum_{c'} PQ_{c'}\,ici_{c'c}, \qquad c \in CM \tag{P1}$$

$$PE_c = PWE_c\,(1-te_c)\,EXR - \sum_{c'} PQ_{c'}\,ice_{c'c}, \qquad c \in CE \tag{P2}$$

with $PWE_c = pwe_c$ for $c \notin CED$. The margin terms are zero without
margins by market (Section 13.4).

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

$$PA_a\,(1-ta_a)\,QA_a = PVA_a\,QVA_a + PINTA_a\,QINTA_a \tag{P7}$$

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
$\widetilde{QF}_{fa} = af_f\,EFF_f\,QF_{fa}$. Factor quantities $QF_{fa}$,
supplies $QFS_f$ and wages $W_f$ remain in physical units, so a more efficient
factor earns more per unit. In the base $af_f = EFF_f = 1$.

Value added, CES case ($\sigma^{va}_a \neq 1$):

$$QVA_a = ad_a\left[\sum_f \delta^{va}_{fa}\,\widetilde{QF}_{fa}^{-\rho^{va}_a}\right]^{-1/\rho^{va}_a} \tag{Q3}$$

$$W_f\,WFDIST_{fa} = PVA_a\,QVA_a\left[\sum_{f'} \delta^{va}_{f'a}\,\widetilde{QF}_{f'a}^{-\rho^{va}_a}\right]^{-1}\delta^{va}_{fa}\,\widetilde{QF}_{fa}^{-\rho^{va}_a-1}\,af_f\,EFF_f \tag{Q4}$$

Value added, Cobb-Douglas case ($\sigma^{va}_a = 1$):

$$QVA_a = ad_a \prod_f \widetilde{QF}_{fa}^{\delta^{va}_{fa}}, \qquad \sum_f \delta^{va}_{fa} = 1 \tag{Q3'}$$

$$W_f\,WFDIST_{fa}\,QF_{fa} = \delta^{va}_{fa}\,PVA_a\,QVA_a \tag{Q4'}$$

Health services and factor efficiency (from version 0.1.14), when $HC$ is not
empty and some $\eta_f > 0$:

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

$$YF_f = \sum_a W_f\,WFDIST_{fa}\,QF_{fa} + trnsfr_{f,row}\,EXR \tag{I1}$$

$$YIF_{if} = shif_{if}\,(1-tshi_f)\,YF_f, \quad i \in I \setminus \{shi\}; \qquad YIF_{shi,f} = tshi_f\,YF_f \tag{I2}$$

Without a health insurance fund, $tshi_f = 0$.

$$YI_d = \sum_f YIF_{df} + \sum_{d' \in D} shii_{dd'}\,(1-MPS_{d'})(1-TINS_{d'})\,YI_{d'} + trnsfr_{d,gov}\,CPI + trnsfr_{d,row}\,EXR + hold_d\,r^d\,DD \tag{I3}$$

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

$$YG = \sum_d TINS_d\,YI_d + \sum_c tq_c\,TQADJ\,PQ_c\,QQ_c + \sum_{c \in CM} tm_c\,TMADJ\,pwm_c\,QM_c\,EXR + \sum_{c \in CE} te_c\,PWE_c\,QE_c\,EXR + \sum_a ta_a\,PA_a\,QA_a + VAT + \sum_f YIF_{gov,f} + trnsfr_{gov,row}\,EXR + trnsfr_{gov,gov}\,CPI \tag{I8}$$

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

$$\sum_{c \in CM} pwm_c\,QM_c + \sum_f \frac{YIF_{row,f}}{EXR} + \sum_d \frac{shir_d\,(1-MPS_d)(1-TINS_d)\,YI_d}{EXR} + trnsfr_{row,gov} + r^f\,DF = \sum_{c \in CE} PWE_c\,QE_c + \sum_{c \in CR} \frac{PQ_c\,QER_c}{EXR} + \sum_d trnsfr_{d,row} + \sum_f trnsfr_{f,row} + trnsfr_{gov,row} + trnsfr_{shi,row} + FSAV \tag{S3}$$

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
| Numeraire | CPI (default) | $CPI$ | $DPI$ |
| | DPI | $DPI$ | $CPI$ |

$TQADJ$, $TMADJ$ and $TVADJ$ are fixed, at one in the base, except the one
that the government closure frees (Section 12.1).

Variable and equation counts must be checked for every closure: the number of
free variables must equal the number of equations.

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
version 0.1.8 exports could not exceed domestic output. An activity with no
flows at all is left out of the mapping.

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
| Nominal GDP | $\sum_c PH_c\,(\sum_h QH_{ch} + QG_c + QINV_c + QSHI_c) + \sum_c PQ_c\,QER_c + EXR\sum_c pwe_c QE_c - EXR\sum_c pwm_c QM_c$ |
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

Both are positive for a gain and reported in per cent of $EH^0_h$. Other
percentage changes are $100\,(x - x^0)/|x^0|$, and missing when $x^0 = 0$.

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
3. **Population.** $\gamma_{ch,t} = (1+g_P)\,\gamma_{ch,t-1}$ and
   $HS^0_t = (1+g_P)\,HS^0_{t-1}$: subsistence consumption grows with the
   population, and the health link compares health services per head.
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
$$P_i = \sum_c s_{ic}\,\frac{PQ_c}{PQ^0_c},$$
with $s_{ic}$ its survey budget shares when budget items are mapped to
commodities, and the group's base shares $PQ^0_c\,QH^0_{ch}/EH^0_h$ otherwise.
Real consumption is $R_i = C^1_i / P_i$; this is a first-order (Laspeyres)
approximation for LES households. With household size $n_i$ and weight $w_i$,
poverty measures use consumption per person, $r_i = R_i/n_i$ (base
$C^0_i/n_i$), and person weights $w_i n_i$:
$$FGT_\alpha = \frac{\sum_i w_i n_i\,\mathbf{1}[r_i < z]\,\big((z - r_i)/z\big)^\alpha}{\sum_i w_i n_i}, \qquad \alpha = 0, 1, 2,$$
for a poverty line $z$, and the Gini coefficient is that of $r_i$ over persons.

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
internal account `_vattax` before the checks (as for taxes paid directly to
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

## References

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
