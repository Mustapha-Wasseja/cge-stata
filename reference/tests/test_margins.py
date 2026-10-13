"""Margins netted out of margin activities (model_spec.md, 7.0, rewrite 3)."""

import dataclasses
import sys
from pathlib import Path

import numpy as np
import pytest

from cge_ref import VARIABLES, SAM, SAMError, prepare
from cge_ref.model import NOMINAL
from cge_ref.scenarios import (MARGINS_SAM, SYNTHETIC_SAM, margins_mapping, margins_model,
                               run_simulations, synthetic_mapping)

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import synthetic_sam  # noqa: E402
from test_validation import _close, _unit_costs  # noqa: E402


@pytest.fixture(scope="module")
def model():
    return margins_model()


def test_sam_balances_and_matches_generator():
    labels, values = synthetic_sam.build_margins_layout()
    assert max(abs(d) for d in synthetic_sam.imbalances(values)) < 1e-12
    sam = SAM.from_csv(MARGINS_SAM)
    assert sam.labels == labels and np.array_equal(sam.values, np.array(values))
    assert sam.cell("com_ser", "act_ser") == -10 and sam.cell("act_ser", "com_ser") == 120


def test_rewrite_moves_the_negative_own_use_to_output():
    prepared, mapping, notes = prepare(SAM.from_csv(MARGINS_SAM), margins_mapping())
    standard = SAM.from_csv(SYNTHETIC_SAM)
    assert notes["margins"] == 10
    assert prepared.cell("act_ser", "com_ser") == 130 and prepared.cell("com_ser", "act_ser") == 0
    for r in standard.labels:
        for c in standard.labels:
            if (r, c) not in (("act_ser", "com_ser"), ("com_ser", "act_ser")):
                assert prepared.cell(r, c) == standard.cell(r, c), (r, c)
    assert np.abs(prepared.imbalances()).max() < 1e-12


def test_without_the_option_the_negative_own_use_is_reported():
    mapping = margins_mapping()
    mapping.margins = []
    prepared, mapping, _ = prepare(SAM.from_csv(MARGINS_SAM), mapping)
    with pytest.raises(SAMError, match="negative flow"):
        mapping.validate(prepared)


def test_activity_without_negative_own_use_is_rejected():
    with pytest.raises(SAMError, match="no negative use of its own product"):
        prepare(SAM.from_csv(SYNTHETIC_SAM), dataclasses.replace(synthetic_mapping(), margins=["act_ser"]))
    with pytest.raises(SAMError, match="not one of the mapped activities"):
        prepare(SAM.from_csv(MARGINS_SAM), dataclasses.replace(synthetic_mapping(), margins=["com_ser"]))


def test_model_replicates_and_solves(model):
    assert model.max_residual(model.base) < 1e-12
    assert np.isclose(model.base["QA"][model.sets["A"].index("act_ser")], 130)
    assert model.params["ica"][model.sets["C"].index("com_ser"), model.sets["A"].index("act_ser")] == 0
    for name, s in run_simulations(model).items():
        assert s.converged, name
        assert abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8, name
        va_cost, arm_cost, cet_revenue = _unit_costs(s)
        st = s.model.struct
        assert _close(s["PVA"], va_cost, rel=1e-9), name
        assert _close((s["PQ"] * (1 - s.params["tq"]))[st["cm"]], arm_cost[st["cm"]], rel=1e-9), name
        assert _close(s["PX"][st["ce"]], cet_revenue[st["ce"]], rel=1e-9), name


def test_homogeneity(model):
    solution = model.solve(fixed={"CPI": 2.0})
    assert solution.converged
    for name in VARIABLES:
        exists = model.exists[name]
        factor = 2.0 if name in NOMINAL else 1.0
        assert _close(solution[name][exists], factor * model.base[name][exists]), name
