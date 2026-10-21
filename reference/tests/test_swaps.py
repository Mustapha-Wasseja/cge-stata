"""Closure swaps (version 0.4.5; docs/model_spec.md, Section 6)."""

import numpy as np
import pytest

from cge_ref import Closure
from cge_ref.model import NOMINAL, VARIABLES
from cge_ref.scenarios import _scaled, swap_cases, synthetic_model


def _same(a, b, rel=1e-8, skip=()):
    for name in VARIABLES:
        if name in skip:
            continue
        assert np.all(np.abs(a[name] - b[name]) <= rel * np.maximum(1.0, np.abs(b[name]))), name


@pytest.fixture(scope="module")
def model():
    return synthetic_model()


def test_swaps_reproduce_the_menu_closures(model):
    p = model.params
    notariff = {"params": {"tm": np.zeros_like(p["tm"])}}
    # fixing the exchange rate and freeing foreign savings is the fixed exchange rate
    _same(model.solve(Closure(swaps=(("EXR", "FSAV"),)), tol=1e-12, **notariff),
          model.solve(Closure(external="fixexr"), tol=1e-12, **notariff))
    # fixing the wage of labour and freeing its supply is unemployment at a fixed wage
    shock = {"params": {"pwm": p["pwm"] * 1.1}}
    _same(model.solve(Closure(swaps=(("W(lab)", "QFS(lab)"),)), tol=1e-12, **shock),
          model.solve(Closure(factors={"lab": "unemployed"}), tol=1e-12, **shock))
    # fixing government purchases of services and freeing their scaling factor
    # scales every purchase in proportion
    ser = model.sets["C"].index("com_ser")
    swap = model.solve(Closure(swaps=(("QG(com_ser)", "GADJ"),)), tol=1e-12,
                       fixed={"QG": _scaled(model.base["QG"], ser, 1.1)})
    _same(swap, model.solve(tol=1e-12, params={"qg": p["qg"] * 1.1}), skip=("GADJ",))
    assert swap["GADJ"][0] == pytest.approx(1.1, rel=1e-12)


def test_new_closures():
    out = swap_cases()
    g = out["swap_gsav_gadj"]
    m = g.model
    assert g.converged and g["GSAV"][0] == pytest.approx(m.base["GSAV"][0], abs=1e-12)
    assert g["GADJ"][0] < 1 and abs(g.gdp_gap()) < 1e-8
    e = out["swap_exr_numeraire"]
    assert e["EXR"][0] == pytest.approx(1.0, abs=1e-14) and e["CPI"][0] != pytest.approx(m.base["CPI"][0])


def test_homogeneity_with_the_exchange_rate_as_numeraire(model):
    s = model.solve(Closure(swaps=(("EXR", "CPI"),)), tol=1e-12, fixed={"EXR": 2.0})
    for name in VARIABLES:
        factor = 2.0 if name in NOMINAL else 1.0
        ex = model.exists[name]
        assert np.allclose(s[name][ex], factor * model.base[name][ex], rtol=1e-9, atol=1e-9), name


def test_errors(model):
    with pytest.raises(ValueError, match="already fixed"):
        model.solve(Closure(swaps=(("FSAV", "EXR"),)))
    with pytest.raises(ValueError, match="not fixed"):
        model.solve(Closure(swaps=(("GSAV", "EXR"),)))
    with pytest.raises(ValueError, match="not a model variable"):
        model.solve(Closure(swaps=(("XYZ", "GADJ"),)))
    with pytest.raises(ValueError, match="not an element"):
        model.solve(Closure(swaps=(("QG(com_xyz)", "GADJ"),)))
