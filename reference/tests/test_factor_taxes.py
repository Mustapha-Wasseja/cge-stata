"""Taxes on factor use and on factor income (version 0.5.0; docs/model_spec.md,
Section 17.1)."""

import numpy as np
import pytest

from cge_ref.model import NOMINAL, VARIABLES, Model
from cge_ref.report import report
from cge_ref.sam import SAM, SAMError
from cge_ref.scenarios import (FACTOR_TAX_SAM, MIXED_ELASTICITIES, TEST_ELASTICITIES, factor_tax_cases,
                               factor_tax_mapping, factor_tax_model)


@pytest.fixture(scope="module")
def model():
    return factor_tax_model()


def test_calibration(model):
    p, b = model.params, model.base
    lab, cap = model.sets["F"].index("lab"), model.sets["F"].index("cap")
    # payroll taxes of 4, 3 and 6 on labour payments of 36, 32 and 54
    assert np.allclose(p["tf"][lab], [4 / 36, 3 / 32, 6 / 54]) and not p["tf"][cap].any()
    # a tax of 7 on capital income of 127
    assert p["tfy"][cap] == pytest.approx(7 / 127) and p["tfy"][lab] == 0
    # value added at factor cost includes the payroll tax
    assert np.allclose(b["QVA"], [36 + 37 + 4, 32 + 40 + 3, 54 + 50 + 6])
    assert model.max_residual(b) < 1e-12


@pytest.mark.parametrize("settings", [{}, MIXED_ELASTICITIES])
def test_homogeneity(settings):
    m = factor_tax_model(**settings)
    s = m.solve(tol=1e-12, fixed={"CPI": 2.0 * m.base["CPI"]})
    for name in VARIABLES:
        ex = m.exists[name]
        factor = 2.0 if name in NOMINAL else 1.0
        assert np.allclose(s[name][ex], factor * m.base[name][ex], rtol=1e-9, atol=1e-9), name


def test_cases_and_incidence(model):
    out = factor_tax_cases()
    lab = model.sets["F"].index("lab")
    for name, s in out.items():
        assert s.converged and abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8, name
    cut = out["ftax_payroll_cut"]
    # With a fixed supply of labour, workers bear the payroll tax: halving it
    # raises the net wage by about the tax cut, while the average cost of
    # labour to employers barely moves
    assert cut["W"][lab] > 1.04 * model.base["W"][lab]

    def average_cost(v, p):
        q = v["QF"][lab]
        return (v["W"][lab] * v["WFDIST"][lab] * (1 + p["tf"][lab]) * q).sum() / q.sum()

    c0, c1 = average_cost(model.base, model.params), average_cost(cut, cut.params)
    assert abs(c1 / c0 - 1) < 0.002
    rows = {(t, m): v for t, m, e, b, v in report(cut)}
    base = {(t, m): b for t, m, e, b, v in report(cut)}
    assert base[("government", "tax_factor_use")] == pytest.approx(13)
    assert base[("government", "tax_factor_income")] == pytest.approx(7)
    assert rows[("government", "tax_factor_use")] < 13


def test_errors():
    sam = SAM.from_csv(FACTOR_TAX_SAM)
    m = factor_tax_mapping()
    m.factor_taxes = {"tax_pay": "xyz"}
    with pytest.raises(SAMError, match="not a factor"):
        Model(sam, m, **TEST_ELASTICITIES)
    m = factor_tax_mapping()
    m.factor_taxes = {"tax_pay": "cap"}
    # a payroll tax on capital is accepted where capital is used; mapped to
    # nothing, the account is an error
    Model(sam, m, **TEST_ELASTICITIES)
    m = factor_tax_mapping()
    m.factor_taxes = {}
    with pytest.raises(SAMError, match="not mapped"):
        Model(sam, m, **TEST_ELASTICITIES)
