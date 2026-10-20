"""Trade and household extensions (version 0.3.2, model_spec.md, Section 13):
home consumption, export demand, export-only commodities, margins by market."""

import numpy as np
import pytest

from cge_ref.dynamics import Dynamics, run
from cge_ref.model import Closure, Model
from cge_ref.report import report
from cge_ref.sam import SAM, SAMError
from cge_ref.scenarios import (HOME_SAM, LES_SETTINGS, TEST_ELASTICITIES, TRADE_SAM, TRADE_SETTINGS,
                               home_model, simulation_inputs, synthetic_model, trade_cases,
                               trade_mapping, trade_model)


@pytest.fixture(scope="module")
def cases():
    return trade_cases()


@pytest.fixture(scope="module")
def trade():
    return trade_model(**TRADE_SETTINGS)


# ---------------------------------------------------------------------------
# Home consumption (13.1)
# ---------------------------------------------------------------------------

def test_home_consumption_calibration():
    m = home_model()
    sam = SAM.from_csv(HOME_SAM)
    b, p = m.base, m.params
    a = m.sets["A"].index("act_agr")
    assert b["QHA"][a, 0] == 20
    assert p["theta"][a, m.sets["C"].index("com_agr")] == 1.0          # per unit of marketed output
    assert b["EH"][0] == pytest.approx(sam.col_total("hhd") - sam.cell("tax_dir", "hhd") - sam.cell("sav", "hhd"))
    assert p["beta"].sum() + p["betah"].sum() == pytest.approx(1.0, abs=1e-15)
    assert m.solve(Closure()).iterations == 0


def test_home_consumption_les_shares_and_subsistence():
    m = home_model(**LES_SETTINGS)
    p, b = m.params, m.base
    assert p["beta"].sum() + p["betah"].sum() == pytest.approx(1.0, abs=1e-15)
    # Supernumerary spending is -EH / phi, counting home goods
    sn = b["EH"][0] - b["PQ"] @ p["gamma"][:, 0] - b["PA"] @ p["gammah"][:, 0]
    assert sn == pytest.approx(-b["EH"][0] / LES_SETTINGS["frisch"], rel=1e-13)
    assert m.solve(Closure()).iterations == 0


def test_home_goods_escape_sales_tax(cases):
    """A higher sales tax on the marketed good raises its price more than the
    price of home goods; with Cobb-Douglas demand, budget shares are unchanged."""
    m = home_model()
    s, b = cases["home_sales_tax_agr_up"], m.base
    c, a = m.sets["C"].index("com_agr"), m.sets["A"].index("act_agr")
    assert s["PQ"][c] / b["PQ"][c] > s["PA"][a] / b["PA"][a]
    assert s["QH"][c, 0] < b["QH"][c, 0]
    assert s["PA"][a] * s["QHA"][a, 0] / s["EH"][0] == pytest.approx(m.params["betah"][a, 0], rel=1e-13)


def test_home_consumption_gdp_and_homogeneity(cases):
    for name in ("home_tariff_removal", "home_les_tariff_removal", "home_sales_tax_agr_up"):
        assert abs(cases[name].gdp_gap()) < 1e-10, name
    m = home_model(**LES_SETTINGS)
    double = m.solve(Closure(), fixed={"CPI": 2.0}, tol=1e-12)
    assert np.allclose(double["PA"], 2 * m.base["PA"], rtol=1e-10)
    assert np.allclose(double["QHA"], m.base["QHA"], rtol=1e-10)


def test_home_consumption_counts_in_real_consumption_and_welfare(cases):
    s = cases["home_les_tariff_removal"]
    rows = {(t, mm, e): (x0, x) for t, mm, e, x0, x in report(s)}
    home0, home1 = rows[("macro", "home_consumption_real", "")]
    assert home0 == pytest.approx(20.0)
    assert home1 == pytest.approx(s.model.base["PA"] @ s["QHA"].sum(axis=1))
    ev = s.equivalent_variation()
    # EV at base prices of the new consumption bundle, with home goods valued at PA
    assert np.isfinite(ev).all()


def test_population_growth_scales_home_subsistence():
    m = home_model(**LES_SETTINGS)
    r = run(m, Dynamics(periods=2, population_growth=0.03), Closure())
    assert np.allclose(r.solutions[2].params["gammah"], m.params["gammah"] * 1.03 ** 2, rtol=1e-14)


def test_activity_must_market_some_output():
    sam = SAM.from_csv(HOME_SAM)
    values = sam.values.copy()
    k = {a: i for i, a in enumerate(sam.labels)}
    # all of act_agr's output consumed at home
    values[k["act_agr"], k["hhd"]] += values[k["act_agr"], k["com_agr"]]
    values[k["com_agr"], k["hhd"]] -= values[k["act_agr"], k["com_agr"]]
    values[k["row"], k["com_agr"]] += values[k["act_agr"], k["com_agr"]]
    values[k["act_agr"], k["com_agr"]] = 0
    with pytest.raises(SAMError):
        Model(SAM(sam.labels, values), trade_mapping.__globals__["synthetic_mapping"](), **TEST_ELASTICITIES)


# ---------------------------------------------------------------------------
# Margins by market (13.4)
# ---------------------------------------------------------------------------

def test_margins_by_market_calibration(trade):
    p, b, C = trade.params, trade.base, trade.sets["C"]
    man, ser = C.index("com_man"), C.index("com_ser")
    assert p["icd"][ser, man] == pytest.approx(4 / 93)
    assert p["ici"][ser, man] == pytest.approx(3 / 60)
    assert p["ice"][ser, man] == pytest.approx(2 / 38)
    assert b["QE"][man] == 38
    assert p["pwe"][man] == pytest.approx(40 / 38)
    assert b["PM"][man] == pytest.approx(1 + 6 / 60 + 3 / 60)
    assert b["QQ"][man] == pytest.approx(178)
    assert trade.solve(Closure()).iterations == 0


def test_composite_margins_give_the_old_model(cases):
    """With every margin account paid per unit of composite supply, results do not
    depend on the market tags; the model is the one of version 0.3.1."""
    plain = trade_model(by_market=False)
    assert not plain.params["icd"].any() and not plain.params["ici"].any() and not plain.params["ice"].any()
    assert cases["tradeplain_tariff_removal"].converged


def test_dearer_trade_services_raise_import_prices():
    trade = trade_model(**TRADE_SETTINGS)
    C = trade.sets["C"]
    man = C.index("com_man")
    p = {"ad": trade.params["ad"] * np.array([1.0, 1.0, 0.9])}     # services 10 per cent less productive
    s = trade.solve(Closure(), params=p, tol=1e-12)
    pm_tariff = trade.params["pwm"][man] * (1 + trade.params["tm"][man]) * s["EXR"][0]
    assert s["PM"][man] - pm_tariff == pytest.approx(s["PQ"] @ trade.params["ici"][:, man], rel=1e-12)


def test_margins_need_their_market():
    sam = SAM.from_csv(TRADE_SAM)
    m = trade_mapping()
    m.export_margins, m.domestic_margins = [], ["mtrd", "mtre"]
    Model(sam, m, **TEST_ELASTICITIES, **TRADE_SETTINGS)          # domestic sales exist: allowed
    m = trade_mapping()
    m.import_margins = ["mtrm"]
    values = sam.values.copy()
    k = {a: i for i, a in enumerate(sam.labels)}
    # move com_man's import margin to com_ser... which has imports: fine; to com_cash: no imports
    values[k["mtrm"], k["com_man"]] -= 3
    values[k["mtrm"], k["com_cash"]] += 3
    values[k["act_agr"], k["com_cash"]] -= 3
    values[k["cap"], k["act_agr"]] -= 3
    values[k["hhd"], k["cap"]] -= 3
    values[k["com_ser"], k["hhd"]] -= 3
    values[k["com_ser"], k["mtrm"]] += 0
    with pytest.raises(SAMError):
        Model(SAM(sam.labels, values), m, **TEST_ELASTICITIES)


# ---------------------------------------------------------------------------
# Export-only commodities (13.3) and export demand (13.2)
# ---------------------------------------------------------------------------

def test_export_only_commodity(trade):
    k = trade.sets["C"].index("com_cash")
    assert trade.struct["cxe"][k] and trade.struct["ce"][k] and not trade.struct["cr"][k]
    assert not trade.exists["QD"][k] and not trade.exists["PQ"][k] and not trade.exists["QQ"][k]
    assert trade.base["QE"][k] == trade.base["QX"][k] == 20


def test_export_only_candidates_are_listed():
    plain = trade_model(by_market=False)
    assert plain.export_only_candidates == ["com_cash"]
    k = plain.sets["C"].index("com_cash")
    assert plain.struct["cr"][k]          # without the choice, exports come from composite supply
    with pytest.raises(SAMError):
        trade_model(export_only=["com_man"])


def test_export_demand_curve(cases, trade):
    C = trade.sets["C"]
    man = C.index("com_man")
    for name in ("trade_tariff_removal", "trade_world_demand_up10", "trade_cash_price_down20"):
        s = cases[name]
        for k in np.flatnonzero(trade.struct["ced"]):
            assert s["QE"][k] == pytest.approx(
                trade.params["qe0"][k] * (s["PWE"][k] / s.params["pwe"][k]) ** -trade.params["eta_e"][k], rel=1e-12)
        assert abs(s.gdp_gap()) < 1e-10
    up = cases["trade_world_demand_up10"]
    assert up["QE"][man] > trade.base["QE"][man] and up["PWE"][man] > trade.base["PWE"][man]


def test_large_export_demand_elasticity_approaches_small_country():
    small = synthetic_model()
    big = synthetic_model(export_demand=1e4)
    a = small.solve(Closure(), tol=1e-12, **simulation_inputs(small)["tariff_removal"])
    b = big.solve(Closure(), tol=1e-12, **simulation_inputs(big)["tariff_removal"])
    assert b.converged
    for name in ("PQ", "QE", "EXR", "QA"):
        assert np.allclose(a[name], b[name], rtol=1e-5), name


def test_export_demand_errors():
    with pytest.raises(SAMError, match="no exports"):
        trade_model(export_demand={"com_agr": 2.0})
    with pytest.raises(ValueError, match="positive"):
        trade_model(export_demand={"com_man": -1.0})


def test_export_only_with_an_export_tax():
    sam = SAM.from_csv(TRADE_SAM)
    labels = sam.labels + ["tax_exp"]
    values = np.pad(sam.values, ((0, 1), (0, 1)))
    k = {a: i for i, a in enumerate(labels)}
    # an export tax of 2 on the cash crop, paid out of the producers' income
    values[k["tax_exp"], k["com_cash"]] = 2
    values[k["gov"], k["tax_exp"]] = 2
    values[k["act_agr"], k["com_cash"]] -= 2
    values[k["cap"], k["act_agr"]] -= 2
    values[k["hhd"], k["cap"]] -= 2
    values[k["hhd"], k["gov"]] += 2
    m = trade_mapping()
    m.exptax = "tax_exp"
    model = Model(SAM(labels, values), m, **TEST_ELASTICITIES, export_only=["com_cash"])
    c = model.sets["C"].index("com_cash")
    assert model.params["te"][c] == pytest.approx(2 / 20)
    assert model.solve(Closure()).iterations == 0
    s = model.solve(Closure(), tol=1e-12, params={"te": np.zeros_like(model.params["te"])})
    assert s.converged and s["QE"][c] > model.base["QE"][c]
