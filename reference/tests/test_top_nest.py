"""CES or Cobb-Douglas top nest between value added and intermediates (version 0.1.12)."""

import numpy as np
import pytest

from cge_ref import VARIABLES, Closure
from cge_ref.model import NOMINAL
from cge_ref.scenarios import TOP_NEST, synthetic_model
from test_validation import _close


@pytest.fixture(scope="module")
def model():
    return synthetic_model(sigma_a=TOP_NEST)


def test_calibration(model):
    p, b, s = model.params, model.base, model.struct
    assert list(s["lt"]) == [True, False, False] and list(s["cda"]) == [False, False, True]
    assert np.allclose(p["delta_a"] + p["deltac_a"], 1.0)
    ser = model.sets["A"].index("act_ser")
    assert np.isclose(p["delta_a"][ser], b["QVA"][ser] / (b["QVA"][ser] + b["QINTA"][ser]))
    assert model.max_residual(model.base) < 1e-12
    assert model.solve().iterations == 0


def test_leontief_is_the_default():
    m = synthetic_model()
    assert m.struct["lt"].all()


def test_substitution_follows_relative_prices(model):
    # Dearer imports raise the price of intermediates: the CES and Cobb-Douglas
    # activities use relatively less of them, the Leontief activity does not
    s = model.solve(Closure(), params={"pwm": model.params["pwm"] * 1.1})
    ratio = s["QINTA"] / s["QVA"]
    base = model.base["QINTA"] / model.base["QVA"]
    A = model.sets["A"]
    assert np.isclose(ratio[A.index("act_agr")], base[A.index("act_agr")])
    for a in ("act_man", "act_ser"):
        k = A.index(a)
        rel = s["PINTA"][k] / s["PVA"][k]
        assert (ratio[k] < base[k]) == (rel > 1)
    # Cobb-Douglas: value shares are constant
    k = A.index("act_ser")
    share = s["PVA"][k] * s["QVA"][k] / (s["PVA"][k] * s["QVA"][k] + s["PINTA"][k] * s["QINTA"][k])
    assert np.isclose(share, model.params["delta_a"][k])


def test_homogeneity(model):
    s = model.solve(fixed={"CPI": 2.0})
    for name in VARIABLES:
        exists = model.exists[name]
        factor = 2.0 if name in NOMINAL else 1.0
        assert _close(s[name][exists], factor * model.base[name][exists]), name


def test_negative_elasticity_is_rejected():
    with pytest.raises(ValueError, match="sigma_a"):
        synthetic_model(sigma_a=-0.5)
