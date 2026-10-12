"""Calibration and SAM mapping (docs/model_spec.md, Sections 7 and 8.1-8.2)."""

import numpy as np
import pytest

from cge_ref import SAM, Model, SAMError
from cge_ref.scenarios import SYNTHETIC_SAM, synthetic_mapping, synthetic_model


@pytest.fixture(scope="module")
def model():
    return synthetic_model()


def test_shares_sum_to_one(model):
    p = model.params
    assert np.allclose(p["ica"].sum(axis=0), 1.0)
    assert np.allclose(p["delta_va"].sum(axis=0), 1.0)
    assert np.allclose(p["beta"].sum(axis=0), 1.0)
    assert np.allclose(p["shif"].sum(axis=0), 1.0)
    assert np.isclose(p["cwts"].sum(), 1.0)
    assert np.isclose(p["dwts"].sum(), 1.0)


def test_tax_rates_match_sam(model):
    p = model.params
    assert np.allclose(p["tm"], [2 / 20, 6 / 60, 0.0])
    assert np.allclose(p["tq"], [8 / 110, 12 / 178, 10 / 165])
    assert np.isclose(p["tins0"][0], 25 / 287)
    assert np.isclose(p["mps0"][0], 32 / (287 - 25))


def test_base_values_match_sam(model):
    b = model.base
    assert np.allclose(b["QD"], [80, 100, 135])
    assert np.allclose(b["QQ"], [110, 178, 165])
    assert np.allclose(b["PM"], [1.1, 1.1, 1.0])
    assert np.isclose(b["YG"][0], 63) and np.isclose(b["EG"][0], 60)
    assert np.isclose(b["GSAV"][0], 3) and np.isclose(b["FSAV"][0], 15)


def test_square_system(model):
    assert model.n_equations == 93


@pytest.mark.parametrize("elasticities", [
    {},
    {"sigma_va": 1.0},
    {"sigma_va": {"act_agr": 0.5, "act_man": 1.0, "act_ser": 1.5},
     "sigma_q": {"com_agr": 0.6, "com_man": 3.0, "com_ser": 1.2},
     "sigma_t": {"com_agr": 0.7, "com_man": 4.0, "com_ser": 1.0}},
])
def test_benchmark_replication(elasticities):
    m = synthetic_model(**elasticities)
    assert m.max_residual(m.base) < 1e-12
    solution = m.solve()
    assert solution.converged and solution.iterations == 0


def test_benchmark_replication_with_factor_quantities():
    workers = {("lab", "act_agr"): 80.0, ("lab", "act_man"): 20.0, ("lab", "act_ser"): 30.0,
               ("cap", "act_agr"): 37.0, ("cap", "act_man"): 40.0, ("cap", "act_ser"): 50.0}
    m = Model(SAM.from_csv(SYNTHETIC_SAM), synthetic_mapping(), 0.8, 2.0, 2.0, factor_quantities=workers)
    assert not np.allclose(m.base["WFDIST"], 1.0)
    assert np.isclose(m.base["W"][0], 135 / 130)
    assert m.max_residual(m.base) < 1e-12
    assert m.solve().iterations == 0


def test_sigma_q_of_one_is_rejected():
    with pytest.raises(ValueError, match="sigma_q"):
        synthetic_model(sigma_q=1.0)


def test_nonpositive_elasticity_is_rejected():
    with pytest.raises(ValueError):
        synthetic_model(sigma_va=0.0)


def _modified_sam(changes):
    sam = SAM.from_csv(SYNTHETIC_SAM)
    values = sam.values.copy()
    for (row, col), delta in changes.items():
        values[sam.index(row), sam.index(col)] += delta
    return SAM(sam.labels, values)


def test_unbalanced_sam_is_rejected():
    sam = _modified_sam({("com_agr", "act_agr"): 1.0})
    with pytest.raises(SAMError, match="not balanced"):
        synthetic_mapping().validate(sam)


def test_unsupported_flow_is_rejected():
    # Household pays 5 directly to government instead of saving it; the
    # government saves it. The SAM stays balanced.
    sam = _modified_sam({("gov", "hhd"): 5.0, ("sav", "hhd"): -5.0, ("sav", "gov"): 5.0})
    assert np.abs(sam.imbalances()).max() < 1e-12
    with pytest.raises(SAMError, match="not represented"):
        synthetic_mapping().validate(sam)


def test_unmapped_account_is_rejected():
    mapping = synthetic_mapping()
    mapping.imptax = None
    with pytest.raises(SAMError, match="tax_imp"):
        mapping.validate(SAM.from_csv(SYNTHETIC_SAM))


def test_activity_paired_with_wrong_commodity_is_rejected():
    mapping = synthetic_mapping()
    mapping.commodities = ["com_man", "com_agr", "com_ser"]
    with pytest.raises(SAMError, match="paired"):
        mapping.validate(SAM.from_csv(SYNTHETIC_SAM))
