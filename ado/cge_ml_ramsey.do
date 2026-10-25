*! cge_ml_ramsey.do -- cge-stata model library (version 0.26.0)
*! title: A Ramsey growth model: optimal saving over 30 years, a nonlinear programme
*! kind: nlp
*! reference: Ramsey (1928); Cass (1965) and Koopmans (1965), with a finite horizon
*! expect: the Euler equation C(t+1)/C(t) = beta (1 - delta + alpha K(t+1)^(alpha - 1)) holds; capital rises from 1 toward K* = 3.161
* A planner chooses consumption C(t) over 30 years to maximise the
* discounted sum of ln C(t); output K^alpha is consumed or added to capital,
* which depreciates at rate delta; capital starts at 1 and ends at the steady
* state K* = (alpha / (1/beta - 1 + delta))^(1/(1 - alpha)). Capital
* accumulates from each year to the next, K(t+1), in every year but the last
* (from version 0.26.0; before, over a set of pairs of consecutive years).
local years
forvalues y = 1/30 {
    local years `years' y`y'
}
cge_model new
cge_set t = `years'
cge_parameter alpha = 0.33
cge_parameter beta = 0.95
cge_parameter delta = 0.1
cge_parameter k0 = 1
cge_parameter kss = (alpha / (1 / beta - 1 + delta))^(1 / (1 - alpha))
cge_variable K(t), value(2)
cge_variable C(t), value(1)
cge_equation K0: K(y1) = k0
cge_equation ACC(t)$(ord(t) < card(t)): K(t+1) = (1 - delta) * K(t) + K(t)^alpha - C(t)
cge_equation TERM: C(y30) = (1 - delta) * K(y30) + K(y30)^alpha - kss
cge_bound K, lower(0)
cge_bound C, lower(0)
cge_solve, name(ramsey) maximize(sum(t, beta^(ord(t) - 1) * ln(C(t))))
cge_results, sim(ramsey)
