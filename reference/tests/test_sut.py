"""Supply-use layouts (version 0.1.7): margin accounts, commodities imported only
and stock-change accounts."""

import itertools
import sys
from pathlib import Path

import numpy as np
import pytest

from cge_ref import VARIABLES, SAM, Closure, Model, SAMError, prepare
from cge_ref.model import NOMINAL
from cge_ref.scenarios import (NONIMPORTED_SAM, SUT_SAM, SYNTHETIC_SAM, TEST_ELASTICITIES, run_simulations,
                               synthetic_mapping, sut_mapping, sut_model)

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import synthetic_sam  # noqa: E402
from test_validation import _close  # noqa: E402


@pytest.fixture(scope="module")
def model():
    return sut_model()


def _sam_with(changes):
    sam = SAM.from_csv(SUT_SAM)
    values = sam.values.copy()
    for (row, col), delta in changes.items():
        values[sam.index(row), sam.index(col)] += delta
    return SAM(sam.labels, values)


def test_sam_balances_and_matches_generator():
    labels, values = synthetic_sam.build_sut_layout()
    assert max(abs(d) for d in synthetic_sam.imbalances(values)) < 1e-12
    sam = SAM.from_csv(SUT_SAM)
    assert sam.labels == labels and np.array_equal(sam.values, np.array(values))


def test_benchmark_replication(model):
    assert model.n_equations == 103          # 105 less two zero intermediate inputs
    assert model.max_residual(model.base) < 1e-12
    solution = model.solve()
    assert solution.converged and solution.iterations == 0


# Stock-change account
def test_stock_account_is_merged_into_savings_investment(model):
    prepared, _, notes = prepare(SAM.from_csv(SUT_SAM), sut_mapping())
    assert notes["stocks"] == 3
    k = prepared.index("dstk")
    assert not prepared.values[k, :].any() and not prepared.values[:, k].any()
    assert prepared.cell("com_agr", "s-i") == 5 - 1 and prepared.cell("com_man", "s-i") == 37 + 4
    assert np.abs(prepared.imbalances()).max() < 1e-12
    C = model.sets["C"]
    assert model.params["qinv"][C.index("com_agr")] == 4
    assert model.base["QINV"].sum() == 50


def test_stock_account_errors():
    with pytest.raises(SAMError, match="receive payments only from s-i"):
        prepare(_sam_with({("dstk", "row"): 1, ("s-i", "row"): -1}), sut_mapping())
    m = sut_mapping()
    m.stocks = ["trd"]
    with pytest.raises(SAMError, match="also mapped"):
        prepare(SAM.from_csv(SUT_SAM), m)
    m = sut_mapping()
    m.stocks = []
    with pytest.raises(SAMError, match="dstk"):
        Model(SAM.from_csv(SUT_SAM), m, **TEST_ELASTICITIES)


# Commodity imported only
def test_import_only_commodity(model):
    k = model.sets["C"].index("com_fuel")
    assert not model.struct["cx"][k] and model.struct["cm"][k]
    for name in ("PX", "PD", "QX", "QD"):
        assert not model.exists[name][k]
    assert np.isclose(model.params["aq"][k], 16 / 12)
    assert np.isclose(model.base["QQ"][k], 16)


def test_fuel_import_price_rise(model):
    k = model.sets["C"].index("com_fuel")
    pwm = model.params["pwm"].copy()
    pwm[k] *= 1.25
    s = model.solve(params={"pwm": pwm})
    assert s.converged
    assert s["PQ"][k] > 1 and s["QM"][k] < model.base["QM"][k]
    assert np.isclose(s["QQ"][k], model.params["aq"][k] * s["QM"][k])      # T7


def test_commodities_must_cover_activities():
    m = synthetic_mapping()
    m.commodities = ["com_agr", "com_man"]
    with pytest.raises(SAMError, match="paired commodity"):
        Model(SAM.from_csv(SYNTHETIC_SAM), m, **TEST_ELASTICITIES)


def test_commodity_without_output_or_imports():
    sam = SAM.from_csv(SYNTHETIC_SAM)
    labels = sam.labels + ["com_none"]
    values = np.pad(sam.values, ((0, 1), (0, 1)))
    m = synthetic_mapping()
    m.commodities = m.commodities + ["com_none"]
    with pytest.raises(SAMError, match="neither domestic output nor imports: com_none$"):
        Model(SAM(labels, values), m, **TEST_ELASTICITIES)


def test_exports_of_import_only_commodity():
    sam = _sam_with({("com_fuel", "row"): 1, ("row", "com_fuel"): 1})
    with pytest.raises(SAMError, match="exports recorded for a commodity without domestic output: com_fuel$"):
        Model(sam, sut_mapping(), **TEST_ELASTICITIES)


def test_import_tariff_without_imports_names_the_commodity():
    # 1 of com_ser's sales tax recorded as an import tariff; com_ser is not imported
    sam = SAM.from_csv(NONIMPORTED_SAM)
    values = sam.values.copy()
    for (row, col), delta in {("tax_imp", "com_ser"): 1, ("tax_sal", "com_ser"): -1,
                              ("gov", "tax_imp"): 1, ("gov", "tax_sal"): -1}.items():
        values[sam.index(row), sam.index(col)] += delta
    with pytest.raises(SAMError, match="import tariff recorded on a commodity without imports: com_ser$"):
        Model(SAM(sam.labels, values), synthetic_mapping(), **TEST_ELASTICITIES)


# Margin accounts
def test_margin_coefficients(model):
    p, b = model.params, model.base
    C = model.sets["C"]
    paid = p["icm"].sum(axis=0) * b["QQ"]                  # margins paid by each commodity
    assert np.allclose(paid, [5, 8, 0, 2])
    assert np.allclose(b["QT"], [0, 1, 14, 0])
    assert np.allclose(p["icm"] @ b["QQ"], b["QT"])
    assert list(model.struct["ct"]) == [False, True, True, False]
    agr, ser = C.index("com_agr"), C.index("com_ser")
    # trd's 3 all buys com_ser; 4/5 of trp's 2 buys com_ser
    assert np.isclose(p["icm"][ser, agr], (3 + 2 * 4 / 5) / 114)


def test_margin_account_with_other_flows():
    # trd pays 1 to households instead of buying 1 of com_ser; households buy it
    sam = _sam_with({("hhd", "trd"): 1, ("com_ser", "trd"): -1, ("com_ser", "hhd"): 1})
    assert np.abs(sam.imbalances()).max() < 1e-12
    with pytest.raises(SAMError, match="from 'trd' \\(mar\\) to 'hhd' \\(hh\\) is not represented"):
        Model(sam, sut_mapping(), **TEST_ELASTICITIES)


def test_margin_cost_follows_the_price_of_margin_services(model):
    # com_fuel pays 2 of margins, all to trd, which buys only com_ser
    C = model.sets["C"]
    ser, fuel = C.index("com_ser"), C.index("com_fuel")
    PQ = model.base["PQ"].copy()
    PQ[ser] = 1.1
    margin_cost = (PQ @ model.params["icm"]) * model.base["QQ"]
    assert np.isclose(margin_cost[fuel], 2 * 1.1)


# Validation checks on the supply-use layout
def test_homogeneity(model):
    s = model.solve(fixed={"CPI": 2.0})
    assert s.converged
    for name in VARIABLES:
        exists = model.exists[name]
        factor = 2.0 if name in NOMINAL else 1.0
        assert _close(s[name][exists], factor * model.base[name][exists]), name


def test_simulations_satisfy_walras_and_gdp_identity(model):
    for name, s in run_simulations(model).items():
        assert s.converged, name
        assert abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8, name


@pytest.mark.parametrize("macro", list(itertools.product(("flexexr", "fixexr"), ("flexgsav", "fixgsav"),
                                                         ("savings", "investment"), ("cpi", "dpi"))),
                         ids=lambda m: "-".join(m))
def test_closures_reproduce_base(model, macro):
    closure = Closure(*macro, factors={"cap": "specific"})
    s = model.solve(closure)
    assert s.converged and s.iterations == 0


def test_perturbed_start_returns_base(model):
    rng = np.random.default_rng(7)
    start = {k: v * (1 + rng.uniform(-0.1, 0.1, size=v.shape)) for k, v in model.base.items()}
    s = model.solve(start=start)
    assert s.converged
    for name in VARIABLES:
        assert _close(s[name], model.base[name], rel=1e-7), name
