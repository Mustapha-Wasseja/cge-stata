*! cge_ml_transport.do -- cge-stata model library (version 0.21.0)
*! title: Dantzig's transportation problem: least-cost shipments, a linear programme
*! kind: nlp
*! reference: Dantzig (1963), Linear Programming and Extensions, section 3.3
*! expect: minimum cost 153.675 (thousands of dollars)
* Two plants ship cases to three markets at 90 dollars per case per thousand
* miles; supplies are limits (equations with slacks SS >= 0) and demands are
* floors (surpluses SD >= 0).
cge_model new
cge_set i = seattle san_diego
cge_set j = new_york chicago topeka
cge_parameter a(i), values(seattle:350 san_diego:600)
cge_parameter b(j), values(new_york:325 chicago:300 topeka:275)
cge_parameter d(i,j), values(seattle.new_york:2.5 seattle.chicago:1.7 seattle.topeka:1.8 san_diego.new_york:2.5 san_diego.chicago:1.8 san_diego.topeka:1.4)
cge_parameter f = 90
cge_parameter c(i,j) = f * d(i,j) / 1000
cge_variable X(i,j), value(100)
cge_variable SS(i), value(10)
cge_variable SD(j), value(10)
cge_equation SUPPLY(i): sum(j, X(i,j)) + SS(i) = a(i)
cge_equation DEMAND(j): sum(i, X(i,j)) - SD(j) = b(j)
cge_bound X, lower(0)
cge_bound SS, lower(0)
cge_bound SD, lower(0)
cge_solve, name(transport) minimize(sum((i,j), c(i,j) * X(i,j)))
matrix list r(marginals)
cge_results, sim(transport)
