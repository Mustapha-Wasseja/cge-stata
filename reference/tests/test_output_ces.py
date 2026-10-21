"""Output of a commodity from several activities, combined by a CES or
Cobb-Douglas function (version 0.5.2; docs/model_spec.md, Section 17.3)."""

import numpy as np
import pytest

from cge_ref.model import NOMINAL, VARIABLES, Closure
from cge_ref.sam import SAMError
from cge_ref.scenarios import MIXED_ELASTICITIES, OUTPUT_CES, multiproduct_model, output_cases, simulation_inputs


@pytest.fixture(scope="module")
def model():
    return multiproduct_model(**OUTPUT_CES)


def test_calibration(model):
    b, p, S = model.base, model.params, model.sets
    agr, man = S["A"].index("act_agr"), S["A"].index("act_man")
    c = S["C"].index("com_man")
    # act_agr sells 10 of manufactures, act_man 140, at a price of one
    assert b["QXAC"][agr, c] == pytest.approx(10) and b["QXAC"][man, c] == pytest.approx(140)
    assert model.exists["PXAC"].sum() == 2 and b["PXAC"][agr, c] == 1
    r = 1 / 2.0 - 1
    d = np.array([10, 140]) ** (1 + r)
    assert p["delta_ac"][[agr, man], c] == pytest.approx(d / d.sum())
    assert model.max_residual(b) < 1e-12


@pytest.mark.parametrize("settings", [OUTPUT_CES, {"sigma_ac": 1.0, **MIXED_ELASTICITIES}])
def test_homogeneity(settings):
    m = multiproduct_model(**settings)
    s = m.solve(tol=1e-12, fixed={"CPI": 2.0 * m.base["CPI"]})
    for name in VARIABLES:
        ex = m.exists[name]
        factor = 2.0 if name in NOMINAL else 1.0
        assert np.allclose(s[name][ex], factor * m.base[name][ex], rtol=1e-9, atol=1e-9), name


def test_perfect_substitutes_in_the_limit():
    """As the elasticity grows, the CES aggregate tends to the sum of the
    activities' outputs, the model without aggregation."""
    flat = multiproduct_model()
    near = multiproduct_model(sigma_ac={"com_man": 1e8})
    for shock in ("agri_productivity_up5", "tariff_removal"):
        a = flat.solve(tol=1e-12, **simulation_inputs(flat)[shock])
        b = near.solve(tol=1e-12, **simulation_inputs(near)[shock])
        for name in VARIABLES:
            if name in ("PXAC", "QXAC"):
                continue
            ex = flat.exists[name]
            assert np.allclose(a[name][ex], b[name][ex], rtol=1e-6, atol=1e-6), (shock, name)


def test_cases_and_prices(model):
    out = output_cases()
    for name, s in out.items():
        assert s.converged and abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8, name
    # Higher productivity in agriculture lowers the price of its manufactures
    # relative to those of act_man: the two are imperfect substitutes
    S = model.sets
    agr, man, c = S["A"].index("act_agr"), S["A"].index("act_man"), S["C"].index("com_man")
    s = out["xac_agri_productivity_up5"]
    assert s["PXAC"][agr, c] < s["PXAC"][man, c]
    # the value of output is the value of the activities' outputs
    assert s["PX"][c] * s["QX"][c] == pytest.approx((s["PXAC"][:, c] * s["QXAC"][:, c]).sum(), rel=1e-12)


def test_errors():
    with pytest.raises(SAMError, match="one activity"):
        multiproduct_model(sigma_ac={"com_agr": 2.0})
    with pytest.raises(ValueError, match="not a commodity"):
        multiproduct_model(sigma_ac={"xyz": 2.0})
    with pytest.raises(ValueError, match="positive"):
        multiproduct_model(sigma_ac={"com_man": 0.0})
    # one value applies to every commodity with more than one producer
    m = multiproduct_model(sigma_ac=3.0)
    assert m.struct["cac"].sum() == 1
    s = m.solve(Closure(factors={"cap": "specific"}), tol=1e-12, **simulation_inputs(m)["agri_productivity_up5"])
    assert s.converged
