# 2. Preparing the SAM

A SAM records every payment in the economy in one square matrix: cell (r, c)
is a payment from column account c to row account r, and each account's row
total (receipts) equals its column total (payments). The model is calibrated
to the SAM, so the SAM's quality limits the model's. This chapter covers the
tools that read and prepare a SAM before it is mapped to the model
([sam_tools.md](../sam_tools.md) gives the methods).

## 2.1 Reading a SAM: `cge_sam`

`cge_sam` reads a SAM and starts a new model. It accepts:

- **wide data in memory or in a file** (`.dta`, `.csv`, `.xls`, `.xlsx`): one
  observation per account, a string variable with the labels and one numeric
  variable per account, in the same order;
- **a wide CSV file read directly**, for SAMs with more accounts than Stata
  can hold as variables (2,048 in Stata/IC): the file is parsed in Mata and the
  data in memory are left unchanged;
- **long data**: one observation per non-zero cell, with `long(row column
  value)`.

```stata
cge_sam using "sam2018.xlsx", sheet("SAM") labels(account) clear
cge_sam using "sam_large.csv", direct
cge_sam, long(row col value)
```

Account labels become names in `cge_map`, so they must be valid Stata names.
Labels such as `s-i` are converted (to `si`) and each change is displayed. A
field that is not a number, such as `1,234` with a thousands separator, is an
error, never a zero. `cge_sam` reports the largest difference between an
account's row and column totals.

## 2.2 A template for roles and groups: `cge_template`

For a SAM of more than a few accounts, assigning roles in a spreadsheet is
easier than typing a long `cge_map` command. `cge_template` writes one row per
account, with columns `role`, `pair` and `group` to fill in, and the account's
totals and imbalance:

```stata
cge_template using "roles.xlsx", replace
```

- **role**: the `cge_map` option that lists the account: `activities`,
  `commodities`, `factors`, `households`, `enterprises`, `government`,
  `savinv`, `row`, a tax role (`dirtax`, `saltax`, `imptax`, `exptax`,
  `acttax`, `vattax`), or one of the layout roles of chapter 3. An Excel
  template has a sheet `roles` that lists them.
- **pair**: for an activity, its main commodity, when the largest sale is not
  that commodity.
- **group**: for aggregation, the account it is merged into.

The filled template is read by `cge_aggregate using` and `cge_map using`.

## 2.3 Aggregation: `cge_aggregate`

`cge_aggregate` merges accounts into groups, from the template's `group`
column or from `groups()`:

```stata
cge_aggregate using "roles.xlsx"
cge_aggregate, groups(act_nag: act_man act_ser, com_nag: com_man com_ser)
```

Each cell of the new SAM is the sum of the cells it merges, so totals add up.
Flows among the members of a group become a diagonal cell of the group;
the model accepts diagonal cells for households, enterprises and government,
and `cge_map` reports any other. `netdiagonal` removes all diagonal cells.

## 2.4 Balancing: `cge_balance`

Survey-based SAMs rarely balance. `cge_balance` adjusts the cells so that
every row total equals its column total, keeping every cell's sign, every
zero, and the cells listed in `fixed()`. Both methods minimise the same
measure of the information added to the SAM (Junius and Oosterhaven 2003):

- **RAS** (`method(ras)`, the default; generalised RAS for negative cells)
  makes every total equal a target: by default the average of the account's
  row and column totals, or the values in `totals()`.
- **Cross entropy** (`method(ce)`) estimates the totals together with the
  cells, subject to balance and to the totals that are known.

```stata
cge_balance                                  // RAS to average totals
cge_balance, method(ce) totals(hh:290)       // household income known
cge_balance, fixed(row:* tax_imp:*)          // keep imports and tariffs
```

The table of the largest changes shows where the SAM was adjusted. A balanced
SAM is an estimate: report which totals were given, which cells were fixed
and which method was used.

## 2.5 Writing the SAM: `cge_samexport`

`cge_samexport` writes the SAM as read, aggregated or balanced (or, with
`mapped`, after the layout rewrites of chapter 3) to a file, or loads it as
data:

```stata
cge_samexport using "sam_balanced.csv", replace
cge_samexport, clear long
```

CSV files keep every digit, so a SAM written and read again is unchanged.

## 2.6 Multiplier analysis: `cge_multiplier`

Once the SAM is mapped (chapter 3), `cge_multiplier` computes its accounting
multipliers (Pyatt and Round 1979; [sam_tools.md](../sam_tools.md), Section 6):
the effect of a unit injection into one account on the incomes of all the
endogenous accounts, with prices fixed. No calibration is needed.

```stata
cge_multiplier, decompose                 // every account, with the decomposition
cge_multiplier, inject(com_hlt:10)        // 10 more spending on health services
cge_multiplier, endogenous(gov) clear     // government spending endogenous; load the matrix
```

By default the activities, commodities and margin accounts (production), the
factors, and the households and enterprises (institutions) are endogenous;
government, savings-investment, the rest of the world and the taxes are
exogenous. For each injection the command reports the total multiplier and
its parts in gross output, value added and household income. `decompose`
splits it into transfer effects within the injected account's block,
open-loop effects on the other blocks, and closed-loop effects of the
circular flow back to it.

Multipliers assume fixed prices, idle capacity in every sector and average
propensities to spend equal to marginal ones. They are upper bounds:
`examples/multipliers.do` gives 10 more government health spending a
multiplier effect of 25.8 on gross output, while the CGE model, with factors
fully employed and the deficit crowding out investment, finds a fall of 3.1.
Report the two together, with their assumptions.

**Structural paths.** `cge_spa` shows how a multiplier builds up along chains
of payments (Defourny and Thorbecke 1984; [sam_tools.md](../sam_tools.md),
Section 7):

```stata
cge_spa, from(com_hlt) to(hhd)
```

Each path, such as health services > health activity > labour > households,
has a direct influence (the product of the spending shares along it), a path
multiplier (the feedback of the loops through its accounts) and a total
influence, their product; the total influences of all paths add up to the
multiplier. On the synthetic health SAM, the path through labour carries 64
per cent of the effect of health spending on household income and the path
through capital 22 per cent; paths through other sectors' intermediate inputs
carry the rest. `maxlength()` and `threshold()` limit the search, and the
share of the multiplier explained by the paths found is reported.

## 2.7 The synthetic SAMs

`cge_synthetic` loads the SYNTHETIC SAMs used in the tests and examples. They
describe no country. The standard SAM has three sectors, two factors, one
household, government, savings-investment and the rest of the world; options
load other layouts: `national` (national-accounts conventions), `institutions`
(an enterprise and a non-profit institution), `margins`, `territorial`,
`multiproduct`, `nonimported`, `sut` (supply-use), `health` (a health sector
and an insurance fund), `unbalanced`, `vat`, `home` and `trade`.

## References

Defourny, J. and E. Thorbecke (1984). Structural path analysis and multiplier
decomposition within a social accounting matrix framework. *Economic Journal*
94(373): 111-136.

Pyatt, G. and J. I. Round (1979). Accounting and fixed price multipliers in a
social accounting matrix framework. *Economic Journal* 89(356): 850-873.

Junius, T. and J. Oosterhaven (2003). The solution of updating or
regionalizing a matrix with both positive and negative entries. *Economic
Systems Research* 15(1): 87-96.
