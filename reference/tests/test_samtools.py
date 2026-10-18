"""SAM tools (version 0.3.0, docs/sam_tools.md): aggregation and balancing."""

import numpy as np
import pytest

from cge_ref.sam import SAM, SAMError
from cge_ref.samtools import aggregate, cross_entropy, fixed_mask, information, ras
from cge_ref.scenarios import (AGGREGATION, INSTITUTIONS_SAM, UNBALANCED_SAM, aggregated_model,
                               balance_cases, run_simulations)


@pytest.fixture(scope="module")
def unbal():
    return SAM.from_csv(UNBALANCED_SAM)


@pytest.fixture(scope="module")
def cases():
    return balance_cases()


def test_unbalanced_sam_is_unbalanced_with_negative_cells(unbal):
    assert np.abs(unbal.imbalances()).max() > 1
    assert (unbal.values < 0).sum() == 2


def test_aggregation_adds_cells_and_balances():
    inst = SAM.from_csv(INSTITUTIONS_SAM)
    agg = aggregate(inst, AGGREGATION)
    assert agg.labels == ["act_agr", "act_nag", "com_agr", "com_nag", "lab", "cap", "hh", "ent",
                          "gov", "tax_dir", "tax_sal", "tax_imp", "sav", "row"]
    assert agg.values.sum() == pytest.approx(inst.values.sum(), abs=1e-12)
    assert np.abs(agg.imbalances()).max() < 1e-12
    assert agg.cell("act_nag", "com_nag") == 140 + 150
    assert agg.cell("com_nag", "act_nag") == 30 + 15 + 15 + 20
    # Transfers within the household group become a diagonal cell
    assert agg.cell("hh", "hh") == 1 + 2
    assert agg.cell("sav", "hh") == 6 - 1
    netted = aggregate(inst, AGGREGATION, net_diagonal=True)
    assert netted.cell("hh", "hh") == 0
    assert np.abs(netted.imbalances()).max() < 1e-12


def test_aggregation_errors():
    inst = SAM.from_csv(INSTITUTIONS_SAM)
    with pytest.raises(SAMError):
        aggregate(inst, {"a": ["act_agr"], "b": ["act_agr", "act_man"]})
    with pytest.raises(SAMError):
        aggregate(inst, {"act_agr": ["act_man", "act_ser"]})
    with pytest.raises(SAMError):
        aggregate(inst, {"x": ["nosuch"]})


def test_fixed_mask(unbal):
    m = fixed_mask(unbal, ["row:*", "*:gov", "hhd:lab", "sav"])
    k = {a: i for i, a in enumerate(unbal.labels)}
    assert m[k["row"], :].all() and m[:, k["gov"]].all()
    assert m[k["sav"], :].all() and m[:, k["sav"]].all()
    assert m[k["hhd"], k["lab"]] and not m[k["hhd"], k["cap"]]


@pytest.mark.parametrize("name", ["ras", "ras_fixed", "ce", "ce_totals"])
def test_balanced_keeps_signs_zeros_and_fixed_cells(unbal, cases, name):
    sam, info = cases[name]
    scale = np.abs(unbal.values).max()
    assert info.maxdiff <= 2e-12 * scale
    assert np.abs(sam.imbalances()).max() <= 2e-12 * scale
    assert (np.sign(sam.values) == np.sign(unbal.values)).all()
    fixed = {"ras": [], "ras_fixed": ["hhd:lab", "com_man:sav", "ent:cap"], "ce": [],
             "ce_totals": ["row:*", "hhd:lab"]}[name]
    mask = fixed_mask(unbal, fixed)
    assert (sam.values[mask] == unbal.values[mask]).all()


def test_ras_meets_targets(unbal, cases):
    sam, info = cases["ras"]
    target = 0.5 * (unbal.values.sum(axis=1) + unbal.values.sum(axis=0))
    assert np.abs(sam.values.sum(axis=1) - target).max() <= 1e-12 * np.abs(unbal.values).max()
    sam, info = cases["ras_fixed"]
    assert sam.row_total("gov") == pytest.approx(71.0, abs=1e-9)
    # lab's column has no other cell, so its target is its fixed column total
    assert sam.row_total("lab") == pytest.approx(unbal.col_total("lab"), abs=1e-9)
    assert sam.row_total("hhd") == pytest.approx(unbal.row_total("hhd"), abs=1e-9)


def test_ras_without_negative_cells_is_classic_ras():
    inst = SAM.from_csv(INSTITUTIONS_SAM)
    values = np.abs(inst.values) * (1 + 0.05 * np.cos(np.arange(inst.values.size)).reshape(inst.values.shape))
    values[inst.values == 0] = 0
    prior = SAM(inst.labels, values)
    sam, info = ras(prior, tol=1e-13)
    t = info.targets
    x = values.copy()
    for _ in range(5000):
        x *= (t / x.sum(axis=1))[:, None]
        x *= (t / x.sum(axis=0))[None, :]
    assert np.abs(sam.values - x).max() < 1e-9


def test_cross_entropy_with_all_totals_is_ras(unbal, cases):
    sam, info = cases["ras"]
    totals = dict(zip(unbal.labels, info.targets))
    ce, _ = cross_entropy(unbal, totals=totals, tol=1e-12)
    assert np.abs(ce.values - sam.values).max() < 1e-9


def test_cross_entropy_known_totals_and_optimality(unbal, cases):
    ce, _ = cases["ce"]
    sam, _ = cases["ce_totals"]
    assert sam.row_total("act_agr") == pytest.approx(97.0, abs=1e-10)
    assert sam.row_total("hhd") == pytest.approx(290.0, abs=1e-10)
    # Cross entropy without known totals adds less information than any other
    # balanced SAM with the same pattern, such as the RAS solution
    assert information(ce, unbal) < information(cases["ras"][0], unbal)
    # Optimality: log ratios have the form mu_i - mu_j (no known totals)
    nz = unbal.values != 0
    ratio = np.log(ce.values[nz] / unbal.values[nz])
    rows, cols = np.nonzero(nz)
    sign = np.sign(unbal.values[nz])
    n = len(unbal.labels)
    design = np.zeros((nz.sum(), n))
    design[np.arange(nz.sum()), rows] += sign
    design[np.arange(nz.sum()), cols] -= sign
    coef, *_ = np.linalg.lstsq(design, ratio, rcond=None)
    assert np.abs(design @ coef - ratio).max() < 1e-9


def test_a_balanced_sam_is_unchanged():
    inst = SAM.from_csv(INSTITUTIONS_SAM)
    for method in (ras, cross_entropy):
        sam, info = method(inst)
        assert np.abs(sam.values - inst.values).max() < 1e-12
        assert info.iterations <= 1


def test_infeasible_balancing_is_an_error(unbal):
    # Imports fixed: the commodity accounts' targets contradict those of the
    # activities and tax accounts
    with pytest.raises(SAMError, match="no longer falls"):
        ras(unbal, fixed=["row:*"])
    with pytest.raises(SAMError, match="differ"):
        ras(unbal, fixed=["tax_dir"])
    with pytest.raises(SAMError, match="differs"):
        ras(unbal, totals={"lab": 100.0}, fixed=["hhd:lab"])
    with pytest.raises(SAMError):
        cross_entropy(unbal, fixed=["tax_dir"])


def test_aggregated_model_solves():
    solutions = run_simulations(aggregated_model())
    assert all(s.converged for s in solutions.values())
