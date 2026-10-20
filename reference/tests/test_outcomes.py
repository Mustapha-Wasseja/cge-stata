"""Health outcomes, days worked and demography (version 0.3.4,
model_spec.md, Section 15)."""

import numpy as np
import pytest

from cge_ref.dynamics import Dynamics, run
from cge_ref.model import Closure
from cge_ref.report import report
from cge_ref.scenarios import OUTCOMES, dynamic_cases, health_model, outcome_cases, synthetic_model


@pytest.fixture(scope="module")
def cases():
    return outcome_cases()


def health_rows(sol):
    return {(m, e): x for t, m, e, b, x in report(sol) if t == "health"}


def test_calibration():
    m = health_model(**OUTCOMES)
    lab = m.sets["F"].index("lab")
    assert m.exists["HS"].all() and m.exists["DW"][lab] and not m.exists["DW"][1 - lab]
    assert not m.exists["EFF"].any()
    assert m.solve(Closure()).iterations == 0
    rows = health_rows(m.solve(Closure()))
    assert rows[("sick_day_share", "lab")] == pytest.approx(5.0)
    assert rows[("mortality_rate", "")] == pytest.approx(10.0)
    assert rows[("population", "")] == 1.0 and rows[("services_per_head", "")] == 1.0


def test_days_worked_equation(cases):
    for name, s in cases.items():
        assert s.converged and abs(s.gdp_gap()) < 1e-10, name
        p = s.params
        ratio = s["HS"][0] / p["hs0"]
        lab = s.model.sets["F"].index("lab")
        dw = (1 - p["sick"][lab] * ratio ** p["eps_s"][lab]) / (1 - p["sick0"][lab])
        assert s["DW"][lab] == pytest.approx(dw, rel=1e-12), name
    # More health services: fewer days lost, a lower death rate
    rows = health_rows(cases["hout_gov_health_up20"])
    assert rows[("sick_day_share", "lab")] < 5 and rows[("mortality_rate", "")] < 10
    assert rows[("days_worked", "lab")] > 1


def test_days_worked_act_as_efficiency_per_worker(cases):
    """The solution with days lost is the solution without them in which labour
    efficiency equals the days worked (Section 15.2)."""
    s = cases["hout_epidemic"]
    plain = health_model()
    lab = plain.sets["F"].index("lab")
    af = np.ones(2)
    af[lab] = s["DW"][lab]
    other = plain.solve(Closure(), tol=1e-12, params={"af": af})
    for var in ("QA", "QVA", "W", "QFS", "PQ", "EH"):
        assert np.allclose(other[var], s[var], rtol=1e-9), var
    # an epidemic doubles the share of days lost (less the response of health services)
    assert s["DW"][lab] < (1 - 0.10) / 0.95 + 0.01 and s["DW"][lab] < 1


def test_outcomes_with_zero_elasticities_need_no_health_commodities():
    m = synthetic_model(sick_days={"lab": 0.05}, mortality=0.01)
    assert not m.exists["HS"].any()
    lab = m.sets["F"].index("lab")
    s = m.solve(Closure(), tol=1e-12, params={"sick": np.where(np.arange(2) == lab, 0.1, 0.0)})
    assert s["DW"][lab] == pytest.approx(0.9 / 0.95, rel=1e-14)
    assert health_rows(s)[("mortality_rate", "")] == pytest.approx(10.0)


def test_mortality_has_no_effect_within_a_period(cases):
    s = cases["hout_mortality_up50"]
    assert s.iterations == 0
    assert health_rows(s)[("mortality_rate", "")] == pytest.approx(15.0)


def test_the_efficiency_link_and_days_worked_combine(cases):
    s = cases["hboth_gov_health_up20"]
    p = s.params
    lab = s.model.sets["F"].index("lab")
    ratio = s["HS"][0] / p["hs0"]
    assert s["EFF"][lab] == pytest.approx(ratio ** 0.3, rel=1e-12)
    assert s["DW"][lab] > 1


@pytest.mark.parametrize("name", ["dyn_hout", "dyn_hout_health"])
def test_population_and_labour_respond_to_deaths(name):
    model, settings, closure, shocks = dynamic_cases()[name]
    r = run(model, settings, closure, shocks)
    lab = model.sets["F"].index("lab")
    k = 0.3 / 0.55
    for prev, sol in zip(r.solutions[:-1], r.solutions[1:]):
        pp = prev.params
        mr = float(pp["mort"] * (prev["HS"][0] / pp["hs0"]) ** pp["eps_m"])
        g = 0.02 + (0.01 - mr)
        assert sol.params["pop"] / pp["pop"] - 1 == pytest.approx(g, rel=1e-12)
        assert sol.params["hs0"] / pp["hs0"] - 1 == pytest.approx(g, rel=1e-12)
        assert sol["QFS"][lab] / prev["QFS"][lab] - 1 == pytest.approx(0.02 + k * (0.01 - mr), rel=1e-12)
    # More health services from period 1: fewer deaths and a larger population from period 2
    base = run(*dynamic_cases()["dyn_hout"][:3])
    if name == "dyn_hout_health":
        assert r.solutions[1].params["pop"] == pytest.approx(base.solutions[1].params["pop"], rel=1e-15)
        assert r.solutions[2].params["pop"] > base.solutions[2].params["pop"]
        assert r.solutions[2]["QFS"][lab] > base.solutions[2]["QFS"][lab]


def test_without_a_death_rate_dynamics_are_unchanged():
    std = synthetic_model()
    common = {"capital": {"cap": (0.05, 0.15)}, "factor_growth": {"lab": 0.02}, "population_growth": 0.02}
    closure = Closure(factors={"cap": "specific"})
    a = run(std, Dynamics(periods=2, **common), closure)
    b = run(synthetic_model(sick_days={"lab": 0.05}), Dynamics(periods=2, **common), closure)
    assert np.allclose(a.solutions[2]["QA"], b.solutions[2]["QA"], rtol=1e-12)
    assert b.solutions[2].params["pop"] == pytest.approx(1.02 ** 2)


def test_errors():
    with pytest.raises(ValueError, match="below 1"):
        synthetic_model(sick_days={"lab": 1.0})
    with pytest.raises(ValueError, match="have no sick days"):
        synthetic_model(sick_days={"lab": 0.05}, sick_elasticity={"cap": -0.2})
    with pytest.raises(ValueError, match="needs mortality"):
        synthetic_model(mortality_elasticity=-0.3)
    with pytest.raises(ValueError, match="health_commodities"):
        synthetic_model(sick_days={"lab": 0.05}, sick_elasticity=-0.2)
    with pytest.raises(ValueError, match="not factors"):
        synthetic_model(sick_days={"xyz": 0.05})
    closure = Closure(factors={"cap": "specific"})
    with pytest.raises(ValueError, match="no death rate"):
        run(synthetic_model(), Dynamics(periods=1, death_factors=("lab",), death_share=0.3), closure)
    m = synthetic_model(mortality=0.01)
    with pytest.raises(ValueError, match="capital factor"):
        run(m, Dynamics(periods=1, capital={"cap": (0.05, 0.15)}, death_factors=("cap",)), closure)
    with pytest.raises(ValueError, match="death_share"):
        run(m, Dynamics(periods=1, death_factors=("lab",), death_share=1.5), closure)
    with pytest.raises(ValueError, match="unemployed"):
        run(m, Dynamics(periods=1, death_factors=("lab",)), Closure(factors={"lab": "unemployed"}))
