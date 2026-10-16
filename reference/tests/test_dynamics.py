"""Recursive dynamics (version 0.2.0; docs/model_spec.md, Section 10)."""

import numpy as np
import pytest

from cge_ref import Closure
from cge_ref.dynamics import Dynamics, real_value_added, run
from cge_ref.scenarios import HEALTH_LINK, health_model, institutions_model, synthetic_model

SPECIFIC = Closure(factors={"cap": "specific"})


@pytest.fixture(scope="module")
def std():
    return synthetic_model()


def test_no_growth_stays_at_the_base(std):
    r = run(std, Dynamics(periods=3), SPECIFIC)
    for s in r.solutions:
        for name in ("QA", "PQ", "QF", "EH"):
            assert np.allclose(s[name], std.base[name], rtol=1e-10), name


def test_capital_accumulation_and_allocation(std):
    d = Dynamics(periods=3, capital={"cap": (0.05, 0.15)}, factor_growth={"lab": 0.02})
    r = run(std, d, SPECIFIC)
    cap = std.sets["F"].index("cap")
    for t in range(1, 4):
        prev, now = r.solutions[t - 1], r.solutions[t]
        inv = std.base["PQ"] @ prev["QINV"]
        assert np.isclose(now["QF"][cap].sum(), 0.95 * prev["QF"][cap].sum() + 0.15 * inv)
        # More new capital, relative to its stock, where the rental rate is above average
        new = now["QF"][cap] - 0.95 * prev["QF"][cap]
        rent = prev["W"][cap] * prev["WFDIST"][cap]
        s = prev["QF"][cap] / prev["QF"][cap].sum()
        above = rent > s @ rent
        ratio = (new / new.sum()) / s
        assert np.all(ratio[above] >= 1 - 1e-12) and np.all(ratio[~above] <= 1 + 1e-12)
        lab = std.sets["F"].index("lab")
        assert np.isclose(now["QFS"][lab], 1.02 * prev["QFS"][lab])


def test_gdp_target_and_baseline_path(std):
    d = Dynamics(periods=3, capital={"cap": (0.05, 0.15)}, factor_growth={"lab": 0.02}, gdp_target=0.04)
    base = run(std, d, SPECIFIC)
    for t in range(1, 4):
        g = real_value_added(std, base.solutions[t].values) / real_value_added(std, base.solutions[t - 1].values)
        assert abs(g - 1.04) < 1e-11
    again = run(std, Dynamics(**{**d.__dict__, "gdp_target": None, "tfp_path": base.tfp_path}), SPECIFIC)
    for a, b in zip(base.solutions, again.solutions):
        assert np.allclose(a["QA"], b["QA"], rtol=1e-10)


def test_population_and_flows():
    m = institutions_model(income_elasticities={"com_agr": 0.6, "com_man": 1.0, "com_ser": 1.4}, frisch=[-2.0, -3.0])
    d = Dynamics(periods=2, capital={"cap": (0.06, 0.12)}, factor_growth={"lab": 0.025}, population_growth=0.025,
                 government_growth=0.03, foreign_growth=0.02)
    r = run(m, d)
    assert all(s.converged for s in r.solutions)
    assert np.allclose(r.solutions[2].params["gamma"], m.params["gamma"] * 1.025 ** 2)
    assert np.allclose(r.solutions[2].params["qg"], m.params["qg"] * 1.03 ** 2)
    assert np.isclose(r.solutions[2]["FSAV"][0], m.base["FSAV"][0] * 1.02 ** 2)
    assert abs(r.solutions[2]["WALRAS"][0]) < 1e-8 and abs(r.solutions[2].gdp_gap()) < 1e-8


def test_shocks_and_health():
    m = health_model(**HEALTH_LINK)
    d = Dynamics(periods=3, capital={"cap": (0.05, 0.15)}, factor_growth={"lab": 0.02}, population_growth=0.02,
                 gdp_target=0.03)
    base = run(m, d, SPECIFIC)
    assert np.isclose(base.solutions[3].params["hs0"], m.params["hs0"] * 1.02 ** 3)

    def donor_exit(t, p, fx):
        if t >= 2:
            p["trshir"] = np.array(0.0)

    scen = run(m, Dynamics(**{**d.__dict__, "gdp_target": None, "tfp_path": base.tfp_path}), SPECIFIC,
               shocks=donor_exit)
    assert np.allclose(scen.solutions[1]["QA"], base.solutions[1]["QA"], rtol=1e-10)
    assert scen.solutions[2]["SHIADJ"][0] < base.solutions[2]["SHIADJ"][0]


@pytest.mark.parametrize("settings, closure, message", [
    ({"capital": {"land": (0.05, 0.15)}}, SPECIFIC, "not a factor"),
    ({"capital": {"lab": (0.05, 0.15)}}, Closure(factors={"lab": "unemployed"}), "unemployed"),
    ({"capital": {"cap": (0.05, 0.15)}, "factor_growth": {"cap": 0.01}}, SPECIFIC, "capital factor"),
])
def test_errors(std, settings, closure, message):
    with pytest.raises(ValueError, match=message):
        run(std, Dynamics(periods=1, **settings), closure)
