"""Inventory changes, the territorial correction and multi-product activities (version 0.1.4)."""

import dataclasses
import sys
from pathlib import Path

import numpy as np
import pytest

from cge_ref import VARIABLES, SAM, Model, SAMError, prepare
from cge_ref.model import NOMINAL
from cge_ref.scenarios import (MULTIPRODUCT_SAM, SYNTHETIC_SAM, TERRITORIAL_SAM, TEST_ELASTICITIES,
                               multiproduct_model, run_simulations, synthetic_mapping,
                               synthetic_model, territorial_mapping, territorial_model)

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import synthetic_sam  # noqa: E402
from test_validation import _close, _unit_costs  # noqa: E402


@pytest.mark.parametrize("builder, path", [
    (synthetic_sam.build_territorial_layout, TERRITORIAL_SAM),
    (synthetic_sam.build_multiproduct_layout, MULTIPRODUCT_SAM),
])
def test_sams_balance_and_match_generators(builder, path):
    labels, values = builder()
    assert max(abs(d) for d in synthetic_sam.imbalances(values)) < 1e-12
    sam = SAM.from_csv(path)
    assert sam.labels == labels and np.array_equal(sam.values, np.array(values))


# Territorial correction and inventory changes
def test_territorial_rewrite():
    prepared, _, notes = prepare(SAM.from_csv(TERRITORIAL_SAM), territorial_mapping())
    assert notes["territorial_imports"] == 4 and notes["territorial_exports"] == 9
    for account in ("act_tc", "com_tc"):
        i = prepared.index(account)
        assert not prepared.values[i, :].any() and not prepared.values[:, i].any()
    assert prepared.cell("row", "hhd") == 4          # residents' purchases abroad
    assert prepared.cell("hhd", "row") == 10 + 9     # non-residents' purchases as transfers
    assert prepared.cell("com_agr", "sav") == -2     # inventory run-down kept
    assert np.abs(prepared.imbalances()).max() < 1e-12


def test_territorial_model():
    m = territorial_model()
    assert m.max_residual(m.base) < 1e-12
    assert m.params["qinv"][m.sets["C"].index("com_agr")] == -2
    assert np.isclose(m.params["shir"][0], 4 / (296 - 25 - 37))
    for name, s in run_simulations(m).items():
        assert s.converged and abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8, name


def test_territorial_errors():
    sam = SAM.from_csv(TERRITORIAL_SAM)
    with pytest.raises(SAMError, match="not mapped to a role"):
        mapping = synthetic_mapping()
        prepared, mapping, _ = prepare(sam, mapping)
        mapping.validate(prepared)
    with pytest.raises(SAMError, match="also mapped"):
        prepare(sam, dataclasses.replace(territorial_mapping(), territorial=["com_ser"]))
    with pytest.raises(SAMError, match="still has flows"):
        prepare(sam, dataclasses.replace(territorial_mapping(), territorial=["com_tc", "lab"],
                                         factors=["cap"]))


def test_negative_inventory_demand_is_allowed_only_in_investment():
    sam = SAM.from_csv(TERRITORIAL_SAM)
    prepared, mapping, _ = prepare(sam, territorial_mapping())
    mapping.validate(prepared)
    values = prepared.values.copy()
    i = {name: k for k, name in enumerate(prepared.labels)}
    values[i["com_agr"], i["gov"]] -= 1      # negative government consumption ...
    values[i["sav"], i["gov"]] += 1          # ... financed as savings
    values[i["com_agr"], i["sav"]] += 1      # investment demand absorbs it
    changed = SAM(prepared.labels, values)
    assert np.abs(changed.imbalances()).max() < 1e-12
    with pytest.raises(SAMError, match="negative flow"):
        mapping.validate(changed)


# Multi-product activities
def test_yields_and_output():
    m = multiproduct_model()
    A, C = m.sets["A"], m.sets["C"]
    assert np.allclose(m.params["theta"][A.index("act_agr")], [0.9, 0.1, 0.0])
    assert np.allclose(m.base["QX"], [90, 150, 150])
    assert np.allclose(m.params["theta"].sum(axis=1), 1.0)
    assert m.max_residual(m.base) < 1e-12


def test_standard_sam_has_identity_yields():
    assert np.array_equal(synthetic_model().params["theta"], np.eye(3))


def test_multiproduct_simulations():
    m = multiproduct_model()
    for name, s in run_simulations(m).items():
        assert s.converged and abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8, name
        va_cost, arm_cost, cet_revenue = _unit_costs(s)
        st = s.model.struct
        assert _close(s["PVA"], va_cost, rel=1e-9), name
        assert _close(s["PX"][st["ce"]], cet_revenue[st["ce"]], rel=1e-9), name
        # activity price is the yield-weighted producer price; commodity output adds up
        assert _close(s["PA"], s.params["theta"] @ s["PX"], rel=1e-12), name
        assert _close(s["QX"], s.params["theta"].T @ s["QA"], rel=1e-12), name


@pytest.mark.parametrize("factory", [territorial_model, multiproduct_model])
def test_homogeneity(factory):
    m = factory()
    solution = m.solve(fixed={"CPI": 2.0})
    assert solution.converged
    for name in VARIABLES:
        exists = m.exists[name]
        factor = 2.0 if name in NOMINAL else 1.0
        assert _close(solution[name][exists], factor * m.base[name][exists]), name


def test_secondary_production_no_longer_rejected():
    sam = SAM.from_csv(MULTIPRODUCT_SAM)
    synthetic_mapping().validate(sam)
    Model(sam, synthetic_mapping(), **TEST_ELASTICITIES)


def test_negative_secondary_sale_gives_a_negative_yield():
    # act_ser sells -1 of com_agr (and 1 more com_ser); households adjust
    sam = SAM.from_csv(MULTIPRODUCT_SAM)
    values = sam.values.copy()
    i = {name: k for k, name in enumerate(sam.labels)}
    values[i["act_ser"], i["com_agr"]] = -1
    values[i["act_ser"], i["com_ser"]] = 151
    values[i["com_agr"], i["hhd"]] -= 1
    values[i["com_ser"], i["hhd"]] += 1
    changed = SAM(sam.labels, values)
    assert np.abs(changed.imbalances()).max() < 1e-12
    m = Model(changed, synthetic_mapping(), **TEST_ELASTICITIES)
    A, C = m.sets["A"], m.sets["C"]
    assert np.isclose(m.params["theta"][A.index("act_ser"), C.index("com_agr")], -1 / 150)
    assert m.max_residual(m.base) < 1e-12
    s = m.solve(params={"tm": np.zeros(3)})
    assert s.converged and abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8


def test_nonimported_commodity_with_sales_tax():
    # Before version 0.1.4, T6 (QQ = QD) failed benchmark replication here
    from cge_ref.scenarios import NONIMPORTED_SAM, nonimported_model
    labels, values = synthetic_sam.build_nonimported_layout()
    assert max(abs(d) for d in synthetic_sam.imbalances(values)) < 1e-12
    assert np.array_equal(SAM.from_csv(NONIMPORTED_SAM).values, np.array(values))
    m = nonimported_model()
    ser = m.sets["C"].index("com_ser")
    assert not m.struct["cm"][ser]
    assert np.isclose(m.params["aq"][ser], 145 / 135)       # QD0 = 150 - exports 15; QQ0 = QD0 + sales tax 10
    assert m.max_residual(m.base) < 1e-12
    for name, s in run_simulations(m).items():
        assert s.converged and abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8, name
    solution = m.solve(fixed={"CPI": 2.0})
    for name in VARIABLES:
        exists = m.exists[name]
        factor = 2.0 if name in NOMINAL else 1.0
        assert _close(solution[name][exists], factor * m.base[name][exists]), name
