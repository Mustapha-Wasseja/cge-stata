*! cge_ml_ras.do -- cge-stata model library (version 0.21.0)
*! title: Balancing a matrix by cross entropy, whose solution is the RAS balance
*! kind: nlp
*! reference: McDougall (1999), Entropy theory and RAS are friends
*! expect: minimum cross entropy 1.81258200; X = r(r) A(r,c) s(c)
* A prior matrix A is balanced to new row and column totals by minimising
* sum X ln(X / A); one column equation is left out, as the totals agree.
cge_model new
cge_set r = r1 r2 r3
cge_set c = c1 c2 c3 c4
cge_parameter a(r,c), values(r1.c1:10 r1.c2:5 r1.c3:2 r1.c4:8 r2.c1:3 r2.c2:12 r2.c3:6 r2.c4:1 r3.c1:4 r3.c2:2 r3.c3:9 r3.c4:7)
cge_parameter u(r), values(r1:30 r2:20 r3:19)
cge_parameter v(c), values(c1:20 c2:21 c3:16 c4:12)
cge_variable X(r,c), value(a(r,c))
cge_equation ROW(r): sum(c, X(r,c)) = u(r)
cge_equation COL(c)$(ord(c) < card(c)): sum(r, X(r,c)) = v(c)
cge_bound X, lower(0)
cge_solve, name(ras) minimize(sum((r,c), X(r,c) * ln(X(r,c) / a(r,c))))
cge_results, sim(ras)
