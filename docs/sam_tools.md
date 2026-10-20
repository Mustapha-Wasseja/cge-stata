# SAM tools (from version 0.3.0)

These commands prepare a social accounting matrix (SAM) before it is mapped and
calibrated. They change the SAM only; the model of `model_spec.md` is
unchanged. Each command that changes the SAM starts a new model from the
result, as `cge_sam` does: earlier mappings, calibrations and simulations are
discarded.

Cell (r, c) of a SAM is a payment from column account c to row account r.
X̄ is the SAM before a command and X the SAM after it.

## 1. Reading a SAM

`cge_sam` reads a SAM in one of three forms.

1. **Wide data**: one observation per account, a string variable with the
   account labels and one numeric variable per account (as in version 0.1).
   Files are read with `import delimited`, `use` or `import excel`.
2. **Wide CSV read directly**: the file is parsed in Mata and the data in
   memory are not changed. This is automatic when the SAM has more accounts
   than Stata can hold as variables (`c(maxvar)`; 2,048 in Stata/IC), and is
   selected for any CSV file with the option `direct`.
3. **Long data**: one observation per non-zero cell, with string variables for
   the row and column accounts and a numeric variable for the value (option
   `long(row column value)`). The number of accounts is limited only by memory.
   Accounts are ordered as they first appear as row accounts, followed by
   any accounts that appear only as column accounts, so that a SAM written in
   long form and read again keeps its order. A cell given twice is an error.

In the direct reader the first line holds the column labels, the first field
of each following line the row label, and the remaining fields the values.
Fields may be quoted. A blank field is a zero, counted in `r(N_blank)`; a
field that is not a number (for example `1,234` with a thousands separator)
is an error, never a zero. Row and column labels must agree, in the same
order.

**Labels.** Account labels are used as names in `cge_map`, so they must be
valid Stata names. In wide data, Stata renames invalid labels when the file is
imported (`s-i` becomes `si`), and the variable names are used, as before. In
the direct reader and in long data the same rule is applied: characters other
than letters, digits and the underscore are removed, then any leading digits,
and the result is cut to 32 characters. If a label cannot be converted (the
result is empty, a reserved word, or the same as another label), `cge_sam`
stops and names the label; `import delimited` would instead number the
variable (`v5`). Each change is displayed.

## 2. Writing a SAM

`cge_samexport` writes the SAM of the current model, as read, aggregated or
balanced, to a `.csv`, `.dta` or `.xlsx` file, or loads it as data. Wide
output has one variable per account (`.dta` and `.xlsx` require the accounts
to fit as variables; `.csv` is written in Mata and has no such limit). Long
output (option `long`) has variables `row`, `column` and `value`, one
observation per non-zero cell. With the option `mapped`, the SAM after the
layout rewrites of `model_spec.md`, Section 7.0, is written instead,
including the internal tax accounts.

Numbers are written in the shortest of `%21.0g` and `%24.17g` that reads back
as the same double, so that a SAM written and read again is unchanged.

## 3. Mapping template

`cge_template using file` writes a template with one row per account and the
columns

| Column | Content |
|---|---|
| `account` | the account label |
| `role` | the `cge_map` options that list the account, separated by spaces |
| `pair` | for an activity, the commodity it is paired with |
| `group` | for aggregation (Section 4), the account it is merged into |
| `row_total`, `column_total`, `difference` | the account's totals and their difference |

An Excel template also has a sheet `roles` that lists the valid entries. When
the model in memory is already mapped, `role` and `pair` are filled from the
mapping; otherwise they are blank.

A role is any option name of `cge_map` (`activities`, `commodities`,
`factors`, `households`, `enterprises`, `government`, `savinv`, `row`,
`dirtax`, `saltax`, `imptax`, `exptax`, `acttax`, `margins`, `territorial`,
`marginaccounts`, `stocks`, `insurance`), in either case, with the singular
forms `activity`, `commodity`, `factor`, `household`, `enterprise`, `margin`,
`marginaccount` and `stock` also accepted. An account may have several roles
when `cge_map` allows it, for example `activities margins` for a margin
activity, or `government saltax` when sales taxes are paid directly to
government. A blank role leaves the account unmapped, which `cge_map` accepts
only for accounts without flows.

`cge_map using file` maps the SAM from a template:

- Each option lists its accounts in the order of the SAM. For
  `territorial`, the correction commodity (the account that households
  consume) is listed before its activity.
- Activities are paired with commodities by the `pair` column. A blank `pair`
  pairs the activity with the commodity whose column pays it most (the
  largest cell X[a, c] among the commodities). A tie, no sales to any
  commodity, or a commodity paired with two activities is an error. The
  `commodities()` list then starts with the paired commodities, in the order
  of the activities.
- After aggregation with the same template, an account of the current SAM may
  be a group: it takes the role of its members, which must agree, and is
  paired with the group of its members' pairs, which must also agree (or, if
  no member has a pair, by the largest-sale rule).

The resulting options are passed to `cge_map` and displayed, so that the same
mapping can be written as a command.

## 4. Aggregation

`cge_aggregate` merges accounts into groups, given in the template's `group`
column or in the option `groups(new: old old ..., new: old ...)`. Accounts
not listed keep their label. With the indicator matrix G (groups by accounts,
G[g, k] = 1 if account k is in group g),

    X = G X̄ G'

so that every cell is the sum of the cells it merges. Totals add up, and an
account balance is the sum of its members' balances. A group takes the
position of its first member. Group labels must be valid Stata names that are
not the labels of accounts left as they are.

Flows among the members of a group become a diagonal cell of the new account.
They are kept, as transfers within the group: the model accepts diagonal cells
for households, enterprises and government, and `cge_map` reports any other
as an unsupported flow. The option `netdiagonal` removes them; totals then
fall by the diagonal cell, and balances do not change.

When the template has roles, the members of each group must have the same
role.

## 5. Balancing

`cge_balance` makes the SAM balanced: every account's row total equals its
column total. Both methods keep:

- the sign of every cell, and every zero cell (structural zeros stay zero);
- the cells listed in `fixed()` at their values in X̄: a cell `row:col`, a
  whole row `row:*`, a whole column `*:col`, or an account's row and column
  (`account`).

Both minimise the same measure of the information added to X̄ (Junius and
Oosterhaven 2003; Lenzen, Wood and Gallego 2007), over the cells that may
change,

    D(X, X̄) = Σ |x_ij| ln(|x_ij| / |x̄_ij|) − |x_ij| + |x̄_ij|

which for non-negative matrices is the cross entropy that RAS minimises
(McDougall 1999). They differ in what is known about the totals.

### 5.1 RAS (`method(ras)`, the default)

Every account k has a target total t_k, and the row and column totals of X
are set to it. By default t_k is the average of the account's row and column
totals in X̄; `targets(rows)` or `targets(columns)` use one of them instead,
and `totals(account:value ...)` gives the target of individual accounts. If an
account's row has no cell that may change, its target is its row total (and
likewise for its column); if both are fixed and differ, or a given target
contradicts them, no balanced SAM exists and `cge_balance` stops.

With P the positive and N the absolute value of the negative part of the
cells that may change, and u and v the targets less the fixed cells of each
row and column, generalised RAS (GRAS) finds row factors r and column factors
s such that

    x_ij = r_i p_ij s_j − n_ij / (r_i s_j)

has row totals u and column totals v. Starting from s = 1, it alternates

    r_i = (u_i + sqrt(u_i² + 4 p_i n_i)) / (2 p_i),  p_i = Σ_j p_ij s_j,  n_i = Σ_j n_ij / s_j

(r_i = −n_i / u_i when p_i = 0), and the same for s with the roles of rows
and columns exchanged, until every row and column total is within the
tolerance of its target. Without negative cells this is RAS. A factor that is
not positive and finite means the targets cannot be met with the signs of the
cells, and `cge_balance` stops.

### 5.2 Cross entropy (`method(ce)`)

Only some totals are known, or none: the totals of the other accounts are
estimated with the cells. X minimises D(X, X̄) subject to

    Σ_j x_kj − Σ_i x_ik = 0          for every account k (balance)
    Σ_j x_kj = t_k                    for the accounts in totals()

The solution has the form

    x_ij = p_ij exp(a_ij) − n_ij exp(−a_ij),  a_ij = μ_i − μ_j + ρ_i

with a multiplier μ_k for the balance of each account and ρ_k for each known
total (ρ_k = 0 for other accounts). The multipliers minimise the convex dual

    φ(μ, ρ) = Σ p_ij exp(a_ij) + Σ n_ij exp(−a_ij) + Σ_k μ_k c_k + Σ_{k known} ρ_k (f_k − t_k)

where c_k is the fixed cells' row total less their column total and f_k their
row total. Its gradient is the vector of balances and of differences from the
known totals, and its Hessian is

    H = Σ |x_ij| d_ij d_ij',  d_ij = ∂a_ij/∂(μ, ρ)

Newton's method with a backtracking line search minimises φ until every
balance and known total is within the tolerance. Adding a constant to all μ
in a connected set of accounts changes nothing, so one μ in each set is fixed
at zero; an account without cells that may change must already balance. If
the iterations do not converge, no balanced SAM with the same pattern of
signs and zeros may exist.

When every account's total is known, the solution is the RAS solution
(r_i = exp(μ_i + ρ_i), s_j = exp(−μ_j)); the tests use this.

This is not the column-coefficient cross entropy of Robinson, Cattaneo and
El-Said (2001), which measures the distance between the column shares of X
and X̄ rather than between the cells; that method is not implemented.

### 5.3 Tolerance and results

Convergence is measured against the largest absolute cell of X̄: every
balance (and target) is met to `tolerance()` times max(1, max |x̄_ij|), by
default 1e-10, well within the 1e-8 of the balance check in `cge_map`.
`cge_balance` reports the largest imbalance before and after, the number of
cells changed, the largest relative change of a cell, the SAM total before
and after, and the cells with the largest changes.

The balanced SAM is an estimate. Which totals are known, which cells are
fixed and which method is used should be stated with any results.

## 6. Multiplier analysis (from version 0.4.1)

`cge_multiplier` computes the accounting multipliers of the mapped SAM
(Pyatt and Round 1979): the effects of an injection into one account on the
incomes of all the accounts whose spending the SAM explains, with prices
fixed. It uses the SAM after the layout rewrites of model_spec.md, Section 7.0,
and needs no calibration.

### 6.1 Accounting multipliers

The accounts are divided into endogenous accounts $n$ and exogenous accounts
$x$. By default the endogenous accounts are the activities, commodities and
margin accounts (the production block, $b = 1$), the factors ($b = 2$), and the
households and enterprises (the institutions block, $b = 3$); the government,
savings-investment, the rest of the world, the tax accounts and the health
insurance fund are exogenous. `endogenous()` adds exogenous accounts to the
institutions block, and `exogenous()` removes endogenous ones.

With $t_j$ the column total of account $j$, the average expenditure
propensities among endogenous accounts are

$$A_{ij} = SAM_{ij} / t_j, \qquad i, j \in n,$$

(zero for an account without payments), and the incomes of the endogenous
accounts satisfy $y = A y + x$, where $x$ is their income from exogenous
accounts. Hence

$$y = M x, \qquad M = (I - A)^{-1}.$$

Column $j$ of $M$ is the change in the incomes of every endogenous account for
a unit injection into $j$. The command reports, for each injection, the total
multiplier $\sum_i M_{ij}$ and its parts: gross output (the rows of the
activities), value added (the factors) and household income (the households).
$I - A$ is invertible when every chain of payments among the endogenous
accounts eventually leaks to an exogenous account (taxes, savings, imports);
an activity may pay all of its income to endogenous accounts.

### 6.2 Decomposition

With the three blocks ordered as above, $A$ has a circular structure: factors
are paid by production ($A_{21}$), institutions by factors ($A_{32}$), and
production by institutions ($A_{13}$), with transfers within production
($A_{11}$), within factors ($A_{22}$) and within institutions ($A_{33}$). With
$\tilde A$ the block-diagonal part of $A$ and
$A^* = (I - \tilde A)^{-1}(A - \tilde A)$, Pyatt and Round (1979) write

$$M = M_3 M_2 M_1, \qquad M_1 = (I - \tilde A)^{-1}, \quad M_2 = I + A^* + A^{*2}, \quad M_3 = (I - A^{*3})^{-1},$$

the transfer, open-loop and closed-loop multipliers, and additively

$$M = I + (M_1 - I) + (M_2 - I) M_1 + (M_3 - I) M_2 M_1.$$

The three terms after $I$ are the transfer effects within the injected
account's block, the open-loop effects on the other blocks, and the
closed-loop effects of the circular flow back to the injected block. The
decomposition requires the blocks outside the circle ($A_{12}$, $A_{23}$,
$A_{31}$) to be zero; `decompose` stops with an error, listing the largest
flows that break the structure, if they are not.

### 6.3 Injections

`inject()` gives a vector $x$ of injections into endogenous accounts, for
example more government purchases of a commodity, and reports $M x$: the
change in gross output by activity, in factor incomes and in household
incomes, and their totals.

### 6.4 Use

Accounting multipliers assume fixed prices, unused capacity in every sector
and average propensities equal to marginal ones; they are upper bounds on
the effects that a CGE model, with its supply constraints and price changes,
would find. They complement the CGE model; they do not replace it.

## 7. Testing

The Python reference (`reference/cge_ref/samtools.py`) implements aggregation,
GRAS and the cross-entropy method; its results for a SYNTHETIC unbalanced SAM
(`data/cge_synthetic_sam_unbal.csv`, derived from the institutions layout by
fixed perturbations, with negative cells) are written to `tests/expected`.
The Stata tests compare:

- the balanced SAMs of both methods, with and without fixed cells and known
  totals;
- RAS with given targets against cross entropy with the same known totals;
- an aggregated SAM, mapped from a template, calibrated and solved, against
  the Python model on the same aggregated SAM;
- the three readers against each other, and a SAM larger than `c(maxvar)`
  written and read back;
- the multipliers and their decomposition for five layouts and closures of the
  accounts (`reference/cge_ref/multipliers.py`, `tests/expected/multipliers_*`),
  injections against the expected multipliers, and the identities of the
  decomposition; the Python tests add a SAM whose multipliers are worked by
  hand.

## References

Junius, T. and J. Oosterhaven (2003). The solution of updating or
regionalizing a matrix with both positive and negative entries. *Economic
Systems Research* 15(1): 87–96.

Lenzen, M., R. Wood and B. Gallego (2007). Some comments on the GRAS method.
*Economic Systems Research* 19(4): 461–465.

McDougall, R. A. (1999). Entropy theory and RAS are friends. GTAP Working
Paper 6, Center for Global Trade Analysis, Purdue University.

Robinson, S., A. Cattaneo and M. El-Said (2001). Updating and estimating a
social accounting matrix using cross entropy methods. *Economic Systems
Research* 13(1): 47–64.

Pyatt, G. and J. I. Round (1979). Accounting and fixed price multipliers in a
social accounting matrix framework. *Economic Journal* 89(356): 850–873.
