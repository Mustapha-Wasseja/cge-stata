{smcl}
{* *! version 0.6.4  26oct2026}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{bf:cge_use} {hline 2}}Load a model saved with cge_save{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_use} {cmd:using} {it:filename}


{title:Description}

{pstd}
{cmd:cge_use} replaces the model in memory with one saved by {helpb cge_save},
including its closure, current shocks and stored simulations. The dataset in
memory is not changed. The extension {cmd:.cgem} is added when the file name has none. Items saved by a
version that the current one no longer uses are ignored, with a note.

{pstd}
Later versions of Stata read files saved in Stata 13. Stata 13 cannot read
files saved in later versions, whose Mata file format differs; {cmd:cge_use}
then stops with a message and leaves the model in memory unchanged.


{title:Example}

{phang2}{cmd:. cge_use using mymodel}{p_end}

{phang2}{cmd:. cge_report, sims(_all)}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(filename)}}file read{p_end}
{synopt:{cmd:r(saved_by)}}version of {bf:cge-stata} that saved the file{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_save}
{p_end}
