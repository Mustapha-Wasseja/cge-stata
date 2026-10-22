{smcl}
{* *! version 0.6.4  22oct2026}{...}
{title:Title}

{p2colset 5 25 27 2}{...}
{p2col:{bf:cge_elasticities} {hline 2}}Published elasticities, with their sources{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_elasticities} [{it:parameter}] [{cmd:using} {it:filename}]
[{cmd:,} {opt c:ountry(codes)} {opt cat:egory(names)} {opt sou:rce(ids)} {opt id(ids)}
{opt clear} {opt val:ues} {opt map(spec)} {opt oth:ers(category)}]

{p 4 4 2}
{it:parameter} is a {helpb cge_calibrate} option: {cmd:sigmaq}, {cmd:sigmat},
{cmd:sigmava}, {cmd:incelas}, {cmd:frisch}, {cmd:wagecurve}, {cmd:sickelas} or
{cmd:mortelas}.


{title:Description}

{pstd}
{cmd:cge_elasticities} lists, loads or turns into {helpb cge_calibrate}
options the entries of the package's elasticity library (from version
0.3.5; Reference Manual, {it:The elasticity library}). Each entry is a published estimate, with its
source, the table and page where it is printed, its definition and the check
made when it was read from the source. Elasticities have no defaults in
{helpb cge_calibrate}; the library documents where values come from, and
nothing is applied without a command.

{pstd}
The library holds:

{p2colset 9 22 24 2}{...}
{p2col:{cmd:sigmaq}, {cmd:sigmat}}aggregate Armington and CET elasticities for 51 African countries
(Devarajan, Go and Robinson 2023, Appendix Tables A1 and A2){p_end}
{p2col:{cmd:incelas}}income elasticities for nine consumption categories, for 47 African countries
(Muhammad, Seale, Meade and Regmi 2011, Appendix table 1){p_end}
{p2col:{cmd:frisch}}the Frisch parameter, the inverse of the income flexibility estimated for 144
countries (same source, Table 3){p_end}
{p2col:{cmd:sigmava}}the elasticity of substitution between capital and labour for 30 African
countries pooled (Hosni and Ouakil 2024){p_end}
{p2col:{cmd:wagecurve}}wage-curve elasticities, international and for South Africa (Blanchflower
and Oswald 1995; Kingdon and Knight 2006){p_end}
{p2col:{cmd:mortelas}}elasticities of under-five and maternal mortality with respect to
government health expenditure (Bokhari, Gai and Gottret 2007), for reference: their outcome and
driver differ from those of {opt mortelas()}{p_end}
{p2colreset}{...}

{pstd}
Countries are ISO 3166 alpha-3 codes, for example {cmd:TGO}; groups are
{cmd:AFR} (Africa), {cmd:WLD} (international) and {cmd:DEV} (developing
countries). Income-elasticity categories are {cmd:food} (with beverages and
tobacco), {cmd:clothing}, {cmd:housing}, {cmd:furnishings}, {cmd:health},
{cmd:transport} (with communication), {cmd:recreation}, {cmd:education} and
{cmd:other}.

{pstd}
Read the definitions before using a value. Aggregate trade elasticities are
lower than sector ones, so they set a level rather than every sector's value
(Devarajan et al. 2023). The income elasticities come from a cross-country
demand system for 2005, not from a household survey of the country.


{title:Options}

{phang}
{opt country(codes)}, {opt category(names)}, {opt source(ids)} and
{opt id(ids)} select entries; each takes one or more values, and an entry is
selected when it matches every option given.

{phang}
{cmd:using} {it:filename} adds the entries of a CSV file in the library's
layout (at least the columns {cmd:id}, {cmd:parameter}, {cmd:country},
{cmd:category}, {cmd:value} and {cmd:source}), for example values a user is
licensed to use or has estimated. Entry ids must be unique.

{phang}
{opt clear} loads the selected entries into memory, replacing the data, with
their definitions, methods, observations, periods, locations, checks, notes
and source details.

{phang}
{opt values} returns the values for {helpb cge_calibrate} in {cmd:r(values)},
in the order of the model's commodities ({cmd:sigmaq}, {cmd:sigmat},
{cmd:incelas}) or activities ({cmd:sigmava}) after {helpb cge_map}, or as one
number. A {cmd:wagecurve} value is one number, which {helpb cge_calibrate}
takes as {it:factor}{cmd::}{it:value}, for example
{cmd:wagecurve(lab:`r(values)')}. Each element takes the single selected entry, or the entry of the
category that {opt map()} or {opt others()} gives it; if more than one entry
matches an element, the command stops and lists them. The entries used, their
definitions and notes are displayed.

{phang}
{opt map(spec)} gives categories to commodities or activities,
{it:element}{cmd::}{it:category} pairs, for example
{cmd:map(com_agr:food com_hlt:health)}; {opt others(category)} gives a
category to those not listed.


{title:Examples}

{phang2}{cmd:. cge_elasticities sigmaq, country(TGO SLE BWA)}{p_end}
{phang2}{cmd:. cge_elasticities incelas, country(TGO) clear}{p_end}

{pstd}Values for the SYNTHETIC SAM with a health sector, mapped as in {helpb cge_map}{p_end}
{phang2}{cmd:. cge_synthetic, clear health}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) factors(lab cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)}{p_end}
{phang2}{cmd:. cge_elasticities sigmaq, country(TGO) values}{p_end}
{phang2}{cmd:. local sq `r(values)'}{p_end}
{phang2}{cmd:. cge_elasticities incelas, country(TGO) values map(com_agr:food com_hlt:health) others(other)}{p_end}
{phang2}{cmd:. local ie `r(values)'}{p_end}
{phang2}{cmd:. cge_elasticities frisch, values}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(`sq') sigmat(2) incelas(`ie') frisch(`r(values)')}{p_end}


{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of entries selected, or of values returned{p_end}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(ids)}}entries selected, or the entry used for each value{p_end}
{synopt:{cmd:r(values)}}values for {helpb cge_calibrate} (with {opt values}){p_end}
{synopt:{cmd:r(parameter)}}parameter (with {opt values}){p_end}


{title:References}

{phang}
Blanchflower, D. G. and A. J. Oswald. 1995. An introduction to the wage curve.
{it:Journal of Economic Perspectives} 9(3): 153-167.

{phang}
Bokhari, F. A. S., Y. Gai and P. Gottret. 2007. Government health
expenditures and health outcomes. {it:Health Economics} 16(3): 257-273.

{phang}
Devarajan, S., D. S. Go and S. Robinson. 2023. Trade elasticities in aggregate
models: estimates for 191 countries. World Bank Policy Research Working Paper
10490.

{phang}
Hosni, M. and H. Ouakil. 2024. Estimation de l'elasticite de substitution entre
le capital et le travail de l'economie africaine : une analyse en donnees de
panel. {it:Revue AME} 6(3): 247-269.

{phang}
Kingdon, G. G. and J. Knight. 2006. How flexible are wages in response to local
unemployment in South Africa? {it:ILR Review} 59(3): 471-495.

{phang}
Muhammad, A., J. L. Seale Jr., B. Meade and A. Regmi. 2011. International
evidence on food consumption patterns: an update using 2005 International
Comparison Program data. Technical Bulletin TB-1929, Economic Research Service,
U.S. Department of Agriculture.


{title:Also see}

{psee}
{helpb cge_calibrate}, {helpb cge_sensitivity}, {helpb cge}
{p_end}
