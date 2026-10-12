{smcl}
{* *! version 0.1.0  12oct2026}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{bf:cge_check} {hline 2}}Run model validation checks{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_check} [{cmd:,} {opt sim(name)} {opt hom:ogeneity} {opt pert:urb(#)} {opt seed(#)}]


{title:Description}

{pstd}
{cmd:cge_check} runs the validation checks of docs/model_spec.md, Section 8, and
reports each as {cmd:[ok]} or {cmd:[fail]} with the value tested:

{p 8 12 2}- SAM balance;{p_end}
{p 8 12 2}- benchmark replication: the base solves every equation;{p_end}
{p 8 12 2}- the closure has as many free variables as equations;{p_end}
{p 8 12 2}- for the selected simulation: the solution residual, Walras's law and the GDP identity;{p_end}
{p 8 12 2}- with {opt homogeneity}: doubling every fixed nominal value doubles all prices and nominal values and leaves quantities unchanged;{p_end}
{p 8 12 2}- with {opt perturb()}: the solver returns to the base from perturbed starting values.{p_end}

{pstd}
{cmd:cge_check} exits with error 9 if any check fails.


{title:Options}

{phang}
{opt sim(name)} selects the simulation; the default is the most recent one.

{phang}
{opt homogeneity} adds the homogeneity check.

{phang}
{opt perturb(#)} adds the perturbed-start check, with starting values drawn
uniformly within plus or minus {it:#} times the base (for example 0.1).

{phang}
{opt seed(#)} sets the random-number seed for {opt perturb()}; the default is
12345.


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(failures)}}number of failed checks{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_solve}, {helpb cge_results}
{p_end}
