{smcl}
{* *! version 0.4.4  21oct2026}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{bf:cge_gams} {hline 2}}Write the model as a GAMS program, and solve it in GAMS{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_gams} {helpb using} {it:folder}
[{cmd:,} {opt sim(name)} {opt dyn:amic(name)} {opt replace} {opt run} {opt compare} {opt noexport}
{opt gams(path)} {opt solver(name)} {opt type(cns|nlp|mcp)}]


{title:Description}

{pstd}
{cmd:cge_gams} writes the calibrated model and one scenario as a GAMS program
in {it:folder} (from version 0.4.3; docs/gams.md). Anyone with GAMS can then
solve the model with PATH, CONOPT, KNITRO, IPOPT or another solver, check the
results of {cmd:cge-stata}, or extend the equations.

{pstd}
GAMS receives what a user supplies, not the calibrated parameters: the SAM
after the layout rewrites of {helpb cge_map}, the roles of its accounts and
the settings given to {helpb cge_calibrate}. The GAMS program calibrates
every parameter itself, solves the base, then the scenario. Its equations,
in {cmd:cge_model.gms}, are an independent implementation of the model
specification, written in GAMS rather than translated from Mata; the
package's own checks compare the two.

{pstd}
The scenario is the shocks and closure in memory (the next {helpb cge_solve}
would solve it) or, with {opt sim()}, those of a stored simulation. Changed
parameters and fixed variables are written as ratios to their base values,
so that GAMS applies them to its own calibrated values.

{pstd}
Files written:

{p2colset 9 30 32 2}{...}
{p2col:{cmd:cge_run.gms}}the driver: run {cmd:gams cge_run.gms}{p_end}
{p2col:{cmd:cge_model.gms}}data, calibration, equations and base solve{p_end}
{p2col:{cmd:cge_closure.gms}}bounds and the closure{p_end}
{p2col:{cmd:cge_solve.gms}, {cmd:cge_write.gms}}the solve statement and the output{p_end}
{p2col:{cmd:cge_data.inc}}the SAM, the roles of its accounts and the calibration settings{p_end}
{p2col:{cmd:cge_shock_par.inc}}parameter changes and the closure{p_end}
{p2col:{cmd:cge_shock_var.inc}}changes to fixed variables{p_end}
{p2col:{cmd:cge_constraints.inc}}constraints, as complementarity pairs (from version 0.4.4){p_end}
{p2colreset}{...}

{pstd}
A scenario with constraints ({helpb cge_constraint}) is written as a mixed
complementarity problem. Each constraint becomes a slack variable, which must
be zero or positive, paired with its bound, and its adjusting variable is
linked to the slack. It is solved with PATH or another MCP solver.

{pstd}
GAMS writes {cmd:cge_base.csv} and {cmd:cge_}{it:name}{cmd:.csv}, one row per
variable and element, with the model status in the first row; {it:name} is
{opt sim()}, or {cmd:current}. With {opt dynamic()} (from version 0.5.3),
GAMS solves every period of a dynamic run in order and writes
{cmd:cge_}{it:period}{cmd:.csv} for each. The death rate, which enters only
dynamic runs through their labour supply, is not a GAMS parameter.


{title:Options}

{phang}
{opt sim(name)} exports the shocks and closure of a stored simulation;
{opt compare} needs it or {opt dynamic()}.

{phang}
{opt dynamic(name)} (from version 0.5.3) exports every period of a dynamic run
of {helpb cge_dynamic}. Each period's changes from the period before, to
parameters and to fixed variables, are written to
{cmd:cge_}{it:period}{cmd:_par.inc} and {cmd:cge_}{it:period}{cmd:_var.inc}, and
the driver solves the periods in order, each from the solution of the one
before. With {opt compare}, every period is compared with Stata's. Runs with
constraints are not exported.

{phang}
{opt replace} allows the files of an earlier export in {it:folder} to be
replaced. The folder is created if it does not exist.

{phang}
{opt run} solves the exported model in GAMS. Stata writes a script,
{cmd:cge_run.cmd} (Windows) or {cmd:cge_run.sh}, in the folder and runs it
with {helpb shell}; the script can be run again by hand. Stata for Windows
cannot start other programs in batch mode: there, run {cmd:cge_run.gms} with
GAMS and then compare with {opt noexport}.

{phang}
{opt compare} compares the GAMS results with the Stata base and with
simulation {opt sim()}. For each value it computes |GAMS - Stata| / max(1,
|Stata|), over the variables and elements that exist in the model, and
reports the largest difference for the base and for the scenario.

{phang}
{opt noexport} uses the files already in {it:folder}: with {opt run} it
solves them again (for example after editing them), and with {opt compare}
alone it compares results that GAMS wrote earlier.

{phang}
{opt gams(path)} gives the GAMS executable, for example
{cmd:gams(C:/GAMS/54/gams.exe)}; by default {cmd:gams} must be on the system
path.

{phang}
{opt solver(name)} chooses the solver; the default is {cmd:path}. An option
file with tolerances scaled to the size of the SAM is written for PATH,
CONOPT, IPOPT and KNITRO; other solvers use their defaults.

{phang}
{opt type(cns|nlp|mcp)} chooses the GAMS model type:

{phang2}o  {cmd:cns}, a constrained nonlinear system (PATH, CONOPT, KNITRO);{p_end}
{phang2}o  {cmd:nlp}, the same equations with a constant objective, for NLP solvers;{p_end}
{phang2}o  {cmd:mcp}, a mixed complementarity problem (PATH), which a scenario with constraints needs.{p_end}

{pmore}
The default is {cmd:mcp} for a scenario with constraints, {cmd:nlp} for
{cmd:ipopt}, {cmd:minos} and {cmd:snopt}, and {cmd:cns} otherwise. Both
solver and type can also be set when GAMS is run, for example
{cmd:gams cge_run.gms --cgesolver=ipopt --cgetype=nlp}.


{title:Examples}

{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}
{phang2}{cmd:. cge_shock tm, value(0)}{p_end}
{phang2}{cmd:. cge_solve, name(notariff)}{p_end}

{pstd}Write the model and the scenario, to solve in GAMS later{p_end}
{phang2}{cmd:. cge_gams using gams_notariff, sim(notariff)}{p_end}

{pstd}Solve it in GAMS with PATH, then with CONOPT, and compare with Stata{p_end}
{phang2}{cmd:. cge_gams using gams_notariff, sim(notariff) replace run compare gams(C:/GAMS/54/gams.exe)}{p_end}
{phang2}{cmd:. cge_gams using gams_notariff, sim(notariff) noexport run compare solver(conopt) gams(C:/GAMS/54/gams.exe)}{p_end}


{title:Stored results}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(N_accounts)}}accounts in the exported SAM{p_end}
{synopt:{cmd:r(N_changes)}}parameter and fixed-variable changes from the base{p_end}
{synopt:{cmd:r(N_constraints)}}constraints exported{p_end}
{synopt:{cmd:r(modelstat)}}GAMS model status of the scenario ({opt compare}; 1, 2, 15 and 16 mean solved){p_end}
{synopt:{cmd:r(base_modelstat)}}GAMS model status of the base{p_end}
{synopt:{cmd:r(maxdiff)}}largest relative difference from the simulation{p_end}
{synopt:{cmd:r(base_maxdiff)}}largest relative difference from the Stata base{p_end}
{synopt:{cmd:r(N_compared)}}values compared{p_end}
{synopt:{cmd:r(walras)}}value of the WALRAS variable in GAMS (largest over periods with {opt dynamic()}){p_end}
{synopt:{cmd:r(N_periods)}}periods exported or compared ({opt dynamic()}){p_end}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(name)}}name of the exported scenario{p_end}
{synopt:{cmd:r(closure)}}its closure{p_end}
{synopt:{cmd:r(compared_with)}}the simulation or dynamic run compared ({opt compare}){p_end}
{synopt:{cmd:r(sims)}}the periods of the dynamic run ({opt dynamic()}){p_end}
{synopt:{cmd:r(worst_period)}}the period with the largest difference ({opt dynamic()} and {opt compare}){p_end}
{synopt:{cmd:r(script)}}the script that ran GAMS ({opt run}){p_end}


{title:Remarks}

{pstd}
GAMS and a licence for the solver are required to solve the exported model;
GAMS runs solvers outside the licence only for small models. Listing files
({cmd:.lst}) name the licence holder.


{title:Also see}

{psee}
{helpb cge_solve}, {helpb cge_results}, {helpb cge}
{p_end}
