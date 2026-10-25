*! cge_ml_hs071.do -- cge-stata model library (version 0.21.0)
*! title: Hock and Schittkowski's problem 71, a nonlinear programme with bounds
*! kind: nlp
*! reference: Hock and Schittkowski (1981), problem 71
*! expect: minimum 17.0140173 at (1, 4.7429994, 3.8211503, 1.3794082)
* min x1 x4 (x1 + x2 + x3) + x3 subject to x1 x2 x3 x4 >= 25 (an equation
* with a slack S >= 0), sum x^2 = 40 and 1 <= x <= 5.
cge_model new
cge_set i = x1 x2 x3 x4
cge_parameter x0(i), values(x1:1 x2:5 x3:5 x4:1)
cge_variable X(i), value(x0(i))
cge_variable S, value(0)
cge_equation G1: X(x1) * X(x2) * X(x3) * X(x4) - S = 25
cge_equation G2: sum(i, X(i)^2) = 40
cge_bound X, lower(1) upper(5)
cge_bound S, lower(0)
cge_solve, name(hs071) minimize(X(x1) * X(x4) * (X(x1) + X(x2) + X(x3)) + X(x3))
matrix list r(marginals)
cge_results, sim(hs071)
