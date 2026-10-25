{smcl}
{* *! version 0.18.0  25oct2026}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{bf:cge_bound} {hline 2}}Attributes of variables: bounds, scales, starting levels and fixed values{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_bound} {it:VAR}[{cmd:(}{it:e}[{cmd:,}{it:e2}]{cmd:)}] [{cmd:,} {opt el:ements(list)}
{opt lo:wer(#)} {opt up:per(#)} {opt sc:ale(#)} {opt lev:el(#)} {opt rel:ative}]

{p 8 12 2}
{cmd:cge_bound} {it:VAR}[{cmd:(}{it:e}[{cmd:,}{it:e2}]{cmd:)}]{cmd:,} {opt fix(#)} [{opt el:ements(list)} {opt rel:ative}]

{p 8 12 2}
{cmd:cge_bound} {it:VAR}[{cmd:(}{it:e}[{cmd:,}{it:e2}]{cmd:)}]{cmd:,} {opt int:eger}|{opt bin:ary}|{opt cont:inuous} [{opt el:ements(list)}]

{p 8 12 2}
{cmd:cge_bound} {it:VAR}{cmd:, clear}

{p 8 12 2}
{cmd:cge_bound} {cmd:,} {opt list}

{p 8 12 2}
{cmd:cge_bound} {cmd:,} {opt clear}

{pstd}
{it:VAR} is a model variable, such as {cmd:QM}, or a user variable
({helpb cge_variable}). Without elements, the attributes apply to every
element that exists; one element is written as in GAMS,
{cmd:PQ(com_man)} or {cmd:QF(lab,act_agr)}, and several with
{opt elements()}, as in {helpb cge_shock}: {cmd:elements(com_agr com_man)} or,
for two indexes, {cmd:elements(lab.act_agr cap.act_man)}.


{title:Description}

{pstd}
{cmd:cge_bound} (from version 0.9.8; Reference Manual, {it:cge_bound}) gives
the elements of a variable the attributes that GAMS writes as {cmd:.lo},
{cmd:.up}, {cmd:.scale}, {cmd:.l} and {cmd:.fx}:

{p2colset 9 26 28 2}{...}
{p2col:{opt lower(#)}, {opt upper(#)}}bounds that keep the solver within a domain, as {cmd:VAR.lo} and {cmd:VAR.up}{p_end}
{p2col:{opt scale(#)}}the scale of the variable in the solver, as {cmd:VAR.scale} with {cmd:scaleopt}{p_end}
{p2col:{opt level(#)}}the level from which {helpb cge_solve} starts, as {cmd:VAR.l} before a solve{p_end}
{p2col:{opt fix(#)}}the value of a variable fixed under the closure, as {cmd:VAR.fx}{p_end}
{p2colreset}{...}

{pstd}
The bounds are those of a square system, GAMS's CNS model: they keep the
iterations within a domain, such as positive prices or imports above a
floor, and are not meant to bind at the solution. The solver rejects every
point outside them. A solution that lies on a bound is accepted with a note,
as GAMS warns of an active bound in a CNS model; a solution beyond one
cannot be reached, and the solve fails, naming the bounds nearest the last
point. A limit that binds in some scenarios and not in others is a
constraint, with a variable that adjusts when it binds: {helpb cge_constraint},
an inequality of {helpb cge_equation}, or {opt lower()} and {opt upper()} of
{helpb cge_variable}.

{pstd}
A scale replaces the solver's own, the absolute base value or 1, for the
elements given; it changes the path of the iterations, not the solution. A
starting level replaces the base value of a free variable at the start of
{helpb cge_solve} and, from version 0.14.0, of a variable that may move from a
bound: one that adjusts for a constraint, or an exogenous user variable at a
bound that a paired inequality may move, as GAMS's {cmd:.l} of a positive
variable; its fixed level stays the bound. {opt fix()} sets a variable that the closure fixes, as
{helpb cge_shock} does; a variable the closure leaves free cannot be fixed,
since the system would have more equations than free variables: swap it into
the closure with {cmd:cge_closure, swap()} first.

{pstd}
Definitions apply in order, later ones replacing earlier ones for the same
elements; {cmd:-inf} and {cmd:inf} remove a lower or upper bound. With
{opt relative}, the values are multiples of the base values (of the automatic
scales for {opt scale()}). The base must lie within the bounds, and so must
the starting levels. The attributes are saved with the model and applied
again when it is calibrated again, from the new base; those of user variables
go with them. {helpb cge_gams} writes them into the GAMS program, in
{cmd:cge_bounds.inc}; a scenario solved as a mixed complementarity problem
keeps the scales and levels and leaves out the bounds, since GAMS's MCP
models bound only variables paired with an equation.

{pstd}
{cmd:cge_listing, solution} lists the variables with their bounds, levels and
the marginals of the constraints, as GAMS's solution listing does.


{title:Options}

{phang}
{opt elements(list)} names the elements; it may not be combined with an element in parentheses.

{phang}
{opt lower(#)} and {opt upper(#)} give the bounds: a number, or {cmd:-inf} and
{cmd:inf} to remove one.

{phang}
{opt scale(#)} gives the scale, a positive number.

{phang}
{opt level(#)} gives the starting level of a free variable.

{phang}
{opt fix(#)} gives the value of a variable fixed under the closure; it is given alone.

{phang}
{opt relative} reads the values as multiples of the base values.

{phang}
{opt integer}, {opt binary} and {opt continuous} (from version 0.18.0) set the
type of the elements of a variable of a standalone model, as GAMS's
{cmd:integer variable} and {cmd:binary variable}; {opt binary} also sets the
bounds 0 and 1, and {opt continuous} makes elements continuous again. Each is
given alone. A nonlinear programme with integer or binary elements
({helpb cge_solve}, {opt minimize()} or {opt maximize()}) is solved by branch
and bound.

{phang}
{opt clear}, after a variable, removes its attributes, its type included;
{cmd:cge_bound, clear} removes every attribute. {opt list} displays the
definitions.


{title:Examples}

{pstd}Setup: the SYNTHETIC SAM, mapped and calibrated{p_end}
{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{pstd}Imports within half and twice their base, a floor on the price of manufactures, a scale and a starting level{p_end}
{phang2}{cmd:. cge_bound QM, lower(0.5) upper(2) relative}{p_end}
{phang2}{cmd:. cge_bound PQ(com_man), lower(0.5)}{p_end}
{phang2}{cmd:. cge_bound QA(act_man), scale(1000)}{p_end}
{phang2}{cmd:. cge_bound EXR, level(1.05)}{p_end}
{phang2}{cmd:. cge_bound, list}{p_end}

{pstd}The tariffs removed; the solution and its listing{p_end}
{phang2}{cmd:. cge_shock tm, value(0)}{p_end}
{phang2}{cmd:. cge_solve, name(notariff)}{p_end}
{phang2}{cmd:. cge_listing, sim(notariff) solution}{p_end}

{pstd}Foreign savings fixed 20 per cent above the base, as {cmd:FSAV.fx}{p_end}
{phang2}{cmd:. cge_bound FSAV, fix(1.2) relative}{p_end}
{phang2}{cmd:. cge_solve, name(fsav)}{p_end}

{pstd}The attributes removed{p_end}
{phang2}{cmd:. cge_bound, clear}{p_end}


{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_elements)}}elements given the attributes{p_end}
{synopt:{cmd:r(N_definitions)}}definitions stored{p_end}
{synopt:{cmd:r(N_lower)}}elements with a lower bound{p_end}
{synopt:{cmd:r(N_upper)}}elements with an upper bound{p_end}
{synopt:{cmd:r(N_scales)}}elements with a scale{p_end}
{synopt:{cmd:r(N_levels)}}elements with a starting level{p_end}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(name)}}the variable{p_end}

{pstd}
{helpb cge_solve} stores {cmd:r(N_atbound)}, the free elements at a bound.


{title:Also see}

{psee}
{helpb cge_listing}, {helpb cge_constraint}, {helpb cge_closure}, {helpb cge_shock}, {helpb cge_solve}, {helpb cge_gams}, {helpb cge}
{p_end}
