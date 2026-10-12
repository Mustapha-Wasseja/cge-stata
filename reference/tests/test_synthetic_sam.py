"""Checks on the synthetic SAM shared by the Stata and Python test suites."""

import csv
import sys
from pathlib import Path

REFERENCE = Path(__file__).resolve().parents[1]
REPO = REFERENCE.parent
sys.path.insert(0, str(REFERENCE))

import synthetic_sam  # noqa: E402


def test_every_account_balances():
    _, sam = synthetic_sam.build()
    assert max(abs(d) for d in synthetic_sam.imbalances(sam)) < 1e-12


def test_no_negative_flows():
    _, sam = synthetic_sam.build()
    assert min(min(row) for row in sam) >= 0


def test_known_totals():
    labels, sam = synthetic_sam.build()
    totals = dict(zip(labels, (sum(row) for row in sam)))
    assert totals["act_agr"] == 100
    assert totals["com_man"] == 218
    assert totals["hhd"] == 287
    assert totals["gov"] == 63
    assert totals["sav"] == 50
    assert totals["row"] == 100
    assert sum(totals.values()) == 1743


def test_bundled_csv_matches_generator():
    labels, sam = synthetic_sam.build()
    with (REPO / "data" / "cge_synthetic_sam.csv").open(newline="", encoding="utf-8") as handle:
        rows = list(csv.reader(handle))
    assert rows[0] == ["account", *labels]
    assert [r[0] for r in rows[1:]] == labels
    assert [[float(v) for v in r[1:]] for r in rows[1:]] == sam
