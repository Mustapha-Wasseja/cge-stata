{smcl}
{* *! version 0.1.0  12oct2026}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{bf:cge_sam} {hline 2}}Read a social accounting matrix{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_sam} [{cmd:using} {it:filename}] [{cmd:,} {opt lab:els(varname)} {opt sheet(string)} {opt clear}]


{title:Description}

{pstd}
{cmd:cge_sam} reads a social accounting matrix (SAM) and starts a new model. The
SAM is taken from the data in memory or, with {cmd:using}, from a {cmd:.csv},
{cmd:.dta}, {cmd:.xls} or {cmd:.xlsx} file.

{pstd}
The SAM must be square: one observation per account, a string variable holding
the account labels, and one numeric variable per account, named exactly as the
account labels and in the same order. Cell ({it:r}, {it:c}) is a payment from
column account {it:c} to row account {it:r}. Blank cells are treated as zero and
counted in {cmd:r(N_blank)}.

{pstd}
{cmd:cge_sam} reports the largest difference between an account's row and column
totals. Balance is enforced by {helpb cge_map}.


{title:Options}

{phang}
{opt labels(varname)} names the string variable with the account labels. The
default is the first string variable.

{phang}
{opt sheet(string)} names the Excel worksheet to read.

{phang}
{opt clear} allows the data in memory to be replaced when reading a file.


{title:Examples}

{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_sam using mysam.xlsx, sheet("SAM") labels(account) clear}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N_accounts)}}number of accounts{p_end}
{synopt:{cmd:r(total)}}sum of all cells{p_end}
{synopt:{cmd:r(maxdiff)}}largest row-column imbalance{p_end}
{synopt:{cmd:r(N_blank)}}number of blank cells treated as zero{p_end}
{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(labels)}}label variable{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_map}, {helpb cge_calibrate}
{p_end}
