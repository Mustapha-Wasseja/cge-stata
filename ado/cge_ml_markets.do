*! cge_ml_markets.do -- cge-stata model library (version 0.21.0)
*! title: Two markets solved block by block with named models
*! kind: system
*! reference: GAMS-style model statements over subsets of equations
*! expect: P = (a / 2)^(2/5): 1.9036539 and 2.5118864; total sales 31.501 in both solves
cge_model new
cge_set g = g1 g2
cge_parameter a(g), values(g1:10 g2:20)
cge_variable P(g), value(1)
cge_variable Q(g), value(1)
cge_equation DEM(g): Q(g) = a(g) / sqrt(P(g))
cge_equation SUP(g): Q(g) = 2 * P(g)^2
cge_variable TOT = sum(g, P(g) * Q(g))
cge_model define markets = DEM SUP
cge_model define total = TOT
cge_solve, name(markets) model(markets)
cge_solve, name(total) model(total) from(markets) hold(P Q)
cge_solve, name(whole)
cge_results, sim(whole)
