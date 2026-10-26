{smcl}
{* *! version 0.12.0  26oct2026}{...}
{title:Title}

{p2colset 5 19 21 2}{...}
{p2col:{bf:cge_region} {hline 2}}Link single-country models through bilateral trade{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_region add} {it:name} [{cmd:using} {it:filename}] [{cmd:,} {opt un:its(#)} {opt replace}]

{p 8 12 2}
{cmd:cge_region select} {it:name}

{p 8 12 2}
{cmd:cge_region trade} [{cmd:using} {it:filename}]{cmd:,} {opt exp:orter(varname)} {opt imp:orter(varname)}
{opt com:modity(varname)} {opt val:ue(varname)} [{opt tar:iff(varname)} {opt sig:ma(spec)} {opt row:elasticity(spec)}]

{p 8 12 2}
{cmd:cge_region tariff,} [{opt from(regions)} {opt to(regions)} {opt com:modities(list)}] {{opt val:ue(#)}|{opt sc:ale(#)}}

{p 8 12 2}
{cmd:cge_region world,} [{opt com:modities(list)}] [{opt imp:ort(#)} {opt exp:ort(#)} {opt reset}]

{p 8 12 2}
{cmd:cge_region solve,} {opt name(name)} [{opt tol:erance(#)} {opt iter:ate(#)} {opt start(base|alone)}]

{p 8 12 2}
{cmd:cge_region results,} {opt sim(name)} {opt clear}

{p 8 12 2}
{cmd:cge_region list}

{p 8 12 2}
{cmd:cge_region clear}


{title:Description}

{pstd}
{cmd:cge_region} (from version 0.12.0) links calibrated single-country models
through bilateral trade, as multi-region models such as GTAP do. Each region
is a model of its own, from its own SAM, with its own closure and shocks;
{cmd:cge_region add} adds the model in memory, or one saved with
{helpb cge_save}, as a region, and {cmd:cge_region select} brings a region's
model into memory, where {helpb cge_shock}, {helpb cge_closure},
{helpb cge_results} and the other commands act on it.

{pstd}
{cmd:cge_region trade} reads the base trade between the regions: one
observation per route, exporter, importer and commodity, with its value at
world prices in world units, the units in which a SAM unit of each region is
worth {opt units()}; and, optionally, the route's tariff, the importer's
average where it is missing. Each region's imports of a commodity that it
buys from the other regions are then a CES aggregate of the routes into it,
from the other regions and from the rest of the world, at prices that include
each route's tariff; its exports of a commodity it sells to them go to them
as their demand for them, and to the rest of the world along a demand curve.
The rest of the world closes each region's trade of the commodity at the base,
and its route has the tariff that gives the importer's average tariff.

{pstd}
{cmd:cge_region solve} solves the regions together: the full systems of all
the regions and, for each commodity a region trades with the others, its
world import price, its average tariff and its world export price, with the
link equations, by Newton's method with the sparse LU. Each region's solution
is stored as simulation {it:name} in its own model, with its world prices and
tariffs as parameters, so it solves that model on its own and can be
reported, compared or exported to GAMS as any simulation.
{cmd:cge_region results} puts the routes of a solution in memory.


{title:Options}

{phang}
{opt units(#)} is the value in world units of a unit of the region's SAM; the
default is 1. Route values are in world units.

{phang}
{opt exporter()}, {opt importer()} and {opt commodity()} name string
variables, {opt value()} and {opt tariff()} numeric ones. Every commodity
must be in both regions; the routes of an importer may not exceed its imports
of the commodity, nor those of an exporter its exports.

{phang}
{opt sigma(spec)} gives the elasticity of substitution among the sources of
imports, one number or {it:commodity}{cmd::}{it:#} pairs; the default is 4.
{opt rowelasticity(spec)} gives the elasticity of the rest of the world's
demand for a region's exports; the default is {opt sigma()}.

{phang}
{opt from()}, {opt to()} and {opt commodities()} of {cmd:cge_region tariff}
choose routes: regions, {cmd:rest} for imports from the rest of the world,
or {cmd:all}; {opt value()} sets their tariffs, {opt scale()} multiplies them.

{phang}
{opt import(#)} and {opt export(#)} of {cmd:cge_region world} set the rest of
the world's export price of the commodities, and the price that shifts its
demand for the regions' exports, relative to the base; {opt reset} puts them
and the tariffs of every route back at the base.

{phang}
{opt start(alone)} starts Newton's method from each region solved on its own
at the base links; the default starts from the base.


{title:Remarks}

{pstd}
In a region, the world prices and tariffs of the commodities it trades with
the other regions are set by the links: change them with
{cmd:cge_region tariff} and {cmd:cge_region world}, not {helpb cge_shock}.
Other shocks of a region, its closure and its other commodities are its own.
A region's exports of a linked commodity may not face a demand curve of its
own ({helpb cge_calibrate}, {opt exportdemand()}). The regions and their trade
last for the session: save each region with {helpb cge_save} after
{cmd:cge_region select}, and the routes as data, to add them again later.


{title:Examples}

{phang2}{cmd:. cge_synthetic, clear}{p_end}

{phang2}{cmd:. cge_sam, labels(account)}{p_end}

{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd)}
{cmd:government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}

{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{phang2}{cmd:. cge_region add A}{p_end}

{phang2}{cmd:. cge_synthetic, clear institutions}{p_end}

{phang2}{cmd:. cge_sam, labels(account)}{p_end}

{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) factors(lab cap) households(hhd npi)}
{cmd:enterprises(ent) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)}{p_end}

{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{phang2}{cmd:. cge_region add B, units(2)}{p_end}

{phang2}{cmd:. clear}{p_end}

{phang2}{cmd:. set obs 2}{p_end}

{phang2}{cmd:. generate exporter = cond(_n == 1, "A", "B")}{p_end}

{phang2}{cmd:. generate importer = cond(_n == 1, "B", "A")}{p_end}

{phang2}{cmd:. generate commodity = "com_man"}{p_end}

{phang2}{cmd:. generate value = cond(_n == 1, 24, 30)}{p_end}

{phang2}{cmd:. cge_region trade, exporter(exporter) importer(importer) commodity(commodity) value(value)}{p_end}

{phang2}{cmd:. cge_region tariff, from(A B) to(A B) value(0)}{p_end}

{phang2}{cmd:. cge_region solve, name(fta)}{p_end}

{phang2}{cmd:. cge_region results, sim(fta) clear}{p_end}


{title:Stored results}

{pstd}{cmd:cge_region solve} stores {cmd:r(iterations)}, {cmd:r(N_regions)},
{cmd:r(N_links)} and {cmd:r(name)}; {cmd:cge_region list} stores
{cmd:r(regions)}, {cmd:r(current)}, {cmd:r(N_regions)} and {cmd:r(N_routes)};
{cmd:cge_region results} stores {cmd:r(sim)} and {cmd:r(N_routes)}.


{title:Reference}

{phang}
Hertel, T. W., ed. (1997). Global Trade Analysis: Modeling and Applications.
Cambridge: Cambridge University Press.


{title:Also see}

{psee}
{helpb cge_save}, {helpb cge_shock}, {helpb cge_results}, {helpb cge_gams}
{p_end}
