"""Synthetic SAMs of any size, for scale benchmarks (version 0.2.0).

SYNTHETIC DATA: the SAMs describe no country. Each has n activities paired
with n commodities, formal and informal labour and capital, h household
groups, an enterprise, government with direct, sales and import taxes,
savings-investment and the rest of the world. Intermediate input use is dense
(about half of all commodity-activity cells), so that the SAM resembles a
detailed national input-output table.

Construction, as in the synthetic health SAM of the testing work: every
account other than government, savings-investment and the rest of the world
spends its income in fixed (random) shares, those three inject fixed amounts,
and totals solve a SAM multiplier system, so the SAM balances by construction.

Usage: python tools/bench/gen_large_sam.py <activities> <households> <output.csv> [seed]
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

import numpy as np


def build(n: int, nh: int, seed: int = 1) -> tuple[list[str], np.ndarray]:
    rng = np.random.default_rng(seed)
    A = [f"a{k:03d}" for k in range(1, n + 1)]
    C = [f"c{k:03d}" for k in range(1, n + 1)]
    F = ["lab_f", "lab_i", "cap"]
    H = [f"hh{k:02d}" for k in range(1, nh + 1)]
    endo = A + C + F + H + ["ent", "tax_dir", "tax_sal", "tax_imp"]
    accounts = endo + ["gov", "sav", "row"]
    ix = {a: k for k, a in enumerate(accounts)}
    m = len(accounts)
    shares = np.zeros((m, m))

    for k, a in enumerate(A):
        inter = rng.uniform(0.3, 0.65)
        used = rng.random(n) < 0.5
        used[k] = True
        w = rng.lognormal(0, 1, n) * used
        for j, c in enumerate(C):
            shares[ix[c], ix[a]] = inter * w[j] / w.sum()
        va = rng.dirichlet([2, 3, 3])
        for f, s in zip(F, va):
            shares[ix[f], ix[a]] = (1 - inter) * s
    for k, c in enumerate(C):
        imported = rng.random() < 0.7
        mshare = rng.uniform(0.05, 0.5) if imported else 0.0
        tariff = mshare * rng.uniform(0, 0.15)
        stax = rng.uniform(0, 0.06)
        shares[ix[A[k]], ix[c]] = 1 - mshare - tariff - stax
        shares[ix["row"], ix[c]] = mshare
        shares[ix["tax_imp"], ix[c]] = tariff
        shares[ix["tax_sal"], ix[c]] = stax
    hw = rng.dirichlet(np.ones(nh))
    for f in F:
        to_hh = 0.95 if f != "cap" else 0.35
        for h, s in zip(H, rng.dirichlet(np.ones(nh) * 2)):
            shares[ix[h], ix[f]] = to_hh * s
        if f == "cap":
            shares[ix["ent"], ix[f]] = 0.55
            shares[ix["gov"], ix[f]] = 0.04
            shares[ix["row"], ix[f]] = 0.06
        else:
            shares[ix["row"], ix[f]] = 0.05
    for k, h in enumerate(H):
        tax = 0.02 + 0.1 * k / max(1, nh - 1)
        sav = 0.03 + 0.12 * k / max(1, nh - 1)
        basket = rng.lognormal(0, 1, n) * (rng.random(n) < 0.7)
        cons = 1 - tax - sav
        for j, c in enumerate(C):
            shares[ix[c], ix[h]] = cons * basket[j] / basket.sum()
        shares[ix["tax_dir"], ix[h]] = tax
        shares[ix["sav"], ix[h]] = sav
    for h, s in zip(H, hw):
        shares[ix[h], ix["ent"]] = 0.5 * s
    shares[ix["tax_dir"], ix["ent"]] = 0.15
    shares[ix["sav"], ix["ent"]] = 0.25
    shares[ix["row"], ix["ent"]] = 0.10
    for t in ("tax_dir", "tax_sal", "tax_imp"):
        shares[ix["gov"], ix[t]] = 1.0
    e = [ix[a] for a in endo]
    if not np.allclose(shares[:, e].sum(axis=0), 1.0):
        raise SystemExit("column shares do not sum to one")

    sam = np.zeros((m, m))
    scale = 1000.0 * n
    gov_c = rng.random(n) < 0.3
    for j, c in enumerate(C):
        if gov_c[j]:
            sam[ix[c], ix["gov"]] = scale * rng.uniform(0.2, 1.0)
        if rng.random() < 0.4:
            sam[ix[c], ix["sav"]] = scale * rng.uniform(0.2, 1.5)
        if rng.random() < 0.6:
            sam[ix[c], ix["row"]] = scale * rng.uniform(0.2, 2.0)
    for h in H:
        sam[ix[h], ix["gov"]] = scale * rng.uniform(0.05, 0.3)
        sam[ix[h], ix["row"]] = scale * rng.uniform(0.05, 0.3)
    sam[ix["gov"], ix["row"]] = scale * 0.5
    Am = shares[np.ix_(e, e)]
    y = np.linalg.solve(np.eye(len(e)) - Am, sam[e].sum(axis=1))
    for k, j in enumerate(e):
        sam[:, j] = shares[:, j] * y[k]
    g, s, r = ix["gov"], ix["sav"], ix["row"]
    sam[s, g] = sam[g].sum() - sam[:, g].sum()
    sam[s, r] = sam[r].sum() - sam[:, r].sum()
    worst = np.abs(sam.sum(axis=1) - sam.sum(axis=0)).max()
    if worst > 1e-6 * np.abs(sam).max():
        raise SystemExit(f"SAM not balanced: {worst}")
    return accounts, sam


def write(path: Path, labels: list[str], sam: np.ndarray) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        w = csv.writer(handle, lineterminator="\n")
        w.writerow(["account", *labels])
        for label, row in zip(labels, sam):
            w.writerow([label, *(repr(float(v)) if v != 0 else "0" for v in row)])


if __name__ == "__main__":
    n, nh, out = int(sys.argv[1]), int(sys.argv[2]), Path(sys.argv[3])
    seed = int(sys.argv[4]) if len(sys.argv) > 4 else 1
    labels, sam = build(n, nh, seed)
    write(out, labels, sam)
    print(f"SYNTHETIC SAM: {len(labels)} accounts, {int((sam != 0).sum())} non-zero cells -> {out}")
