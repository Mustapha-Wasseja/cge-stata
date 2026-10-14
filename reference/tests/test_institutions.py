"""Enterprises, non-profit institutions and institutional transfers (version 0.1.2)."""

import dataclasses
import itertools
import sys
from pathlib import Path

import numpy as np
import pytest

from cge_ref import VARIABLES, SAM, Closure, Model, SAMError
from cge_ref.model import NOMINAL
from cge_ref.scenarios import (INSTITUTIONS_SAM, TEST_ELASTICITIES, institutions_mapping,
                               institutions_model, run_simulations)

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import synthetic_sam  # noqa: E402
from test_validation import _close, _unit_costs  # noqa: E402


@pytest.fixture(scope="module")
def model():
    return institutions_model()


@pytest.fixture(scope="module")
def simulations(model):
    return run_simulations(model)


def test_sam_balances_and_matches_generator():
    labels, values = synthetic_sam.build_institutions_layout()
    assert max(abs(d) for d in synthetic_sam.imbalances(values)) < 1e-12
    sam = SAM.from_csv(INSTITUTIONS_SAM)
    assert sam.labels == labels and np.array_equal(sam.values, np.array(values))


def test_calibrated_shares(model):
    p, D = model.params, model.sets["D"]
    d = {name: k for k, name in enumerate(D)}
    # income after direct taxes and savings: hhd 254 - 18 - 6, npi 9 + 1, ent 104 - 12 - 18
    assert np.isclose(p["shii"][d["hhd"], d["ent"]], 60 / 74)
    assert np.isclose(p["shii"][d["ent"], d["ent"]], 2 / 74)
    assert np.isclose(p["shii"][d["npi"], d["hhd"]], 2 / 230)
    assert np.isclose(p["shir"][d["ent"]], 8 / 74)
    assert np.allclose(p["hc"], [220 / 230, 1.0])
    assert np.isclose(p["mps0"][d["npi"]], -1 / 9)
    # households: consumption + transfers = 1; enterprises transfer everything
    nH = len(model.sets["H"])
    shares = p["shii"].sum(axis=0) + p["shir"]
    assert np.allclose(shares[:nH] + p["hc"], 1.0)
    assert np.allclose(shares[nH:], 1.0)
    assert np.isclose(p["trfr"][model.sets["F"].index("lab")], 6)
    assert np.isclose(p["trgg"], 3) and np.isclose(p["trrg"], 2)


def test_benchmark_replication(model):
    assert model.n_equations == 105          # npi buys only com_ser: two purchases are zero
    assert model.max_residual(model.base) < 1e-12
    assert model.solve().iterations == 0


def test_homogeneity(model):
    solution = model.solve(fixed={"CPI": 2.0})
    assert solution.converged
    for name in VARIABLES:
        exists = model.exists[name]
        factor = 2.0 if name in NOMINAL else 1.0
        assert _close(solution[name][exists], factor * model.base[name][exists]), name


def test_walras_gdp_and_dual_costs(simulations):
    for name, s in simulations.items():
        assert s.converged, name
        assert abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8, name
        va_cost, arm_cost, cet_revenue = _unit_costs(s)
        st = s.model.struct
        assert _close(s["PVA"], va_cost, rel=1e-9), name
        assert _close((s["PQ"] * (1 - s.params["tq"]))[st["cm"]], arm_cost[st["cm"]], rel=1e-9), name
        assert _close(s["PX"][st["ce"]], cet_revenue[st["ce"]], rel=1e-9), name


def test_institution_accounts_balance(simulations):
    """Each institution's income equals its taxes, savings, transfers and consumption."""
    for name, s in simulations.items():
        p = s.params
        DY = (1 - s["MPS"]) * (1 - s["TINS"]) * s["YI"]
        paid = p["shii"].sum(axis=0) * DY + p["shir"] * DY
        paid[: len(s["EH"])] += s["EH"]
        assert np.allclose(paid, DY, rtol=1e-10, atol=1e-10), name


@pytest.mark.parametrize("seed", range(3))
def test_perturbed_start(model, seed):
    rng = np.random.default_rng(seed)
    start = {k: v * (1 + rng.uniform(-0.1, 0.1, size=v.shape)) for k, v in model.base.items()}
    solution = model.solve(start=start)
    assert solution.converged
    for name in VARIABLES:
        assert _close(solution[name], model.base[name], rel=1e-7), name


@pytest.mark.parametrize("macro", list(itertools.product(("flexexr", "fixexr"), ("flexgsav", "fixgsav"),
                                                         ("savings", "investment"), ("cpi", "dpi"))),
                         ids=lambda m: "-".join(m))
def test_closures_reproduce_base(model, macro):
    closure = Closure(*macro, factors={"lab": "unemployed", "cap": "specific"})
    solution = model.solve(closure)
    assert solution.converged and solution.iterations == 0


def _perturbed(changes):
    sam = SAM.from_csv(INSTITUTIONS_SAM)
    values = sam.values.copy()
    i = {name: k for k, name in enumerate(sam.labels)}
    for (row, col), delta in changes.items():
        values[i[row], i[col]] += delta
    changed = SAM(sam.labels, values)
    assert np.abs(changed.imbalances()).max() < 1e-12
    return changed


def test_enterprise_consumption_is_rejected():
    # The enterprise buys services instead of saving; investment falls to match
    changed = _perturbed({("com_ser", "ent"): 2, ("sav", "ent"): -2, ("com_ser", "sav"): -2})
    with pytest.raises(SAMError, match="not represented"):
        institutions_mapping().validate(changed)


def test_transfers_without_income_after_savings_are_rejected():
    # npi saves all its income (9) but still transfers 2 to households and -2 to
    # the rest of the world; its consumption moves to investment demand
    changed = _perturbed({("sav", "npi"): 10, ("com_ser", "npi"): -10, ("com_ser", "sav"): 10,
                          ("hhd", "npi"): 2, ("row", "npi"): -2, ("row", "hhd"): 2})
    institutions_mapping().validate(changed)
    with pytest.raises(SAMError, match="no income after direct taxes and savings"):
        Model(changed, institutions_mapping(), **TEST_ELASTICITIES)
