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
  input; CES (or Cobb-Douglas) value added over factors; Leontief intermediate
  inputs.
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
- From version 0.1.8: exports drawn from composite supply, for commodities whose
  exports are at least their domestic output (re-exports, and exports supplied
  from inventories or valued at purchaser prices).

Deferred to later versions: margins that differ between domestic sales, imports
and exports; recursive dynamics.

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
| $T$ | margin accounts (may be empty; from version 0.1.7) |
| $CT \subseteq C$ | margin commodities: the services that margin accounts buy |
| $F$ | factors |
| $H$ | households (including non-profit institutions mapped as households) |
| $E$ | enterprises (may be empty) |
| $D = H \cup E$ | domestic non-government institutions |
| $I = D \cup \{gov, row\}$ | institutions receiving factor income |

## 3. Variables

Prices

| Variable | Description |
|---|---|
| $PA_a$ | activity price (gross revenue per unit of activity) |
| $PVA_a$ | price of value added |
| $PINTA_a$ | price of aggregate intermediate input |
| $PX_c$ | producer price of commodity output, $c \in CX$ |
| $PD_c$ | price of domestic output sold domestically, $c \in CX$ |
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
| $QX_c$ | output of commodity $c \in CX$ |
| $QD_c$ | domestic sales of domestic output, $c \in CX$ |
| $QE_c$ | exports, $c \in CE$ |
| $QM_c$ | imports, $c \in CM$ |
| $QQ_c$ | composite commodity supply |
| $QH_{ch}$ | consumption of $c$ by household $h$ |
| $QG_c$ | government consumption |
| $QINV_c$ | investment demand |
| $QT_c$ | demand for margin services, $c \in CT$ |
| $QER_c$ | exports drawn from composite supply, $c \in CR$ |
| $QFS_f$ | supply of factor $f$ |

Incomes, rates and adjustment variables

| Variable | Description |
|---|---|
| $YF_f$ | income of factor $f$ |
| $YIF_{if}$ | income of institution $i$ from factor $f$ |
| $YI_d$ | income of domestic non-government institution $d$ |
| $EH_h$ | household consumption spending |
| $YG$, $EG$ | government revenue and spending |
| $GSAV$ | government savings |
| $FSAV$ | foreign savings (foreign currency) |
| $TINS_d$ | direct tax rate of institution $d$ |
| $MPS_d$ | marginal propensity to save of institution $d$ |
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
| $\theta_{ac}$ | yield: output of commodity $c$ per unit of activity $a$ |
| $iva_a$, $inta_a$ | value added and aggregate intermediate input per unit of activity |
| $ica_{ca}$ | intermediate input $c$ per unit of aggregate intermediate input of $a$ |
| $icm_{c'c}$ | margin services of commodity $c' \in CT$ per unit of composite supply of $c$ |
| $ad_a$, $\delta^{va}_{fa}$, $\rho^{va}_a$ | value-added CES efficiency, share and exponent parameters |
| $at_c$, $\delta^{t}_c$, $\rho^{t}_c$ | CET efficiency, share and exponent parameters |
| $aq_c$, $\delta^{q}_c$, $\rho^{q}_c$ | Armington efficiency, share and exponent parameters |
| $shif_{if}$ | share of factor $f$ income going to institution $i$ |
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
factors), $\sigma^{t}_c$ (transformation between exports and domestic sales; for
$c \in CR$, the price elasticity of exports from composite supply, T9) and
$\sigma^{q}_c$ (substitution between imports and domestic goods). The exponents
are $\rho^{va}_a = 1/\sigma^{va}_a - 1$, $\rho^{t}_c = 1/\sigma^{t}_c + 1$ and
$\rho^{q}_c = 1/\sigma^{q}_c - 1$. All elasticities must be positive and finite.
$\sigma^{va}_a = 1$ selects the Cobb-Douglas form of value added (Q3', Q4').
Version 0.1 has no Cobb-Douglas form of the Armington function, so
$\sigma^{q}_c \neq 1$ is required for imported commodities.

## 5. Equations

### 5.1 Price block

$$PM_c = pwm_c\,(1+tm_c)\,EXR, \qquad c \in CM \tag{P1}$$

$$PE_c = pwe_c\,(1-te_c)\,EXR, \qquad c \in CE \tag{P2}$$

$$PQ_c\,(1-tq_c)\,QQ_c = PD_c\,QD_c + PM_c\,QM_c + \sum_{c' \in CT} PQ_{c'}\,icm_{c'c}\,QQ_c \tag{P3}$$

where the domestic term applies only for $c \in CX$, the import term only for
$c \in CM$, and the margin term only when $c$ pays margins.

$$PX_c\,QX_c = PD_c\,QD_c + PE_c\,QE_c, \qquad c \in CX \tag{P4}$$

where the export term applies only for $c \in CE$.

$$PA_a = \sum_c \theta_{ac}\,PX_c \tag{P5}$$

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

$$QX_c = \sum_a \theta_{ac}\,QA_a, \qquad c \in CX \tag{Q6}$$

Output of a commodity from different activities is a perfect substitute and
sells at one producer price $PX_c$.

### 5.3 Trade block

For exported commodities, $c \in CE$:

$$QX_c = at_c\left[\delta^{t}_c\,QE_c^{\rho^{t}_c} + (1-\delta^{t}_c)\,QD_c^{\rho^{t}_c}\right]^{1/\rho^{t}_c} \tag{T1}$$

$$\frac{QE_c}{QD_c} = \left[\frac{PE_c}{PD_c}\cdot\frac{1-\delta^{t}_c}{\delta^{t}_c}\right]^{1/(\rho^{t}_c-1)} \tag{T2}$$

For produced, non-exported commodities, $c \in CNE$:

$$QX_c = QD_c \tag{T3}$$

For imported commodities with domestic output, $c \in CM \cap CX$:

$$QQ_c = aq_c\left[\delta^{q}_c\,QM_c^{-\rho^{q}_c} + (1-\delta^{q}_c)\,QD_c^{-\rho^{q}_c}\right]^{-1/\rho^{q}_c} \tag{T4}$$

$$\frac{QM_c}{QD_c} = \left[\frac{PD_c}{PM_c}\cdot\frac{\delta^{q}_c}{1-\delta^{q}_c}\right]^{1/(1+\rho^{q}_c)} \tag{T5}$$

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

$$QT_c = \sum_{c'} icm_{cc'}\,QQ_{c'} \tag{T8}$$

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

$$YIF_{if} = shif_{if}\,YF_f, \qquad i \in I \tag{I2}$$

$$YI_d = \sum_f YIF_{df} + \sum_{d' \in D} shii_{dd'}\,(1-MPS_{d'})(1-TINS_{d'})\,YI_{d'} + trnsfr_{d,gov}\,CPI + trnsfr_{d,row}\,EXR \tag{I3}$$

$$EH_h = hc_h\,(1-MPS_h)(1-TINS_h)\,YI_h \tag{I4}$$

Enterprises do not consume: for $e \in E$, $\sum_d shii_{de} + shir_e = 1$, so all
income after direct taxes and savings is transferred. For households,
$hc_h = 1 - \sum_d shii_{dh} - shir_h$. A transfer from an institution to itself
(a diagonal SAM cell) is allowed; it appears on both sides of its accounts.

$$PQ_c\,QH_{ch} = PQ_c\,\gamma_{ch} + \beta_{ch}\left(EH_h - \sum_{c'} PQ_{c'}\,\gamma_{c'h}\right) \tag{I5}$$

With $\gamma_{ch} = 0$ this is Cobb-Douglas demand, the default. From version
0.1.11 the linear expenditure system (LES) is available: households first buy
subsistence quantities $\gamma_{ch}$ and spend the rest of their consumption
budget in fixed marginal shares $\beta_{ch}$, so that budget shares change with
income. The equivalent variation of household $h$ at base prices is
$EV_h = \sum_c PQ^0_c\gamma_{ch} + \left(EH_h - \sum_c PQ_c\gamma_{ch}\right)\prod_c (PQ^0_c/PQ_c)^{\beta_{ch}} - EH^0_h$,
which reduces to the Cobb-Douglas form when $\gamma_{ch} = 0$.

$$QINV_c = \overline{qinv}_c\,IADJ \tag{I6}$$

$$QG_c = \overline{qg}_c\,GADJ \tag{I7}$$

$$YG = \sum_d TINS_d\,YI_d + \sum_c tq_c\,PQ_c\,QQ_c + \sum_{c \in CM} tm_c\,pwm_c\,QM_c\,EXR + \sum_{c \in CE} te_c\,pwe_c\,QE_c\,EXR + \sum_a ta_a\,PA_a\,QA_a + \sum_f YIF_{gov,f} + trnsfr_{gov,row}\,EXR + trnsfr_{gov,gov}\,CPI \tag{I8}$$

$$EG = \sum_c PQ_c\,QG_c + \sum_d trnsfr_{d,gov}\,CPI + trnsfr_{gov,gov}\,CPI + trnsfr_{row,gov}\,EXR \tag{I9}$$

$$TINS_d = \overline{tins}_d\,TINSADJ \tag{I10}$$

$$MPS_d = \overline{mps}_d\,MPSADJ \tag{I11}$$

### 5.5 System constraints

$$\sum_a QF_{fa} = QFS_f \tag{S1}$$

$$QQ_c = \sum_a QINT_{ca} + \sum_h QH_{ch} + QG_c + QINV_c + QT_c + QER_c \tag{S2}$$

where $QT_c$ applies only for $c \in CT$ and $QER_c$ only for $c \in CR$.

$$\sum_{c \in CM} pwm_c\,QM_c + \sum_f \frac{YIF_{row,f}}{EXR} + \sum_d \frac{shir_d\,(1-MPS_d)(1-TINS_d)\,YI_d}{EXR} + trnsfr_{row,gov} = \sum_{c \in CE} pwe_c\,QE_c + \sum_{c \in CR} \frac{PQ_c\,QER_c}{EXR} + \sum_d trnsfr_{d,row} + \sum_f trnsfr_{f,row} + trnsfr_{gov,row} + FSAV \tag{S3}$$

$$YG = EG + GSAV \tag{S4}$$

$$\sum_d MPS_d\,(1-TINS_d)\,YI_d + GSAV + EXR\cdot FSAV = \sum_c PQ_c\,QINV_c + WALRAS \tag{S5}$$

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

### 7.0 SAM checks and supported flows

Before calibration the SAM must be square, with identical row and column labels,
balanced (each row total equals the column total within $10^{-8}$ times the
largest absolute cell), and every account with a non-zero flow must be mapped to
a role. Every non-zero cell must be one of the flows below. Any other flow stops
calibration with an error that names the paying and receiving accounts; the
Stata implementation lists every such flow, grouped by role, before stopping.

| Paid by (column) | Received by (row) |
|---|---|
| commodity $c$ | activities (domestic output); rest of world (imports); import, sales and export tax accounts; margin accounts (margins, from version 0.1.7) |
| activity | commodities (intermediate inputs); factors; activity tax account |
| factor | households; enterprises; government; rest of world |
| household | commodities; direct tax account; savings-investment; households and enterprises (transfers); rest of world (transfers) |
| enterprise | direct tax account; savings-investment; households and enterprises (transfers); rest of world (transfers) |
| government | commodities; households and enterprises (transfers); government (internal transfers); rest of world (transfers); savings-investment |
| tax account | government |
| savings-investment | commodities (investment, including changes in inventories) |
| margin account | commodities (margin services, from version 0.1.7) |
| rest of world | commodities (exports); households, enterprises and government (transfers); factors (factor income from abroad); savings-investment |

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
  $tq_c = SAM(tax_{sal}, c) / QQ^0_c$.
- Margin services: $QT^0_{c'} = \sum_{t \in T} SAM(c', t)$, and
  $icm_{c'c} = \sum_{t \in T} SAM(t, c)\,\dfrac{SAM(c', t)}{\sum_{c''} SAM(c'', t)} \Big/ QQ^0_c$,
  so that margins collected by account $t$ are spent on services in the
  proportions that $t$ buys them.

SAM balance implies that $QQ^0_c$ equals total demand for $c$ at purchaser
prices, other than exports from domestic output: the commodity row total minus
$QE^0_c$, including purchases of margin services by margin accounts and exports
from composite supply. Calibration must verify this identity, not assume it.

### 7.3 Production

- $QINTA^0_a = \sum_c SAM(c, a)$; $ica_{ca} = SAM(c, a) / QINTA^0_a$.
- $QF^0_{fa} = SAM(f, a) / (W^0_f\,WFDIST^0_{fa})$; $QVA^0_a = \sum_f SAM(f, a)$.
- $iva_a = QVA^0_a / QA^0_a$; $inta_a = QINTA^0_a / QA^0_a$.
- CES value added: with $w_{fa} = W^0_f\,WFDIST^0_{fa}$,
  $\delta^{va}_{fa} = w_{fa}\,(QF^0_{fa})^{1+\rho^{va}_a} / \sum_{f'} w_{f'a}\,(QF^0_{f'a})^{1+\rho^{va}_a}$
  and $ad_a = QVA^0_a / \left[\sum_f \delta^{va}_{fa}\,(QF^0_{fa})^{-\rho^{va}_a}\right]^{-1/\rho^{va}_a}$.
- Cobb-Douglas value added: $\delta^{va}_{fa} = SAM(f, a) / QVA^0_a$ and
  $ad_a = QVA^0_a / \prod_f (QF^0_{fa})^{\delta^{va}_{fa}}$.

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

- $YF^0_f$ = row total of factor $f$; $shif_{if} = SAM(i, f) / YF^0_f$.
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
  $\gamma_{ch} = QH^0_{ch} + \beta_{ch}\,EH^0_h / (PQ^0_c\,\phi_h)$. Supernumerary
  spending $EH^0_h - \sum_c PQ^0_c\gamma_{ch}$ is then $-EH^0_h/\phi_h$, positive
  and below total spending because $\phi_h < -1$. Household consumption must be
  non-negative.
- $trnsfr_{d,gov} = SAM(d, gov)$, $trnsfr_{gov,gov} = SAM(gov, gov)$,
  $trnsfr_{d,row} = SAM(d, row)$, $trnsfr_{f,row} = SAM(f, row)$,
  $trnsfr_{gov,row} = SAM(gov, row)$, $trnsfr_{row,gov} = SAM(row, gov)$.
- $\overline{qg}_c = SAM(c, gov)$, $\overline{qinv}_c = SAM(c, sav)$,
  $GSAV^0 = SAM(sav, gov)$, $FSAV^0 = SAM(sav, row)$.
- $TINSADJ^0 = MPSADJ^0 = IADJ^0 = GADJ^0 = 1$.
- $cwts_c = \sum_h SAM(c, h) / \sum_{c'} \sum_h SAM(c', h)$;
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

## References

Decaluwé, B., A. Lemelin, V. Robichaud and H. Maisonnave (2013). *PEP-1-1: The
PEP standard single-country, static CGE model*. Partnership for Economic Policy.

Lofgren, H., R. L. Harris and S. Robinson (2002). *A Standard Computable General
Equilibrium (CGE) Model in GAMS*. Microcomputers in Policy Research 5.
International Food Policy Research Institute.
