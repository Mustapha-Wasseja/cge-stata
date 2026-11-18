{smcl}
{* *! version 0.51.0  18nov2026}{...}
{title:Title}

{p2colset 5 12 14 2}{...}
{p2col:{bf:cge} {hline 2}}Computable general equilibrium modelling in Stata{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge}


{title:Description}

{pstd}
{bf:cge-stata} builds, calibrates and solves computable general equilibrium
(CGE) models in Stata. The built-in model uses a social accounting matrix (SAM)
and supports static simulations, recursive dynamics and perfect-foresight runs
with user-specified forward-looking equations ({helpb cge_dynamic}). Calibrated
single-country models can be linked through bilateral trade to form a
multi-region model ({helpb cge_region}). {cmd:cge} displays the package version
and its commands.

{pstd}
The standard model includes CES or Cobb-Douglas value added, Leontief
intermediate inputs, CET exports, Armington imports, and households with
Cobb-Douglas or linear expenditure system (LES) demand. Enterprises, government,
savings-investment and the rest of the world are linked by income and transfer
flows. Selectable closures and extensions cover taxes and VAT with input
credits, public debt, labour-market regimes, health financing and outcomes,
and binding limits such as quotas, capacity and borrowing ceilings.

{pstd}
Users can extend the built-in model or write a standalone model without a SAM,
using sets, parameters, variables, equations and nested CES or CET blocks
({helpb cge_model}, {helpb cge_equation}, {helpb cge_nest}), or in the form of
MPSGE ({helpb cge_mpsge}). The package solves
equilibrium and complementarity systems and nonlinear optimisation problems,
including models with integer or binary variables. It also supports policy
optimisation ({helpb cge_optimize}), Nash and Stackelberg games
({helpb cge_nash}), and a library of ready-to-run examples ({helpb cge_modlib}).

{pstd}
The workflow includes SAM preparation and balancing, multiplier and structural
path analysis, scenario loops, validation checks, sensitivity analysis and
reporting. A link to household survey data measures poverty, inequality,
welfare and fiscal incidence ({helpb cge_microsim}).

{pstd}
The built-in solvers run in Stata and Mata on Stata 13 or later. Optional,
experimental links to SciPy's SuperLU and HiGHS require Stata 16 or later with
Python and SciPy ({helpb cge_options}, {helpb cge_solve}). GAMS export and GDX
data exchange are also available ({helpb cge_gams}, {helpb cge_gdx}); solving an
exported model in GAMS requires GAMS and the selected solver.

{pstd}
Large models are built and solved in time that grows with their size. A set
of 20,000 labels is read in about three seconds, and the variables,
parameters and equations over it are built in seconds ({helpb cge_set}, from
version 0.49.1). Systems of 1,000 equations or more with a sparse Jacobian
are solved with a sparse LU by default (from version 0.50.0), which takes
the columns with one entry first and leaves the rows that fill in to Mata's
dense LU (from version 0.50.1); it factorises and solves by levels, the rows
that do not depend on one another together (from version 0.51.0). Smaller or
denser systems use the dense LU
({helpb cge_options}).

{pstd}
The {browse "https://github.com/Mustapha-Wasseja/cge-stata/blob/main/docs/manual/cge-stata-manual.pdf":cge-stata Reference Manual}
documents the model equation by equation and describes every command with
examples. Its repository path is {cmd:docs/manual/cge-stata-manual.pdf}.


{title:Preparing a SAM}

{p2colset 5 22 24 2}{...}
{p2col:{helpb cge_sam}}read a SAM of any size, wide or long{p_end}
{p2col:{helpb cge_template}}write a template for roles and aggregation, in Excel or CSV{p_end}
{p2col:{helpb cge_aggregate}}merge accounts into groups{p_end}
{p2col:{helpb cge_balance}}balance the SAM by RAS or cross entropy{p_end}
{p2col:{helpb cge_samexport}}write the SAM to a file or to memory{p_end}
{p2col:{helpb cge_multiplier}}SAM multipliers and their decomposition{p_end}
{p2col:{helpb cge_spa}}structural paths of a SAM multiplier{p_end}
{p2colreset}{...}


{title:Workflow}

{p2colset 5 22 24 2}{...}
{p2col:{helpb cge_map}}assign SAM accounts to model roles, with options or from a template{p_end}
{p2col:{helpb cge_calibrate}}calibrate the model and check benchmark replication{p_end}
{p2col:{helpb cge_elasticities}}published elasticities, with sources, as calibration options{p_end}
{p2col:{helpb cge_closure}}choose the closure{p_end}
{p2col:{helpb cge_shock}}change parameters or fixed variables{p_end}
{p2col:{helpb cge_constraint}}limits that may bind: quotas, capacity, borrowing and deficit ceilings{p_end}
{p2col:{helpb cge_bound}}attributes of variables: bounds, scales, starting levels and fixed values{p_end}
{p2col:{helpb cge_variable}}user variables, defined by an expression or by user equations{p_end}
{p2col:{helpb cge_equation}}user equations: new relations among the model's variables{p_end}
{p2col:{helpb cge_set}}user sets of elements, for indexes and sums{p_end}
{p2col:{helpb cge_parameter}}user parameters: values, assignments and data{p_end}
{p2col:{helpb cge_macro}}macros of the language of user variables and equations{p_end}
{p2col:{helpb cge_nest}}declare a nested CES or CET block, as MPSGE's production blocks{p_end}
{p2col:{helpb cge_mpsge}}a model in the form of MPSGE: sectors, commodities, consumers and their blocks{p_end}
{p2col:{helpb cge_model}}a standalone model, written whole in the user language; model statistics{p_end}
{p2col:{helpb cge_modlib}}a library of ready-to-run models in the user language{p_end}
{p2col:{helpb cge_solve}}solve and store a simulation{p_end}
{p2col:{helpb cge_options}}settings of the solver: LU, limits, Jacobian{p_end}
{p2col:{helpb cge_optimize}}choose instruments to maximise an outcome or reach targets{p_end}
{p2col:{helpb cge_nash}}Nash equilibria of players who choose instruments, and leaders{p_end}
{p2col:{helpb cge_loop}}solve the model for a list or grid of scenarios{p_end}
{p2col:{helpb cge_dynamic}}solve a dynamic run, recursive or with perfect foresight{p_end}
{p2col:{helpb cge_region}}link single-country models through bilateral trade{p_end}
{p2col:{helpb cge_results}}display or save all results of a simulation{p_end}
{p2col:{helpb cge_report}}standard report tables, to screen, Stata or Excel{p_end}
{p2col:{helpb cge_dynresults}}results of a dynamic run, against a baseline{p_end}
{p2col:{helpb cge_sensitivity}}sensitivity of a scenario to the elasticities{p_end}
{p2col:{helpb cge_microsim}}pass simulations to household survey data: poverty, inequality and incidence{p_end}
{p2col:{helpb cge_check}}run validation checks{p_end}
{p2col:{helpb cge_listing}}equation listing and infeasibility report{p_end}
{p2col:{helpb cge_structure}}structure of the system: structural singularity and blocks{p_end}
{p2col:{helpb cge_iis}}irreducible infeasible set of bounds and constraints{p_end}
{p2col:{helpb cge_gdx}}GAMS data exchange (GDX) files: write, read and list{p_end}
{p2col:{helpb cge_parameters}}calibrated parameters as a dataset{p_end}
{p2col:{helpb cge_save}}save the model and its simulations{p_end}
{p2col:{helpb cge_use}}load a saved model{p_end}
{p2col:{helpb cge_gams}}write the model as a GAMS program; solve it with PATH, CONOPT or IPOPT{p_end}
{p2col:{helpb cge_synthetic}}load the synthetic SAM used in tests and examples{p_end}
{p2colreset}{...}


{title:Examples}

{pstd}The synthetic SAM of {helpb cge_synthetic}{p_end}

{phang2}{cmd:. cge_synthetic, clear}{p_end}

{phang2}{cmd:. cge_sam, labels(account)}{p_end}

{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd)}
{cmd:government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}

{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{phang2}{cmd:. cge_shock tm, value(0)}{p_end}

{phang2}{cmd:. cge_solve, name(notariff)}{p_end}

{phang2}{cmd:. cge_results}{p_end}

{phang2}{cmd:. cge_check, homogeneity}{p_end}

{pstd}
A real SAM: IFPRI's 2019 SAM for Malawi, shipped with the package
({helpb cge_sam##data:cge_sam}, {it:Example data}). {cmd:cge_sam} reads the file as
published; the activities and commodities are the accounts whose codes begin
with {cmd:a} and {cmd:c}, paired in the same order:{p_end}

{phang2}{cmd:. cge_sam using cge_malawi_sam.csv, clear}{p_end}

{phang2}{cmd:. quietly levelsof Code if substr(Code, 1, 1) == "a", local(acts) clean}{p_end}

{phang2}{cmd:. quietly levelsof Code if substr(Code, 1, 1) == "c", local(coms) clean}{p_end}

{pstd}
Mapped with every account in the role the SAM gives it, the SAM has three
flows the model does not represent, which {helpb cge_map} lists before it
stops: enterprises' purchases of commodities (962 billion kwacha) and
households' and enterprises' payments to the government besides direct taxes
(37):{p_end}

{phang2}{cmd:. cge_map, activities(`acts') commodities(`coms') factors(flabn flabp flabs flnd fcap) households(hhdr1 hhdr2 hhdr3 hhdr4 hhdr5 hhdu1 hhdu2 hhdu3 hhdu4 hhdu5)}
{cmd:enterprises(ent) government(gov) savinv(si) row(row) dirtax(dtax) saltax(stax) imptax(mtax) marginaccounts(trc)}{p_end}

{pstd}
Two choices of this example, made on the model's copy of the SAM and not on
the file: the direct-tax account is merged into the government, so that
{cmd:dirtax(gov)} counts all those payments as direct taxes, and the enterprise
account is mapped as an institution that consumes, among the households. The
SAM balances to the rounding of its cells, which {helpb cge_balance} removes:{p_end}

{phang2}{cmd:. cge_aggregate, groups(gov: gov dtax) netdiagonal}{p_end}

{phang2}{cmd:. cge_balance}{p_end}

{phang2}{cmd:. cge_map, activities(`acts') commodities(`coms') factors(flabn flabp flabs flnd fcap) households(hhdr1 hhdr2 hhdr3 hhdr4 hhdr5 hhdu1 hhdu2 hhdu3 hhdu4 hhdu5 ent)}
{cmd:government(gov) savinv(si) row(row) dirtax(gov) saltax(stax) imptax(mtax) marginaccounts(trc)}{p_end}

{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{phang2}{cmd:. cge_shock tm, value(0)}{p_end}

{phang2}{cmd:. cge_solve, name(notariff)}{p_end}

{phang2}{cmd:. cge_shock, reset}{p_end}

{phang2}{cmd:. cge_shock ad, elements(amaiz) scale(1.1)}{p_end}

{phang2}{cmd:. cge_solve, name(maize)}{p_end}

{phang2}{cmd:. cge_report, sims(notariff maize) tables(macro welfare)}{p_end}

{pstd}
The elasticities are round values for illustration, not estimates for Malawi,
and the results show the commands; they are not findings about Malawi. The same
steps, with comments, are {cmd:examples/malawi_sam.do} in the package's
repository.


{title:Stored results}

{pstd}
{cmd:cge} stores the following in {cmd:r()}:

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(version)}}package version{p_end}


{title:Author}

{pstd}
Mustapha Wasseja Mohammed{p_end}
