# 11. Solving the model in GAMS

`cge-stata` solves its model in Stata, but many CGE modellers work in GAMS.
From version 0.4.3, `cge_gams` writes the calibrated model and a scenario as
a GAMS program. You can then:

- solve it with another solver, such as PATH, CONOPT, KNITRO or IPOPT;
- confirm a result with a second implementation;
- hand the model to a colleague who uses GAMS;
- add equations that the package does not have.

The details are in [docs/gams.md](../gams.md).

## 11.1 Writing the model

```stata
cge_closure, government(fixgsav sales)
cge_shock tm, value(0)
cge_solve, name(notariff)
cge_gams using gams_notariff, sim(notariff)
```

The folder `gams_notariff` then holds the driver `cge_run.gms`, the GAMS
model and three data files:

- the SAM, after the rewrites of `cge_map`, with the roles of its accounts
  and the calibration settings;
- the parameter changes and the closure;
- the changes to fixed variables.

GAMS calibrates the model itself from the SAM and the settings, with its own
implementation of the equations. A GAMS solution that matches Stata's
therefore also confirms the calibration. Without `sim()`, the shocks and
closure in memory are written instead.

## 11.2 Solving it and comparing

In the folder, `gams cge_run.gms` solves the base and the scenario with PATH.
Other solvers are chosen on the command line, for example
`--cgesolver=conopt`, or `--cgesolver=ipopt --cgetype=nlp` for an NLP solver.

From interactive Stata, `run` starts GAMS and `compare` reports how far its
results are from Stata's:

```stata
cge_gams using gams_notariff, sim(notariff) replace run compare gams(C:/GAMS/54/gams.exe)
cge_gams using gams_notariff, sim(notariff) noexport run compare solver(ipopt) gams(C:/GAMS/54/gams.exe)
```

The comparison is the largest relative difference, |GAMS − Stata| / max(1,
|Stata|), over every variable that exists in the model, for the base and for
the scenario. With PATH, KNITRO and IPOPT it is about 1e-11, the precision of
the two solutions. CONOPT stops at a looser tolerance, about 1e-9.

Stata for Windows cannot start GAMS in batch mode. In a batch do-file, run
`cge_run.gms` with GAMS separately and then compare:

```stata
cge_gams using gams_notariff, sim(notariff) compare noexport
```

The example `examples/gams_export.do` does all of this.

## 11.3 Constraints

A scenario with constraints (chapter 6.5) is written as a mixed
complementarity problem in `cge_constraints.inc`. Each constraint becomes:

- a slack variable, zero or positive, paired with the bound;
- its adjusting variable, linked to the slack.

GAMS then solves it with PATH (`type(mcp)`, the default for such a
scenario). CONOPT, KNITRO and IPOPT do not solve complementarity problems.
NLPEC, which turns one into a nonlinear programme for CONOPT, solved the
test cases only to about 1e-4 with its default settings.

## 11.4 Limits

- Static simulations are exported. Dynamic runs, microsimulation and
  sensitivity analysis stay in Stata.
- GAMS and a solver licence are needed. GAMS runs solvers outside the licence
  only for small models.
- Listing files (`.lst`) name the licence holder; keep them out of shared
  folders if that matters.
