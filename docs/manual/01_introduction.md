# 1. Introduction

## 1.1 What the package does

`cge-stata` builds, calibrates and solves single-country CGE models from a
SAM, within Stata and Mata, without an external modelling system. The model is
the standard SAM-based model of the IFPRI and PEP traditions (Lofgren, Harris
and Robinson 2002; Decaluwé et al. 2013), written out in
[model_spec.md](../model_spec.md):

- production with CES or Cobb-Douglas value added and Leontief intermediate
  inputs, with an optional CES nest between them; activities may produce
  several commodities;
- trade through a CET between exports and domestic sales and an Armington CES
  between imports and domestic goods;
- households with Cobb-Douglas or linear expenditure system (LES) demand,
  enterprises, government, savings-investment and the rest of the world, with
  transfers among them;
- direct, sales, import, export and activity taxes, and VAT with input
  credits;
- closures for the external account, government, savings-investment, the
  numeraire and each factor.

Extensions cover public debt, home consumption, finite export demand, margins
by market, labour-market regimes, a social health insurance fund, factor
efficiency linked to health services, and health outcomes. The model can be
solved for one period or as a recursive dynamic sequence, its results can be
passed to household survey data, and the sensitivity of results to the
elasticities can be measured. Tools prepare the SAM, and a library gives
published elasticities with their sources.

What the package does not do: it has no intertemporal optimisation (agents do
not look ahead), no multi-region model, and no estimation of elasticities. Its
elasticities are inputs, stated by the user.

## 1.2 Installation

The package needs Stata 13 or later; it runs on Stata/IC. Install it from
GitHub:

```stata
net install cge, from("https://raw.githubusercontent.com/Mustapha-Wasseja/cge-stata/main/") replace
```

Stata 13 cannot connect to GitHub (its TLS version is too old). Download or
clone the repository, then install from the folder:

```stata
net install cge, from("C:/path/to/cge-stata") replace
```

`help cge` lists the commands; `cge` displays the version. The Mata library is
compiled the first time a command runs in a session.

## 1.3 The workflow

A model is built in a fixed order. Each step is a command:

| Step | Command | Chapter |
|---|---|---|
| Read the SAM | `cge_sam` | 2 |
| Prepare it: template, aggregation, balancing | `cge_template`, `cge_aggregate`, `cge_balance`, `cge_samexport` | 2 |
| Assign accounts to model roles | `cge_map` | 3 |
| Choose elasticities | `cge_elasticities` | 3 |
| Calibrate | `cge_calibrate` | 3 |
| Check | `cge_check` | 3, 10 |
| Choose a closure, apply shocks, solve | `cge_closure`, `cge_shock`, `cge_solve` | 4 |
| Report | `cge_results`, `cge_report`, `cge_parameters` | 5 |
| Dynamic runs | `cge_dynamic`, `cge_dynresults` | 7 |
| Sensitivity, household survey link | `cge_sensitivity`, `cge_microsim` | 8 |
| Save and reload | `cge_save`, `cge_use` | 5 |

The shortest complete model, on the synthetic SAM:

```stata
cge_synthetic, clear
cge_sam, labels(account)
cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)       ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
cge_solve, name(notariff)
cge_report, sims(notariff)
```

The model lives in Mata, not in the data in memory: commands that load data
(`clear` options, `cge_microsim`) leave the model intact, and `cge_save`
stores it with its simulations.

## 1.4 Principles

- **No defaults for economic assumptions.** Elasticities have no default
  values. The closure starts from a documented default and is displayed with
  every simulation.
- **Checks bound to the values used.** Every calibration checks that the base
  solves every equation (benchmark replication) and stops if it does not.
  `cge_check` runs the validation checks on the model actually solved.
- **Errors, not guesses.** A SAM cell the model cannot represent, an
  unbalanced account, or a number that cannot be read stops the command with
  a report; nothing is set to zero silently.

## 1.5 How the package is tested

The equations are implemented three times:

- in Stata and Mata (the package);
- in Python (`reference/cge_ref`), which writes the expected results;
- in GAMS (`tools/gams`), written from the specification and solved with PATH.

The Stata test suite compares every result with the Python reference; the
two agree to about 1e-11 or better. The GAMS implementation reproduces the
same cases, 139 scenarios, to 3e-11 or better. Chapter 10 gives the details.

## References

Decaluwé, B., A. Lemelin, V. Robichaud and H. Maisonnave (2013). *PEP-1-1: The
PEP standard single-country, static CGE model*. Partnership for Economic Policy.

Lofgren, H., R. L. Harris and S. Robinson (2002). *A Standard Computable General
Equilibrium (CGE) Model in GAMS*. Microcomputers in Policy Research 5.
International Food Policy Research Institute.
