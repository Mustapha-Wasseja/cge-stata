"""SAM tools (docs/sam_tools.md): aggregation and balancing.

Cell (r, c) of a SAM is a payment from column account c to row account r.
Both balancing methods keep signs, zeros and fixed cells, and minimise

    D(X, Xbar) = sum |x| ln(|x| / |xbar|) - |x| + |xbar|

over the cells that may change: RAS (generalised RAS, GRAS) given every
account's total, cross entropy given balance and any known totals.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from .sam import SAM, SAMError


@dataclass
class BalanceInfo:
    method: str
    iterations: int
    maxdiff_before: float
    maxdiff: float
    targets: np.ndarray = field(repr=False)


def aggregate(sam: SAM, groups: dict[str, list[str]], net_diagonal: bool = False) -> SAM:
    """Merge accounts into groups (Section 4): X = G Xbar G'."""
    member_of: dict[str, str] = {}
    for group, members in groups.items():
        for member in members:
            sam.index(member)
            if member in member_of:
                raise SAMError(f"account {member} is in two groups")
            member_of[member] = group
    for group in groups:
        if group in sam.labels and member_of.get(group, group) != group:
            raise SAMError(f"group {group} has the label of an account in another group")
        if group in sam.labels and group not in member_of:
            raise SAMError(f"group {group} has the label of an account left as it is")
    labels: list[str] = []
    position: dict[str, int] = {}
    for label in sam.labels:
        new = member_of.get(label, label)
        if new not in position:
            position[new] = len(labels)
            labels.append(new)
    G = np.zeros((len(labels), len(sam.labels)))
    for k, label in enumerate(sam.labels):
        G[position[member_of.get(label, label)], k] = 1.0
    values = G @ sam.values @ G.T
    if net_diagonal:
        np.fill_diagonal(values, 0.0)
    return SAM(labels, values)


def fixed_mask(sam: SAM, fixed: list[str] | tuple[str, ...] = ()) -> np.ndarray:
    """Cells kept at their values: 'row:col', 'row:*', '*:col' or 'account'."""
    n = len(sam.labels)
    mask = np.zeros((n, n), dtype=bool)
    for item in fixed:
        if ":" in item:
            row, col = item.split(":", 1)
            rows = slice(None) if row == "*" else sam.index(row)
            cols = slice(None) if col == "*" else sam.index(col)
            if row == "*" and col == "*":
                raise SAMError("fixed(): *:* fixes every cell")
            mask[rows, cols] = True
        else:
            k = sam.index(item)
            mask[k, :] = True
            mask[:, k] = True
    return mask


def _parts(values: np.ndarray, free: np.ndarray):
    P = np.where(free & (values > 0), values, 0.0)
    N = np.where(free & (values < 0), -values, 0.0)
    F = np.where(free, 0.0, values)
    return P, N, F


def _scale(values: np.ndarray) -> float:
    return max(1.0, float(np.abs(values).max()))


def _maxdiff(values: np.ndarray) -> float:
    return float(np.abs(values.sum(axis=1) - values.sum(axis=0)).max())


def _factor(u: np.ndarray, p: np.ndarray, n: np.ndarray, active: np.ndarray, what: str,
            labels: list[str]) -> np.ndarray:
    """Positive root r of p r^2 - u r - n = 0, in the stable form for each sign of u."""
    r = np.ones_like(u)
    for k in np.flatnonzero(active):
        d = np.sqrt(u[k] ** 2 + 4.0 * p[k] * n[k])
        if u[k] >= 0:
            x = (u[k] + d) / (2.0 * p[k]) if p[k] > 0 else np.inf
        else:
            x = 2.0 * n[k] / (d - u[k])
        if not (np.isfinite(x) and x > 0):
            raise SAMError(f"the {what} target of {labels[k]} cannot be met with the signs of its cells")
        r[k] = x
    return r


def _targets(sam: SAM, free: np.ndarray, F: np.ndarray, totals: dict[str, float],
             rule: str, tol: float) -> np.ndarray:
    values = sam.values
    rows, cols = values.sum(axis=1), values.sum(axis=0)
    if rule == "average":
        t = 0.5 * (rows + cols)
    elif rule == "rows":
        t = rows.copy()
    elif rule == "columns":
        t = cols.copy()
    else:
        raise SAMError(f"targets(): {rule} is not average, rows or columns")
    given = np.zeros(len(t), dtype=bool)
    for account, value in totals.items():
        k = sam.index(account)
        t[k] = float(value)
        given[k] = True
    row_free, col_free = free.any(axis=1), free.any(axis=0)
    frow, fcol = F.sum(axis=1), F.sum(axis=0)
    for k, label in enumerate(sam.labels):
        implied = []
        if not row_free[k]:
            implied.append(frow[k])
        if not col_free[k]:
            implied.append(fcol[k])
        if not implied:
            continue
        if len(implied) == 2 and abs(implied[0] - implied[1]) > tol:
            raise SAMError(f"{label}: its row and column cannot change and their totals differ")
        if given[k] and abs(t[k] - implied[0]) > tol:
            raise SAMError(f"{label}: the given total differs from the total of cells that cannot change")
        t[k] = implied[0]
    return t


def ras(sam: SAM, totals: dict[str, float] | None = None, targets: str = "average",
        fixed: list[str] | tuple[str, ...] = (), tol: float = 1e-10,
        maxit: int = 10000) -> tuple[SAM, BalanceInfo]:
    """Generalised RAS (Section 5.1): row and column totals set to the targets."""
    values = sam.values
    scale = _scale(values)
    free = (values != 0) & ~fixed_mask(sam, fixed)
    P, N, F = _parts(values, free)
    t = _targets(sam, free, F, totals or {}, targets, tol * scale)
    u = t - F.sum(axis=1)
    v = t - F.sum(axis=0)
    row_free, col_free = free.any(axis=1), free.any(axis=0)
    r = np.ones(len(t))
    s = np.ones(len(t))
    frow, fcol = F.sum(axis=1), F.sum(axis=0)
    history = []
    for it in range(1, maxit + 1):
        r = _factor(u, P @ s, N @ (1.0 / s), row_free, "row", sam.labels)
        s = _factor(v, P.T @ r, N.T @ (1.0 / r), col_free, "column", sam.labels)
        # Row and column totals of X without forming it
        rows = r * (P @ s) - (N @ (1.0 / s)) / r + frow
        cols = s * (P.T @ r) - (N.T @ (1.0 / r)) / s + fcol
        err = max(np.abs(rows - t).max(), np.abs(cols - t).max())
        if err <= tol * scale:
            break
        # A gap that no longer falls means the targets cannot be met with the
        # zeros and fixed cells of the SAM
        history.append(err)
        if it > 100 and err >= (1 - 1e-6) * history[-101]:
            raise SAMError(f"RAS stopped after {it} iterations with a gap of {err:.6g} that no longer falls: "
                           "the targets cannot be met with the zeros and fixed cells of the SAM")
    else:
        raise SAMError(f"RAS did not converge in {maxit} iterations")
    X = r[:, None] * P * s[None, :] - N / (r[:, None] * s[None, :]) + F
    info = BalanceInfo("ras", it, _maxdiff(values), _maxdiff(X), t)
    return SAM(list(sam.labels), X), info


def _components(free: np.ndarray) -> list[list[int]]:
    """Accounts connected by off-diagonal cells that may change."""
    n = free.shape[0]
    link = free | free.T
    np.fill_diagonal(link, False)
    seen = np.zeros(n, dtype=bool)
    parts = []
    for start in range(n):
        if seen[start]:
            continue
        stack, part = [start], []
        seen[start] = True
        while stack:
            k = stack.pop()
            part.append(k)
            for m in np.flatnonzero(link[k] & ~seen):
                seen[m] = True
                stack.append(m)
        parts.append(sorted(part))
    return parts


def cross_entropy(sam: SAM, totals: dict[str, float] | None = None,
                  fixed: list[str] | tuple[str, ...] = (), tol: float = 1e-10,
                  maxit: int = 100) -> tuple[SAM, BalanceInfo]:
    """Cross entropy (Section 5.2): balance, any known totals, minimum D(X, Xbar)."""
    values = sam.values
    n = len(sam.labels)
    scale = _scale(values)
    free = (values != 0) & ~fixed_mask(sam, fixed)
    P, N, F = _parts(values, free)
    c = F.sum(axis=1) - F.sum(axis=0)
    frow, fcol = F.sum(axis=1), F.sum(axis=0)
    row_free, col_free = free.any(axis=1), free.any(axis=0)
    known = np.zeros(n, dtype=bool)
    t = np.zeros(n)
    for account, value in (totals or {}).items():
        k = sam.index(account)
        known[k] = True
        t[k] = float(value)
    # A known total whose row or column cannot change is implied by the fixed
    # cells; it must agree with them and needs no multiplier
    rho_free = known.copy()
    for k in np.flatnonzero(known):
        implied = None if row_free[k] else frow[k]
        if not col_free[k]:
            implied = fcol[k]
        if implied is not None:
            if abs(t[k] - implied) > tol * scale:
                raise SAMError(f"{sam.labels[k]}: the given total differs from the total of cells that cannot change")
            rho_free[k] = False
    # One balance multiplier in each connected set of accounts is fixed at
    # zero; the fixed cells of each set must balance among themselves
    mu_free = np.ones(n, dtype=bool)
    for part in _components(free):
        if abs(c[part].sum()) > tol * scale:
            raise SAMError("the cells that cannot change do not balance for accounts " + " ".join(sam.labels[k] for k in part))
        mu_free[part[0]] = False
    iK = np.flatnonzero(rho_free)
    imu = np.flatnonzero(mu_free)
    nmu = len(imu)

    def cells(mu, rho_full):
        A = mu[:, None] - mu[None, :] + rho_full[:, None]
        with np.errstate(over="ignore", invalid="ignore"):
            Xp = np.where(P > 0, P * np.exp(np.where(P > 0, A, 0.0)), 0.0)
            Xn = np.where(N > 0, N * np.exp(np.where(N > 0, -A, 0.0)), 0.0)
        return Xp, Xn

    def unpack(theta):
        mu = np.zeros(n)
        mu[imu] = theta[:nmu]
        rho = np.zeros(n)
        rho[iK] = theta[nmu:]
        return mu, rho

    def phi(theta):
        mu, rho = unpack(theta)
        Xp, Xn = cells(mu, rho)
        return Xp.sum() + Xn.sum() + mu @ c + rho[iK] @ (frow[iK] - t[iK])

    def gradient(Xp, Xn):
        X = Xp - Xn + F
        g = X.sum(axis=1) - X.sum(axis=0)
        h = X.sum(axis=1)[iK] - t[iK]
        return X, g, h

    theta = np.zeros(nmu + len(iK))
    mu, rho = unpack(theta)
    Xp, Xn = cells(mu, rho)
    X, g, h = gradient(Xp, Xn)
    for it in range(0, maxit + 1):
        err = max(np.abs(g).max(), np.abs(h).max() if len(iK) else 0.0)
        if err <= tol * scale:
            break
        if it == maxit:
            raise SAMError(f"cross entropy did not converge in {maxit} iterations")
        W = Xp + Xn
        rs, cs = W.sum(axis=1), W.sum(axis=0)
        Hmm = np.diag(rs + cs) - W - W.T
        Hrm = np.diag(rs)[iK, :] - W[iK, :]
        Hrr = np.diag(rs[iK])
        H = np.block([[Hmm[np.ix_(imu, imu)], Hrm[:, imu].T], [Hrm[:, imu], Hrr]])
        grad = np.concatenate([g[imu], h])
        step = -np.linalg.solve(H, grad)
        f0 = phi(theta)
        slope = grad @ step
        # Close to the solution the predicted decrease is below the rounding
        # of the dual, and the full Newton step is taken
        if -slope <= 1e-12 * max(1.0, abs(f0)):
            trial = theta + step
        else:
            alpha = 1.0
            for _ in range(60):
                trial = theta + alpha * step
                f1 = phi(trial)
                if np.isfinite(f1) and f1 <= f0 + 1e-4 * alpha * slope:
                    break
                alpha *= 0.5
            else:
                raise SAMError("cross entropy: the line search failed; no balanced SAM with this pattern may exist")
        theta = trial
        mu, rho = unpack(theta)
        Xp, Xn = cells(mu, rho)
        X, g, h = gradient(Xp, Xn)
    info = BalanceInfo("ce", it, _maxdiff(values), _maxdiff(X), X.sum(axis=1))
    return SAM(list(sam.labels), X), info


def information(new: SAM, prior: SAM) -> float:
    """D(X, Xbar) over the non-zero cells of the prior."""
    x, a = np.abs(new.values), np.abs(prior.values)
    nz = a > 0
    with np.errstate(divide="ignore", invalid="ignore"):
        terms = np.where(x[nz] > 0, x[nz] * np.log(x[nz] / a[nz]), 0.0) - x[nz] + a[nz]
    return float(terms.sum())


def write_sam(sam: SAM, path) -> None:
    """Write a SAM as CSV with an account column, numbers in repr form."""
    with open(path, "w", newline="", encoding="utf-8") as handle:
        handle.write(",".join(["account", *sam.labels]) + "\n")
        for label, row in zip(sam.labels, sam.values):
            handle.write(",".join([label, *(repr(float(v)) for v in row)]) + "\n")
