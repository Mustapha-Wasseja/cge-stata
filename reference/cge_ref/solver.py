"""Newton solver for square nonlinear systems F(z) = 0."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

import numpy as np


@dataclass
class SolverResult:
    z: np.ndarray
    converged: bool
    iterations: int
    max_residual: float
    method: str


def _jacobian(F: Callable[[np.ndarray], np.ndarray], z: np.ndarray) -> np.ndarray:
    """Central-difference Jacobian."""
    n = z.size
    J = np.empty((n, n))
    for j in range(n):
        h = 1e-6 * max(1.0, abs(z[j]))
        zp = z.copy()
        zm = z.copy()
        zp[j] += h
        zm[j] -= h
        J[:, j] = (F(zp) - F(zm)) / (2.0 * h)
    return J


def newton(F: Callable[[np.ndarray], np.ndarray], z0: np.ndarray,
           tol: float = 1e-10, max_iter: int = 100) -> SolverResult:
    """Newton-Raphson with a backtracking line search on the residual norm."""
    z = np.array(z0, dtype=float)
    with np.errstate(all="ignore"):
        f = F(z)
    if not np.all(np.isfinite(f)):
        return SolverResult(z, False, 0, float("inf"), "newton")

    for iteration in range(max_iter + 1):
        err = float(np.max(np.abs(f))) if f.size else 0.0
        if err < tol:
            return SolverResult(z, True, iteration, err, "newton")
        if iteration == max_iter:
            break
        with np.errstate(all="ignore"):
            J = _jacobian(F, z)
        if not np.all(np.isfinite(J)):
            break
        try:
            dz = np.linalg.solve(J, -f)
        except np.linalg.LinAlgError:
            break

        norm0 = np.linalg.norm(f)
        step = 1.0
        while step >= 1e-8:
            z_new = z + step * dz
            with np.errstate(all="ignore"):
                f_new = F(z_new)
            if np.all(np.isfinite(f_new)) and np.linalg.norm(f_new) <= (1.0 - 1e-4 * step) * norm0:
                break
            step *= 0.5
        else:
            break
        z, f = z_new, f_new

    err = float(np.max(np.abs(f))) if f.size else 0.0
    return SolverResult(z, False, iteration, err, "newton")


def solve_system(F: Callable[[np.ndarray], np.ndarray], z0: np.ndarray,
                 tol: float = 1e-10, max_iter: int = 100) -> SolverResult:
    """Solve with Newton; if that fails, retry with MINPACK's hybrid method."""
    result = newton(F, z0, tol, max_iter)
    if result.converged:
        return result

    from scipy.optimize import root

    start = result.z if np.isfinite(result.max_residual) else np.asarray(z0, dtype=float)
    with np.errstate(all="ignore"):
        fallback = root(F, start, method="hybr", tol=1e-14)
        f = F(fallback.x)
    err = float(np.max(np.abs(f))) if np.all(np.isfinite(f)) else float("inf")
    return SolverResult(fallback.x, err < tol, result.iterations + int(fallback.nfev), err, "hybr")
