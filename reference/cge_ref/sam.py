"""Social accounting matrix (SAM) input and account mapping.

Cell (r, c) of a SAM is a payment from column account c to row account r.
"""

from __future__ import annotations

import csv
import dataclasses
from dataclasses import dataclass
from pathlib import Path

import numpy as np


class SAMError(ValueError):
    """Raised when a SAM or its mapping cannot be used by the model."""


@dataclass
class SAM:
    labels: list[str]
    values: np.ndarray

    def __post_init__(self) -> None:
        self.values = np.asarray(self.values, dtype=float)
        n = len(self.labels)
        if self.values.shape != (n, n):
            raise SAMError(f"SAM has {n} labels but values of shape {self.values.shape}")
        if len(set(self.labels)) != n:
            raise SAMError("SAM account labels are not unique")
        self._index = {label: i for i, label in enumerate(self.labels)}

    @classmethod
    def from_csv(cls, path: str | Path) -> "SAM":
        """Read a SAM with an ``account`` label column and one column per account."""
        with Path(path).open(newline="", encoding="utf-8") as handle:
            rows = list(csv.reader(handle))
        header = rows[0][1:]
        labels = [r[0] for r in rows[1:]]
        if header != labels:
            raise SAMError("row labels and column labels differ or are in a different order")
        values = [[float(v) for v in r[1:]] for r in rows[1:]]
        return cls(labels, np.array(values))

    def index(self, account: str) -> int:
        try:
            return self._index[account]
        except KeyError:
            raise SAMError(f"account '{account}' is not in the SAM") from None

    def cell(self, row: str, col: str) -> float:
        return float(self.values[self.index(row), self.index(col)])

    def row_total(self, account: str) -> float:
        return float(self.values[self.index(account), :].sum())

    def col_total(self, account: str) -> float:
        return float(self.values[:, self.index(account)].sum())

    def imbalances(self) -> np.ndarray:
        """Row total minus column total for each account."""
        return self.values.sum(axis=1) - self.values.sum(axis=0)


# Flows the version 0.1 model represents, as (row role, column role) pairs.
_ALLOWED = {
    ("act", "com"),
    ("com", "act"), ("fac", "act"), ("acttax", "act"),
    ("row", "com"), ("imptax", "com"), ("saltax", "com"), ("exptax", "com"),
    ("com", "hh"), ("com", "gov"), ("com", "sav"), ("com", "row"),
    ("hh", "fac"), ("ent", "fac"), ("gov", "fac"), ("row", "fac"),
    ("dirtax", "hh"), ("sav", "hh"), ("dirtax", "ent"), ("sav", "ent"),
    ("gov", "dirtax"), ("gov", "saltax"), ("gov", "imptax"), ("gov", "exptax"), ("gov", "acttax"),
    ("sav", "gov"), ("sav", "row"),
    ("mar", "com"), ("com", "mar"),          # margin accounts (version 0.1.7)
    # health insurance fund (version 0.1.13)
    ("shi", "fac"), ("shi", "gov"), ("shi", "row"), ("com", "shi"), ("sav", "shi"),
}
# Transfers (they may be negative)
_TRANSFERS = {
    ("hh", "hh"), ("hh", "ent"), ("ent", "hh"), ("ent", "ent"),
    ("row", "hh"), ("row", "ent"),
    ("hh", "gov"), ("ent", "gov"), ("gov", "gov"), ("row", "gov"),
    ("hh", "row"), ("ent", "row"), ("gov", "row"), ("fac", "row"),
}
_ALLOWED |= _TRANSFERS

# Row roles whose cells may be negative (taxes, subsidies, savings), and other
# cells that may be negative (transfers and tax-account payments).
_MAY_BE_NEGATIVE = {"dirtax", "saltax", "imptax", "exptax", "acttax", "sav"}
_NEGATIVE_CELLS = _TRANSFERS | {("gov", "dirtax"), ("gov", "saltax"), ("gov", "imptax"),
                                ("gov", "exptax"), ("gov", "acttax"), ("com", "sav"),
                                ("act", "com")}

TAX_ROLES = ("dirtax", "saltax", "imptax", "exptax", "acttax")
COMMODITY_TAXES = ("saltax", "imptax", "exptax")


def _territorial(values: np.ndarray, sam: "SAM", m: "Mapping") -> dict[str, float]:
    """Rewrite 4 of model_spec.md, 7.0: the territorial correction (in place)."""
    if len(m.territorial) not in (1, 2):
        raise SAMError("territorial needs the correction commodity and, optionally, its activity")
    mapped = _mapped_accounts(m)
    for name in m.territorial:
        sam.index(name)
        if name in mapped:
            raise SAMError(f"territorial: {name} is also mapped to a role")
    tol = 1e-9 * max(1.0, float(np.abs(values).max()))
    c, r = sam.index(m.territorial[0]), sam.index(m.row)
    if len(m.territorial) == 2:
        a = sam.index(m.territorial[1])
        x = values[a, r]
        values[c, r] += x
        values[a, c] += x
        values[a, r] = 0.0
        if np.abs(values[a, :]).max() > tol or np.abs(values[:, a]).max() > tol:
            raise SAMError(f"territorial: {m.territorial[1]} still has flows after its exports are moved")
    H = [sam.index(h) for h in m.households]
    imports, exports = values[r, c], values[c, r]
    consumption = values[c, H].copy()
    other_row = values[c, :].copy()
    other_row[H] = 0.0
    other_row[r] = 0.0
    other_col = values[:, c].copy()
    other_col[r] = 0.0
    if np.abs(other_row).max() > tol or np.abs(other_col).max() > tol:
        raise SAMError(f"territorial: {m.territorial[0]} may have only household consumption, "
                       "imports and exports")
    total = consumption.sum()
    if abs(total) <= tol:
        raise SAMError(f"territorial: households have no consumption of {m.territorial[0]}")
    share = consumption / total
    values[r, H] += share * imports
    values[H, r] += share * exports
    values[c, H] = 0.0
    values[c, r] = 0.0
    values[r, c] = 0.0
    return {"territorial_imports": float(imports), "territorial_exports": float(exports)}


def _mapped_accounts(m: "Mapping") -> set[str]:
    mapped = {*m.activities, *m.commodities, *m.factors, *m.households, *m.enterprises,
              *m.margin_accounts, m.government, m.savinv, m.row}
    if m.insurance is not None:
        mapped.add(m.insurance)
    return mapped | {getattr(m, t) for t in TAX_ROLES if getattr(m, t) is not None}


def _stocks(values: np.ndarray, sam: "SAM", m: "Mapping") -> float:
    """Rewrite 5 of model_spec.md, 7.0: merge stock-change accounts into savings-investment."""
    mapped = _mapped_accounts(m) | set(m.territorial)
    s = sam.index(m.savinv)
    tol = 1e-9 * max(1.0, float(np.abs(values).max()))
    merged = 0.0
    for name in m.stocks:
        k = sam.index(name)
        if name in mapped:
            raise SAMError(f"stocks: {name} is also mapped to a role")
        receipts = values[k, :].copy()
        receipts[s] = 0.0
        if np.abs(receipts).max() > tol:
            raise SAMError(f"stocks: {name} may receive payments only from {m.savinv}")
        merged += values[k, s]
        values[:, s] += values[:, k]
        values[:, k] = 0.0
        values[k, :] = 0.0
    return float(merged)


def prepare(sam: "SAM", mapping: "Mapping") -> tuple["SAM", "Mapping", dict[str, float]]:
    """Rewrite national-accounts layouts into the standard layout (model_spec.md, 7.0).

    Exports recorded as sales by activities are moved to the paired commodity
    rows; margins netted out of the activities listed in ``mapping.margins``
    (as a negative use of their own product) are moved to their output; and
    taxes paid directly to the government account are routed through internal
    tax accounts. Returns the rewritten SAM, a mapping that names the internal
    tax accounts, and the amounts rewritten.
    """
    m = dataclasses.replace(mapping)
    labels = list(sam.labels)
    values = sam.values.copy()
    for name in (*m.activities, *m.commodities, *m.households, *m.enterprises, m.government, m.row):
        sam.index(name)
    if len(m.commodities) < len(m.activities):
        raise SAMError(_PAIRING)
    direct = [t for t in TAX_ROLES if getattr(m, t) is not None and getattr(m, t) == m.government]
    if sum(t in COMMODITY_TAXES for t in direct) > 1:
        raise SAMError("only one of saltax, imptax and exptax may name the government account")

    notes: dict[str, float] = {}
    r = sam.index(m.row)
    moved = 0.0
    for a, c in zip(m.activities, m.commodities):
        ia, ic = sam.index(a), sam.index(c)
        x = values[ia, r]
        if x != 0:
            values[ic, r] += x
            values[ia, ic] += x
            values[ia, r] = 0.0
            moved += x
    notes["exports"] = moved

    pair = dict(zip(m.activities, m.commodities))
    netted = 0.0
    for a in m.margins:
        if a not in pair:
            raise SAMError(f"margins: {a} is not one of the mapped activities")
        ia, ic = sam.index(a), sam.index(pair[a])
        x = values[ic, ia]
        if x >= 0:
            raise SAMError(f"margins: activity {a} has no negative use of its own product {pair[a]}")
        values[ia, ic] -= x
        values[ic, ia] = 0.0
        netted -= x
    if m.margins:
        notes["margins"] = netted

    if m.territorial:
        notes.update(_territorial(values, sam, m))

    if m.stocks:
        notes["stocks"] = _stocks(values, sam, m)

    g = sam.index(m.government)
    for tax in direct:
        payers = {"dirtax": [*m.households, *m.enterprises],
                  "acttax": m.activities}.get(tax, m.commodities)
        cols = [sam.index(p) for p in payers]
        name = "_" + tax
        if name in labels:
            raise SAMError(f"the SAM already has an account named {name}")
        n = len(labels)
        values = np.pad(values, ((0, 1), (0, 1)))
        labels.append(name)
        values[n, cols] = values[g, cols]
        values[g, cols] = 0.0
        values[g, n] = values[n].sum()
        setattr(m, tax, name)
        notes[tax] = float(values[n].sum())
    return SAM(labels, values), m, notes


_PAIRING = ("each activity needs a paired commodity: list the commodities paired with the "
            "activities first, in the same order, then any commodities without a paired activity")


@dataclass
class Mapping:
    """Assignment of SAM accounts to model roles.

    Activities and commodities are paired by position: ``activities[k]`` is
    paired with ``commodities[k]``; commodities after the last paired one have
    no paired activity (for example commodities that are imported only). Tax
    accounts are optional; a missing tax account means that tax is zero.
    ``margin_accounts`` collect margins from commodities and buy margin
    services; ``stocks`` are stock-change accounts merged into savings-investment.
    """

    activities: list[str]
    commodities: list[str]
    factors: list[str]
    households: list[str]
    government: str
    savinv: str
    row: str
    dirtax: str | None = None
    saltax: str | None = None
    imptax: str | None = None
    exptax: str | None = None
    acttax: str | None = None
    enterprises: list[str] = dataclasses.field(default_factory=list)
    margins: list[str] = dataclasses.field(default_factory=list)
    territorial: list[str] = dataclasses.field(default_factory=list)
    margin_accounts: list[str] = dataclasses.field(default_factory=list)
    stocks: list[str] = dataclasses.field(default_factory=list)
    insurance: str | None = None

    def roles(self) -> dict[str, str]:
        """Role of every mapped account."""
        assigned: dict[str, str] = {}

        def assign(account: str, role: str) -> None:
            if account in assigned:
                raise SAMError(f"account '{account}' is mapped to both {assigned[account]} and {role}")
            assigned[account] = role

        for a in self.activities:
            assign(a, "act")
        for c in self.commodities:
            assign(c, "com")
        for f in self.factors:
            assign(f, "fac")
        for h in self.households:
            assign(h, "hh")
        for e in self.enterprises:
            assign(e, "ent")
        for t in self.margin_accounts:
            assign(t, "mar")
        if self.insurance is not None:
            assign(self.insurance, "shi")
        assign(self.government, "gov")
        assign(self.savinv, "sav")
        assign(self.row, "row")
        for role in TAX_ROLES:
            account = getattr(self, role)
            if account is not None:
                assign(account, role)
        return assigned

    def validate(self, sam: SAM, tol: float = 1e-8) -> dict[str, str]:
        """Check the SAM against the mapping and return the role of each account."""
        if len(self.commodities) < len(self.activities):
            raise SAMError(_PAIRING)
        if not self.factors or not self.households or not self.activities:
            raise SAMError("at least one activity, factor and household is required")

        roles = self.roles()
        for account in roles:
            sam.index(account)
        scale = max(1.0, float(np.abs(sam.values).max()))

        unmapped = [a for a in sam.labels if a not in roles]
        for account in unmapped:
            i = sam.index(account)
            if np.abs(sam.values[i, :]).max() > tol * scale or np.abs(sam.values[:, i]).max() > tol * scale:
                raise SAMError(f"account '{account}' has flows but is not mapped to a role")

        worst = np.abs(sam.imbalances()).max()
        if worst > tol * scale:
            raise SAMError(f"SAM is not balanced (largest row-column difference {worst:.3g})")

        pair = dict(zip(self.activities, self.commodities))
        for r_label in roles:
            for c_label in roles:
                value = sam.cell(r_label, c_label)
                if abs(value) <= tol * scale:
                    continue
                r_role, c_role = roles[r_label], roles[c_label]
                if (r_role, c_role) not in _ALLOWED:
                    raise SAMError(
                        f"flow from '{c_label}' ({c_role}) to '{r_label}' ({r_role}) "
                        "is not represented in the version 0.1 model"
                    )
                if value < 0 and r_role not in _MAY_BE_NEGATIVE and (r_role, c_role) not in _NEGATIVE_CELLS:
                    raise SAMError(f"negative flow from '{c_label}' to '{r_label}'")
        return roles
