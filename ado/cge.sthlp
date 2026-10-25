{smcl}
{* *! version 0.26.0  25oct2026}{...}
{title:Title}

{p2colset 5 12 14 2}{...}
{p2col:{bf:cge} {hline 2}}Computable general equilibrium modelling in Stata{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge}


{title:Description}

{pstd}
{bf:cge-stata} builds, calibrates and solves static, single-country computable
general equilibrium (CGE) models from a social accounting matrix (SAM), entirely
in Stata and Mata. {cmd:cge} displays the package version and its commands.

{pstd}
The model is documented equation by equation in the cge-stata Reference Manual
(docs/manual/cge-stata-manual.pdf in the package repository), which also
describes every command with examples: CES or Cobb-Douglas value added, Leontief intermediate
inputs, CET exports, Armington imports, households with Cobb-Douglas demand,
government, savings-investment and the rest of the world, with selectable
closures. Fiscal instruments (from version 0.3.1) include VAT with
input credits, closures in which a chosen tax replaces lost revenue, and public
debt with interest.


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
{p2col:{helpb cge_gdx}}GAMS data exchange (GDX) files: write, read and list{p_end}
{p2col:{helpb cge_parameters}}calibrated parameters as a dataset{p_end}
{p2col:{helpb cge_save}}save the model and its simulations{p_end}
{p2col:{helpb cge_use}}load a saved model{p_end}
{p2col:{helpb cge_gams}}write the model as a GAMS program; solve it with PATH, CONOPT or IPOPT{p_end}
{p2col:{helpb cge_synthetic}}load the synthetic SAM used in tests and examples{p_end}
{p2colreset}{...}


{title:Example}

{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}
{phang2}{cmd:. cge_shock tm, value(0)}{p_end}
{phang2}{cmd:. cge_solve, name(notariff)}{p_end}
{phang2}{cmd:. cge_results}{p_end}
{phang2}{cmd:. cge_check, homogeneity}{p_end}


{title:Stored results}

{pstd}
{cmd:cge} stores the following in {cmd:r()}:

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(version)}}package version{p_end}


{title:Author}

{pstd}
Mustapha Wasseja{p_end}
