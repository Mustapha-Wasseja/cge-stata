{smcl}
{* *! version 0.51.0  18nov2026}{...}
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

{p 8 12 2}
{cmd:cge_sam} {cmd:using} {it:filename}{cmd:.gdx}{cmd:,} {opt sym:bol(name)} {opt clear} [{opt norun} {opt gams(path)}]


{title:Description}

{pstd}
{cmd:cge_sam} reads a social accounting matrix (SAM) and starts a new model. The
SAM is taken from the data in memory or, with {cmd:using}, from a {cmd:.csv},
{cmd:.dta}, {cmd:.xls} or {cmd:.xlsx} file (Reference Manual, {it:SAM tools}).
Cell ({it:r}, {it:c}) is a payment from column account {it:c} to row account
{it:r}. Blank cells are treated as zero and counted in {cmd:r(N_blank)}.

{pstd}
{bf:A real SAM to work with.} The package ships IFPRI's 2019 SAM for Malawi,
{cmd:cge_malawi_sam.csv}, as published (see {help cge_sam##data:Example data} below). When the
working directory has no file of that name, {cmd:cge_sam using cge_malawi_sam.csv}
reads the copy shipped with the package, and {cmd:r(filename)} gives its path.
The examples below read it in each form, and {cmd:examples/malawi_sam.do} in the
package's repository takes it to the results of policy simulations.

{pstd}
{bf:SAMs as published} (from version 0.51.0). A SAM file often has a column
of descriptions besides the codes of the accounts, and a total row and a total
column. String variables other than the labels hold text and are left out; a
row labelled {cmd:total} or {cmd:totals}, in any case, and a column so named are
checked against the sums of the cells, within 1e-4 of the largest total, and
left out. A row or column so labelled that is not the sum of the cells is an
error. The direct reader treats the leading fields of the first row that are
text, neither numbers nor blank, as columns of labels in the same way.

{pstd}
{bf:Wide data.} One observation per account, a string variable holding the
account labels, and one numeric variable per account, named exactly as the
account labels and in the same order. Other string variables, such as
descriptions of the accounts, are left out.

{pstd}
{bf:A wide CSV file read directly.} A SAM can have more accounts than Stata can
hold as variables ({cmd:c(maxvar)}; 2,048 in Stata/IC). Such a CSV file is
parsed directly in Mata, without loading it as data; the option {opt direct}
does the same for any CSV file. The data in memory are not changed. The first
line holds the column labels, the first field of each other line the row label
(or, after columns of descriptions, the field of the column of codes). Fields
may be quoted. A field that is not a number, such as {cmd:1,234} with a
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
wide data or, with the direct reader, the heading of the column of labels.
By default, of several string variables (columns of text), the labels are the
one whose values are the names of the account variables (columns), as the
codes of a SAM published with descriptions are; otherwise the first.

{phang}
{opt long(rowvar colvar valuevar)} reads long data.

{phang}
{opt symbol(name)} (from version 0.10.0) reads the SAM from a GDX file, the
parameter with two indexes {it:name} ({cmd:SAM} by default), through
{helpb cge_gdx}; {opt norun} and {opt gams()} are those of {cmd:cge_gdx}.

{phang}
{opt direct} reads a wide CSV file directly, as described above.

{phang}
{opt sheet(string)} names the Excel worksheet to read.

{phang}
{opt clear} allows the data in memory to be replaced when reading a file.


{title:Examples}

{pstd}IFPRI's 2019 SAM for Malawi, shipped with the package and read as published:
the codes are the labels, the descriptions are left out, and the total row and
column are checked and left out{p_end}

{phang2}{cmd:. cge_sam using cge_malawi_sam.csv, clear}{p_end}

{pstd}The same file read directly, leaving the data in memory unchanged{p_end}

{phang2}{cmd:. cge_sam using cge_malawi_sam.csv, direct}{p_end}

{pstd}A copy of the file in the working directory, to open in Excel or edit{p_end}

{phang2}{cmd:. cge_sam using cge_malawi_sam.csv, clear}{p_end}

{phang2}{cmd:. copy "`r(filename)'" malawi_sam.csv, replace}{p_end}

{phang2}{cmd:. cge_sam using malawi_sam.csv, clear}{p_end}

{pstd}An Excel worksheet and a dataset of cells, written by {helpb cge_samexport} and read back{p_end}

{phang2}{cmd:. cge_samexport using malawi_sam.xlsx, replace}{p_end}

{phang2}{cmd:. cge_sam using malawi_sam.xlsx, sheet("SAM") labels(account) clear}{p_end}

{phang2}{cmd:. cge_samexport using malawi_cells.dta, long replace}{p_end}

{phang2}{cmd:. cge_sam using malawi_cells.dta, long(row column value) clear}{p_end}

{pstd}The SAM in memory: the synthetic SAM of {helpb cge_synthetic}{p_end}

{phang2}{cmd:. cge_synthetic, clear}{p_end}

{phang2}{cmd:. cge_sam, labels(account)}{p_end}

{pstd}A SAM in a GDX file, which needs GAMS; the examples of {helpb cge_gdx} write {cmd:model.gdx}{p_end}

{phang2}{cmd:. cge_sam using model.gdx, symbol(SAM) clear gams(C:/GAMS/54/gams.exe)}{p_end}

{pstd}The whole workflow on the Malawi SAM, from mapping to simulations, is the example of {helpb cge}.{p_end}


{marker data}{...}
{title:Example data}

{pstd}
{cmd:cge_malawi_sam.csv} is the 2019 Social Accounting Matrix for Malawi of
the International Food Policy Research Institute (IFPRI), from its Nexus
project, as published: 107 accounts in billions of Malawian kwacha. They are
42 activities and 42 commodities, a transaction-cost account for margins,
labour of three levels of education, agricultural land, capital, enterprises,
ten households by rural and urban area and expenditure quintile, government,
direct, import and sales taxes, savings-investment and the rest of the world.
The first column describes the accounts, the second holds their codes, and
the last row and column are totals. The SAM balances to the rounding of its
cells (5e-6); {helpb cge_balance} removes the difference before calibration.

{pstd}
Source: International Food Policy Research Institute (IFPRI). 2023. 2019
Social Accounting Matrix for Malawi. Washington, DC: IFPRI [dataset].
{browse "https://doi.org/10.7910/DVN/C9WA0I"}. Harvard Dataverse. Version 1.
Data paper: Kankwamba, H., K. Pauw, J. Randriamamonjy and J. Thurlow. 2023.
2019 Social Accounting Matrix for Malawi: A Nexus Project SAM. Washington, DC:
IFPRI. {browse "https://doi.org/10.2499/p15738coll2.136898"}.

{pstd}
The SAM is licensed under the Creative Commons Attribution 4.0 International
licence (CC BY 4.0). This data was provided by the International Food Policy
Research Institute (IFPRI). IFPRI bears no responsibility for the analyses or
interpretations of the data presented here.


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
{synopt:{cmd:r(filename)}}the file read (from version 0.51.0), the copy shipped with the package for {cmd:cge_malawi_sam.csv}{p_end}


{title:Also see}

{psee}
{helpb cge}, {helpb cge_template}, {helpb cge_aggregate}, {helpb cge_balance},
{helpb cge_samexport}, {helpb cge_map}
{p_end}
