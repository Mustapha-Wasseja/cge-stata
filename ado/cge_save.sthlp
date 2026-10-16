{smcl}
{* *! version 0.1.15  16oct2026}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{bf:cge_save} {hline 2}}Save the model and its simulations to a file{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_save} {cmd:using} {it:filename} [{cmd:,} {opt replace}]


{title:Description}

{pstd}
{cmd:cge_save} writes the model in memory to a file: the SAM, the mapping, the
calibrated parameters, the closure, the current shocks and every stored
simulation. {helpb cge_use} loads it again, so a calibrated model need not be
rebuilt in a later session. A model may be saved at any stage after
{helpb cge_sam}.

{pstd}
The default extension is {cmd:.cgem}. Each item is stored with its name, so a
newer version of {bf:cge-stata} can read files saved by an older one. The
dataset in memory is not saved.


{title:Options}

{phang}
{opt replace} allows an existing file to be overwritten.


{title:Example}

{phang2}{cmd:. cge_save using mymodel, replace}{p_end}
{phang2}{cmd:. cge_use using mymodel}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(filename)}}file written{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_use}
{p_end}
