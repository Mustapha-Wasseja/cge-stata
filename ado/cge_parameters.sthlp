{smcl}
{* *! version 0.1.15  16oct2026}{...}
{title:Title}

{p2colset 5 23 25 2}{...}
{p2col:{bf:cge_parameters} {hline 2}}The calibrated parameters as a dataset{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_parameters}{cmd:,} {opt clear} [{opt sim(name)} {opt cur:rent}]


{title:Description}

{pstd}
{cmd:cge_parameters} replaces the data in memory with the model's parameters,
one observation per parameter element, with the variables {cmd:parameter},
{cmd:element1}, {cmd:element2} and {cmd:value}. Parameter names are those
of the Reference Manual ({it:Notation and the social accounting matrix}), as they are named in the Mata library: for
example {cmd:ica} (intermediate input coefficients), {cmd:dva} and {cmd:ad}
(value-added shares and efficiency), {cmd:beta} and {cmd:gamma} (household
demand), {cmd:shif} (factor income shares) and {cmd:tm}, {cmd:te}, {cmd:tq},
{cmd:ta} (tax rates). Use it to inspect or document a calibration.


{title:Options}

{phang}
{opt clear} is required: the data in memory are replaced.

{phang}
{opt sim(name)} gives the parameters of a stored simulation, including its
shocks. By default the base (calibrated) parameters are given.

{phang}
{opt current} gives the current parameters, including shocks set with
{helpb cge_shock} since the last solve.


{title:Example}

{phang2}{cmd:. cge_parameters, clear}{p_end}
{phang2}{cmd:. list if parameter == "tm"}{p_end}


{title:Stored results}

{synoptset 12 tabbed}{...}
{p2col 5 12 16 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of parameter elements{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_report}, {helpb cge_calibrate}
{p_end}
