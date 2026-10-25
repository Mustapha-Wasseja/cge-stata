*! cge_ml_cournot.do -- cge-stata model library (version 0.21.0)
*! title: Cournot duopoly and a Stackelberg leader, Nash equilibria
*! kind: nash
*! reference: Cournot (1838); von Stackelberg (1934); textbook closed forms
*! expect: Cournot (a - c) / 3b = 3 each; leader (a - c) / 2b = 4.5, follower 2.25
cge_model new
cge_parameter a = 10
cge_parameter b = 1
cge_parameter c = 1
cge_variable Q1, value(1) fixed
cge_variable Q2, value(1) fixed
cge_variable P = a - b * (Q1 + Q2)
cge_nash player firm1, instruments(Q1) maximize((P - c) * Q1) lower(Q1:0)
cge_nash player firm2, instruments(Q2) maximize((P - c) * Q2) lower(Q2:0)
cge_nash solve, name(cournot)
cge_shock, reset
cge_nash solve, name(stackelberg) leader(firm1)
cge_results, sim(stackelberg)
