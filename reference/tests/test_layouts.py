"""National-accounts layouts rewritten before calibration (model_spec.md, 7.0)."""

import dataclasses
import sys
from pathlib import Path

import numpy as np
import pytest

from cge_ref import VARIABLES, SAM, Model, SAMError, prepare
from cge_ref.scenarios import (SYNTHETIC_SAM, TEST_ELASTICITIES, run_simulations,
                               synthetic_mapping, synthetic_model)

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import synthetic_sam  # noqa: E402

NA_SAM = SYNTHETIC_SAM.parent / "cge_synthetic_sam_na.csv"


def na_mapping():
    return dataclasses.replace(synthetic_mapping(), dirtax="gov", saltax="gov")


def test_na_layout_balances_and_matches_generator():
    labels, values = synthetic_sam.build_national_accounts_layout()
    assert max(abs(d) for d in synthetic_sam.imbalances(values)) < 1e-12
    assert "tax_sal" not in labels and "tax_dir" not in labels
    sam = SAM.from_csv(NA_SAM)
    assert sam.labels == labels
    assert np.array_equal(sam.values, np.array(values))
    assert np.isclose(sam.values.sum(), 1743 - 25 - 30 - 75)


def test_prepare_recovers_the_standard_sam():
    prepared, mapping, notes = prepare(SAM.from_csv(NA_SAM), na_mapping())
    standard = SAM.from_csv(SYNTHETIC_SAM)
    rename = {"tax_dir": "_dirtax", "tax_sal": "_saltax"}
    assert sorted(prepared.labels) == sorted(rename.get(x, x) for x in standard.labels)
    for r in standard.labels:
        for c in standard.labels:
            assert prepared.cell(rename.get(r, r), rename.get(c, c)) == standard.cell(r, c), (r, c)
    assert mapping.dirtax == "_dirtax" and mapping.saltax == "_saltax" and mapping.imptax == "tax_imp"
    assert notes == {"exports": 75.0, "dirtax": 25.0, "saltax": 30.0}


def test_na_layout_gives_the_same_model():
    standard = synthetic_model()
    na = Model(SAM.from_csv(NA_SAM), na_mapping(), **TEST_ELASTICITIES)
    for name in VARIABLES:
        assert np.allclose(na.base[name], standard.base[name], rtol=0, atol=1e-12), name
    for (name, s), (_, t) in zip(run_simulations(standard).items(), run_simulations(na).items()):
        for var in VARIABLES:
            assert np.allclose(t[var], s[var], rtol=1e-10, atol=1e-10), (name, var)


def test_two_commodity_taxes_naming_government_are_rejected():
    mapping = dataclasses.replace(na_mapping(), imptax="gov")
    with pytest.raises(SAMError, match="only one of saltax, imptax, exptax and vattax"):
        prepare(SAM.from_csv(NA_SAM), mapping)


def test_taxes_paid_to_government_need_a_tax_option():
    mapping = dataclasses.replace(na_mapping(), saltax=None)
    prepared, mapping, _ = prepare(SAM.from_csv(NA_SAM), mapping)
    with pytest.raises(SAMError, match="not represented"):
        mapping.validate(prepared)


def test_standard_layout_is_unchanged():
    sam = SAM.from_csv(SYNTHETIC_SAM)
    prepared, mapping, notes = prepare(sam, synthetic_mapping())
    assert prepared.labels == sam.labels and np.array_equal(prepared.values, sam.values)
    assert mapping == synthetic_mapping() and notes == {"exports": 0.0}
