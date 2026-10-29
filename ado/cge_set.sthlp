{smcl}
{* *! version 0.29.0  29oct2026}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{bf:cge_set} {hline 2}}User sets of elements{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_set} {it:name} {cmd:=} {it:elements} [{cmd:,} {opt except(elements)}]

{p 8 12 2}
{cmd:cge_set} {it:name}[{cmd:(}{it:i}{cmd:)}]{cmd:,} {opt from(varname)} [{opt except(elements)}]

{p 8 12 2}
{cmd:cge_set} {it:name}[{cmd:(}{it:i}[{cmd:,}{it:j} ...]{cmd:)}][{cmd:$(}{it:condition}{cmd:)}] {cmd:=} {it:set expression}
[{cmd:,} {opt except(set expression)}]

{p 8 12 2}
{cmd:cge_set} {it:name}{cmd:(}{it:i}{cmd:,}{it:j}[{cmd:,}{it:k} ...]{cmd:)} {cmd:=} {it:e1}{cmd:.}{it:f1}[{cmd:.}{it:g1} ...] [{it:e2}{cmd:.}{it:f2}[{cmd:.}{it:g2} ...] ...]

{p 8 12 2}
{cmd:cge_set} {cmd:,} {opt list}

{p 8 12 2}
{cmd:cge_set} {cmd:,} {opt clear}

{pstd}
{it:elements} are labels of elements of the model (accounts such as
{cmd:com_hlt}, or nests), the letters of model sets ({cmd:a} activities,
{cmd:c} commodities, {cmd:f} factors, {cmd:h} households, {cmd:d} households
and enterprises, {cmd:i} institutions receiving factor income, {cmd:n} nests
of value added) and the names of other user sets, separated by spaces. In a
standalone model ({helpb cge_model}) there are no model sets: the elements
are labels of the set's own, of letters, digits and underscores, at most 32
characters, or the names of other user sets.

{pstd}
A {it:set expression} (from version 0.29.0) combines elements and sets with
{cmd:+} (union; elements side by side are a union too), {cmd:*}
(intersection), {cmd:-} (difference), {cmd:not} (the complement in the
domain), {cmd:yes} and {cmd:no} (every element of the domain, none), and
conditions, {cmd:$(}{it:condition}{cmd:)} after a factor, with parentheses
for grouping; see {it:Set algebra} below.


{title:Description}

{pstd}
{cmd:cge_set} (from version 0.7.1; Reference Manual,
{it:User variables and equations}) defines a set of elements of the calibrated model, such as the
health commodities or the rural households. Its name then serves as an index
wherever the letter of a model set does: in the definitions of user variables
({helpb cge_variable}), in user equations ({helpb cge_equation}), in sums,
and in the indexes of user parameters ({helpb cge_parameter}). An index is
the set's name, followed by digits where a second index over the same set is
needed, as in {cmd:hc2}.

{pstd}
From version 0.9.1, {cmd:cge_set} {it:name}{cmd:(}{it:i}{cmd:,}{it:j}{cmd:)}
defines a set of pairs, as a GAMS set over two indexes does: a mapping such as
the activities and the commodities they make. Each pair is written
{it:e}{cmd:.}{it:f}, with {it:e} an element of the set of {it:i} and {it:f}
one of the set of {it:j}. A set of pairs is not an index. It serves in sums,
{cmd:sum(}{it:name}{cmd:(}{it:i}{cmd:,}{it:j}{cmd:),} {it:expression}{cmd:)}
being the sum over its pairs, and in conditions, where
{it:name}{cmd:(}{it:i}{cmd:,}{it:j}{cmd:)} is 1 for a pair of the set, so
that it restricts sums, terms and the domains of variables and equations with
two indexes; see {it:Two indexes and sets of pairs} in {helpb cge_equation}.
From version 0.25.0 a set may hold tuples of three or more elements,
{cmd:cge_set m(i,j,k) = p1.q1.r1 p2.q3.r1}, which serve in the same ways:
{cmd:sum(m(i,j,k),} {it:expression}{cmd:)} and the condition
{cmd:m(i,j,k)}.

{pstd}
The elements are written out in the order given, each once, without those in
{opt except()}. A name must be new: not a variable, a parameter, an element,
an equation or an index letter of a model set. A set whose elements are those
of another, {cmd:cge_set j = i}, serves as GAMS's {cmd:alias}; the index of a
set with digits after it, as {cmd:i2}, runs over the same set too.

{pstd}
{bf:Set algebra.} From version 0.29.0, {cmd:cge_set}
{it:name}{cmd:(}{it:i}{cmd:)} defines a subset of the set of index {it:i},
as GAMS's {cmd:set} {it:name}{cmd:(}{it:i}{cmd:)} does: every element must
belong to that set (error 111 otherwise), and {it:i} may itself be a subset,
as in {cmd:cge_set food(goods)}. The elements may be a set expression:

{p2colset 9 30 32 2}{...}
{p2col:{it:A} {cmd:+} {it:B}, {it:A} {it:B}}the elements of {it:A}, then those of {it:B} not in {it:A}{p_end}
{p2col:{it:A} {cmd:*} {it:B}}the elements of {it:A} that are in {it:B}{p_end}
{p2col:{it:A} {cmd:-} {it:B}}the elements of {it:A} that are not in {it:B}{p_end}
{p2col:{cmd:not} {it:A}}the elements of the domain not in {it:A}{p_end}
{p2col:{cmd:yes}, {cmd:no}}every element of the domain, in its order; none{p_end}
{p2col:{it:A}{cmd:$(}{it:condition}{cmd:)}}the elements of {it:A} for which the condition holds{p_end}
{p2colreset}{...}

{pstd}
{cmd:*} binds before {cmd:+} and {cmd:-}; {cmd:not} and conditions apply to
the factor before or after them, so {cmd:not} {cmd:(}{it:A} {cmd:+}
{it:B}{cmd:)} needs its parentheses. The result keeps the order in which the
elements are first named. A condition is written as in the domains of
{helpb cge_variable}: with the index of the domain, comparisons,
{cmd:&} {cmd:|} {cmd:!}, membership of sets, {cmd:ord()} and {cmd:card()},
parameters, and variables at the base, and it is evaluated at the base when
the set is defined, so that the set does not change with later shocks, as a
GAMS assignment to a dynamic set does not. The condition must be in
parentheses: Stata reads a dollar sign followed by a name as a global macro.
A condition on the name, {it:name}{cmd:(}{it:i}{cmd:)$(}{it:condition}{cmd:)}
{cmd:=} {it:expression}, applies to the whole expression:
{cmd:cge_set imp(c)$(tm(c) > 0) = yes} is {cmd:cge_set imp(c) = yes$(tm(c) > 0)}.

{pstd}
With two or more indexes, {it:name}{cmd:(}{it:i}{cmd:,}{it:j}{cmd:)},
the expression is one of pairs: pairs of labels {it:e}{cmd:.}{it:f}, sets of
pairs, {cmd:yes}, {cmd:no} and conditions on both indexes, as
{cmd:cge_set used(f,a) = yes$(QF(f,a) > 0)}; single sets enter through
their membership in a condition, {cmd:$(goods(c))}. Without a domain,
{cmd:cge_set} {it:name} {cmd:=} {it:expression} combines sets of the model
with {cmd:+}, {cmd:*} and {cmd:-}; {cmd:not}, {cmd:yes}, {cmd:no} and
conditions need a domain. In a standalone model new labels are written out,
without operators. {cmd:yes}, {cmd:no} and {cmd:not} are words of set
expressions, not names of sets.

{pstd}
GAMS's {cmd:loop}, {cmd:if} and {cmd:while} over assignments are Stata's own
{helpb foreach}, {helpb if} and {helpb while} around {cmd:cge_set} and
{helpb cge_parameter}, which store the number of elements in
{cmd:r(N_elements)}; see the examples.

{pstd}
From version 0.13.0, {opt from(varname)} takes the elements from a string
variable of the data in memory, in the order they appear, each once, as the
account labels of a SAM in memory: {cmd:cge_set ac, from(account)}.

{pstd}
User sets are saved with the model and kept when it is calibrated again.
{cmd:cge_set, list} displays them; {cmd:cge_set, clear} removes them all,
once no user variable, equation or parameter uses them.


{title:Options}

{phang}
{opt except(elements)} leaves out the elements listed, given as for the set;
from version 0.29.0 a set expression.

{phang}
{opt from(varname)} takes the elements from the string variable
{it:varname}, skipping empty values; in a model from a SAM they must be
elements of the model.


{title:Examples}

{pstd}Setup: the SYNTHETIC SAM with a health sector, mapped and calibrated{p_end}

{phang2}{cmd:. cge_synthetic, clear health}{p_end}

{phang2}{cmd:. cge_sam, labels(account)}{p_end}

{phang2}{cmd:. cge_map, activities(act_agr act_man act_ser act_hlt) commodities(com_agr com_man com_ser com_hlt) factors(lab cap)}
{cmd:households(hhd) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp) insurance(shi)}{p_end}

{phang2}{cmd:. cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)}{p_end}

{pstd}The goods, the commodities other than services and health{p_end}

{phang2}{cmd:. cge_set goods = c, except(com_ser com_hlt)}{p_end}

{pstd}Spending on goods by the government, as a user variable{p_end}

{phang2}{cmd:. cge_variable GGOODS = sum(goods, PQ(goods) * QG(goods)), nominal}{p_end}

{pstd}Activities paired with the commodities they make; the value of their output, and a price ratio for the pairs only (from version 0.9.1){p_end}

{phang2}{cmd:. cge_set map(a,c) = act_agr.com_agr act_hlt.com_hlt}{p_end}

{phang2}{cmd:. cge_variable VMAP = sum(map(a,c), PA(a) * QA(a)), nominal}{p_end}

{phang2}{cmd:. cge_variable PR(a,c)$(map(a,c)) = PA(a) / PQ(c)}{p_end}

{pstd}Set algebra (from version 0.29.0): the commodities with tariffs, the others, and the labour-intensive activities{p_end}

{phang2}{cmd:. cge_set imp(c) = yes$(tm(c) > 0)}{p_end}

{phang2}{cmd:. cge_set nonimp(c) = not imp}{p_end}

{phang2}{cmd:. cge_set staples(goods) = goods - com_man}{p_end}

{phang2}{cmd:. cge_set labint(a) = yes$(QF(lab,a) > QF(cap,a))}{p_end}

{pstd}The pairs of factors and activities with large factor use, and the factors they use{p_end}

{phang2}{cmd:. cge_set large(f,a) = yes$(QF(f,a) > 20)}{p_end}

{phang2}{cmd:. cge_variable QLARGE = sum(large(f,a), QF(f,a))}{p_end}

{pstd}Stata's loops around cge_set: a set for each threshold, kept when it has elements{p_end}

{p 8 8 2}{cmd:foreach v in 10 20 40 {c -(}}{break}
{space 4}{cmd:capture cge_set above`v'(f,a) = yes$(QF(f,a) > `v')}{break}
{space 4}{cmd:if !_rc display "above `v': " r(N_elements)}{break}
{cmd:{c )-}}{p_end}

{pstd}The user sets{p_end}

{phang2}{cmd:. cge_set, list}{p_end}


{title:Stored results}

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N_elements)}}number of elements, or pairs, of the set defined{p_end}
{synopt:{cmd:r(N_sets)}}number of user sets ({opt list}){p_end}
{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(name)}}name of the set defined{p_end}
{synopt:{cmd:r(elements)}}its elements{p_end}
{synopt:{cmd:r(domain)}}its domain, the indexes in parentheses (from version 0.29.0){p_end}


{title:Also see}

{psee}
{helpb cge_parameter}, {helpb cge_variable}, {helpb cge_equation}, {helpb cge}
{p_end}
