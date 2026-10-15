"""Linear expenditure system (LES) household demand (version 0.1.11)."""

import numpy as np
import pytest

from cge_ref import VARIABLES, Closure
from cge_ref.model import NOMINAL
from cge_ref.scenarios import LES_SETTINGS, institutions_model, synthetic_model
from test_validation import _close


@pytest.fixture(scope="module")
def model():
    return synthetic_model(**LES_SETTINGS)


def test_calibration(model):
    p, b = model.params, model.base
    w = b["QH"] / b["EH"][None, :]
    assert np.allclose(p["beta"].sum(axis=0), 1.0)
    eps = np.array([LES_SETTINGS["income_elasticities"][c] for c in model.sets["C"]])
    used = p["beta"][:, 0] / w[:, 0]
    assert np.allclose(used / used[0], eps / eps[0])          # proportional to those supplied
    supernumerary = b["EH"] - b["PQ"] @ p["gamma"]
    assert np.allclose(-b["EH"] / supernumerary, LES_SETTINGS["frisch"])
    assert model.max_residual(model.base) < 1e-12
    assert model.solve().iterations == 0


def test_cobb_douglas_is_the_default():
    m = synthetic_model()
    assert not m.params["gamma"].any()


def test_homogeneity(model):
    s = model.solve(fixed={"CPI": 2.0})
    assert s.converged
    for name in VARIABLES:
        exists = model.exists[name]
        factor = 2.0 if name in NOMINAL else 1.0
        assert _close(s[name][exists], factor * model.base[name][exists]), name


def test_budget_shares_change_with_income(model):
    # More transfers from abroad: the share of the luxury (com_ser) rises and
    # the share of the necessity (com_agr) falls
    s = model.solve(Closure(), params={"trdr": model.params["trdr"] * 3})
    assert s.converged
    C = model.sets["C"]
    share = lambda v: (v["PQ"] * v["QH"][:, 0]) / v["EH"][0]
    assert share(s.values)[C.index("com_ser")] > share(model.base)[C.index("com_ser")]
    assert share(s.values)[C.index("com_agr")] < share(model.base)[C.index("com_agr")]


def test_equivalent_variation_from_utility(model):
    # Utility after the shock, U = prod (QH - gamma)^beta, equals utility at base
    # prices with consumption spending raised by the equivalent variation
    s = model.solve(Closure(), params={"pwm": model.params["pwm"] * 1.1})
    p, b = model.params, model.base
    beta, gamma = p["beta"][:, 0], p["gamma"][:, 0]
    u1 = np.prod((s["QH"][:, 0] - gamma) ** beta)
    ev = s.equivalent_variation()[0]
    budget = b["EH"][0] + ev
    qh = gamma + beta * (budget - b["PQ"] @ gamma) / b["PQ"]
    assert np.isclose(np.prod((qh - gamma) ** beta), u1, rtol=1e-10)


def test_several_households():
    m = institutions_model(income_elasticities=LES_SETTINGS["income_elasticities"], frisch=[-2.0, -3.0])
    supernumerary = m.base["EH"] - m.base["PQ"] @ m.params["gamma"]
    assert np.allclose(-m.base["EH"] / supernumerary, [-2.0, -3.0])
    s = m.solve(Closure(), params={"tm": np.zeros_like(m.params["tm"])})
    assert s.converged and abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8


@pytest.mark.parametrize("settings, message", [
    ({"income_elasticities": {"com_agr": 0.6, "com_man": 1.0, "com_ser": 1.4}}, "Frisch"),
    ({"frisch": -0.5}, "below -1"),
    ({"frisch": -2.0, "income_elasticities": 0.0}, "positive"),
])
def test_errors(settings, message):
    with pytest.raises(ValueError, match=message):
        synthetic_model(**settings)
