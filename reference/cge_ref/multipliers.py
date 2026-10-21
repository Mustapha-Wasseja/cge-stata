"""SAM accounting multipliers and their decomposition (version 0.4.1;
docs/sam_tools.md, Section 6; Pyatt and Round 1979)."""

from __future__ import annotations

import dataclasses

import numpy as np

from .sam import SAM, Mapping, SAMError


@dataclasses.dataclass
class Multipliers:
    labels: list[str]          # endogenous accounts, in order
    blocks: np.ndarray         # 1 production, 2 factors, 3 institutions
    A: np.ndarray              # average expenditure propensities
    M: np.ndarray              # (I - A)^-1
    parts: dict | None = None  # transfer, open-loop and closed-loop terms

    def index(self, label: str) -> int:
        return self.labels.index(label)

    def inject(self, injections: dict[str, float]) -> np.ndarray:
        x = np.zeros(len(self.labels))
        for label, value in injections.items():
            if label not in self.labels:
                raise SAMError(f"inject: {label} is not an endogenous account")
            x[self.index(label)] = value
        return self.M @ x


def endogenous_accounts(mapping: Mapping, endogenous=(), exogenous=()) -> tuple[list[str], list[int]]:
    """Endogenous accounts and their blocks: by default production (activities,
    commodities, margin accounts), factors, and institutions (households and
    enterprises); endogenous() adds accounts to the institutions block and
    exogenous() removes accounts."""
    margins = (list(mapping.margin_accounts) + list(mapping.domestic_margins) + list(mapping.import_margins)
               + list(mapping.export_margins))
    labels = list(mapping.activities) + list(mapping.commodities) + margins + list(mapping.factors) \
        + list(mapping.households) + list(mapping.enterprises)
    blocks = [1] * (len(mapping.activities) + len(mapping.commodities) + len(margins)) \
        + [2] * len(mapping.factors) + [3] * (len(mapping.households) + len(mapping.enterprises))
    for a in exogenous:
        if a not in labels:
            raise SAMError(f"exogenous: {a} is not an endogenous account")
        k = labels.index(a)
        del labels[k], blocks[k]
    for a in endogenous:
        if a in labels:
            raise SAMError(f"endogenous: {a} is already endogenous")
        labels.append(a)
        blocks.append(3)
    return labels, blocks


def multipliers(sam: SAM, mapping: Mapping, endogenous=(), exogenous=(), decompose=False) -> Multipliers:
    """Accounting multipliers of a SAM in the model's layout (after prepare())."""
    labels, blocks = endogenous_accounts(mapping, endogenous, exogenous)
    for a in labels:
        if a not in sam.labels:
            raise SAMError(f"{a} is not an account of the SAM")
    idx = [sam.labels.index(a) for a in labels]
    totals = sam.values.sum(axis=0)
    t = totals[idx]
    A = sam.values[np.ix_(idx, idx)] / np.where(t != 0, t, 1.0)[None, :]
    n = len(idx)
    I = np.eye(n)
    M = np.linalg.inv(I - A)
    out = Multipliers(labels, np.array(blocks), A, M)
    if decompose:
        b = out.blocks
        same = b[:, None] == b[None, :]
        # flows outside the circle production -> factors -> institutions -> production
        circle = ((b[:, None] == 2) & (b[None, :] == 1)) | ((b[:, None] == 3) & (b[None, :] == 2)) | \
                 ((b[:, None] == 1) & (b[None, :] == 3))
        off = ~same & ~circle & (np.abs(A) > 1e-12)
        if off.any():
            raise SAMError("decompose: the SAM has flows outside the circular block structure")
        At = np.where(same, A, 0.0)
        M1 = np.linalg.inv(I - At)
        As = M1 @ (A - At)
        M2 = I + As + As @ As
        M3 = np.linalg.inv(I - As @ As @ As)
        out.parts = {"M1": M1, "M2": M2, "M3": M3, "transfer": M1 - I, "open_loop": (M2 - I) @ M1,
                     "closed_loop": (M3 - I) @ M2 @ M1}
    return out


def from_model(model, **kwargs) -> Multipliers:
    return multipliers(model.sam, model.mapping, **kwargs)


@dataclasses.dataclass
class Path:
    poles: list[str]
    direct: float               # product of the intensities along the path
    multiplier: float           # det of M on the path's poles
    total: float                # direct * multiplier


def structural_paths(r: Multipliers, origin: str, destination: str, maxlength: int = 6,
                     threshold: float = 0.001) -> tuple[float, list[Path]]:
    """Elementary paths from origin to destination (docs/sam_tools.md, Section
    7; Defourny and Thorbecke 1984), with at most maxlength arcs and a direct
    influence of at least threshold times the global influence in absolute
    value. Returns the global influence and the paths, largest total
    influence first."""
    if origin not in r.labels or destination not in r.labels:
        raise SAMError("origin and destination must be endogenous accounts")
    if origin == destination:
        raise SAMError("origin and destination must differ")
    i, j = r.index(origin), r.index(destination)
    glob = float(r.M[j, i])
    floor = threshold * abs(glob)
    A, n = r.A, len(r.labels)
    found: list[tuple[list[int], float]] = []

    def extend(path: list[int], direct: float) -> None:
        c = path[-1]
        for k in range(n):
            a = A[k, c]
            if a == 0 or k in path:
                continue
            d = direct * a
            if abs(d) < floor:
                continue
            if k == j:
                found.append((path + [k], d))
            elif len(path) <= maxlength - 1:
                extend(path + [k], d)

    extend([i], 1.0)
    paths = []
    for poles, d in found:
        m = float(np.linalg.det(r.M[np.ix_(poles, poles)]))
        paths.append(Path([r.labels[k] for k in poles], d, m, d * m))
    paths.sort(key=lambda p: (-abs(p.total), " ".join(p.poles)))
    return glob, paths
