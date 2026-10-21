"""Recursive dynamics (docs/model_spec.md, Section 10; version 0.2.0).

A run solves the static model for a sequence of periods. Period 0 is the
calibrated base. Before each later period, the exogenous values are updated
from the previous period's solution:

1. capital accumulates: depreciation, plus new capital from the previous
   period's real investment, allocated among activities by relative rental
   rates when capital is specific to each activity;
2. other factor supplies grow at given rates;
3. value-added efficiency (TFP) grows at a given rate, follows a given path,
   or is solved for so that real value added grows at a target rate;
4. population growth scales subsistence consumption and the base of the
   health link;
5. government consumption and real transfers, and flows in foreign currency
   (including fixed foreign savings), grow at given rates;
6. with public debt (version 0.3.1), last period's deficit is added to the
   debt, a share phi borrowed abroad;
7. optional shocks are applied, and the period is solved from the previous
   period's solution.

The Stata command cge_dynamic must reproduce these runs.
"""

from __future__ import annotations

import dataclasses
from typing import Callable

import numpy as np

from .model import Closure, Model, Solution, value_added_real

GOVERNMENT = ("qg", "trdg", "trgg", "trshi")
FOREIGN = ("trdr", "trfr", "trgr", "trrg", "trshir")


@dataclasses.dataclass
class Dynamics:
    """Settings of a dynamic run; rates are per period."""

    periods: int
    capital: dict[str, tuple[float, float]] = dataclasses.field(default_factory=dict)
    sensitivity: float = 1.0
    factor_growth: dict[str, float] = dataclasses.field(default_factory=dict)
    tfp_growth: float | dict = 0.0
    population_growth: float = 0.0
    government_growth: float = 0.0
    foreign_growth: float = 0.0
    gdp_target: float | list | None = None
    tfp_path: list | None = None
    # Deaths at working ages (model_spec.md, 15.4): the factors that lose
    # workers, the share of deaths at working ages and the working-age share
    # of the population
    death_factors: tuple = ()
    death_share: float = 0.0
    working_age: float = 1.0


@dataclasses.dataclass
class Run:
    solutions: list[Solution]
    tfp_path: list[float]          # uniform efficiency factor applied in periods 1..T


def real_value_added(model: Model, values: dict) -> float:
    return float(value_added_real(model, values).sum())


def _per_activity(model: Model, value) -> np.ndarray:
    A = model.sets["A"]
    if isinstance(value, dict):
        return np.array([float(value.get(a, 0.0)) for a in A])
    return np.full(len(A), float(value))


def run(model: Model, settings: Dynamics, closure: Closure | None = None,
        shocks: Callable[[int, dict, dict], None] | None = None, tol: float = 1e-12) -> Run:
    """Solve periods 0..settings.periods. `shocks(t, params, fixed)` may change
    the parameters and fixed values of period t (t >= 1) in place."""
    closure = closure or Closure()
    F = model.sets["F"]
    fac = {f: closure.factors.get(f, "mobile") for f in F}
    for f in settings.capital:
        if f not in F:
            raise ValueError(f"capital: {f} is not a factor")
        if fac[f] == "unemployed":
            raise ValueError(f"capital: {f} cannot be unemployed in a dynamic run")
    inlf = model.struct["inlf"]
    for f in settings.capital:
        if fac[f] in ("wagecurve", "minwage"):
            raise ValueError(f"capital: {f} cannot have a labour-market regime in a dynamic run")
    for f, g in settings.factor_growth.items():
        if f in settings.capital:
            raise ValueError(f"factor_growth: {f} is a capital factor")
        if g != 0 and fac[f] == "unemployed" and not inlf[F.index(f)]:
            raise ValueError(f"factor_growth: {f} is unemployed, so its supply is not fixed")
    if settings.death_factors:
        if not model.struct["hasmort"]:
            raise ValueError("death_factors: the model has no death rate (give mortality)")
        if not 0 <= settings.death_share <= 1 or not 0 < settings.working_age <= 1:
            raise ValueError("death_share must lie between 0 and 1, and working_age above 0 and at most 1")
        for f in settings.death_factors:
            if f not in F:
                raise ValueError(f"death_factors: {f} is not a factor")
            if f in settings.capital:
                raise ValueError(f"death_factors: {f} is a capital factor")
            if fac[f] == "unemployed" and not inlf[F.index(f)]:
                raise ValueError(f"death_factors: {f} is unemployed, so its supply is not fixed")
    targets = settings.gdp_target
    if targets is not None and not np.iterable(targets):
        targets = [targets] * settings.periods
    tfp = _per_activity(model, settings.tfp_growth)

    p = {k: np.array(v, dtype=float, copy=True) for k, v in model.params.items()}
    fx = {k: np.array(model.base[k], dtype=float, copy=True) for k in ("QF", "QFS", "FSAV")}
    prev = model.solve(closure, params=p, fixed=fx, tol=tol)
    solutions, path = [prev], []
    base_income = {f: model.base["YF"][F.index(f)] for f in settings.capital}
    total_income = sum(base_income.values())
    for t in range(1, settings.periods + 1):
        # Deaths in t-1 relative to the base death rate (model_spec.md, 15.4)
        excess = 0.0
        if model.struct["hasmort"]:
            pp = prev.params
            ratio = prev["HS"][0] / pp["hs0"]
            excess = float(pp["mort0"] - pp["mort"] * ratio ** pp["eps_m"])
        gpop = settings.population_growth + excess
        # 1. Capital accumulation from last period's real investment
        inv = float(model.base["PQ"] @ prev["QINV"])
        for f, (delta, rental) in settings.capital.items():
            k = F.index(f)
            new = rental * base_income[f] / total_income * inv
            if fac[f] == "specific":
                fa = model.struct["fa"][k]
                q = np.where(fa, prev["QF"][k], 0.0)
                s = q / q.sum()
                rent = prev["W"][k] * prev["WFDIST"][k]
                avg = s @ rent
                eta = np.where(fa, s * (1 + settings.sensitivity * (rent / avg - 1)), 0.0)
                eta = np.maximum(eta, 0.0)
                eta = eta / eta.sum()
                fx["QF"][k] = (1 - delta) * q + new * eta
            else:
                fx["QFS"][k] = (1 - delta) * prev["QFS"][k] + new
        # 2. Other factor supplies
        for f in F:
            if f in settings.capital:
                continue
            k = F.index(f)
            g = settings.factor_growth.get(f, 0.0)
            if f in settings.death_factors:
                g = g + settings.death_share / settings.working_age * excess
            if fac[f] == "specific":
                fx["QF"][k] = (1 + g) * prev["QF"][k]
            elif fac[f] == "mobile":
                fx["QFS"][k] = (1 + g) * prev["QFS"][k]
            # the labour force grows at the same rate (Section 14.4)
            if inlf[k]:
                p["qlf"] = np.array(p["qlf"], dtype=float)
                p["qlf"][k] = (1 + g) * p["qlf"][k]
        # 4. Population, 5. government and foreign flows
        p["gamma"] = p["gamma"] * (1 + gpop)
        p["gammah"] = p["gammah"] * (1 + gpop)
        p["hs0"] = p["hs0"] * (1 + gpop)
        p["pop"] = p["pop"] * (1 + gpop)
        for name in GOVERNMENT:
            p[name] = p[name] * (1 + settings.government_growth)
        for name in FOREIGN:
            p[name] = p[name] * (1 + settings.foreign_growth)
        if closure.external == "flexexr":
            fx["FSAV"] = fx["FSAV"] * (1 + settings.foreign_growth)
        # Public debt (model_spec.md, 12.3): last period's deficit is borrowed
        if p["debt"] != 0:
            deficit = -prev["GSAV"][0]
            p["ddebt"] = np.array(p["ddebt"] + (1 - p["phi"]) * deficit)
            p["fdebt"] = np.array(p["fdebt"] + p["phi"] * deficit / prev["EXR"][0])
        # 6. Shocks
        if shocks is not None:
            shocks(t, p, fx)
        # 3. Efficiency, then solve
        ad = p["ad"].copy()
        if settings.tfp_path is not None:
            lam = settings.tfp_path[t - 1]
            p["ad"] = ad * lam
            sol = model.solve(closure, params=p, fixed=fx, start=prev.values, tol=tol)
        elif targets is not None:
            lam, sol = _target(model, closure, p, fx, prev, ad, targets[t - 1], tol)
        else:
            lam = None
            p["ad"] = ad * (1 + tfp)
            sol = model.solve(closure, params=p, fixed=fx, start=prev.values, tol=tol)
        if not sol.converged:
            raise RuntimeError(f"period {t} did not converge")
        path.append(lam if lam is not None else float("nan"))
        solutions.append(sol)
        prev = sol
    return Run(solutions, path)


def _target(model, closure, p, fx, prev, ad, growth, tol):
    """Uniform efficiency factor such that real value added grows at `growth`
    (secant iterations; the same steps as cge_dynamic)."""
    target = (1 + growth) * real_value_added(model, prev.values)

    def gap(lam):
        p["ad"] = ad * lam
        sol = model.solve(closure, params=p, fixed=fx, start=prev.values, tol=tol)
        if not sol.converged:
            raise RuntimeError("period did not converge while targeting real value added")
        return real_value_added(model, sol.values) / target - 1, sol

    l0, l1 = 1.0, 1.0 + growth
    g0, _ = gap(l0)
    g1, sol = gap(l1)
    for _ in range(50):
        if abs(g1) < 1e-13:
            return l1, sol
        l0, l1, g0 = l1, l1 - g1 * (l1 - l0) / (g1 - g0), g1
        g1, sol = gap(l1)
    raise RuntimeError("targeting real value added did not converge")
