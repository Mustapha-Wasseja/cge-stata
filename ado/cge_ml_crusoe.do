*! cge_ml_crusoe.do -- cge-stata model library (version 0.21.0)
*! title: Robinson Crusoe: consumption and leisure, a planner's nonlinear programme
*! kind: nlp
*! reference: textbook one-agent economy; Cobb-Douglas utility and technology
*! expect: labour N = a b T / (a b + 1 - a) = 3.3333333, consumption 2 sqrt(N) = 3.6514837
* Crusoe divides T = 10 hours between labour N and leisure L, and produces
* C = A N^b; he maximises a ln C + (1 - a) ln L. With a = b = 1/2 and A = 2,
* the optimum is N = 10/3.
cge_model new
cge_parameter a = 0.5
cge_parameter b = 0.5
cge_parameter A = 2
cge_parameter T = 10
cge_variable N, value(5)
cge_variable L, value(5)
cge_variable C = A * N^b
cge_equation TIME: N + L = T
cge_bound N, lower(0)
cge_bound L, lower(0)
cge_solve, name(crusoe) maximize(a * ln(C) + (1 - a) * ln(L))
cge_results, sim(crusoe)
