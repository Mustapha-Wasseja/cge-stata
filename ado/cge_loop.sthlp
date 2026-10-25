{smcl}
{* *! version 0.24.0  25oct2026}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{bf:cge_loop} {hline 2}}Solve the model for a list or grid of scenarios{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_loop}{cmd:,} {opt name(name)} {opt val:ues(target = values[; target = values ...])} [{it:options}]

{p 8 12 2}
{cmd:cge_loop} {cmd:using} {it:filename}{cmd:,} {opt name(name)} [{it:options}]

{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt name(name)}}stub of the simulations, {it:name}{cmd:1}, {it:name}{cmd:2}, ...{p_end}
{synopt:{opt val:ues(spec)}}the values of each target, as {cmd:tm(com_man) = 0 0.1 0.2}{p_end}
{synopt:{opt grid}}every combination of the lists of values{p_end}
{synopt:{opt sc:ale}}values as multiples of the targets' values in place{p_end}
{synopt:{opt cold}}solve each scenario from the base, not from the solution before{p_end}
{synopt:{opt nostore}}keep the results without storing the simulations{p_end}
{synopt:{opt meas:ures(list)}}report measures or expressions to collect, separated by commas{p_end}
{synopt:{opt keep(varlist)}}the variables of the dataset of results; all by default{p_end}
{synopt:{opt clear}}replace the data in memory with the results{p_end}
{synopt:{opt tol:erance(#)}}convergence tolerance of each solve; default 1e-10{p_end}
{synopt:{opt iter:ate(#)}}Newton iterations of each solve; default 100{p_end}
{synopt:{opt par:allel(#)}}solve the scenarios in # Stata processes (from version 0.19.0){p_end}
{synopt:{opt stata:exe(path)}}the Stata executable of the processes{p_end}
{synopt:{opt first(#)}}the number of the first scenario; default 1{p_end}
{synoptline}


{title:Description}

{pstd}
{cmd:cge_loop} (from version 0.9.9; Reference Manual, {it:cge_loop}) solves the
model for many scenarios in one command, as a GAMS {cmd:loop} over a set of
scenarios, or GUSS, does. A target is what a scenario sets: one element of a
parameter that {helpb cge_shock} changes, such as {cmd:tm(com_man)}; one
element of a user parameter ({helpb cge_parameter}); or one element of a
variable fixed under the closure, such as {cmd:QFS(lab)}, as the instruments
of {helpb cge_optimize}. Each scenario takes the shocks in place and sets its
targets; it is solved from the solution of the scenario before, so that a
sweep over a parameter moves in small steps, and is stored as a simulation,
{it:name}{cmd:1}, {it:name}{cmd:2}, and so on, for {helpb cge_results},
{helpb cge_report} and {helpb cge_gams}. A scenario that does not solve from
the solution before is tried from the base, then by continuation; one that
still does not solve is recorded as such, and the loop goes on. The shocks in
place are left as they were.

{pstd}
{opt values()} gives each target its list of values, separated by semicolons:
{cmd:values(tm(com_man) = 0 0.05 0.1; tm(com_agr) = 0 0.1 0.2)}. The lists may
be numlists, such as {cmd:0(0.05)0.2}. By default the lists are taken in
order, scenario by scenario, and must have the same length (a list of one
value applies to every scenario); with {opt grid}, every combination is a
scenario, the first target varying slowest.

{pstd}
With {cmd:using}, the scenarios come from a dataset with one observation per
scenario and target: {cmd:scenario} (string or numeric), {cmd:target} (a
string, such as {cmd:tm(com_man)}) and {cmd:value}. A scenario that leaves a
target out keeps its value in place. The data in memory are left as they are.

{pstd}
{cmd:cge_gams} {it:folder}{cmd:, loop(}{it:name}{cmd:)} writes the loop as a
GAMS program that solves the scenarios in order, each from the solution of the
one before, and {opt compare} checks each against Stata's.


{title:Options}

{phang}
{opt measures(list)} collects, for each scenario, report measures, as
{it:table measure} [{it:element}], such as {cmd:welfare equivalent_variation hhd},
or expressions of the user language of {helpb cge_equation}, such as
{cmd:YG - EG}, separated by commas. They are returned in {cmd:r(measures)} and
added to the dataset of results.

{phang}
{opt clear} replaces the data in memory with one observation per scenario and
element of the variables in {opt keep()}: {cmd:s}, {cmd:scenario},
{cmd:sim}, {cmd:converged}, the targets {cmd:t1}, {cmd:t2}, ... (labelled),
the measures {cmd:m1}, {cmd:m2}, ..., and {cmd:variable}, {cmd:element1},
{cmd:element2}, {cmd:base} and {cmd:value}.

{phang}
{opt scale} reads the values as multiples of the targets' values in place.

{phang}
{opt cold} solves each scenario from the base, as separate solves would;
the default starts each from the solution before.

{phang}
{opt nostore} does not store the simulations; the measures and the dataset
are kept.

{phang}
{opt parallel(#)} (from version 0.19.0) solves the scenarios in # Stata
processes at once: the model is saved, the scenarios split into contiguous
groups, each solved by Stata in batch mode, and the simulations merged back
with the same names and results as one run. In batch mode on Windows, from
version 0.24.0, Stata 16 and later start the processes through Python
({helpb python}, which needs a Python installation). {bf:Caution:} this works
only on some versions of Stata: Stata 13 to 15 cannot start other processes
from batch mode, nor can Stata 16 or later without Python, so the scenarios
are then solved in the session, one after another, with a note. Interactive
Stata of any version starts the processes. {opt stataexe(path)} gives the
executable of the processes; by default that of the running edition.

{phang}
{opt first(#)} (from version 0.19.0) numbers the scenarios from #, so that
the simulations are {it:name}#, ....


{title:Examples}

{pstd}Setup: the SYNTHETIC SAM, mapped and calibrated{p_end}
{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{pstd}A sweep over the tariff on manufactures, with revenue and welfare{p_end}
{phang2}{cmd:. cge_loop, name(tariff) values(tm(com_man) = 0(0.05)0.3) measures(YG, welfare equivalent_variation hhd)}{p_end}
{phang2}{cmd:. matrix list r(measures)}{p_end}

{pstd}Every combination of two tariffs, with the imports of each commodity as a dataset{p_end}
{phang2}{cmd:. cge_loop, name(two) values(tm(com_man) = 0 0.1 0.2; tm(com_agr) = 0 0.1) grid keep(QM) clear}{p_end}
{phang2}{cmd:. list scenario t1 t2 element1 value if element1 == "com_man", noobs}{p_end}

{pstd}Government purchases of services and the labour force, as multiples of their values{p_end}
{phang2}{cmd:. cge_loop, name(fiscal) values(qg(com_ser) = 1 1.1 1.2; QFS(lab) = 1 1 1.05) scale}{p_end}
{phang2}{cmd:. cge_report, sims(fiscal1 fiscal2 fiscal3) tables(macro)}{p_end}


{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_scenarios)}}scenarios{p_end}
{synopt:{cmd:r(N_converged)}}scenarios solved{p_end}
{synopt:{cmd:r(N_failed)}}scenarios not solved{p_end}
{synopt:{cmd:r(iterations)}}Newton iterations in all{p_end}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(name)}}the loop{p_end}
{synopt:{cmd:r(targets)}}its targets{p_end}
{synopt:{cmd:r(sims)}}its simulations, unless {opt nostore}{p_end}
{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(values)}}the targets' values, one row per scenario{p_end}
{synopt:{cmd:r(converged)}}1 for each scenario solved{p_end}
{synopt:{cmd:r(measures)}}the measures, one row per scenario{p_end}


{title:Also see}

{psee}
{helpb cge_shock}, {helpb cge_solve}, {helpb cge_optimize}, {helpb cge_sensitivity}, {helpb cge_gams}, {helpb cge}
{p_end}
