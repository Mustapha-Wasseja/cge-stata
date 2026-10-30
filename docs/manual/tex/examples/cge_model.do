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

*>> model_named
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
cge_model describe markets
cge_solve, name(mk) model(markets)
cge_results, sim(mk)
display (10 / 2)^(2/5) "  " (20 / 2)^(2/5)
cge_solve, name(tt) model(total) from(mk) hold(P Q)
cge_solve, name(full)
cge_results, sim(full)
*<<

*>> model_roles
cge_model new
cge_set c = g1 g2 g3
cge_set h = h1 h2
cge_parameter alpha(c,h), values(g1.h1:0.5 g2.h1:0.3 g3.h1:0.2 g1.h2:0.2 g2.h2:0.3 g3.h2:0.5)
cge_parameter ybar(h), values(h1:100 h2:50)
cge_parameter A(c) = sum(h, alpha(c,h) * ybar(h))
cge_variable P(c), value(1)
cge_variable Y(h) = ybar(h)
cge_variable X(c) = A(c) * P(c)
cge_variable Q(c,h) = alpha(c,h) * Y(h) / P(c)
cge_equation MKT(c): sum(h, Q(c,h)) = X(c)
cge_model roles, groups(h) goods(c) prices(P) consumption(Q) income(Y)
*<<
