"""Policy optimisation (version 0.6.0; docs/model_spec.md, Section 18).

``optimize(model, instruments, ...)`` chooses the values of a few
instruments -- elements of parameters, such as a tax rate, or of variables
that the closure fixes, such as government consumption -- to maximise or
minimise a report measure, or to reach targets for report measures, solving
the model at every trial value. It is the reference for cge_optimize.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
from scipy.optimize import least_squares, minimize

from .model import VARIABLES, Closure, Solution
from .report import report


@dataclass
class Instrument:
    """One element of a parameter or of a variable the closure fixes, with
    optional bounds."""

    name: str
    element: tuple = ()
    lower: float | None = None
    upper: float | None = None


@dataclass
class Optimum:
    values: np.ndarray                 # the instruments at the optimum
    solution: Solution
    objective: float | None
    targets: np.ndarray                # target measures at the optimum
    converged: bool
    evaluations: int
    message: str = ""
    history: list = field(default_factory=list)


def _measure(rows: dict, key: tuple) -> float:
    if key not in rows:
        raise ValueError(f"no report measure {key}")
    return rows[key]


def optimize(model, instruments, objective=None, sense: str = "max", targets=(), closure: Closure | None = None,
             params: dict | None = None, fixed: dict | None = None, tol: float = 1e-12) -> Optimum:
    """objective: (table, measure, element); targets: [((table, measure,
    element), value), ...]. With an objective, the targets are equality
    constraints; without one, there must be as many targets as instruments."""
    closure = closure or Closure()
    if sense not in ("max", "min"):
        raise ValueError("sense must be max or min")
    if objective is None and len(targets) != len(instruments):
        raise ValueError("without an objective, give one target for each instrument")
    is_fixed = closure.fixed(model)
    base_p = {k: np.array(v, dtype=float, copy=True) for k, v in model.params.items()}
    for k, v in (params or {}).items():
        base_p[k] = np.broadcast_to(np.asarray(v, dtype=float), base_p[k].shape).copy()
    base_x = {k: np.array(v, dtype=float, copy=True) for k, v in model.base.items()}
    for k, v in (fixed or {}).items():
        base_x[k] = np.broadcast_to(np.asarray(v, dtype=float), base_x[k].shape).copy()

    # where each instrument lives: a parameter element or a fixed variable element
    where, start = [], []
    for ins in instruments:
        if ins.name in VARIABLES:
            name, k = model.position(ins.name, "instrument", ins.element)
            if not is_fixed[name].ravel()[k]:
                raise ValueError(f"instrument {ins.name}{ins.element} is not fixed under the closure")
            where.append(("x", name, k))
            start.append(base_x[name].ravel()[k])
        elif ins.name in PARAM_SETS:
            arr = base_p[ins.name]
            labels = _param_labels(model, ins.name)
            key = tuple(ins.element)
            if arr.ndim == 0:
                k = 0
            else:
                if key not in labels:
                    raise ValueError(f"instrument {ins.name}{ins.element}: no such element")
                k = labels.index(key)
            where.append(("p", ins.name, k))
            start.append(arr.ravel()[k])
        else:
            raise ValueError(f"instrument {ins.name} is not a parameter or variable")
    start = np.array(start, dtype=float)
    scale = np.where(np.abs(start) > 1e-12, np.abs(start), 1.0)

    last = {"start": None}
    count = {"n": 0}

    def evaluate(z):
        values = z * scale
        p = {k: v.copy() for k, v in base_p.items()}
        fx = {k: v.copy() for k, v in base_x.items()}
        for (kind, name, k), value in zip(where, values):
            target = p if kind == "p" else fx
            arr = target[name]
            if arr.ndim == 0:
                target[name] = np.array(value)
            else:
                arr.ravel()[k] = value
        changed_fixed = {k: v for k, v in fx.items() if np.any(v != model.base[k])}
        sol = model.solve(closure, params=p, fixed=changed_fixed, start=last["start"], tol=tol)
        if not sol.converged:
            raise RuntimeError(f"the model did not solve at instruments {values}")
        last["start"] = sol.values
        count["n"] += 1
        rows = {(t, m, e): v for t, m, e, b, v in report(sol)}
        return sol, rows

    tkeys = [tuple(k) for k, _ in targets]
    tvals = np.array([float(v) for _, v in targets])
    tscale = np.where(np.abs(tvals) > 1e-12, np.abs(tvals), 1.0)
    sign = -1.0 if sense == "max" else 1.0
    bounds = [(None if ins.lower is None else ins.lower / s, None if ins.upper is None else ins.upper / s)
              for ins, s in zip(instruments, scale)]
    cache = {}

    def at(z):
        key = tuple(np.round(z, 15))
        if key not in cache:
            cache[key] = evaluate(z)
        return cache[key]

    z0 = np.ones(len(start))
    if objective is None:
        def resid(z):
            _, rows = at(z)
            return np.array([_measure(rows, k) for k in tkeys]) / tscale - tvals / tscale
        lo = [b[0] if b[0] is not None else -np.inf for b in bounds]
        hi = [b[1] if b[1] is not None else np.inf for b in bounds]
        res = least_squares(resid, z0, bounds=(lo, hi), xtol=1e-15, ftol=1e-15, gtol=1e-15)
        z, ok, msg = res.x, bool(np.max(np.abs(res.fun)) < 1e-9), res.message
    else:
        okey = tuple(objective)
        oscale = max(1.0, abs(_measure(at(z0)[1], okey)))

        def fun(z):
            return sign * _measure(at(z)[1], okey) / oscale

        def central(g):
            """A gradient by central differences (step 1e-5 in scaled units),
            one-sided at a bound: forward differences are too noisy for the
            optimum to be located to better than about 1e-6."""
            h = 1e-5

            def grad(z):
                out = np.zeros(len(z))
                for i in range(len(z)):
                    e = np.zeros(len(z))
                    e[i] = h
                    up = bounds[i][1] is None or z[i] + h <= bounds[i][1]
                    dn = bounds[i][0] is None or z[i] - h >= bounds[i][0]
                    if up and dn:
                        out[i] = (g(z + e) - g(z - e)) / (2 * h)
                    elif up:
                        out[i] = (g(z + e) - g(z)) / h
                    else:
                        out[i] = (g(z) - g(z - e)) / h
                return out
            return grad

        cons = []
        for i in range(len(tkeys)):
            gi = (lambda z, i=i: _measure(at(z)[1], tkeys[i]) / tscale[i] - tvals[i] / tscale[i])
            cons.append({"type": "eq", "fun": gi, "jac": central(gi)})
        res = minimize(fun, z0, jac=central(fun), method="SLSQP", bounds=bounds, constraints=cons,
                       options={"ftol": 1e-15, "maxiter": 500})
        z, ok, msg = res.x, bool(res.success), res.message
    sol, rows = evaluate(z)
    return Optimum(values=z * scale, solution=sol,
                   objective=None if objective is None else _measure(rows, tuple(objective)),
                   targets=np.array([_measure(rows, k) for k in tkeys]), converged=ok,
                   evaluations=count["n"], message=str(msg))


# Parameters that may be instruments, with their index sets: those that
# cge_shock changes and cge_gams exports
PARAM_SETS = {"tm": "C", "te": "C", "tq": "C", "ta": "A", "tv": "C", "kappa": "A", "pwm": "C", "pwe": "C",
              "ad": "A", "af": "F", "qg": "C", "qinv": "C", "trdg": "D", "trdr": "D", "trfr": "F", "trgr": "",
              "trrg": "", "tshi": "F", "qshi": "C", "trshi": "", "trshir": "", "rd": "", "rf": "", "ddebt": "",
              "fdebt": "", "qlf": "F", "wmin": "F", "wref": "F", "sick": "F", "tfy": "F"}


def _param_labels(model, name: str) -> list[tuple]:
    """Element labels of an instrument parameter, as tuples."""
    if name not in PARAM_SETS:
        raise ValueError(f"instrument {name}: not a parameter that may be an instrument")
    s = PARAM_SETS[name]
    return [()] if s == "" else [(e,) for e in model.sets[s]]
