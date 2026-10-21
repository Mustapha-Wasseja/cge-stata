"""Policy optimisation (version 0.6.0; docs/model_spec.md, Section 18)."""

import numpy as np
import pytest

from cge_ref.model import Closure
from cge_ref.optimize import Instrument, optimize
from cge_ref.report import report
from cge_ref.scenarios import WELFARE, optimize_cases, synthetic_model


@pytest.fixture(scope="module")
def cases():
    return optimize_cases()


def welfare(m, closure, tm):
    s = m.solve(closure, params={"tm": tm}, tol=1e-12)
    return {(t, k, e): v for t, k, e, b, v in report(s)}[WELFARE]


def test_target_is_the_closure(cases):
    """The direct tax rate that keeps government savings at the base is the
    solution of the closure with fixed savings and direct taxes adjusting."""
    m = synthetic_model()
    notariff = {"tm": np.zeros_like(m.params["tm"])}
    ref = m.solve(Closure(government="fixgsav"), params=notariff, tol=1e-12)
    o = cases["opt_target_gsav"]
    assert o.converged
    assert o.values[0] == pytest.approx(ref["TINSADJ"][0], rel=1e-10)
    for name in ref.values:
        if ref[name].size and name not in ("GSAV", "TINSADJ"):
            assert np.allclose(o.solution[name], ref[name], rtol=1e-9, atol=1e-9), name


def test_interior_optimum(cases):
    """At the welfare-maximising tariff the derivative of welfare is zero,
    and welfare is lower on either side."""
    m = synthetic_model()
    fix = Closure(government="fixgsav")
    o = cases["opt_tariff_man"]
    assert o.converged and -0.5 < o.values[0] < 1.0
    t = m.params["tm"].copy()

    def ev(x):
        t[m.sets["C"].index("com_man")] = x
        return welfare(m, fix, t)

    h = 1e-4
    x = o.values[0]
    assert abs(ev(x + h) - ev(x - h)) / (2 * h) < 1e-4
    assert ev(x) > ev(x + 0.01) and ev(x) > ev(x - 0.01)
    # solved from another start, the model agrees to its tolerance
    assert o.objective == pytest.approx(ev(x), rel=1e-9)


def test_two_instruments_and_bounds(cases):
    o2, ob = cases["opt_two_tariffs"], cases["opt_bound"]
    assert o2.converged and o2.objective >= cases["opt_tariff_man"].objective - 1e-9
    # the optimum on manufactures alone, 0.30, is above the bound of 0.2
    assert ob.converged and ob.values[0] == pytest.approx(0.2, abs=1e-8)


def test_objective_with_a_target(cases):
    o = cases["opt_revenue"]
    assert o.converged and o.targets[0] == pytest.approx(8.0, rel=1e-9)
    # keeping tariff revenue costs welfare against the unconstrained optimum
    assert o.objective <= cases["opt_two_tariffs"].objective + 1e-9


def test_errors():
    m = synthetic_model()
    with pytest.raises(ValueError, match="not fixed"):
        optimize(m, [Instrument("W", ("lab",))], objective=WELFARE)
    with pytest.raises(ValueError, match="one target"):
        optimize(m, [Instrument("tm", ("com_man",))])
    with pytest.raises(ValueError, match="no such element"):
        optimize(m, [Instrument("tm", ("xyz",))], objective=WELFARE)
    with pytest.raises(ValueError, match="no report measure"):
        optimize(m, [Instrument("tm", ("com_man",))], objective=("macro", "nothing", ""))
