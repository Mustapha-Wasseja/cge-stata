# Sources of the cge-stata Reference Manual

The manual is written in LaTeX and built with

```
python tools/build_manual.py                      # the whole manual -> docs/manual/cge-stata-manual.pdf
python tools/build_manual.py --entry cge_solve    # one command entry on its own, for checking
python tools/build_manual.py --examples           # run every example do-file in Stata and update output/
python tools/build_manual.py --examples cge_solve # one example do-file
```

It needs pdflatex with the packages loaded by `cgestyle.sty`, and Stata for
`--examples`.

| File or folder | Content |
|---|---|
| `cge-stata-manual.tex` | the main file: the order of the parts, chapters and entries |
| `cgestyle.sty` | page layout, fonts and the macros below |
| `front.tex`, `references.tex` | title page; bibliography |
| `intro/` | Part I, introduction and user's guide |
| `model/` | Part II, the model: methods and formulas |
| `ref/` | Part III, one file per command, named after it |
| `examples/` | do-files whose output the manual shows, one per entry or chapter |
| `output/` | that output, written by `--examples`; do not edit by hand |

## Command entries (Part III)

Each entry follows the order of the entries in Stata's own manuals. Leave out
a section that has nothing to say (for example Stored results for a command
that stores none).

```latex
\cgeentry{cge_solve}{Solve the model}
\cgesec{Description}
\cgesec{Quick start}          % short commands, each with one line saying what it does
\cgesec{Syntax}               % stsyntax and opttable
\cgesec{Options}              % optdesc
\cgesec{Remarks and examples} % \cgesubsec{Example 1: ...} with \stlog{} output
\cgesec{Stored results}       % storedres
\cgesec{Methods and formulas} % formulas, and the chapters of Part II
\cgesec{References}           % only if the entry cites
\cgesec{Also see}             % alsosee
```

`ref/cge_solve.tex` is a complete example.

### Macros

| Macro | Use |
|---|---|
| `\cmd{cge_map}` | a command, variable, option value or file name, as typed (underscores need no escaping) |
| `\cmdb{cge_map}` | the bold command name at the start of a syntax diagram |
| `\opt{tol}{erance}` | an option, with its minimum abbreviation underlined; `\opt{}{trace}` when it cannot be abbreviated |
| `\optarg{tol}{erance}{\#}` | an option with an argument: tolerance(#) |
| `\argu{varname}` | an argument in a syntax diagram (italic) |
| `\res{r(N_solved)}` | a stored result |
| `\manref{cge_shock}` | a link to another entry: **[CGE]** cge_shock |
| `\chapref{chap:solution}`, `\secref{sec:reduced}`, `\eqref{eq:P3}` | links to Part II |
| `\V{PQ}_c` | a model variable or parameter in mathematics |
| `\pkg` | the package name |

Environments: `stsyntax` (a syntax diagram), `opttable` (the options table of
the diagram; rows `\opt...` `&` description `\\`, groups `\optgroup{Main}`),
`optdesc` (`\item[\opt{}{trace}] description`), `storedres` (rows
`\res{...} & description \\`, groups `\resgroup{Scalars}`), `stcode`
(commands as typed, verbatim), `filecode` (lines of a file, verbatim),
`alsosee` (`\seeentry{cmd}{title}`, `\seechapter{label}{title}`), and
`\stlog{tag}` for the output of an example.

### Syntax and abbreviations

The `syntax` statement of each `.ado` file is the authority for the syntax:
capital letters give the minimum abbreviation (`TOLerance` is
`\opt{tol}{erance}`), and an option written all in capitals cannot be
abbreviated (`TRACE` is `\opt{}{trace}`). The help file gives the
descriptions; where it and the code differ, the code is right.

### Examples and their output

Put the commands of an entry's examples in `examples/<command>.do` and mark
each piece of output the entry shows:

```stata
*>> solve_notariff
cge_shock tm, value(0)
cge_solve, name(notariff)
*<<
```

`--examples` runs the do-file in Stata 13 (`version 13.0`, line size 100) from
a temporary directory, and writes the marked lines to `output/solve_notariff.txt`,
which the entry shows with `\stlog{solve_notariff}`. Tags start with a short
form of the command name and are unique. To show an error as Stata shows it,
write

```stata
capture noisily cge_solve, name(qg10)
di as err "r(" _rc ");"
```

The output then shows `. cge_solve, name(qg10)`, the error message and
`r(430);`.

Output up to 100 characters wide fits the page at the default size. For a
table up to 110 characters wide, make `set linesize 110` the first command
inside the markers and `set linesize 100` the first after them (the
`set linesize` lines are not shown), and show it with
`\stlog[\scriptsize]{tag}`. Wider output does not fit; show less of it. Examples use the synthetic SAMs of `cge_synthetic` and synthetic
data generated in the do-file; files are written with relative names, to the
temporary directory. Output that names a path, a user or a licence stops the
build.

### Writing

- British spelling, as in the help files and the rest of the documentation.
- Each statement can be checked against the help file, the code or Part II.
  Explain the economics where it helps, but do not interpret output beyond
  what it shows.
- Formulas live in Part II; an entry's Methods and formulas gives the formulas
  of the command itself and points to Part II for the model.
- No references to other documentation files: the manual is self-contained.

## Labels

Part I: `chap:intro`, `chap:start`, `chap:workflow`, `chap:example`,
`chap:validation`.

Part II:

| Chapter | Label | Sections |
|---|---|---|
| Notation and the social accounting matrix | `chap:notation` | `sec:sam-conventions`, `sec:sets`, `sec:variables`, `sec:parameters` |
| The equations of the standard model | `chap:equations` | `sec:prices`, `sec:production`, `sec:trade`, `sec:institutions`, `sec:system` |
| Closures | `chap:closures` | `sec:closure-options`, `sec:swaps` |
| Calibration | `chap:calibration` | `sec:flows`, `sec:layouts`, `sec:normalisation`, `sec:cal-trade`, `sec:cal-production`, `sec:cal-cet`, `sec:cal-institutions`, `sec:factor-quantities` |
| The solution method | `chap:solution` | `sec:newton`, `sec:reduced`, `sec:jacobian`, `sec:continuation`, `sec:diagnostics` |
| Validation checks | `chap:checks` | |
| Reporting measures and welfare | `chap:reporting` | `sec:measures`, `sec:welfare` |
| Fiscal instruments | `chap:fiscal` | `sec:replacement`, `sec:vat`, `sec:debt` |
| Trade and household extensions | `chap:trade` | `sec:home`, `sec:exportdemand`, `sec:exportonly`, `sec:margins-market` |
| Labour-market regimes | `chap:labour` | `sec:labourforce`, `sec:wagecurve`, `sec:minwage` |
| Health | `chap:health` | `sec:fund`, `sec:efficiency`, `sec:sickdays`, `sec:mortality`, `sec:population` |
| Bounds and complementarity | `chap:constraints` | `sec:rents`, `sec:cons-def`, `sec:cons-solution` |
| Factor taxes, nests and output aggregation | `chap:production` | `sec:factortax`, `sec:nests`, `sec:outputces` |
| Recursive dynamics | `chap:dynamics` | |
| The link to household surveys | `chap:microsim` | |
| Sensitivity analysis | `chap:sensitivity` | |
| Policy optimisation | `chap:optimize` | |
| User variables and equations | `chap:user` | |
| SAM tools | `chap:samtools` | `sec:reading`, `sec:writing`, `sec:template`, `sec:aggregation`, `sec:balancing`, `sec:ras`, `sec:ce`, `sec:multipliers`, `sec:decomposition`, `sec:spa` |
| The GAMS implementation | `chap:gams` | `sec:gams-files`, `sec:gams-types`, `sec:gams-import` |
| The elasticity library | `chap:elasticities` | |

Equations carry the labels of the model's blocks, `eq:P1` to `eq:P9`,
`eq:Q1` to `eq:Q6`, `eq:T1` to `eq:T10`, `eq:I1` to `eq:I14`, `eq:S1` to
`eq:S6`, `eq:H1` to `eq:H3`, `eq:L1`, `eq:L2`, `eq:N1` to `eq:N3`, and the
variants named in Part II (for example `eq:Q3CD`, `eq:Q6A`).

Entry titles, for `\cgeentry` and `\seeentry`:

| Entry | Title |
|---|---|
| `cge` | Computable general equilibrium modelling in Stata |
| `cge_aggregate` | Merge SAM accounts into groups |
| `cge_balance` | Balance a SAM by RAS or cross entropy |
| `cge_calibrate` | Calibrate the model to the SAM |
| `cge_check` | Run model validation checks |
| `cge_closure` | Choose the model closure |
| `cge_constraint` | Limits that bind in some scenarios and not in others |
| `cge_dynamic` | Solve a recursive dynamic run |
| `cge_dynresults` | Results of a dynamic run as a dataset |
| `cge_elasticities` | Published elasticities, with their sources |
| `cge_equation` | User equations: new relations among the model's variables |
| `cge_gams` | Write the model as a GAMS program, and solve it in GAMS |
| `cge_map` | Assign SAM accounts to model roles |
| `cge_microsim` | Pass a simulation to household survey data |
| `cge_multiplier` | SAM multipliers and their decomposition |
| `cge_optimize` | Choose policy instruments to maximise an outcome or reach targets |
| `cge_parameters` | The calibrated parameters as a dataset |
| `cge_report` | Standard report tables for one or more simulations |
| `cge_results` | Report simulation results |
| `cge_sam` | Read a social accounting matrix |
| `cge_samexport` | Write the SAM to a file or to memory |
| `cge_save` | Save the model and its simulations to a file |
| `cge_sensitivity` | Sensitivity of a scenario's results to the elasticities |
| `cge_shock` | Change a parameter or a fixed variable |
| `cge_solve` | Solve the model |
| `cge_spa` | Structural path analysis of a SAM multiplier |
| `cge_synthetic` | Load the synthetic social accounting matrix |
| `cge_template` | Write a template that maps SAM accounts to roles and groups |
| `cge_use` | Load a model saved with cge_save |
| `cge_variable` | User variables, defined by an expression or determined by user equations |
