{smcl}
{* *! version 0.35.0  29oct2026}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{bf:cge_structure} {hline 2}}Structure of the system: structural singularity and blocks{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_structure} [{cmd:,} {opt sim(name)} {opt base} {opt full} {opt top(#)}]


{title:Description}

{pstd}
{cmd:cge_structure} (from version 0.35.0; Reference Manual,
{it:cge_structure}) analyses the structure of the system that
{helpb cge_solve} solves under the closure: which free variables each
equation contains, from the nonzeros of its exact Jacobian at a point. A
maximum matching assigns variables to equations. If it covers every
equation and variable, the system is structurally nonsingular; if not, it
is structurally singular, whatever its values, and the Dulmage-Mendelsohn
decomposition names its parts: the over-determined part, equations that
together contain fewer free variables than they number (one equation too
many, or a variable to free with a swap), and the under-determined part,
variables that the equations cannot all determine (one to fix, or an
equation to add). CONOPT reports such a model as structurally singular.

{pstd}
The square part is then split into blocks that can be solved in turn, each
given the ones before it, as CONOPT finds a model's pre-triangular,
simultaneous and post-triangular parts: the strongly connected components of
the graph of the equations, by Tarjan's algorithm. The report gives their
number, how many have one equation, and the largest blocks.

{pstd}
{helpb cge_solve} with {opt blocks} solves a standalone model block by block,
in this order.

{pstd}
The point is the current point (the default), the base or a stored
simulation. The structure is that of the system solved, the reduced one for
a model from a SAM; with {opt full}, the full system. Use it when
{helpb cge_solve} reports a singular Jacobian after a change of closure or a
user equation, or to see how a standalone model ({helpb cge_model})
decomposes.


{title:Options}

{phang}
{opt sim(name)} analyses the system at simulation {it:name}; {opt base} at
the base. By default, the current point, with the current shocks and closure.

{phang}
{opt full} analyses the full system, with the definitions that the reduced
system leaves out.

{phang}
{opt top(#)} limits the labels and blocks listed; the default is 10.


{title:Examples}

{pstd}Setup{p_end}

{phang2}{cmd:. cge_synthetic, clear}{p_end}

{phang2}{cmd:. cge_sam, labels(account)}{p_end}

{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap)}
{cmd:households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}

{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{pstd}The structure of the system under the default closure{p_end}

{phang2}{cmd:. cge_structure}{p_end}

{pstd}A user variable that no equation determines, and an equation in the numeraire alone: structurally singular{p_end}

{phang2}{cmd:. cge_variable Z, value(1)}{p_end}

{phang2}{cmd:. cge_equation ez: CPI = base(CPI)}{p_end}

{phang2}{cmd:. cge_structure}{p_end}

{phang2}{cmd:. cge_equation, clear}{p_end}


{title:Stored results}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(N_equations)}}equations of the system{p_end}
{synopt:{cmd:r(N_variables)}}free variables{p_end}
{synopt:{cmd:r(rank)}}structural rank, the size of a maximum matching{p_end}
{synopt:{cmd:r(singular)}}1 if the system is structurally singular{p_end}
{synopt:{cmd:r(N_over_eq)}, {cmd:r(N_over_var)}}equations and variables of the over-determined part{p_end}
{synopt:{cmd:r(N_under_eq)}, {cmd:r(N_under_var)}}equations and variables of the under-determined part{p_end}
{synopt:{cmd:r(N_square)}}equations of the square part{p_end}
{synopt:{cmd:r(N_blocks)}}blocks of the square part{p_end}
{synopt:{cmd:r(largest_block)}}equations of the largest block{p_end}
{synopt:{cmd:r(N_singletons)}}blocks of one equation{p_end}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(over_equations)}}equations of the over-determined part{p_end}
{synopt:{cmd:r(over_variables)}}its variables{p_end}
{synopt:{cmd:r(under_equations)}}equations of the under-determined part{p_end}
{synopt:{cmd:r(under_variables)}}its variables{p_end}


{title:Also see}

{psee}
{helpb cge_listing}, {helpb cge_closure}, {helpb cge_solve}, {helpb cge_model}, {helpb cge}
{p_end}
