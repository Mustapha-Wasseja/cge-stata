"""Synthetic social accounting matrix (SAM) for cge-stata tests and examples.

The SAM is constructed by hand from a consistent set of flows, so that every
account balances exactly (row total = column total). It is not data for any
country. All values are in arbitrary currency units, with all prices equal to
one in the base year.

Accounts
    act_agr, act_man, act_ser   activities (one activity per commodity)
    com_agr, com_man, com_ser   commodities
    lab, cap                    factors
    hhd                         households (one representative household)
    gov                         government
    tax_dir, tax_sal, tax_imp   direct, sales and import-tariff tax accounts
    sav                         savings-investment
    row                         rest of the world

Convention: each cell (r, c) is a payment from column account c to row
account r.

``build_national_accounts_layout`` gives the same economy in the layout of many
national SAMs (exports in activity rows, taxes paid directly to government).

Run as a script to (re)write ``data/cge_synthetic_sam.csv`` and
``data/cge_synthetic_sam_na.csv``:

    python reference/synthetic_sam.py
"""

from __future__ import annotations

import csv
from pathlib import Path

ACCOUNTS = [
    "act_agr", "act_man", "act_ser",
    "com_agr", "com_man", "com_ser",
    "lab", "cap",
    "hhd", "gov",
    "tax_dir", "tax_sal", "tax_imp",
    "sav", "row",
]

# (receiving row account, paying column account): value
FLOWS = {
    # Activities sell their output to the matching commodity account.
    ("act_agr", "com_agr"): 100, ("act_man", "com_man"): 140, ("act_ser", "com_ser"): 150,
    # Intermediate inputs (commodity rows, activity columns).
    ("com_agr", "act_agr"): 10, ("com_man", "act_agr"): 8, ("com_ser", "act_agr"): 5,
    ("com_agr", "act_man"): 20, ("com_man", "act_man"): 30, ("com_ser", "act_man"): 15,
    ("com_agr", "act_ser"): 5, ("com_man", "act_ser"): 15, ("com_ser", "act_ser"): 20,
    # Value added (factor rows, activity columns).
    ("lab", "act_agr"): 40, ("cap", "act_agr"): 37,
    ("lab", "act_man"): 35, ("cap", "act_man"): 40,
    ("lab", "act_ser"): 60, ("cap", "act_ser"): 50,
    # Household consumption at purchaser prices.
    ("com_agr", "hhd"): 70, ("com_man", "hhd"): 80, ("com_ser", "hhd"): 80,
    # Government consumption.
    ("com_man", "gov"): 5, ("com_ser", "gov"): 40,
    # Investment demand.
    ("com_agr", "sav"): 5, ("com_man", "sav"): 40, ("com_ser", "sav"): 5,
    # Exports (commodity rows, rest-of-world column).
    ("com_agr", "row"): 20, ("com_man", "row"): 40, ("com_ser", "row"): 15,
    # Imports at c.i.f. prices (rest-of-world row, commodity columns).
    ("row", "com_agr"): 20, ("row", "com_man"): 60, ("row", "com_ser"): 20,
    # Import tariffs and sales taxes paid by commodity accounts.
    ("tax_imp", "com_agr"): 2, ("tax_imp", "com_man"): 6,
    ("tax_sal", "com_agr"): 8, ("tax_sal", "com_man"): 12, ("tax_sal", "com_ser"): 10,
    # Factor income to households.
    ("hhd", "lab"): 135, ("hhd", "cap"): 127,
    # Transfers to households from government and the rest of the world.
    ("hhd", "gov"): 15, ("hhd", "row"): 10,
    # Household direct tax and savings.
    ("tax_dir", "hhd"): 25, ("sav", "hhd"): 32,
    # Tax accounts pass revenue to government.
    ("gov", "tax_dir"): 25, ("gov", "tax_sal"): 30, ("gov", "tax_imp"): 8,
    # Government and foreign savings.
    ("sav", "gov"): 3, ("sav", "row"): 15,
}


def build() -> tuple[list[str], list[list[float]]]:
    """Return the account labels and the SAM as a list of rows."""
    index = {name: i for i, name in enumerate(ACCOUNTS)}
    n = len(ACCOUNTS)
    sam = [[0.0] * n for _ in range(n)]
    for (row, col), value in FLOWS.items():
        sam[index[row]][index[col]] = float(value)
    return list(ACCOUNTS), sam


def build_national_accounts_layout() -> tuple[list[str], list[list[float]]]:
    """The same economy in the layout of many national SAMs.

    Exports are recorded as sales by activities to the rest of the world, and
    sales taxes and direct taxes are paid directly to the government account
    (the tax_sal and tax_dir accounts are removed). Import tariffs keep their
    own account. Rewriting this layout (model_spec.md, Section 7.0) must give
    back the standard SAM.
    """
    labels, sam = build()
    i = {name: k for k, name in enumerate(labels)}
    for act, com in (("act_agr", "com_agr"), ("act_man", "com_man"), ("act_ser", "com_ser")):
        exports = sam[i[com]][i["row"]]
        sam[i[act]][i["row"]] += exports
        sam[i[act]][i[com]] -= exports
        sam[i[com]][i["row"]] = 0.0
    for com in ("com_agr", "com_man", "com_ser"):
        sam[i["gov"]][i[com]] += sam[i["tax_sal"]][i[com]]
    sam[i["gov"]][i["hhd"]] += sam[i["tax_dir"]][i["hhd"]]
    keep = [k for k, name in enumerate(labels) if name not in ("tax_sal", "tax_dir")]
    return [labels[k] for k in keep], [[sam[r][c] for c in keep] for r in keep]


SERVICE_MARGINS = 30.0


def build_margins_layout() -> tuple[list[str], list[list[float]]]:
    """The standard SAM with margins netted out of the service activity.

    act_ser earns 30 of margins. As in some national SAMs, its recorded output
    is reduced by 30 and its use of its own product (20) becomes -10. Rewriting
    this layout (model_spec.md, Section 7.0, rewrite 3) moves the -10 to output,
    giving output 130 and own use 0: the rewrite cannot separate the activity's
    own use from the netted margins.
    """
    labels, sam = build()
    i = {name: k for k, name in enumerate(labels)}
    sam[i["act_ser"]][i["com_ser"]] -= SERVICE_MARGINS
    sam[i["com_ser"]][i["act_ser"]] -= SERVICE_MARGINS
    return labels, sam


INSTITUTION_ACCOUNTS = [
    "act_agr", "act_man", "act_ser",
    "com_agr", "com_man", "com_ser",
    "lab", "cap",
    "hhd", "npi", "ent", "gov",
    "tax_dir", "tax_sal", "tax_imp",
    "sav", "row",
]

# Changes to FLOWS for the institutions layout: an enterprise (ent) and a
# non-profit institution (npi, mapped as a household), transfers among them,
# transfers to and from the rest of the world, factor income from and to abroad,
# transfers within government, and negative savings.
INSTITUTION_FLOWS = {
    ("com_ser", "hhd"): 70, ("com_ser", "npi"): 10,
    ("lab", "row"): 6,
    ("hhd", "lab"): 141, ("hhd", "cap"): 27, ("ent", "cap"): 90, ("row", "cap"): 10,
    ("hhd", "ent"): 60, ("hhd", "gov"): 15, ("hhd", "row"): 10, ("hhd", "hhd"): 1,
    ("npi", "ent"): 4, ("npi", "hhd"): 2, ("npi", "gov"): 3,
    ("ent", "gov"): 5, ("ent", "row"): 4, ("ent", "hhd"): 3, ("ent", "ent"): 2,
    ("gov", "tax_dir"): 30, ("gov", "gov"): 3,
    ("tax_dir", "hhd"): 18, ("tax_dir", "ent"): 12,
    ("sav", "hhd"): 6, ("sav", "ent"): 18, ("sav", "npi"): -1, ("sav", "gov"): -2, ("sav", "row"): 29,
    ("row", "ent"): 8, ("row", "hhd"): 4, ("row", "gov"): 2,
}


def build_institutions_layout() -> tuple[list[str], list[list[float]]]:
    """The synthetic economy with an enterprise and a non-profit institution."""
    flows = {**FLOWS, **INSTITUTION_FLOWS}
    index = {name: i for i, name in enumerate(INSTITUTION_ACCOUNTS)}
    n = len(INSTITUTION_ACCOUNTS)
    sam = [[0.0] * n for _ in range(n)]
    for (row, col), value in flows.items():
        sam[index[row]][index[col]] = float(value)
    return list(INSTITUTION_ACCOUNTS), sam


def imbalances(sam: list[list[float]]) -> list[float]:
    """Row total minus column total for each account."""
    n = len(sam)
    return [sum(sam[i]) - sum(sam[r][i] for r in range(n)) for i in range(n)]


def write_csv(path: Path, layout=build) -> None:
    """Write the SAM with an ``account`` label column and one column per account."""
    labels, sam = layout()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["account", *labels])
        for label, row in zip(labels, sam):
            writer.writerow([label, *(f"{value:.10g}" for value in row)])


if __name__ == "__main__":
    data = Path(__file__).resolve().parents[1] / "data"
    for layout, filename in ((build, "cge_synthetic_sam.csv"),
                             (build_national_accounts_layout, "cge_synthetic_sam_na.csv"),
                             (build_institutions_layout, "cge_synthetic_sam_inst.csv"),
                             (build_margins_layout, "cge_synthetic_sam_margins.csv")):
        names, matrix = layout()
        worst = max(abs(d) for d in imbalances(matrix))
        if worst > 1e-12:
            raise SystemExit(f"{filename} is not balanced (max imbalance {worst})")
        write_csv(data / filename, layout)
        print(f"Wrote {data / filename} ({len(names)} accounts, balanced)")
