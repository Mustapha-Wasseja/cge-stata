"""Linked regions (version 0.12.0; docs/model_spec.md, Section 21): calibrated
single-country models linked by bilateral trade, the reference implementation
of cge_region.

For a commodity that a region trades with another, its world import price
(relative to the base), its average tariff and its world export price
(relative to the base) are unknowns. Its imports are a CES aggregate of the
routes from the other regions and from the rest of the world, at prices that
include each route's tariff (elasticity sigma among sources); its exports go
to the other regions as their demand for them and to the rest of the world
along a demand curve (elasticity eta). Route values are in world units; a
unit of a region's SAM is worth `units` of them.
"""

from __future__ import annotations

import csv
import sys
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

from .model import VARIABLES, Closure, Model, Solution
from .solver import solve_system

REPO = Path(__file__).resolve().parents[2]
EXPECTED_DIR = REPO / "tests" / "expected"


@dataclass
class Route:
    exporter: str | None          # None: the rest of the world
    importer: str | None
    commodity: str
    value: float                  # base value, world units
    tariff0: float
    tariff: float = 0.0


@dataclass
class Linked:
    models: dict[str, Model]
    units: dict[str, float]
    routes: list[Route] = field(default_factory=list)
    sigma: dict[str, float] = field(default_factory=dict)
    eta: dict[str, float] = field(default_factory=dict)

    @classmethod
    def build(cls, models, units, trade, sigma=4.0, eta=None):
        """trade: (exporter, importer, commodity, value, tariff or None)."""
        routes = [Route(e, i, c, float(v), np.nan if t is None else float(t)) for e, i, c, v, t in trade if v > 0]
        comms = sorted({r.commodity for r in routes})
        for name, m in models.items():
            C = m.sets["C"]
            for c in comms:
                j = C.index(c)
                into = [r for r in routes if r.importer == name and r.commodity == c]
                if into:
                    base = m.params["pwm"][j] * m.base["QM"][j] * units[name]
                    tm0 = m.params["tm"][j]
                    for r in into:
                        if np.isnan(r.tariff0):
                            r.tariff0 = tm0
                    rest = base - sum(r.value for r in into)
                    if rest < -1e-6 * base:
                        raise ValueError(f"{name} imports less {c} than the routes give")
                    if rest > 1e-9 * base:
                        t_rest = (tm0 * base - sum(r.value * r.tariff0 for r in into)) / rest
                        routes.append(Route(None, name, c, rest, max(0.0, t_rest)))
                out = [r for r in routes if r.exporter == name and r.importer is not None and r.commodity == c]
                if out:
                    supply = (m.base["QE"][j] if m.exists["QE"][j] else 0.0) + \
                             (m.base["QER"][j] if m.exists["QER"][j] else 0.0)
                    base = m.params["pwe"][j] * supply * units[name]
                    rest = base - sum(r.value for r in out)
                    if rest < -1e-6 * base:
                        raise ValueError(f"{name} exports less {c} than the routes take")
                    if rest > 1e-9 * base:
                        routes.append(Route(name, None, c, rest, 0.0))
        for r in routes:
            r.tariff = r.tariff0
        sig = {c: float(sigma if np.isscalar(sigma) else sigma.get(c, 4.0)) for c in comms}
        et = {c: sig[c] if eta is None else float(eta if np.isscalar(eta) else eta.get(c, sig[c])) for c in comms}
        return cls(models, units, routes, sig, et)

    def solve(self, params=None, tariffs=None, pwrow=None, pwrowe=None, tol=1e-10, max_iter=100):
        """params: region -> parameter changes (as Model.solve); tariffs:
        (exporter, importer, commodity) -> tariff; pwrow and pwrowe:
        commodity -> the rest of the world's export price and demand shifter,
        relative to the base."""
        params = params or {}
        tariffs = tariffs or {}
        pwrow = pwrow or {}
        pwrowe = pwrowe or {}
        names = list(self.models)
        for r in self.routes:
            r.tariff = tariffs.get((r.exporter, r.importer, r.commodity), r.tariff0)
        # each region: parameters, free variables and their scale (default closure)
        setup = {}
        for name in names:
            m = self.models[name]
            p = {k: np.array(v, dtype=float, copy=True) for k, v in m.params.items()}
            for k, v in params.get(name, {}).items():
                p[k] = np.broadcast_to(np.asarray(v, dtype=float), p[k].shape).copy()
            fixed = Closure().fixed(m)
            free = {k: m.exists[k] & ~fixed[k] for k in VARIABLES}
            values = {k: m.base[k].copy() for k in VARIABLES}
            setup[name] = (m, p, free, values)
        # link variables: for each import pair pwm (relative) and tm; for each export pair pwe (relative)
        imp = sorted({(r.importer, r.commodity) for r in self.routes if r.importer is not None and r.exporter is not None})
        exp_ = sorted({(r.exporter, r.commodity) for r in self.routes if r.exporter is not None and r.importer is not None})
        nz = {name: int(sum(f.sum() for f in setup[name][2].values())) for name in names}
        ul0 = []
        for name, c in imp:
            m = self.models[name]
            ul0 += [1.0, float(m.params["tm"][m.sets["C"].index(c)])]
        ul0 += [1.0] * len(exp_)
        z0 = np.concatenate([np.concatenate([setup[n][3][k][setup[n][2][k]] / setup[n][0].var_scale[k][setup[n][2][k]]
                                             for k in VARIABLES]) for n in names] + [np.array(ul0)])

        def unpack(z):
            out, pos = {}, 0
            for name in names:
                m, p, free, values = setup[name]
                v = {k: a.copy() for k, a in values.items()}
                for k in VARIABLES:
                    cnt = int(free[k].sum())
                    v[k][free[k]] = z[pos:pos + cnt] * m.var_scale[k][free[k]]
                    pos += cnt
                out[name] = v
            return out, z[pos:]

        def region_params(name, ul):
            m, p, _, _ = setup[name]
            q = {k: a.copy() for k, a in p.items()}
            C = m.sets["C"]
            for i, (r, c) in enumerate(imp):
                if r == name:
                    j = C.index(c)
                    q["pwm"][j] = m.params["pwm"][j] * ul[2 * i]
                    q["tm"][j] = ul[2 * i + 1]
            for i, (s, c) in enumerate(exp_):
                if s == name:
                    j = C.index(c)
                    q["pwe"][j] = m.params["pwe"][j] * ul[2 * len(imp) + i]
            return q

        def routes(vals, ul):
            """world price relative to the base, quantity in base world units"""
            price, qty, index = {}, {}, {}
            for k, r in enumerate(self.routes):
                if r.exporter is None:
                    price[k] = pwrow.get(r.commodity, 1.0)
                else:
                    price[k] = ul[2 * len(imp) + exp_.index((r.exporter, r.commodity))]
            for i, (name, c) in enumerate(imp):
                m = self.models[name]
                j = m.sets["C"].index(c)
                ks = [k for k, r in enumerate(self.routes) if r.importer == name and r.commodity == c]
                s = self.sigma[c]
                x = np.array([price[k] * (1 + self.routes[k].tariff) / (1 + self.routes[k].tariff0) for k in ks])
                th = np.array([self.routes[k].value * (1 + self.routes[k].tariff0) for k in ks])
                th = th / th.sum()
                P = float(np.exp(th @ np.log(x))) if s == 1 else float((th @ x ** (1 - s)) ** (1 / (1 - s)))
                index[(name, c)] = P
                ratio = vals[name]["QM"][j] / m.base["QM"][j]
                for k, xk in zip(ks, x):
                    qty[k] = self.routes[k].value * ratio * (P / xk) ** s
            for k, r in enumerate(self.routes):
                if r.importer is None:
                    qty[k] = r.value * (price[k] / pwrowe.get(r.commodity, 1.0)) ** (-self.eta[r.commodity])
            return price, qty, index

        def F(z):
            vals, ul = unpack(z)
            res = [np.concatenate(list(setup[n][0].residuals(vals[n], region_params(n, ul)).values())) for n in names]
            price, qty, index = routes(vals, ul)
            link = []
            for i, (name, c) in enumerate(imp):
                m = self.models[name]
                j = m.sets["C"].index(c)
                tm0 = float(m.params["tm"][j])
                base = m.params["pwm"][j] * m.base["QM"][j] * self.units[name]
                ratio = vals[name]["QM"][j] / m.base["QM"][j]
                ks = [k for k, r in enumerate(self.routes) if r.importer == name and r.commodity == c]
                pwm, tm = ul[2 * i], ul[2 * i + 1]
                link.append((pwm * (1 + tm) - (1 + tm0) * index[(name, c)]) / (1 + tm0))
                link.append((tm * pwm * base * ratio - sum(self.routes[k].tariff * price[k] * qty[k] for k in ks)) / base)
            for i, (name, c) in enumerate(exp_):
                m = self.models[name]
                j = m.sets["C"].index(c)
                supply0 = (m.base["QE"][j] if m.exists["QE"][j] else 0.0) + (m.base["QER"][j] if m.exists["QER"][j] else 0.0)
                supply = (vals[name]["QE"][j] if m.exists["QE"][j] else 0.0) + (vals[name]["QER"][j] if m.exists["QER"][j] else 0.0)
                base = m.params["pwe"][j] * supply0 * self.units[name]
                ks = [k for k, r in enumerate(self.routes) if r.exporter == name and r.commodity == c]
                link.append((supply / supply0 * base - sum(qty[k] for k in ks)) / base)
            return np.concatenate(res + [np.array(link)])

        result = solve_system(F, z0, tol=tol, max_iter=max_iter)
        vals, ul = unpack(result.z)
        price, qty, _ = routes(vals, ul)
        sols = {n: Solution(setup[n][0], vals[n], region_params(n, ul), Closure(), result.converged,
                            result.iterations, result.max_residual, result.method) for n in names}
        return sols, [(r, price[k], qty[k]) for k, r in enumerate(self.routes)], result


# The test case: the synthetic SAM (region A) and the institutions layout
# (region B, a SAM unit worth two world units), with routes between them
LINK_TRADE = [("A", "B", "com_agr", 8.0, None), ("A", "B", "com_man", 24.0, 0.08), ("A", "B", "com_ser", 6.0, None),
              ("B", "A", "com_agr", 10.0, None), ("B", "A", "com_man", 30.0, None), ("B", "A", "com_ser", 5.0, 0.0)]


def link_cases() -> dict:
    from .scenarios import institutions_model, synthetic_model
    A, B = synthetic_model(), institutions_model()
    L = Linked.build({"A": A, "B": B}, {"A": 1.0, "B": 2.0}, LINK_TRADE)
    cases = {"base": {}}
    cases["fta"] = {"tariffs": {(r.exporter, r.importer, r.commodity): 0.0 for r in L.routes
                                if r.exporter is not None and r.importer is not None}}
    cases["world"] = {"pwrow": {"com_man": 1.1}}
    ad = A.params["ad"].copy()
    ad[A.sets["A"].index("act_man")] *= 1.05
    cases["prod"] = {"params": {"A": {"ad": ad}}}
    out = {}
    for name, kw in cases.items():
        sols, rts, res = L.solve(tol=1e-12, **kw)
        if not res.converged:
            raise RuntimeError(f"linked case {name} did not converge")
        out[name] = (sols, rts)
    return out


def write_linked(directory: Path = EXPECTED_DIR) -> list[Path]:
    """Solve the linked cases; write each region's solution and the routes."""
    written = []
    for case, (sols, rts) in link_cases().items():
        for region, sol in sols.items():
            path = directory / f"link_{case}_{region}.csv"
            with path.open("w", newline="", encoding="utf-8") as handle:
                writer = csv.writer(handle, lineterminator="\n")
                writer.writerow(["variable", "element1", "element2", "base", "value"])
                for name, e1, e2, base, value in sol.rows():
                    writer.writerow([name, e1, e2, f"{base:.15g}", f"{value:.15g}"])
            written.append(path)
        path = directory / f"link_{case}_routes.csv"
        with path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle, lineterminator="\n")
            writer.writerow(["exporter", "importer", "commodity", "quantity", "price"])
            for r, pr, q in rts:
                writer.writerow([r.exporter or "rest", r.importer or "rest", r.commodity, f"{q:.15g}", f"{pr:.15g}"])
        written.append(path)
    return written


if __name__ == "__main__":
    for p in write_linked():
        print(f"Wrote {p}")
    sys.exit(0)
