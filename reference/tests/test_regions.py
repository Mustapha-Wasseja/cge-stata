"""Linked regions (version 0.12.0): the reference implementation of
cge_region. At the base the linked system holds at the regions' base
solutions; the routes close each region's trade; a free-trade area raises the
trade between the regions and lowers that with the rest of the world; each
region's solution satisfies its own model with its link prices."""

import numpy as np
import pytest

from cge_ref.regions import LINK_TRADE, Linked
from cge_ref.scenarios import institutions_model, synthetic_model


@pytest.fixture(scope="module")
def linked():
    return Linked.build({"A": synthetic_model(), "B": institutions_model()}, {"A": 1.0, "B": 2.0}, LINK_TRADE)


def test_routes_close_trade(linked):
    for name, m in linked.models.items():
        for j, c in enumerate(m.sets["C"]):
            into = [r for r in linked.routes if r.importer == name and r.commodity == c]
            if into:
                base = m.params["pwm"][j] * m.base["QM"][j] * linked.units[name]
                assert sum(r.value for r in into) == pytest.approx(base, rel=1e-12)
                avg = sum(r.value * r.tariff0 for r in into) / base
                assert avg == pytest.approx(m.params["tm"][j], abs=1e-12)
            out = [r for r in linked.routes if r.exporter == name and r.commodity == c]
            if out:
                assert sum(r.value for r in out) == pytest.approx(m.base["QE"][j] * linked.units[name], rel=1e-12)


def test_base(linked):
    sols, routes, res = linked.solve(tol=1e-12)
    assert res.converged and res.iterations == 0
    for (r, price, q) in routes:
        assert price == pytest.approx(1.0) and q == pytest.approx(r.value)


def test_free_trade_area(linked):
    fta = {(r.exporter, r.importer, r.commodity): 0.0 for r in linked.routes
           if r.exporter is not None and r.importer is not None}
    sols, routes, res = linked.solve(tariffs=fta, tol=1e-12)
    assert res.converged
    between = [(r, q) for r, _, q in routes if r.exporter is not None and r.importer is not None]
    assert all(q > r.value for r, q in between if r.tariff0 > 0)
    rest = [(r, q) for r, _, q in routes if r.exporter is None and r.commodity == "com_man"]
    assert all(q < r.value for r, q in rest)
    # each region's solution satisfies its own model with its link prices
    for name, sol in sols.items():
        assert sol.model.max_residual(sol.values, sol.params) < 1e-10
