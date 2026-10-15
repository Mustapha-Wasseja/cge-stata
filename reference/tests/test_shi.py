"""Social health insurance fund with contributions on factor income (version 0.1.13)."""

import numpy as np
import pytest

from cge_ref import SAM, VARIABLES, Closure, Model, SAMError
from cge_ref.model import NOMINAL
from cge_ref.scenarios import HEALTH_SAM, TEST_ELASTICITIES, health_mapping, health_model
from test_validation import _close


@pytest.fixture(scope="module")
def model():
    return health_model()


def test_calibration(model):
    p, b = model.params, model.base
    F, C = model.sets["F"], model.sets["C"]
    lab = F.index("lab")
    assert model.sets["I"][-1] == "shi"
    assert np.isclose(p["tshi"][lab], 6 / 135) and p["tshi"][F.index("cap")] == 0
    assert np.isclose(p["shif"][0, lab], 1.0) and not p["shif"][-1].any()
    assert np.isclose(b["YSHI"][0], 9.0) and np.isclose(p["sshi"], 1 / 9)
    assert np.isclose(b["QSHI"][C.index("com_hlt")], 8.0)
    assert model.max_residual(model.base) < 1e-12
    assert model.solve().iterations == 0


def test_no_fund_by_default():
    from cge_ref.scenarios import synthetic_model
    m = synthetic_model()
    assert not m.params["tshi"].any() and not m.exists["YSHI"].any() and not m.exists["QSHI"].any()


def test_homogeneity(model):
    s = model.solve(fixed={"CPI": 2.0})
    for name in VARIABLES:
        exists = model.exists[name]
        factor = 2.0 if name in NOMINAL else 1.0
        assert _close(s[name][exists], factor * model.base[name][exists]), name


def test_higher_contribution_rate(model):
    # The fund buys more health services; households receive less labour income
    lab = model.sets["F"].index("lab")
    tshi = model.params["tshi"].copy()
    tshi[lab] *= 1.5
    s = model.solve(Closure(), params={"tshi": tshi})
    assert s.converged and abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8
    hlt = model.sets["C"].index("com_hlt")
    assert s["QSHI"][hlt] > model.base["QSHI"][hlt]
    assert np.isclose(s["YIF"][-1, lab], tshi[lab] * s["YF"][lab])
    share = s["YIF"][0, lab] / s["YF"][lab]
    assert share < model.base["YIF"][0, lab] / model.base["YF"][lab]
    # The fund spends its revenue less the share saved
    assert np.isclose(s["PQ"] @ s["QSHI"], (1 - model.params["sshi"]) * s["YSHI"][0])


def test_government_transfer_to_fund(model):
    s = model.solve(Closure(), params={"trshi": model.params["trshi"] * 1.5})
    assert s.converged and abs(s["WALRAS"][0]) < 1e-8
    assert s["SHIADJ"][0] > 1.0


def _health_sam(changes):
    sam = SAM.from_csv(HEALTH_SAM)
    values = sam.values.copy()
    for (r, c), x in changes.items():
        values[sam.labels.index(r), sam.labels.index(c)] += x
    return SAM(sam.labels, values)


def test_unsupported_flow_is_rejected():
    # A transfer from the fund to households, saved by them, is not represented
    sam = _health_sam({("hhd", "shi"): 1, ("sav", "shi"): -1, ("sav", "hhd"): 1})
    with pytest.raises(SAMError, match="shi"):
        Model(sam, health_mapping(), **TEST_ELASTICITIES)


def test_unmapped_fund_is_rejected():
    m = health_mapping()
    m.insurance = None
    with pytest.raises(SAMError, match="shi"):
        Model(SAM.from_csv(HEALTH_SAM), m, **TEST_ELASTICITIES)
