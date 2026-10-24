{smcl}
{* *! version 0.9.8  24oct2026}{...}
{title:Title}

{p2colset 5 21 23 2}{...}
{p2col:{bf:cge_optimize} {hline 2}}Choose policy instruments to maximise an outcome or reach targets{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_optimize}{cmd:,} {opt inst:ruments(list)}
{opt max:imize(objective)}|{opt min:imize(objective)}|{opt targ:ets(spec)}
[{opt targ:ets(spec)} {opt cons:traints(spec)} {opt low:er(spec)} {opt up:per(spec)} {opt name(name)}
{opt tol:erance(#)} {opt iter:ate(#)} {opt trace}]

{p 4 4 2}
A {it:measure} is a measure of {helpb cge_report}: {it:table measure}
[{it:element}], for example {cmd:welfare equivalent_variation hhd} or
{cmd:macro gdp_real}. From version 0.9.4, an objective, a target or a
constraint may also be an expression of the user language of
{helpb cge_equation}, such as {cmd:YG - EG} or {cmd:sum(c, PQ(c) * QG(c))},
evaluated at the solution of each trial; the right side of a target or a
constraint is a number or such an expression.


{title:Description}

{pstd}
{cmd:cge_optimize} (from version 0.6.0; Reference Manual, {it:Policy optimisation})
chooses the values of a few instruments to maximise or minimise a report
measure, or to reach targets for report measures. It solves the model at
every trial value, starting from the solution of the trial before, inside a
projected Newton optimiser, as one would with an NLP solver such as CONOPT. It
is meant for a few instruments: a tax rate, the volume of a public service, a
transfer.

{pstd}
An instrument is one element of a parameter that {helpb cge_shock} changes,
written as {it:parameter}{cmd:(}{it:element}{cmd:)}, such as {cmd:tm(com_man)}
or {cmd:qg(com_hlt)}, a scalar parameter such as {cmd:trgr}, one element of a
user parameter ({helpb cge_parameter}, from version 0.7.1), such as {cmd:w(com_agr)}
or {cmd:sh(com_hlt,hhd)}, or one element of a variable that the closure fixes,
such as {cmd:GADJ} or {cmd:QFS(lab)}. The
optimisation starts from the instruments' current values, with any shocks
already applied, under the current closure.

{pstd}
With {opt targets()} alone there must be one target for each instrument, and
the targets are solved for by Newton's method. With an objective, targets are
equality constraints, met by the augmented Lagrangian method. The optimum is
stored as a simulation, and the instruments are left at their optimal values
as current shocks, so that {helpb cge_report} and {helpb cge_results} show
it.

{pstd}
From version 0.9.8, an optimisation with an objective reports marginals, as
the solution listing of GAMS's NLP models does. The marginal of a target or a
constraint is its shadow price: the change in the objective per unit increase
in its right side, from the multipliers of the augmented Lagrangian at the
optimum. It is zero for a constraint that does not bind; for a constraint
{it:h} {cmd:>=} {it:b} that binds in a maximisation it is negative, since
raising {it:b} tightens it. The marginal of an instrument is its reduced cost:
the change in the objective per unit of the instrument, zero within its
bounds and, at a bound, the gain from relaxing it. Targets alone, without an
objective, have no marginals.


{title:Options}

{phang}
{opt instruments(list)} lists the instruments, separated by spaces.

{phang}
{opt maximize(objective)} or {opt minimize(objective)} gives the objective: a
report measure or an expression.

{phang}
{opt targets(spec)} gives targets, separated by commas, as {it:table measure}
[{it:element}] {cmd:=} {it:value}, for example
{cmd:targets(government savings = 3, macro investment_real = 50)}, or with
expressions on either side, as {cmd:targets(sum(c, PQ(c) * QG(c)) = 50)}.

{phang}
{opt constraints(spec)} (from version 0.9.4) gives inequality constraints,
separated by commas, as a measure or an expression {cmd:<=} or {cmd:>=} a
value or an expression, for example
{cmd:constraints(QM(com_man) >= 0.98 * base(QM(com_man)), government tax_import <= 9)}.
They need an objective, and are met by the augmented Lagrangian method, with
the targets; the display marks those that bind.

{phang}
{opt lower(spec)} and {opt upper(spec)} give bounds as
{it:instrument}{cmd::}{it:value} pairs, for example
{cmd:lower(tm(com_man):0) upper(tm(com_man):0.2)}. An instrument's current
value must lie strictly within its bounds.

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

{pstd}The tariff that maximises government revenue while imports of manufactures stay within 2 per cent of the base, with the objective and the constraint written as expressions (from version 0.9.4){p_end}
{phang2}{cmd:. cge_shock, reset}{p_end}
{phang2}{cmd:. cge_optimize, instruments(tm(com_man)) maximize(YG) constraints(QM(com_man) >= 0.98 * base(QM(com_man))) lower(tm(com_man):0) upper(tm(com_man):2) name(revenue)}{p_end}

{pstd}Its shadow price: the revenue lost per unit increase in the floor on imports (from version 0.9.8){p_end}
{phang2}{cmd:. matrix list r(constraint_marginals)}{p_end}


{title:Stored results}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(converged)}}1 if the optimisation converged{p_end}
{synopt:{cmd:r(objective)}}the objective at the optimum{p_end}
{synopt:{cmd:r(N_evaluations)}}solves of the model{p_end}
{synopt:{cmd:r(N_failed)}}trial values at which the model did not solve{p_end}
{synopt:{cmd:r(iterations)}}iterations of the optimiser{p_end}
{synopt:{cmd:r(N_binding)}}constraints that bind at the optimum, with constraints{p_end}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(name)}}the simulation that holds the optimum{p_end}
{synopt:{cmd:r(instruments_list)}}the instruments{p_end}
{p2col 5 22 26 2: Matrices}{p_end}
{synopt:{cmd:r(instruments)}}the instruments at the optimum{p_end}
{synopt:{cmd:r(start)}}their starting values{p_end}
{synopt:{cmd:r(targets)}}the target measures or expressions at the optimum{p_end}
{synopt:{cmd:r(constraints)}}the constrained measures or expressions at the optimum{p_end}
{synopt:{cmd:r(instrument_marginals)}}the reduced costs of the instruments, with an objective (from version 0.9.8){p_end}
{synopt:{cmd:r(target_marginals)}}the shadow prices of the targets, with an objective{p_end}
{synopt:{cmd:r(constraint_marginals)}}the shadow prices of the constraints{p_end}


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
