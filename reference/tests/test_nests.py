"""Nests of value added (version 0.5.1; docs/model_spec.md, Section 17.2):
labour types in one nest, capital and an energy commodity in another."""

import numpy as np
import pytest

from cge_ref.model import NOMINAL, VARIABLES, Closure
from cge_ref.report import report
from cge_ref.scenarios import NEST_MIXED, nest_cases, nest_model, nest_shocks


@pytest.fixture(scope="module")
def model():
    return nest_model()


def test_calibration(model):
    b, p, S = model.base, model.params, model.sets
    man, ene = S["A"].index("act_man"), S["A"].index("act_ene")
    lab, ke = S["N"].index("labour"), S["N"].index("ke")
    e = S["C"].index("com_ene")
    # each nest at its members' costs: labour types with the payroll tax,
    # capital and energy
    assert b["QNA"][lab, man] == pytest.approx(12 + 2 + 21)
    assert b["QNA"][ke, man] == pytest.approx(30 + 10)
    assert b["QVA"][man] == pytest.approx(75)
    # energy leaves intermediate input; act_ene buys none, so its capital
    # nest holds capital only, and its labour nest skilled labour only
    assert p["ica"][e].sum() == 0 and b["QINTA"][man] == pytest.approx(20 + 30 + 15)
    assert b["QNA"][ke, ene] == pytest.approx(25) and b["QNA"][lab, ene] == pytest.approx(5)
    assert model.max_residual(b) < 1e-12
    # real value added excludes energy
    rows = {(t, m, el): v for t, m, el, v0, v in report(model.solve(tol=1e-12))}
    assert rows[("macro", "value_added_real", "")] == pytest.approx(53 + 83 + 132 + 4)
    assert rows[("activities", "value_added", "act_man")] == pytest.approx(65)


@pytest.mark.parametrize("settings", [{}, NEST_MIXED])
def test_homogeneity(settings):
    m = nest_model(**settings)
    s = m.solve(tol=1e-12, fixed={"CPI": 2.0 * m.base["CPI"]})
    for name in VARIABLES:
        ex = m.exists[name]
        factor = 2.0 if name in NOMINAL else 1.0
        assert np.allclose(s[name][ex], factor * m.base[name][ex], rtol=1e-9, atol=1e-9), name


@pytest.mark.parametrize("sigma", [0.8, 1.0])
def test_equal_elasticity_is_flat(sigma):
    """A nest of factors with the elasticity of value added is the flat CES
    (or Cobb-Douglas) function of value added."""
    flat = nest_model(nests={}, sigma_nest=None, sigma_va=sigma)
    nested = nest_model(nests={"labour": ["lab_hi", "lab_lo"]}, sigma_nest=sigma, sigma_va=sigma)
    for shock in ("skilled_supply_up10", "energy_price_up50", "payroll_cut"):
        a = flat.solve(tol=1e-12, **nest_shocks(flat)[shock])
        b = nested.solve(tol=1e-12, **nest_shocks(nested)[shock])
        for name in VARIABLES:
            if name in ("QNA", "PNA"):
                continue
            ex = flat.exists[name]
            assert np.allclose(a[name][ex], b[name][ex], rtol=1e-10, atol=1e-10), (shock, name)


def test_cases_and_substitution(model):
    out = nest_cases()
    for name, s in out.items():
        assert s.converged and abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8, name
    # dearer energy: activities use less of it, more so when energy and
    # capital substitute more easily
    S = model.sets
    e, man = S["C"].index("com_ene"), S["A"].index("act_man")
    use = {}
    for sigma in (0.25, 1.5):
        m = nest_model(sigma_nest={"labour": 1.5, "ke": sigma})
        s = m.solve(tol=1e-12, **nest_shocks(m)["energy_price_up50"])
        use[sigma] = s["QINT"][e, man] / m.base["QINT"][e, man]
    assert use[1.5] < use[0.25] < 1
    # more skilled workers: their wage falls relative to the unskilled
    s = out["vnest_skilled_supply_up10"]
    hi, lo = S["F"].index("lab_hi"), S["F"].index("lab_lo")
    assert s["W"][hi] / s["W"][lo] < model.base["W"][hi] / model.base["W"][lo]


def test_errors():
    with pytest.raises(ValueError, match="two nests"):
        nest_model(nests={"a": ["lab_hi"], "b": ["lab_hi", "cap"]}, sigma_nest=0.5)
    with pytest.raises(ValueError, match="not a factor or commodity"):
        nest_model(nests={"a": ["xyz"]}, sigma_nest=0.5)
    with pytest.raises(ValueError, match="name of a factor"):
        nest_model(nests={"cap": ["lab_hi", "lab_lo"]}, sigma_nest=0.5)
    with pytest.raises(ValueError, match="sigma_nest"):
        nest_model(nests={"a": ["lab_hi", "lab_lo"]}, sigma_nest={"b": 1.0})
    with pytest.raises(ValueError, match="positive"):
        nest_model(sigma_nest={"labour": 0.0, "ke": 0.5})
    # a specific closure for capital in a nest solves
    m = nest_model()
    s = m.solve(Closure(factors={"cap": "specific"}), tol=1e-12, **nest_shocks(m)["energy_price_up50"])
    assert s.converged
