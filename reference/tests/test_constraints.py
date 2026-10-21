"""Bounds and complementarity (version 0.4.4; docs/model_spec.md, Section 16)."""

import numpy as np
import pytest

from cge_ref import Closure
from cge_ref.model import VARIABLES, Constraint
from cge_ref.scenarios import constraint_cases, constraint_solutions, synthetic_model


@pytest.fixture(scope="module")
def solutions():
    return constraint_solutions()


def _same(a, b, rel=1e-8, skip=()):
    for name in VARIABLES:
        if name in skip:
            continue
        x, y = a[name], b[name]
        assert np.all(np.abs(x - y) <= rel * np.maximum(1.0, np.abs(y))), name


def _gaps(solution, cons):
    """g and h of each constraint at a solution (Section 16.2)."""
    m = solution.model
    out = []
    for c in cons:
        k = m._constraint(c, solution.closure.fixed(m))
        y = solution[k["y"][0]].ravel()[k["y"][1]]
        x = solution[k["x"][0]].ravel()[k["x"][1]]
        out.append((k["sigma"] * (k["bound"] - y) / k["sy"], k["delta"] * (x - m.base[k["x"][0]].ravel()[k["x"][1]])
                    / k["sx"]))
    return out


def test_complementarity_and_identities(solutions):
    for name, (model, closure, shock, cons) in constraint_cases().items():
        s = solutions[name]
        assert s.converged, name
        assert abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8, name
        for (g, h), binding in zip(_gaps(s, cons), s.binding):
            assert g >= -1e-9 and h >= -1e-9, name
            assert abs(g if binding else h) < 1e-9, name
    assert [solutions[n].binding for n in ("con_quota", "con_quota_slack", "con_quota_base", "con_two")] == \
        [[True], [False], [False], [True, True]]


def test_quota_is_a_tariff_whose_revenue_is_a_rent(solutions):
    # With the rent paid to the government, the quota gives the allocation of
    # the tariff equal to its premium
    q = solutions["con_quota"]
    m = q.model
    man = m.sets["C"].index("com_man")
    tm = np.zeros_like(m.params["tm"])
    tm[man] = q["RM"][man]
    t = m.solve(tol=1e-12, params={"tm": tm})
    _same(q, t, skip=("RM", "QM"))
    assert q["QM"][man] == pytest.approx(1.02 * m.base["QM"][man], rel=1e-10)
    assert q["RM"][man] > 0
    # A quota that does not bind, or one at base imports without a shock,
    # changes nothing
    free = m.solve(tol=1e-12, params={"tm": np.zeros_like(tm)})
    _same(solutions["con_quota_slack"], free)
    base = solutions["con_quota_base"]
    for name in VARIABLES:
        assert np.allclose(base[name], m.base[name], rtol=1e-10, atol=1e-10), name


def test_rents_go_to_their_recipient(solutions):
    gov, hhd, row = (solutions[n] for n in ("con_quota", "con_quota_hhd", "con_quota_row"))
    man = gov.model.sets["C"].index("com_man")

    def rent(s):
        return s["RM"][man] * s["EXR"][0] * s["QM"][man]

    # every premium clears the same quota, but the recipients spend the rent
    # differently, so the premiums differ
    for s in (gov, hhd, row):
        assert s["QM"][man] == pytest.approx(1.02 * s.model.base["QM"][man], rel=1e-10)
    assert len({round(s["RM"][man], 6) for s in (gov, hhd, row)}) == 3
    # paid abroad, the rent is a payment in the balance of payments
    assert row.params["rent_m"][-1, man] == 1 and hhd.params["rent_m"][len(hhd.model.sets["F"]), man] == 1
    assert rent(row) > 0


def test_closure_switches_match_fixed_closures(solutions):
    m = synthetic_model()
    b, p = m.base, m.params
    # A binding wage floor is unemployment at the fixed wage
    unemployed = m.solve(Closure(factors={"lab": "unemployed"}), tol=1e-12, params={"pwm": p["pwm"] * 1.1})
    _same(solutions["con_wage_floor"], unemployed)
    # A binding borrowing limit under a peg is a flexible exchange rate with
    # foreign savings at the limit
    flex = m.solve(tol=1e-12, params={"pwe": p["pwe"] * 0.8}, fixed={"FSAV": 2 * b["FSAV"]})
    _same(solutions["con_peg_limit"], flex)
    assert solutions["con_peg_limit"]["EXR"][0] > 1
    # A binding ban on borrowing with direct taxes adjusting is fixed
    # government savings at zero
    fix = m.solve(Closure(government="fixgsav"), tol=1e-12, params={"tm": np.zeros_like(p["tm"])},
                  fixed={"GSAV": np.zeros(1)})
    _same(solutions["con_deficit_tax"], fix)
    assert solutions["con_deficit_spending"]["GADJ"][0] < 1
    assert solutions["con_deficit_spending"]["GSAV"][0] == pytest.approx(0, abs=1e-9)


def test_capacity(solutions):
    s = solutions["con_capacity"]
    a = s.model.sets["A"].index("act_ser")
    assert s["QA"][a] == pytest.approx(1.01 * s.model.base["QA"][a], rel=1e-10)
    assert s["RA"][a] > 0
    h = solutions["con_health_capacity"]
    a = h.model.sets["A"].index("act_hlt")
    assert h["QA"][a] == pytest.approx(1.03 * h.model.base["QA"][a], rel=1e-10) and h["RA"][a] > 0


def test_a_premium_set_by_hand_acts_as_a_tariff():
    m = synthetic_model()
    man = m.sets["C"].index("com_man")
    tm = m.params["tm"].copy()
    tm[man] += 0.05
    t = m.solve(tol=1e-12, params={"tm": tm})
    premium = np.zeros_like(tm)
    premium[man] = 0.05
    r = m.solve(tol=1e-12, fixed={"RM": premium})
    _same(r, t, skip=("RM",))


def test_errors():
    m = synthetic_model()
    b = m.base
    with pytest.raises(ValueError, match="upper or a lower"):
        m.solve(constraints=[Constraint("QM", ("com_man",), upper=1.0, lower=0.5)])
    with pytest.raises(ValueError, match="fixed under the closure"):
        m.solve(constraints=[Constraint("FSAV", (), upper=1.0, adjust="EXR", direction="up")])
    with pytest.raises(ValueError, match="not fixed under the closure"):
        m.solve(constraints=[Constraint("GSAV", (), lower=0.0, adjust="EXR", direction="up")])
    with pytest.raises(ValueError, match="direction"):
        m.solve(constraints=[Constraint("GSAV", (), lower=0.0, adjust="GADJ")])
    with pytest.raises(ValueError, match="give the adjusting variable"):
        m.solve(constraints=[Constraint("QD", ("com_man",), upper=1.0)])
    with pytest.raises(ValueError, match="only for rent variables"):
        m.solve(constraints=[Constraint("GSAV", (), lower=0.0, adjust="GADJ", direction="down", rents="hhd")])
    with pytest.raises(ValueError, match="not an element"):
        m.solve(constraints=[Constraint("QM", ("com_xyz",), upper=1.0)])
    with pytest.raises(ValueError, match="is not a factor, household"):
        m.solve(constraints=[Constraint("QM", ("com_man",), upper=b["QM"][1], rents="tax_dir")])
