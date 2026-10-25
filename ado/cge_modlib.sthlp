{smcl}
{* *! version 0.21.0  25oct2026}{...}
{title:Title}

{p2colset 5 19 21 2}{...}
{p2col:{bf:cge_modlib} {hline 2}}A library of ready-to-run models in the user language{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_modlib} [{cmd:list}]

{p 8 12 2}
{cmd:cge_modlib describe} {it:model}

{p 8 12 2}
{cmd:cge_modlib run} {it:model}

{p 8 12 2}
{cmd:cge_modlib copy} {it:model} [{cmd:,} {opt replace}]


{title:Description}

{pstd}
{cmd:cge_modlib} (from version 0.21.0; Reference Manual, {it:cge_modlib})
lists, describes, runs and copies the models of the package's library, as
GAMS's model library does: small, complete standalone models written in the
user language ({helpb cge_model}), each with its reference and the result it
reproduces, which also serve as templates. {cmd:cge_modlib copy} puts a
model's do-file, {cmd:cge_ml_}{it:model}{cmd:.do}, in the current folder.

{p2colset 9 21 23 2}{...}
{p2col:{cmd:exchange}}an exchange economy of two goods and two consumers{p_end}
{p2col:{cmd:crusoe}}Robinson Crusoe's labour and leisure, a nonlinear programme{p_end}
{p2col:{cmd:markets}}two markets solved block by block with named models{p_end}
{p2col:{cmd:hs071}}Hock and Schittkowski's problem 71{p_end}
{p2col:{cmd:transport}}Dantzig's transportation problem, a linear programme{p_end}
{p2col:{cmd:ras}}a matrix balanced by cross entropy, the RAS solution{p_end}
{p2col:{cmd:knapsack}}eight binary choices, a mixed-integer programme{p_end}
{p2col:{cmd:cournot}}Cournot duopoly and a Stackelberg leader ({helpb cge_nash}){p_end}
{p2colreset}{...}


{title:Examples}

{phang2}{cmd:. cge_modlib list}{p_end}
{phang2}{cmd:. cge_modlib describe transport}{p_end}
{phang2}{cmd:. cge_modlib run transport}{p_end}


{title:Stored results}

{pstd}
{cmd:cge_modlib list} stores {cmd:r(models)} and {cmd:r(N_models)};
{cmd:cge_modlib describe} stores {cmd:r(title)}, {cmd:r(kind)} and
{cmd:r(expect)}.


{title:Also see}

{psee}
{helpb cge_model}, {helpb cge_solve}, {helpb cge}
{p_end}
