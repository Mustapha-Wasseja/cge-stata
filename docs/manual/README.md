# cge-stata user manual

Version 0.6.1. This manual explains how to build, calibrate and solve a
computable general equilibrium (CGE) model from a social accounting matrix
(SAM) with `cge-stata`, and how to use the results. It is written for
economists who know Stata and the basics of SAM-based modelling. The model's
equations are in [docs/model_spec.md](../model_spec.md), the SAM tools in
[docs/sam_tools.md](../sam_tools.md) and the elasticity library in
[docs/elasticities.md](../elasticities.md); each command has a help file
(`help cge`).

## Contents

1. [Introduction](01_introduction.md): what the package does, installation,
   the workflow, and how the package is tested
2. [Preparing the SAM](02_sam.md): reading, templates, aggregation, balancing,
   export, multipliers and structural path analysis
3. [Mapping and calibration](03_calibration.md): model roles, national-accounts
   layouts, elasticities, calibration and the checks
4. [Closures, shocks and solving](04_simulation.md)
5. [Results](05_results.md): summaries, report tables, parameters, saving a
   model
6. [Model extensions](06_extensions.md): fiscal instruments, trade and
   households, labour markets, health, and limits that may bind
7. [Recursive dynamics](07_dynamics.md)
8. [Sensitivity analysis and household surveys](08_sensitivity_microsim.md)
9. [A worked example: from a raw SAM to results](09_worked_example.md)
10. [Validation, performance and troubleshooting](10_troubleshooting.md)
11. [Solving the model in GAMS](11_gams.md): writing the model for GAMS,
    other solvers, comparison with Stata, extending the equations

## Worked examples

The do-files in [examples/](../../examples) run on the synthetic SAMs that come
with the package. The SAMs are SYNTHETIC: they are constructed for testing and
describe no country.

| File | Content |
|---|---|
| `raw_sam_to_results.do` | the whole workflow, from an unbalanced SAM to policy results, sensitivity, dynamics and poverty (chapter 9) |
| `tariff_removal.do` | a first model: mapping, calibration, a tariff removal under two closures, checks |
| `sam_preparation.do` | templates, aggregation and balancing by cross entropy and RAS |
| `elasticities.do` | published elasticities as calibration options |
| `multipliers.do` | SAM multipliers, their decomposition, structural paths, and the same injection in the CGE model |
| `fiscal_instruments.do` | revenue-neutral tax replacement, VAT with input credits, public debt |
| `trade_home.do` | home consumption, export demand, export-only commodities, margins by market |
| `labour_market.do` | unemployment, a wage curve and a minimum wage |
| `health_outcomes.do` | days lost to illness, the death rate, population and labour |
| `gams_export.do` | the model as a GAMS program, solved with PATH and IPOPT and compared with Stata |
| `constraints.do` | a capacity limit on health services, a deficit ceiling and an import quota |

Every example is run by the Stata test suite (`tests/test_examples.do`).
