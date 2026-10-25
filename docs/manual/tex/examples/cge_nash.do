* Examples of [CGE] cge_nash. The market is illustrative.
*>> nash_cournot
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
*<<
