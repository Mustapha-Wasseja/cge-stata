"""Factor efficiency and its link to health services (version 0.1.14)."""

import numpy as np
import pytest

from cge_ref import VARIABLES, Closure, SAMError
from cge_ref.model import NOMINAL
from cge_ref.scenarios import HEALTH_LINK, health_model, synthetic_model
from test_validation import _close


@pytest.fixture(scope="module")
def model():
    return health_model(**HEALTH_LINK)


def test_calibration(model):
    p, b = model.params, model.base
    assert np.isclose(p["hs0"], 30.0)                  # households 12, government 10, fund 8
    assert list(model.exists["EFF"]) == [True, False] and model.exists["HS"][0]
    assert np.allclose(p["eta_h"], [0.3, 0.0]) and np.allclose(p["af"], 1.0)
    assert np.allclose(b["EFF"], 1.0)
    assert model.n_equations == health_model().n_equations + 2
    assert model.max_residual(model.base) < 1e-12
    assert model.solve().iterations == 0


def test_no_link_by_default():
    m = synthetic_model()
    assert not m.exists["EFF"].any() and not m.exists["HS"].any()


def test_homogeneity(model):
    s = model.solve(fixed={"CPI": 2.0})
    for name in VARIABLES:
        exists = model.exists[name]
        factor = 2.0 if name in NOMINAL else 1.0
        assert _close(s[name][exists], factor * model.base[name][exists]), name


def test_more_health_services_raise_labour_efficiency(model):
    C, F = model.sets["C"], model.sets["F"]
    hlt, lab = C.index("com_hlt"), F.index("lab")
    qg = model.params["qg"].copy()
    qg[hlt] *= 1.2
    s = model.solve(Closure(), params={"qg": qg})
    assert s.converged and abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8
    hs = s["QH"][hlt].sum() + s["QG"][hlt] + s["QSHI"][hlt]
    assert np.isclose(s["HS"][0], hs)
    assert np.isclose(s["EFF"][lab], (hs / 30.0) ** 0.3) and s["EFF"][lab] > 1
    # Real value added rises more than without the link
    plain = health_model().solve(Closure(), params={"qg": qg})
    real_va = lambda v: model.base["PVA"] @ v["QVA"]
    assert real_va(s.values) > real_va(plain.values)


def test_exogenous_efficiency_equals_effective_labour_supply():
    # Without the link, labour 2 per cent less efficient gives the same real
    # outcome as 2 per cent less labour, with wages per worker 2 per cent lower
    # than wages per efficiency unit
    m = health_model()
    lab = m.sets["F"].index("lab")
    af = m.params["af"].copy()
    af[lab] = 0.98
    a = m.solve(Closure(), params={"af": af})
    qfs = m.base["QFS"].copy()
    qfs[lab] *= 0.98
    q = m.solve(Closure(), fixed={"QFS": qfs})
    assert a.converged and q.converged
    for name in ("QA", "QVA", "QQ", "QH", "YF", "PQ"):
        assert np.allclose(a[name], q[name], rtol=1e-9), name
    assert np.isclose(a["W"][lab], 0.98 * q["W"][lab], rtol=1e-9)
    assert np.allclose(a["QF"][lab], q["QF"][lab] / 0.98, rtol=1e-9)


@pytest.mark.parametrize("settings, error, message", [
    ({"health_elasticities": {"lab": 0.3}}, ValueError, "health_commodities"),
    ({"health_commodities": ["com_xyz"], "health_elasticities": 0.3}, ValueError, "not commodities"),
    ({"health_commodities": ["com_hlt"], "health_elasticities": {"land": 0.3}}, ValueError, "not factors"),
    ({"health_commodities": ["com_hlt"], "health_elasticities": -0.1}, ValueError, "zero or positive"),
])
def test_errors(settings, error, message):
    with pytest.raises(error, match=message):
        health_model(**settings)


def test_health_services_without_consumption():
    # com_hlt bought only by activities: no health services consumed
    from cge_ref import SAM, Model
    from cge_ref.scenarios import HEALTH_SAM, TEST_ELASTICITIES, health_mapping
    sam = SAM.from_csv(HEALTH_SAM)
    values = sam.values.copy()
    i = sam.labels.index
    for col, x in (("hhd", 12), ("gov", 10), ("shi", 8)):
        values[i("com_hlt"), i(col)] -= x
        values[i("com_ser"), i(col)] += x
    for act, x in (("act_ser", 18), ("act_man", 12)):
        values[i("com_hlt"), i(act)] += x
        values[i("com_ser"), i(act)] -= x
    with pytest.raises(SAMError, match="no consumption"):
        Model(SAM(sam.labels, values), health_mapping(), **TEST_ELASTICITIES, **HEALTH_LINK)
