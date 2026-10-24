* Examples of [CGE] cge_model. The economy is illustrative.
*>> model_new
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
*<<

*>> model_describe
cge_model describe
*<<

*>> model_solve
cge_solve, name(eq)
cge_results, sim(eq)
*<<

*>> model_shock
cge_shock e, elements(h1.g1) value(15)
cge_solve, name(more)
cge_results, sim(more)
*<<
