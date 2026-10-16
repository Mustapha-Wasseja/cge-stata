"""Standard report measures and the compensating variation (version 0.1.15)."""

import numpy as np
import pytest

from cge_ref import Closure, report
from cge_ref.scenarios import HEALTH_LINK, LES_SETTINGS, health_model, institutions_model, synthetic_model


def _rows(solution):
    return {(t, m, e): (b, v) for t, m, e, b, v in report(solution)}


@pytest.fixture(scope="module")
def les():
    return synthetic_model(**LES_SETTINGS)


def test_base_report_is_consistent():
    m = institutions_model()
    r = _rows(m.solve())
    for key, (b, v) in r.items():
        assert np.isclose(b, v), key                     # unchanged at the base
    b = {k: v[0] for k, v in r.items()}
    assert np.isclose(b[("macro", "gdp_real", "")], b[("macro", "gdp_nominal", "")])
    assert np.isclose(b[("macro", "gdp_deflator", "")], 1.0)
    # Expenditure components add up to real GDP
    parts = ("consumption_real", "government_real", "investment_real", "insurance_fund_real", "exports_real")
    total = sum(b[("macro", x, "")] for x in parts) - b[("macro", "imports_real", "")]
    assert np.isclose(total, b[("macro", "gdp_real", "")])
    # Tax revenue by type, plus factor income and transfers to government, is revenue
    taxes = sum(b[("government", x, "")] for x in
                ("tax_direct", "tax_sales", "tax_import", "tax_export", "tax_activity"))
    other = m.base["YIF"][m.sets["I"].index("gov")].sum() + m.params["trgr"] + m.params["trgg"]
    assert np.isclose(taxes + other, b[("government", "revenue", "")])


def test_nominal_gdp_equals_income(les):
    s = les.solve(Closure(), params={"pwm": les.params["pwm"] * 1.1})
    r = _rows(s)
    income = (s["PVA"] @ s["QVA"] + (s.params["tq"] * s["PQ"] * s["QQ"]).sum()
              + s["EXR"][0] * (s.params["tm"] * s.params["pwm"] * s["QM"]).sum()
              + s["EXR"][0] * (s.params["te"] * s.params["pwe"] * s["QE"]).sum()
              + (s.params["ta"] * s["PA"] * s["QA"]).sum())
    assert np.isclose(r[("macro", "gdp_nominal", "")][1], income)


def test_compensating_variation(les):
    # Spending less CV at the new prices gives base utility (LES)
    s = les.solve(Closure(), params={"pwm": les.params["pwm"] * 1.1})
    p, b = les.params, les.base
    beta, gamma = p["beta"][:, 0], p["gamma"][:, 0]
    u0 = np.prod((b["QH"][:, 0] - gamma) ** beta)
    budget = s["EH"][0] - s.compensating_variation()[0]
    qh = gamma + beta * (budget - s["PQ"] @ gamma) / s["PQ"]
    assert np.isclose(np.prod((qh - gamma) ** beta), u0, rtol=1e-10)
    # A loss, and CV and EV of the same sign
    assert s.compensating_variation()[0] < 0 and s.equivalent_variation()[0] < 0


def test_numeraire_change_has_no_welfare_effect():
    # Doubling the numeraire scales all prices and incomes: EV and CV are zero
    m = synthetic_model()
    s = m.solve(fixed={"CPI": 2.0})
    assert np.allclose(s.equivalent_variation(), 0.0, atol=1e-9)
    assert np.allclose(s.compensating_variation(), 0.0, atol=1e-9)


def test_health_rows():
    m = health_model(**HEALTH_LINK)
    tables = {(t, x) for t, x, _ in _rows(m.solve())}
    assert ("health", "health_services") in tables and ("health", "fund_volume") in tables
    assert ("health", "efficiency") in tables
    assert ("health", "health_services") not in {(t, x) for t, x, _ in _rows(synthetic_model().solve())}
