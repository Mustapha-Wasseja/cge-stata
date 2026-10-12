{smcl}
{* *! version 0.0.1  12oct2026}{...}
{title:Title}

{p2colset 5 12 14 2}{...}
{p2col:{bf:cge} {hline 2}}Computable general equilibrium modelling in Stata{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge}


{title:Description}

{pstd}
{cmd:cge} displays the version of the {bf:cge-stata} package and lists its
commands. The package builds, calibrates and solves static, single-country
computable general equilibrium (CGE) models from a social accounting matrix
(SAM), using Stata and Mata.

{pstd}
This is a development release. It provides the package information command and
{helpb cge_synthetic}, which loads the synthetic SAM used in tests and examples.
Calibration and solution commands are planned for version 0.1.


{title:Stored results}

{pstd}
{cmd:cge} stores the following in {cmd:r()}:

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(version)}}package version{p_end}


{title:Author}

{pstd}
Mustapha Wasseja{p_end}


{title:Also see}

{psee}
Help: {helpb cge_synthetic}
{p_end}
