{smcl}
{* *! version 0.6.4  22oct2026}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{bf:cge_sam} {hline 2}}Read a social accounting matrix{p_end}
{p2colreset}{...}


{title:Syntax}

{pstd}
Wide data: one observation and one variable per account

{p 8 12 2}
{cmd:cge_sam} [{cmd:using} {it:filename}] [{cmd:,} {opt lab:els(varname)} {opt sheet(string)} {opt direct} {opt clear}]

{pstd}
Long data: one observation per cell

{p 8 12 2}
{cmd:cge_sam} [{cmd:using} {it:filename}]{cmd:,} {opt long(rowvar colvar valuevar)} [{opt sheet(string)} {opt clear}]


{title:Description}

{pstd}
{cmd:cge_sam} reads a social accounting matrix (SAM) and starts a new model. The
SAM is taken from the data in memory or, with {cmd:using}, from a {cmd:.csv},
{cmd:.dta}, {cmd:.xls} or {cmd:.xlsx} file (Reference Manual, {it:SAM tools}).
Cell ({it:r}, {it:c}) is a payment from column account {it:c} to row account
{it:r}. Blank cells are treated as zero and counted in {cmd:r(N_blank)}.

{pstd}
{bf:Wide data.} One observation per account, a string variable holding the
account labels, and one numeric variable per account, named exactly as the
account labels and in the same order.

{pstd}
{bf:A wide CSV file read directly.} A SAM can have more accounts than Stata can
hold as variables ({cmd:c(maxvar)}; 2,048 in Stata/IC). Such a CSV file is
parsed directly in Mata, without loading it as data; the option {opt direct}
does the same for any CSV file. The data in memory are not changed. The first
line holds the column labels, the first field of each other line the row label.
Fields may be quoted. A field that is not a number, such as {cmd:1,234} with a
thousands separator, is an error, never a zero.

{pstd}
{bf:Long data.} With {opt long()}, each observation is a cell: string
variables with the row and column accounts and a numeric variable with the
value. The number of accounts is limited only by memory. Accounts are ordered
as they first appear as row accounts, then any that appear only as column
accounts. A cell given twice is an error.

{pstd}
{bf:Labels.} Account labels are used as names in {helpb cge_map}, so they must be
valid Stata names. When Stata imports a wide file, it renames a column whose
label is not a valid name ({cmd:s-i} becomes {cmd:si}), and the variable names
are used. The direct reader and long data apply the same rule: characters
other than letters, digits and the underscore are removed, then any leading
digits, and the result is cut to 32 characters. A label that cannot be
converted, or that gives the same name as another label, is an error. Each
change is displayed.

{pstd}
{cmd:cge_sam} reports the largest difference between an account's row and column
totals. Balance is enforced by {helpb cge_map}; {helpb cge_balance} balances a
SAM.


{title:Options}

{phang}
{opt labels(varname)} names the string variable with the account labels in
wide data. The default is the first string variable.

{phang}
{opt long(rowvar colvar valuevar)} reads long data.

{phang}
{opt direct} reads a wide CSV file directly, as described above.

{phang}
{opt sheet(string)} names the Excel worksheet to read.

{phang}
{opt clear} allows the data in memory to be replaced when reading a file.


{title:Examples}

{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}

{pstd}A SAM of your own, from an Excel sheet, a CSV file, or a dataset of cells{p_end}
{phang2}{cmd:. cge_sam using mysam.xlsx, sheet("SAM") labels(account) clear}{p_end}
{phang2}{cmd:. cge_sam using large_sam.csv}{p_end}
{phang2}{cmd:. cge_sam using sam_cells.dta, long(row column value) clear}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N_accounts)}}number of accounts{p_end}
{synopt:{cmd:r(total)}}sum of all cells{p_end}
{synopt:{cmd:r(maxdiff)}}largest row-column imbalance{p_end}
{synopt:{cmd:r(N_blank)}}number of blank cells treated as zero{p_end}
{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(source)}}{cmd:wide}, {cmd:direct} or {cmd:long}{p_end}
{synopt:{cmd:r(labels)}}label variable (wide data){p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_template}, {helpb cge_aggregate}, {helpb cge_balance},
{helpb cge_samexport}, {helpb cge_map}
{p_end}
