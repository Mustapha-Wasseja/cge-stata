*! cge_ml_exchange.do -- cge-stata model library (version 0.21.0)
*! title: An exchange economy of two goods and two consumers
*! kind: system
*! reference: textbook general equilibrium; Cobb-Douglas utility
*! expect: P(g2) = (0.7 x 10 + 0.4 x 3) / (0.3 x 2 + 0.6 x 8) = 1.5185185
* Two consumers with Cobb-Douglas utility trade two goods from their
* endowments; good 1 is the numeraire, and WALRAS, the excess supply of good
* 1, is zero by Walras's law.
cge_model new
cge_set g = g1 g2
cge_set h = h1 h2
cge_parameter alpha(h,g), values(h1.g1:0.3 h1.g2:0.7 h2.g1:0.6 h2.g2:0.4)
cge_parameter e(h,g), values(h1.g1:10 h1.g2:2 h2.g1:3 h2.g2:8)
cge_variable P(g), value(1)
cge_variable Y(h) = sum(g, P(g) * e(h,g))
cge_variable X(h,g) = alpha(h,g) * Y(h) / P(g)
cge_variable WALRAS, value(0)
cge_equation NUM: P(g1) = 1
cge_equation MKT(g): sum(h, X(h,g)) = sum(h, e(h,g)) + WALRAS
cge_solve, name(exchange)
cge_results, sim(exchange)
