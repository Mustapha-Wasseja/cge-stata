{smcl}
{* *! version 0.24.0  25oct2026}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{bf:cge_nash} {hline 2}}Nash equilibria of players who choose instruments, and leaders{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 12 2}
{cmd:cge_nash player} {it:name}{cmd:,} {opt inst:ruments(list)} {opt max:imize(objective)}|{opt min:imize(objective)}
[{opt low:er(spec)} {opt up:per(spec)}]

{p 8 12 2}
{cmd:cge_nash solve}{cmd:,} {opt name(name)} [{opt lead:er(player)} {opt meth:od(gs|newton)} {opt damp:ing(#)}
{opt tol:erance(#)} {opt iter:ate(#)} {opt trace}]

{p 8 12 2}
{cmd:cge_nash list}

{p 8 12 2}
{cmd:cge_nash clear} [{it:player}]


{title:Description}

{pstd}
{cmd:cge_nash} (from version 0.20.0; Reference Manual, {it:cge_nash}) finds
the Nash equilibrium of players who each choose instruments to maximise or
minimise an outcome of the model given the others' choices, as an equilibrium
problem in GAMS's EMP framework does, and the choice of a leader who
anticipates the others' equilibrium, as in a Stackelberg game. A player's
instruments, objective and bounds are written as in {helpb cge_optimize}; an
instrument belongs to one player. The players are saved with the model.

{pstd}
{cmd:cge_nash solve} lets each player in turn choose its best response to the
others' instruments, by {helpb cge_optimize} with exact derivatives, until a
round changes no instrument by more than the tolerance, and stores the
equilibrium as simulation {it:name}. With {opt leader()}, the leader's
instruments maximise its objective at the followers' equilibrium that each
choice gives, by a projected Newton method with differences, each evaluation
solving the followers' equilibrium.

{pstd}
With {cmd:method(newton)} (from version 0.24.0), {cmd:cge_nash solve} solves
the players' first-order conditions together, by a semismooth Newton method
on each instrument's derivative of its player's objective, projected on the
bounds. It converges where best responses in turn cycle or diverge, and
needs fewer solves of the model. It finds points where every player's
derivatives vanish (or push against a bound); a note says when a player's
objective is not concave in its instruments there, so that the point may
not be its best response.


{title:Options}

{phang}
{opt instruments(list)}, {opt maximize()}, {opt minimize()}, {opt lower()} and
{opt upper()} define a player as in {helpb cge_optimize}.

{phang}
{opt name(name)} names the simulation of the equilibrium.

{phang}
{opt leader(player)} makes {it:player} a leader.

{phang}
{opt method(gs|newton)} (from version 0.24.0) chooses best responses in turn
(Gauss-Seidel, {cmd:gs}, the default) or Newton's method on the first-order
conditions ({cmd:newton}). With a leader, it solves the followers'
equilibria.

{phang}
{opt damping(#)} (from version 0.24.0), above 0 and at most 1, moves each
player that share of the way to its best response, which can make best
responses that cycle or diverge converge; the default is 1. It goes with
{cmd:method(gs)}.

{phang}
{opt tolerance(#)} is the largest change of an instrument, relative to its
size, in a round that ends the iteration; with {cmd:method(newton)}, the
largest gap in the first-order conditions. The default is 1e-8.
{opt iterate(#)} limits the rounds or Newton iterations (default 50);
{opt trace} displays them.


{title:Examples}

{pstd}Cournot duopoly and a Stackelberg leader in a standalone model{p_end}
{phang2}{cmd:. cge_model new}{p_end}
{phang2}{cmd:. cge_parameter a = 10}{p_end}
{phang2}{cmd:. cge_parameter b = 1}{p_end}
{phang2}{cmd:. cge_parameter c = 1}{p_end}
{phang2}{cmd:. cge_variable Q1, value(1) fixed}{p_end}
{phang2}{cmd:. cge_variable Q2, value(1) fixed}{p_end}
{phang2}{cmd:. cge_variable P = a - b * (Q1 + Q2)}{p_end}
{phang2}{cmd:. cge_nash player firm1, instruments(Q1) maximize((P - c) * Q1) lower(Q1:0)}{p_end}
{phang2}{cmd:. cge_nash player firm2, instruments(Q2) maximize((P - c) * Q2) lower(Q2:0)}{p_end}
{phang2}{cmd:. cge_nash solve, name(cournot)}{p_end}
{phang2}{cmd:. cge_shock, reset}{p_end}
{phang2}{cmd:. cge_nash solve, name(cournot_newton) method(newton)}{p_end}
{phang2}{cmd:. cge_shock, reset}{p_end}
{phang2}{cmd:. cge_nash solve, name(stackelberg) leader(firm1)}{p_end}
{phang2}{cmd:. cge_nash list}{p_end}


{title:Stored results}

{pstd}
{cmd:cge_nash solve} stores {cmd:r(converged)}, {cmd:r(rounds)},
{cmd:r(N_players)}, {cmd:r(name)}, {cmd:r(method)}, and the matrices
{cmd:r(instruments)} and {cmd:r(objectives)}; with {cmd:method(newton)},
{cmd:r(N_solves)} and {cmd:r(second_order)} (1 if every player's objective
is concave in its instruments at the equilibrium); with a leader,
{cmd:r(objective)}, {cmd:r(N_equilibria)}, {cmd:r(leader)} and
{cmd:r(leader_instruments)}.


{title:Also see}

{psee}
{helpb cge_optimize}, {helpb cge_model}, {helpb cge}
{p_end}
