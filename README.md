# cge-stata

Computable general equilibrium (CGE) modelling in Stata.

`cge-stata` builds, calibrates and solves single-country CGE models from a
social accounting matrix (SAM) entirely within Stata and Mata. No external
modelling system (GAMS, GEMPACK or similar) is required.

## Status

Development release 0.0.1. The package currently provides:

- `cge`: version and command list;
- `cge_synthetic`: loads a synthetic, balanced 15-account SAM used in tests and
  examples.

Version 0.1 will implement the standard static model described in
[docs/model_spec.md](docs/model_spec.md): CES/Leontief production, CET exports,
Armington imports, households, government, savings-investment and the rest of
the world, with selectable closures. The package should not be used for policy
analysis until version 0.1 has passed its validation suite.

## Requirements

Stata 13 or later (Stata/IC is sufficient). No other Stata packages are needed.

## Installation

The repository is private during development. Clone it, then install from the
local copy:

```stata
net install cge, from("C:/path/to/cge-stata") replace
```

Once the repository is public it will also install directly from GitHub:

```stata
net install cge, from("https://raw.githubusercontent.com/Mustapha-Wasseja/cge-stata/main/") replace
```

## Quick start

```stata
cge
cge_synthetic, clear
list account act_agr act_man act_ser com_agr, noobs
```

## Documentation

- [docs/model_spec.md](docs/model_spec.md): equations, calibration, closures
  and validation checks.
- [docs/design.md](docs/design.md): commands, data structures, solver, testing
  and roadmap.
- [CONTRIBUTING.md](CONTRIBUTING.md): development conventions.

## Validation

Every model is checked for benchmark replication, homogeneity, Walras's law and
closure consistency. A Python reference implementation of the same equations
(`reference/`) runs in continuous integration, and the Stata results are
compared against it.

## Author

Mustapha Wasseja

## Licence

No licence has been granted yet. All rights reserved until a licence is chosen
before public release.
