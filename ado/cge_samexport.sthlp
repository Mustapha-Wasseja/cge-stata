{smcl}
{* *! version 0.3.0  26oct2026}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{bf:cge_samexport} {hline 2}}Write the SAM to a file or to memory{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_samexport} [{cmd:using} {it:filename}] [{cmd:,} {opt long} {opt mapped} {opt clear} {opt sheet(string)} {opt replace}]


{title:Description}

{pstd}
{cmd:cge_samexport} writes the SAM of the current model, as read, aggregated or
balanced, to a {cmd:.csv}, {cmd:.dta}, {cmd:.xls} or {cmd:.xlsx} file, or with
{opt clear} loads it as data (Reference Manual, {it:SAM tools}).

{pstd}
Wide output has a variable {cmd:account} and one variable per account. A
{cmd:.csv} file is written directly and has no limit on the number of
accounts; {cmd:.dta}, Excel and data in memory need the accounts to fit as
variables. Long output has variables {cmd:row}, {cmd:column} and {cmd:value},
one observation per non-zero cell.

{pstd}
Numbers in a CSV file are written with as many digits as needed to read back as
the same values, so a SAM written and read again with {helpb cge_sam} is
unchanged.


{title:Options}

{phang}
{opt long} writes long output.

{phang}
{opt mapped} writes the SAM after the layout rewrites of {helpb cge_map}
(Reference Manual, {it:Calibration}), including internal tax accounts.

{phang}
{opt clear} replaces the data in memory with the SAM. It may be combined with
{cmd:using}.

{phang}
{opt sheet(string)} names the Excel worksheet; the default is {cmd:SAM}.

{phang}
{opt replace} allows an existing file to be replaced.


{title:Examples}

{phang2}{cmd:. cge_balance, method(ce)}{p_end}

{phang2}{cmd:. cge_samexport using balanced_sam.xlsx, replace}{p_end}

{phang2}{cmd:. cge_samexport, clear long}{p_end}


{title:Also see}

{psee}
{helpb cge_sam}, {helpb cge_balance}, {helpb cge_aggregate}
{p_end}
