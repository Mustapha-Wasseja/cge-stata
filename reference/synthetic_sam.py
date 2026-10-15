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


TERRITORIAL_ACCOUNTS = [
    "act_agr", "act_man", "act_ser", "act_tc",
    "com_agr", "com_man", "com_ser", "com_tc",
    "lab", "cap",
    "hhd", "gov",
    "tax_dir", "tax_sal", "tax_imp",
    "sav", "row",
]

# Changes to FLOWS for the territorial-correction layout: residents spend 4
# abroad (imports of com_tc), non-residents spend 9 in the country (exports,
# recorded in the row of act_tc), and household consumption of com_tc is the
# net, -5; household savings rise and foreign savings fall to match. An
# inventory run-down of com_agr (-2) is also included.
TERRITORIAL_FLOWS = {
    ("act_tc", "com_tc"): -9, ("act_tc", "row"): 9,
    ("com_tc", "hhd"): -5, ("row", "com_tc"): 4,
    ("sav", "hhd"): 37, ("sav", "row"): 10,
    ("com_agr", "sav"): -2, ("com_man", "sav"): 47,
    ("row", "com_agr"): 13, ("row", "com_man"): 67,
}

# Changes to FLOWS for the multi-product layout: act_agr also produces 10 of
# com_man, and households buy 10 less com_agr and 10 more com_man.
MULTIPRODUCT_FLOWS = {
    ("act_agr", "com_agr"): 90, ("act_agr", "com_man"): 10,
    ("com_agr", "hhd"): 60, ("com_man", "hhd"): 90,
}


# Changes to FLOWS for the non-imported layout: com_ser (which pays sales tax)
# has no imports; its imports of 20 move to com_man, and households buy 20 less
# com_ser and 20 more com_man.
NONIMPORTED_FLOWS = {
    ("row", "com_ser"): 0, ("row", "com_man"): 80,
    ("com_ser", "hhd"): 60, ("com_man", "hhd"): 100,
}


def _layout(accounts, changes):
    flows = {**FLOWS, **changes}
    index = {name: i for i, name in enumerate(accounts)}
    n = len(accounts)
    sam = [[0.0] * n for _ in range(n)]
    for (row, col), value in flows.items():
        sam[index[row]][index[col]] = float(value)
    return list(accounts), sam


def build_territorial_layout() -> tuple[list[str], list[list[float]]]:
    """The synthetic economy with a territorial correction and an inventory run-down."""
    return _layout(TERRITORIAL_ACCOUNTS, TERRITORIAL_FLOWS)


def build_multiproduct_layout() -> tuple[list[str], list[list[float]]]:
    """The synthetic economy with secondary production of com_man by act_agr."""
    return _layout(ACCOUNTS, MULTIPRODUCT_FLOWS)


def build_nonimported_layout() -> tuple[list[str], list[list[float]]]:
    """The synthetic economy with a non-imported commodity that pays sales tax."""
    return _layout(ACCOUNTS, NONIMPORTED_FLOWS)


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


SUT_ACCOUNTS = [
    "act_agr", "act_man", "act_ser",
    "com_agr", "com_man", "com_ser", "com_fuel",
    "trd", "trp",
    "lab", "cap",
    "hhd", "gov",
    "tax_dir", "tax_sal", "tax_imp",
    "s-i", "dstk", "row",
]

# Changes to FLOWS for the supply-use layout (version 0.1.7):
# - com_fuel is imported only (12, tariff 1, sales tax 1, margins 2) and used by
#   act_man (6, in place of 6 of com_man) and households (10);
# - margin accounts collect margins from commodities: trd (trade) 10, spent on
#   com_ser; trp (transport) 5, spent on com_ser (4) and com_man (1); household
#   purchases of com_ser fall by the 14 now sold as margins;
# - a stock-change account dstk, financed by savings-investment (3), buys
#   com_man (4) and runs down com_agr (-1);
# - savings-investment is labelled "s-i", which is not a valid Stata name;
# - exports at least as large as domestic output (version 0.1.8): com_fuel
#   re-exports 2 of its imports (14), and com_agr exports 105 against output of
#   100, with a fall in its stocks held under savings-investment (-80);
#   savings-investment buys 85 more com_man, which is imported.
# Imports, tax revenue, government savings and foreign savings adjust so that
# every account balances.
SUT_FLOWS = {
    ("row", "com_fuel"): 14, ("com_fuel", "row"): 2, ("tax_imp", "com_fuel"): 1, ("tax_sal", "com_fuel"): 1,
    ("trd", "com_fuel"): 2, ("com_fuel", "act_man"): 6, ("com_fuel", "hhd"): 10,
    ("trd", "com_agr"): 3, ("trd", "com_man"): 5, ("trp", "com_agr"): 2, ("trp", "com_man"): 3,
    ("com_ser", "trd"): 10, ("com_ser", "trp"): 4, ("com_man", "trp"): 1,
    ("com_man", "act_man"): 24,
    ("com_agr", "hhd"): 75, ("com_man", "hhd"): 79, ("com_ser", "hhd"): 66,
    ("com_man", "sav"): 122, ("dstk", "sav"): 3, ("com_man", "dstk"): 4, ("com_agr", "dstk"): -1,
    ("com_agr", "sav"): -80, ("com_agr", "row"): 105,
    ("row", "com_agr"): 19, ("row", "com_man"): 132,
    ("gov", "tax_imp"): 9, ("gov", "tax_sal"): 31, ("sav", "gov"): 5, ("sav", "row"): 13,
}


def build_sut_layout() -> tuple[list[str], list[list[float]]]:
    """The synthetic economy in a supply-use layout: margin accounts, a commodity
    imported only, a stock-change account, the label s-i, and exports at least as
    large as domestic output."""
    flows = {}
    for (row, col), value in {**FLOWS, **SUT_FLOWS}.items():
        flows[("s-i" if row == "sav" else row, "s-i" if col == "sav" else col)] = value
    return _from_flows(SUT_ACCOUNTS, flows)


HEALTH_ACCOUNTS = [
    "act_agr", "act_man", "act_ser", "act_hlt",
    "com_agr", "com_man", "com_ser", "com_hlt",
    "lab", "cap",
    "hhd", "gov", "shi",
    "tax_dir", "tax_sal", "tax_imp",
    "sav", "row",
]

# Changes to FLOWS for the health layout (version 0.1.13):
# - health services (act_hlt, com_hlt) are separated from other services: act_hlt
#   produces 30 with intermediates 6 and value added 24; com_hlt is neither
#   imported, exported nor taxed;
# - a social health insurance fund (shi) receives contributions of 6 on labour
#   income, 2 from government and 1 from abroad, buys health services (8) and
#   saves 1;
# - households, paid 6 less labour income, buy 12 of health services and save 2
#   more; government buys 10 of health services and saves 2 less; foreign
#   savings fall by 1.
HEALTH_FLOWS = {
    ("act_ser", "com_ser"): 120, ("act_hlt", "com_hlt"): 30,
    ("com_man", "act_ser"): 11, ("com_ser", "act_ser"): 18, ("lab", "act_ser"): 42, ("cap", "act_ser"): 44,
    ("com_man", "act_hlt"): 4, ("com_ser", "act_hlt"): 2, ("lab", "act_hlt"): 18, ("cap", "act_hlt"): 6,
    ("com_ser", "hhd"): 60, ("com_hlt", "hhd"): 12, ("com_ser", "gov"): 30, ("com_hlt", "gov"): 10,
    ("com_hlt", "shi"): 8, ("sav", "shi"): 1,
    ("shi", "lab"): 6, ("hhd", "lab"): 129, ("shi", "gov"): 2, ("shi", "row"): 1,
    ("sav", "hhd"): 34, ("sav", "gov"): 1, ("sav", "row"): 14,
}


def build_health_layout() -> tuple[list[str], list[list[float]]]:
    """The synthetic economy with a health sector and a social health insurance fund."""
    return _from_flows(HEALTH_ACCOUNTS, {**FLOWS, **HEALTH_FLOWS})


def _from_flows(accounts, flows):
    index = {name: i for i, name in enumerate(accounts)}
    n = len(accounts)
    sam = [[0.0] * n for _ in range(n)]
    for (row, col), value in flows.items():
        sam[index[row]][index[col]] = float(value)
    return list(accounts), sam


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
                             (build_margins_layout, "cge_synthetic_sam_margins.csv"),
                             (build_territorial_layout, "cge_synthetic_sam_tc.csv"),
                             (build_multiproduct_layout, "cge_synthetic_sam_mp.csv"),
                             (build_nonimported_layout, "cge_synthetic_sam_cnm.csv"),
                             (build_sut_layout, "cge_synthetic_sam_sut.csv"),
                             (build_health_layout, "cge_synthetic_sam_health.csv")):
        names, matrix = layout()
        worst = max(abs(d) for d in imbalances(matrix))
        if worst > 1e-12:
            raise SystemExit(f"{filename} is not balanced (max imbalance {worst})")
        write_csv(data / filename, layout)
        print(f"Wrote {data / filename} ({len(names)} accounts, balanced)")
