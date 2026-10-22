# cge-stata Reference Manual

**[cge-stata-manual.pdf](cge-stata-manual.pdf)** is the manual of the package,
in the form of Stata's own manuals:

- **Part I, Introduction and user's guide**: what the package does,
  installation, a first model, the workflow, a worked example from a raw SAM
  to results, and validation, performance and troubleshooting.
- **Part II, The model: methods and formulas**: the notation, every equation
  of the model, the closures, calibration, the solution method, the
  validation checks, the reporting measures, the extensions (fiscal
  instruments, trade and households, labour markets, health, constraints,
  factor taxes, nests and output aggregation), recursive dynamics, the
  household survey link, sensitivity analysis, policy optimisation, user
  equations, the SAM tools, the GAMS implementation and the elasticity
  library.
- **Part III, Command reference**: one entry for each command, with its
  syntax, options, examples and their output, stored results, and methods and
  formulas.

The examples use the SYNTHETIC SAMs that come with the package; they describe
no country.

The manual is built from the LaTeX sources in [tex/](tex), whose
[README](tex/README.md) describes how they are organised:

```
python tools/build_manual.py              # the PDF
python tools/build_manual.py --examples   # run the examples in Stata and update their output first
```

Each command also has a help file in Stata (`help cge`).
