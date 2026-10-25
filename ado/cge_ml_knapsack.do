*! cge_ml_knapsack.do -- cge-stata model library (version 0.21.0)
*! title: A knapsack of eight items: binary choices, a mixed-integer programme
*! kind: minlp
*! reference: textbook integer programming
*! expect: maximum value 43, items 2, 3, 4, 6 and 8 (the only optimum)
cge_model new
cge_set i = i1 i2 i3 i4 i5 i6 i7 i8
cge_parameter v(i), values(i1:15 i2:12 i3:11 i4:5 i5:13 i6:9 i7:10 i8:6)
cge_parameter w(i), values(i1:8 i2:5 i3:6 i4:3 i5:7 i6:4 i7:6 i8:2)
cge_parameter cap = 20
cge_variable X(i), value(0.5)
cge_variable S, value(1)
cge_equation CAP: sum(i, w(i) * X(i)) + S = cap
cge_bound X, binary
cge_bound S, lower(0)
cge_solve, name(knapsack) maximize(sum(i, v(i) * X(i)))
cge_results, sim(knapsack)
