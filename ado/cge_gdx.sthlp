{smcl}
{* *! version 0.10.0  24oct2026}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{bf:cge_gdx} {hline 2}}GAMS data exchange (GDX) files: write, read and list{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_gdx write} {helpb using} {it:file}{cmd:.gdx} [{cmd:,} {opt sims(names|_all)} {opt replace} {opt norun} {opt gams(path)}]

{p 8 12 2}
{cmd:cge_gdx read} {helpb using} {it:file}{cmd:.gdx}{cmd:,} {opt sym:bol(name)} {opt clear} [{opt norun} {opt gams(path)}]

{p 8 12 2}
{cmd:cge_gdx list} {helpb using} {it:file}{cmd:.gdx} [{cmd:,} {opt clear} {opt norun} {opt gams(path)}]

{p 8 12 2}
{cmd:cge_sam} {helpb using} {it:file}{cmd:.gdx}{cmd:,} {opt sym:bol(name)} {opt clear} [{opt norun} {opt gams(path)}]


{title:Description}

{pstd}
{cmd:cge_gdx} (from version 0.10.0; Reference Manual, {it:cge_gdx}) exchanges
data with GAMS through GDX files, as GAMS's {cmd:execute_unload} and
{cmd:$gdxin} do. It needs GAMS: GAMS writes the files and its tool
{cmd:gdxdump} reads them.

{pstd}
{cmd:cge_gdx write} writes the calibrated model and its simulations to a GDX
file: the set {cmd:AC} of accounts and its subsets {cmd:A}, {cmd:C}, {cmd:F},
{cmd:H} and {cmd:E}; the parameter {cmd:SAM(AC, AC)}; the calibrated parameters,
{cmd:CAL(}{it:name}{cmd:,} {it:element}{cmd:,} {it:element}{cmd:)}; the set
{cmd:sim} of the base and the simulations; and the levels of the variables,
{cmd:LEVEL(}{it:sim}{cmd:,} {it:variable}{cmd:,} {it:element}{cmd:,} {it:element}{cmd:)},
with {cmd:-} for an index a symbol does not have. Stata writes a GAMS program,
{it:file}{cmd:_write.gms}, with every number to the last digit, and GAMS runs
it. GAMS stores no zeros.

{pstd}
{cmd:cge_gdx read} replaces the data in memory with a symbol of a GDX file, one
observation per record: a string variable for each index, named after its
domain ({cmd:dim1}, {cmd:dim2}, ... for an index without one), and
{cmd:value} for a parameter; {cmd:level}, {cmd:marginal}, {cmd:lower},
{cmd:upper} and {cmd:scale} for a variable or an equation; and {cmd:text} for
a set. {cmd:gdxdump} writes the numbers as hexadecimal floats, which are read
exactly, so that a GDX file written by {cmd:cge_gdx write} gives back Stata's
values to the last digit. GAMS's {cmd:EPS} is read as 0; infinities and the
special values {cmd:NA} and {cmd:UNDF} are missing. The symbol can be any
symbol of any GDX file, such as the SAM of another GAMS model, or the solution
of the GAMS program of {helpb cge_gams}, run with {cmd:gdx=}.

{pstd}
{cmd:cge_gdx list} lists the symbols of a GDX file, with their dimension,
type, number of records and text; with {opt clear}, as a dataset.

{pstd}
{cmd:cge_sam} reads a SAM from a GDX file, a parameter with two indexes,
{cmd:SAM} by default.

{pstd}
Each command writes a script in the folder of the file, which runs GAMS or
{cmd:gdxdump} there, and runs it with {helpb shell}. Stata for Windows cannot
start other programs in batch mode: there, and with {opt norun}, the script is
written and not run. Run it, then give the command again with {opt norun}: it
reads what the script wrote.


{title:Options}

{phang}
{opt sims(names)} names the stored simulations whose levels are written,
with the base; {cmd:_all} writes every one. By default only the base is
written.

{phang}
{opt symbol(name)} names the symbol to read.

{phang}
{opt clear} replaces the data in memory; {cmd:cge_gdx read} needs it.

{phang}
{opt replace} allows an existing GDX file to be replaced.

{phang}
{opt norun} writes the script without running it, and reads the output of
an earlier run.

{phang}
{opt gams(path)} names the GAMS executable, as
{cmd:gams(C:/GAMS/54/gams.exe)}; {cmd:gdxdump} is taken from its folder. By
default {cmd:gams} and {cmd:gdxdump} must be on the system path.


{title:Examples}

{pstd}Setup: the SYNTHETIC SAM, mapped, calibrated and solved{p_end}
{phang2}{cmd:. cge_synthetic, clear}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}
{phang2}{cmd:. cge_shock tm, value(0)}{p_end}
{phang2}{cmd:. cge_solve, name(notariff)}{p_end}

{pstd}The model and the simulation as a GDX file{p_end}
{phang2}{cmd:. cge_gdx write using model.gdx, sims(notariff) gams(C:/GAMS/54/gams.exe)}{p_end}

{pstd}Its symbols, and the levels read back{p_end}
{phang2}{cmd:. cge_gdx list using model.gdx, gams(C:/GAMS/54/gams.exe)}{p_end}
{phang2}{cmd:. cge_gdx read using model.gdx, symbol(LEVEL) clear gams(C:/GAMS/54/gams.exe)}{p_end}

{pstd}A SAM from the GDX file of a GAMS model{p_end}
{phang2}{cmd:. cge_sam using model.gdx, symbol(SAM) clear gams(C:/GAMS/54/gams.exe)}{p_end}


{title:Stored results}

{pstd}
{cmd:cge_gdx write} stores {cmd:r(N_sims)}, {cmd:r(N_levels)} and
{cmd:r(N_parameters)}, the numbers of simulations, levels and parameters
written, and {cmd:r(sims)}. {cmd:cge_gdx read} stores {cmd:r(N)}, the number of
records; {cmd:r(dim)}, the number of indexes; {cmd:r(kind)}
({cmd:parameter}, {cmd:variable} or {cmd:set}); {cmd:r(indexes)}, the names of
the index variables; and {cmd:r(symbol)}. {cmd:cge_gdx list} stores
{cmd:r(N_symbols)} and {cmd:r(symbols)}.


{title:Also see}

{psee}
{helpb cge_gams}, {helpb cge_sam}, {helpb cge_parameters}, {helpb cge_results}, {helpb cge}
{p_end}
