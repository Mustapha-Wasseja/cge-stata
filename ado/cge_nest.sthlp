{smcl}
{* *! version 0.11.0  24oct2026}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{bf:cge_nest} {hline 2}}Declare a nested CES or CET block{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_nest begin} {it:name}[{cmd:(}{it:i}{cmd:)}][{cmd:$(}{it:condition}{cmd:)}]{cmd:,}
{opt out:put(reference)} {opt pr:ice(reference)} {{opt s(#)}|{opt t(#)}}
[{opt eff:iciency(expression)} {opt rep:lace(block)}]

{p 8 12 2}
{cmd:cge_nest nest} {it:nestname}{cmd:,} {{opt s(#)}|{opt t(#)}} [{opt in(nestname)}]

{p 8 12 2}
{cmd:cge_nest input} {it:reference}{cmd:,} {opt pr:ice(expression)} [{opt un:its(expression)} {opt in(nestname)} {opt rep:lace(block)}]

{p 8 12 2}
{cmd:cge_nest output} {it:reference}{cmd:,} {opt pr:ice(expression)} [{opt un:its(expression)} {opt in(nestname)} {opt rep:lace(block)}]

{p 8 12 2}
{cmd:cge_nest end}

{p 8 12 2}
{cmd:cge_nest,} {opt list} | {opt drop}


{title:Description}

{pstd}
{cmd:cge_nest} (from version 0.11.0) declares a production or transformation
function as a tree of CES or CET nests over variables of the model, in the
manner of the production blocks of MPSGE. {cmd:cge_nest begin} names the
block, its output quantity and price and the elasticity at the top:
{opt s(#)} for a cost block, whose inputs substitute for each other, or
{opt t(#)} for a revenue block, whose outputs are transformed into each
other. {cmd:cge_nest nest} adds a nest within the block, or within another
nest with {opt in()}. {cmd:cge_nest input} (in a cost block) and
{cmd:cge_nest output} (in a revenue block) add a leaf: a variable and the
expression of its price. {cmd:cge_nest end} writes the block as user
variables and equations ({helpb cge_variable}, {helpb cge_equation}) in
calibrated share form: the shares and base values come from the base, through
{cmd:base()}, so the block holds at the base and follows the model when it is
calibrated again.

{pstd}
Each leaf's equation gives its quantity from the price index and quantity of
its nest, and the top equation sets the price of the output against the price
index of the block. They take the place of the built-in equations named in
{opt replace()}, so that the system stays square: for value added, the CES
function (Q3) with the top equation and the factor demands (Q4) with the
leaves. With an index, {opt replace()} may give the index of the block in
place of a label, as {cmd:replace(Q4(lab, a))}.

{pstd}
In nest {it:n} with elasticity {it:s}, child {it:j} with price {it:p_j} and
base value share {it:th_j}, the price index is
{it:P_n} = (sum {it:th_j} ({it:p_j}/{it:p0_j})^(1-{it:s}))^(1/(1-{it:s}))
(the geometric mean at {it:s} = 1, the weighted sum at {it:s} = 0) and the
quantity is
{it:q_j} = {it:q0_j} ({it:Q_n}/{it:Q0_n}) ({it:P_n} {it:p0_j}/{it:p_j})^{it:s}.
A revenue nest has the exponent 1+{it:t} and {it:q_j} = {it:q0_j}
({it:Q_n}/{it:Q0_n}) ({it:p_j}/({it:p0_j} {it:P_n}))^{it:t}. At the top,
{it:Q_n} is the output divided by {opt efficiency()} in a cost block (times it
in a revenue block), and the price of the output is its base value times
{it:P_n}, divided by efficiency (times it in a revenue block).


{title:Options}

{phang}
{opt output(reference)} and {opt price(reference)} name the variables of the
block's output quantity and price, with the block's index, as
{cmd:output(QVA(a)) price(PVA(a))}.

{phang}
{opt s(#)} or {opt t(#)} gives the elasticity of substitution of a cost block
or nest, or of transformation of a revenue block or nest; 0 or more.

{phang}
{opt efficiency(expression)} scales the output, 1 at the base, as
{cmd:efficiency(ad(a) / base(ad(a)))}; the default is 1.

{phang}
{opt replace(block)} names the built-in equation that the top equation, or a
leaf's equation, takes the place of.

{phang}
{opt price(expression)} of a leaf is the price of its quantity, as
{cmd:price(W(lab) * WFDIST(lab, a) * (1 + tf(lab, a)))}.

{phang}
{opt units(expression)} gives the units in which a leaf enters the block, as
{cmd:units(af(lab) * EFF(lab) * DW(lab))} for factors in efficiency units:
the block takes {it:units} times the quantity, at the price over {it:units}.

{phang}
{opt in(nestname)} puts a nest or a leaf within a nest; the default is the
top of the block.

{phang}
{opt list} lists the declared blocks; {opt drop} drops the block that is open.
{helpb cge_equation}{cmd:, clear} removes the blocks with the other user
variables and equations.


{title:Remarks}

{pstd}
A leaf exists where its quantity is not zero at the base; elsewhere it is left
out of the block. The names of the variables written start with the block's
name: {it:name}{cmd:_P} for its price index, {it:name}{cmd:_}{it:nest}{cmd:_P}
and {cmd:_Q} for a nest, {it:name}{cmd:_w}{it:k} and {cmd:_x}{it:k} for the
price and quantity of leaf {it:k}, and the equations {it:name}{cmd:_d}{it:k}
and {it:name}{cmd:_z}. {helpb cge_gams} writes them as other user equations.


{title:Examples}

{pstd}Value added of two kinds of labour in a nest of 1.5, with capital at the
top at 0.8, and a payroll tax{p_end}

{phang2}{cmd:. cge_synthetic, clear nests}{p_end}
{phang2}{cmd:. cge_sam, labels(account)}{p_end}
{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser act_ene) commodities(com_agr com_man com_ser com_ene) factors(lab_hi lab_lo cap) households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) factortax(tax_pay:lab_hi)}{p_end}
{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}
{phang2}{cmd:. cge_nest begin va(a), output(QVA(a)) price(PVA(a)) s(0.8) efficiency(ad(a) / base(ad(a))) replace(Q3)}{p_end}
{phang2}{cmd:. cge_nest nest labour, s(1.5)}{p_end}
{phang2}{cmd:. cge_nest input QF(lab_hi, a), price(W(lab_hi) * WFDIST(lab_hi, a) * (1 + tf(lab_hi, a))) in(labour) replace(Q4(lab_hi, a))}{p_end}
{phang2}{cmd:. cge_nest input QF(lab_lo, a), price(W(lab_lo) * WFDIST(lab_lo, a) * (1 + tf(lab_lo, a))) in(labour) replace(Q4(lab_lo, a))}{p_end}
{phang2}{cmd:. cge_nest input QF(cap, a), price(W(cap) * WFDIST(cap, a) * (1 + tf(cap, a))) replace(Q4(cap, a))}{p_end}
{phang2}{cmd:. cge_nest end}{p_end}
{phang2}{cmd:. cge_shock QFS, elements(lab_hi) scale(1.1)}{p_end}
{phang2}{cmd:. cge_solve, name(skilled)}{p_end}


{title:Stored results}

{pstd}{cmd:cge_nest end} stores:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_variables)}}user variables written{p_end}
{synopt:{cmd:r(N_equations)}}user equations written{p_end}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(name)}}name of the block{p_end}

{pstd}{cmd:cge_nest, list} stores {cmd:r(N_blocks)} and {cmd:r(blocks)}.


{title:Reference}

{phang}
Rutherford, T. F. (1999). Applied general equilibrium modeling with MPSGE as
a GAMS subsystem: an overview of the modeling framework and syntax.
Computational Economics 14: 1-46.


{title:Also see}

{psee}
{helpb cge_variable}, {helpb cge_equation}, {helpb cge_calibrate}
{p_end}
