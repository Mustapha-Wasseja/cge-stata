"""Labour-market regimes (version 0.3.3, model_spec.md, Section 14): labour
force, wage curve and minimum wage; the smoothed minimum-wage condition is
checked against the exact regimes."""

import numpy as np
import pytest

from cge_ref.dynamics import Dynamics, run
from cge_ref.model import Closure
from cge_ref.report import report
from cge_ref.scenarios import WAGE_CURVE, labour_cases, simulation_inputs, synthetic_model

WC = Closure(factors={"lab": "wagecurve"})
MW = Closure(factors={"lab": "minwage"})


@pytest.fixture(scope="module")
def cases():
    return labour_cases()


def unemployment(sol):
    k = sol.model.sets["F"].index("lab")
    return 1 - sol["QFS"][k] / sol.params["qlf"][k]


def real_wage(sol):
    k = sol.model.sets["F"].index("lab")
    return sol["W"][k] / sol["CPI"][0]


def test_labour_force_calibration():
    m = synthetic_model(**WAGE_CURVE)
    k = m.sets["F"].index("lab")
    assert m.params["qlf"][k] == pytest.approx(m.base["QFS"][k] / 0.85)
    assert m.params["u0"][k] == 0.15 and m.params["epsw"][k] == 0.1
    for closure in (WC, MW, Closure()):
        assert m.solve(closure).iterations == 0


def test_wage_curve(cases):
    m = synthetic_model(**WAGE_CURVE)
    for name in ("wc_tariff_removal", "wc_import_price_up10", "wc_labour_force_up5", "wc_dpi_tariff_removal"):
        s = cases[name]
        u = unemployment(s)
        assert real_wage(s) == pytest.approx(real_wage(m.solve(Closure())) * (u / 0.15) ** -0.1, rel=1e-12), name
    # Higher import prices: lower real wages and more unemployment
    s = cases["wc_import_price_up10"]
    assert unemployment(s) > 0.15 and real_wage(s) < 1


def test_wage_curve_limits():
    """A tiny elasticity approaches a fixed real wage; a large one, fixed employment."""
    shock = {"params": {"pwm": synthetic_model().params["pwm"] * 1.1}}
    fixed_wage = synthetic_model(unemployment={"lab": 0.15}).solve(Closure(factors={"lab": "unemployed"}),
                                                                  tol=1e-12, **shock)
    flat = synthetic_model(unemployment={"lab": 0.15}, wage_curve={"lab": 1e-6}).solve(WC, tol=1e-12, **shock)
    assert np.allclose(flat["QA"], fixed_wage["QA"], rtol=1e-5)
    full = synthetic_model().solve(Closure(), tol=1e-12, **shock)
    steep = synthetic_model(unemployment={"lab": 0.15}, wage_curve={"lab": 1e4}).solve(WC, tol=1e-12, **shock)
    assert np.allclose(steep["QA"], full["QA"], rtol=1e-4)


def test_minimum_wage_binding_matches_the_exact_regime(cases):
    """With the floor binding, the smoothed solution is unemployment at the fixed
    real wage, to within the smoothing."""
    m = synthetic_model(unemployment={"lab": 0.15})
    k = m.sets["F"].index("lab")
    exact_closure = Closure(factors={"lab": "unemployed"})
    for name, shock in (("mw_import_price_up10", {"params": {"pwm": m.params["pwm"] * 1.1}}),
                        ("mw_tariff_removal", simulation_inputs(m)["tariff_removal"])):
        s = cases[name]
        exact = m.solve(exact_closure, tol=1e-12, fixed={"W": np.where(np.arange(2) == k, m.params["wmin"][k],
                                                                       m.base["W"])}, **shock)
        for var in ("QA", "QFS", "PQ", "W"):
            assert np.allclose(s[var], exact[var], rtol=1e-8), (name, var)
        a = unemployment(s)
        b = real_wage(s) / m.params["wmin"][k] - 1
        assert a > 0 and b > 0 and a * b == pytest.approx(1e-10, rel=1e-6)


def test_minimum_wage_regime_switches(cases):
    # Full employment at the base; a large rise in import prices brings the wage
    # down to the floor and creates unemployment
    nb = synthetic_model(min_wage={"lab": 0.95})
    k = nb.sets["F"].index("lab")
    s = cases["mwnb_pwm_up50"]
    assert unemployment(s) > 0.05
    assert real_wage(s) == pytest.approx(0.95, rel=1e-8)
    exact = nb.solve(Closure(factors={"lab": "unemployed"}), tol=1e-12,
                     fixed={"W": np.where(np.arange(2) == k, nb.params["wmin"][k], nb.base["W"])},
                     params={"pwm": nb.params["pwm"] * 1.5})
    assert np.allclose(s["QA"], exact["QA"], rtol=1e-8)
    # A smaller shock leaves the floor slack and labour fully employed
    s = cases["mwnb_foreign_savings_down20"]
    assert unemployment(s) < 1e-8 and real_wage(s) > 0.95
    full = nb.solve(Closure(), tol=1e-12, **simulation_inputs(nb)["foreign_savings_down20"])
    assert np.allclose(s["QA"], full["QA"], rtol=1e-8)
    # Low unemployment at the floor; higher productivity employs everyone and
    # raises the wage above the floor
    lo = synthetic_model(unemployment={"lab": 0.02})
    s = cases["mwlo_productivity_up5"]
    assert unemployment(s) < 1e-8 and real_wage(s) > 1.01
    full = lo.solve(Closure(), tol=1e-12, fixed={"QFS": np.where(np.arange(2) == k, lo.params["qlf"][k], lo.base["QFS"])},
                    params={"ad": lo.params["ad"] * 1.05})
    assert np.allclose(s["QA"], full["QA"], rtol=1e-7)


def test_regime_gdp_identity_and_homogeneity(cases):
    for name, s in cases.items():
        assert s.converged and abs(s.gdp_gap()) < 1e-10, name
    m = synthetic_model(unemployment={"lab": 0.15})
    double = m.solve(MW, fixed={"CPI": 2.0}, tol=1e-12)
    assert np.allclose(double["W"], 2 * m.base["W"], rtol=1e-10)
    assert np.allclose(double["QFS"], m.base["QFS"], rtol=1e-10)


def test_report_labour_measures(cases):
    rows = {(t, mm, e): (x0, x) for t, mm, e, x0, x in report(cases["wc_tariff_removal"])}
    u0, u1 = rows[("factors", "unemployment_rate", "lab")]
    assert u0 == pytest.approx(15.0) and u1 == pytest.approx(100 * unemployment(cases["wc_tariff_removal"]))
    assert ("factors", "labour_force", "cap") not in rows


def test_labour_force_grows_in_dynamic_runs():
    m = synthetic_model(**WAGE_CURVE)
    closure = Closure(factors={"lab": "wagecurve"})
    r = run(m, Dynamics(periods=2, factor_growth={"lab": 0.02}), closure)
    k = m.sets["F"].index("lab")
    assert r.solutions[2].params["qlf"][k] == pytest.approx(m.params["qlf"][k] * 1.02 ** 2, rel=1e-14)
    # with no other growth, a growing labour force raises unemployment
    assert unemployment(r.solutions[2]) > 0.15


def test_labour_errors():
    with pytest.raises(ValueError, match="labour force"):
        synthetic_model().solve(MW)
    with pytest.raises(ValueError, match="elasticity"):
        synthetic_model(unemployment={"lab": 0.15}).solve(WC)
    with pytest.raises(ValueError):
        synthetic_model(unemployment={"lab": 1.0})
    with pytest.raises(ValueError, match="below the base wage"):
        synthetic_model(min_wage={"lab": 1.0})
    with pytest.raises(ValueError, match="base wage"):
        synthetic_model(unemployment={"lab": 0.1}, min_wage={"lab": 0.9})
    with pytest.raises(ValueError, match="unemployment in the base"):
        synthetic_model(min_wage={"lab": 0.9}, wage_curve={"lab": 0.1})
    with pytest.raises(ValueError, match="unemployment in the base"):
        synthetic_model(wage_curve={"lab": 0.1})
    with pytest.raises(ValueError, match="must be positive"):
        synthetic_model(unemployment={"lab": 0.1}, wage_curve={"lab": -0.1})
    with pytest.raises(ValueError, match="not factors"):
        synthetic_model(unemployment={"xyz": 0.1})
    m = synthetic_model(**WAGE_CURVE)
    with pytest.raises(ValueError, match="labour-market regime"):
        run(m, Dynamics(periods=1, capital={"lab": (0.05, 0.15)}), Closure(factors={"lab": "wagecurve"}))
