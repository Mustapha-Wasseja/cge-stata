{smcl}
{* *! version 0.6.0  21oct2026}{...}
{title:Title}

{p2colset 5 21 23 2}{...}
{p2col:{bf:cge_optimize} {hline 2}}Choose policy instruments to maximise an outcome or reach targets{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_optimize}{cmd:,} {opt inst:ruments(list)}
{opt max:imize(measure)}|{opt min:imize(measure)}|{opt targ:ets(spec)}
[{opt targ:ets(spec)} {opt low:er(spec)} {opt up:per(spec)} {opt name(name)}
{opt tol:erance(#)} {opt iter:ate(#)} {opt trace}]

{p 4 4 2}
A {it:measure} is a measure of {helpb cge_report}: {it:table measure}
[{it:element}], for example {cmd:welfare equivalent_variation hhd} or
{cmd:macro gdp_real}.


{title:Description}

{pstd}
{cmd:cge_optimize} (from version 0.6.0; docs/model_spec.md, Section 18)
chooses the values of a few instruments to maximise or minimise a report
measure, or to reach targets for report measures. It solves the model at
every trial value, starting from the solution of the trial before, inside a
projected Newton optimiser, as one would with an NLP solver such as CONOPT. It
is meant for a few instruments: a tax rate, the volume of a public service, a
transfer.

{pstd}
An instrument is one element of a parameter that {helpb cge_shock} changes,
written as {it:parameter}{cmd:(}{it:element}{cmd:)}, such as {cmd:tm(com_man)}
or {cmd:qg(com_hlt)}, a scalar parameter such as {cmd:trgr}, or one element of
a variable that the closure fixes, such as {cmd:GADJ} or {cmd:QFS(lab)}. The
optimisation starts from the instruments' current values, with any shocks
already applied, under the current closure.

{pstd}
With {opt targets()} alone there must be one target for each instrument, and
the targets are solved for by Newton's method. With an objective, targets are
equality constraints, met by the augmented Lagrangian method. The optimum is
stored as a simulation, and the instruments are left at their optimal values
as current shocks, so that {helpb cge_report} and {helpb cge_results} show
it.


{title:Options}

{phang}
{opt instruments(list)} lists the instruments, separated by spaces.

{phang}
{opt maximize(measure)} or {opt minimize(measure)} gives the objective.

{phang}
{opt targets(spec)} gives targets, separated by commas, as {it:table measure}
[{it:element}] {cmd:=} {it:value}, for example
{cmd:targets(government savings = 3, macro investment_real = 50)}.

{phang}
{opt lower(spec)} and {opt upper(spec)} give bounds as
{it:instrument}{cmd::}{it:value} pairs, for example
{cmd:lower(tm(com_man):0) upper(tm(com_man):0.2)}. An instrument's current
value must lie within its bounds.

{phang}
{opt name(name)} names the simulation that holds the optimum; the default is
{cmd:optimum}.

{phang}
{opt tolerance(#)} is the convergence tolerance of each solve of the model
(default 1e-12); {opt iterate(#)} the largest number of Newton iterations of
each solve (default 100). {opt trace} shows the optimiser's iterations.


{title:Examples}

{pstd}The tariff on manufactures that maximises household welfare, revenue-neutral{p_end}
{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}
{phang2}{cmd:. cge_closure, government(fixgsav)}{p_end}
{phang2}{cmd:. cge_optimize, instruments(tm(com_man)) maximize(welfare equivalent_variation hhd) lower(tm(com_man):-0.5) upper(tm(com_man):1)}{p_end}

{pstd}Both tariffs, keeping tariff revenue at its base value{p_end}
{phang2}{cmd:. cge_optimize, instruments(tm(com_agr) tm(com_man)) maximize(welfare equivalent_variation hhd) targets(government tax_import = 8)}{p_end}

{pstd}The direct tax rate that keeps government savings at the base when tariffs are removed{p_end}
{phang2}{cmd:. cge_closure, government(flexgsav)}{p_end}
{phang2}{cmd:. cge_shock tm, value(0)}{p_end}
{phang2}{cmd:. cge_optimize, instruments(TINSADJ) targets(government savings = 3)}{p_end}


{title:Stored results}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(converged)}}1 if the optimisation converged{p_end}
{synopt:{cmd:r(objective)}}the objective at the optimum{p_end}
{synopt:{cmd:r(N_evaluations)}}solves of the model{p_end}
{synopt:{cmd:r(N_failed)}}trial values at which the model did not solve{p_end}
{synopt:{cmd:r(iterations)}}iterations of the optimiser{p_end}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(name)}}the simulation that holds the optimum{p_end}
{synopt:{cmd:r(instruments_list)}}the instruments{p_end}
{p2col 5 22 26 2: Matrices}{p_end}
{synopt:{cmd:r(instruments)}}the instruments at the optimum{p_end}
{synopt:{cmd:r(start)}}their starting values{p_end}
{synopt:{cmd:r(targets)}}the target measures at the optimum{p_end}


{title:Remarks}

{pstd}
Derivatives are found by central differences of the solved model. A smooth
objective is flat at its optimum, so the optimum is located to about 1e-6
relative to the instruments' scale. A model that does
not solve at a trial value makes the optimiser step back. An optimum may be
local: try other starting values.


{title:Also see}

{psee}
{helpb cge_shock}, {helpb cge_solve}, {helpb cge_report}, {helpb cge_closure}, {helpb cge}
{p_end}
