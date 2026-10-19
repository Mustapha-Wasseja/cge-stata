"""Fiscal instruments (version 0.3.1, model_spec.md, Section 12): tax
replacement closures, VAT with input credits, public debt and interest."""

import dataclasses

import numpy as np
import pytest

from cge_ref.dynamics import Dynamics, run
from cge_ref.model import Closure, Model, final_price, vat_revenue
from cge_ref.report import report
from cge_ref.sam import SAM, SAMError, prepare
from cge_ref.scenarios import (DEBT, SYNTHETIC_SAM, TEST_ELASTICITIES, VAT_CREDIT, VAT_SAM, VAT_SHARES,
                               debt_model, fiscal_cases, institutions_model, synthetic_mapping,
                               synthetic_model, vat_mapping, vat_model, vatshare_model)


@pytest.fixture(scope="module")
def vat():
    return vat_model()


@pytest.fixture(scope="module")
def cases():
    return fiscal_cases()


# ---------------------------------------------------------------------------
# VAT (12.2)
# ---------------------------------------------------------------------------

def test_vat_calibration_reproduces_the_base(vat):
    sam = SAM.from_csv(VAT_SAM)
    b, p = vat.base, vat.params
    assert vat_revenue(b, p)[0] == pytest.approx(sam.row_total("tax_vat"), abs=1e-12)
    assert b["CPI"][0] == pytest.approx(1.0, abs=1e-15)
    solution = vat.solve(Closure())
    assert solution.converged and solution.iterations == 0


def test_vat_rate_equation_by_commodity(vat):
    """Each rate solves SAM(vat, c) = sum_u V_u tv k_u / (1 + tv k_u)."""
    sam = SAM.from_csv(VAT_SAM)
    tv, kappa = vat.params["tv"], vat.params["kappa"]
    A = vat.sets["A"]
    for k, c in enumerate(vat.sets["C"]):
        inputs = np.array([sam.cell(c, a) for a in A])
        final = sam.cell(c, "hhd") + sam.cell(c, "gov") + sam.cell(c, "sav")
        due = (inputs * tv[k] * (1 - kappa) / (1 + tv[k] * (1 - kappa))).sum() + final * tv[k] / (1 + tv[k])
        assert due == pytest.approx(sam.cell("tax_vat", c), abs=1e-12)


def test_vat_with_full_credits_is_a_tax_on_final_demand():
    model = vat_model(vat_credit=1.0)
    sam = SAM.from_csv(VAT_SAM)
    for k, c in enumerate(model.sets["C"]):
        final = sam.cell(c, "hhd") + sam.cell(c, "gov") + sam.cell(c, "sav")
        v = sam.cell("tax_vat", c)
        assert model.params["tv"][k] == pytest.approx(v / (final - v), rel=1e-14)
    # Quantities of intermediate inputs equal their values: no VAT is borne
    assert np.allclose(model.base["QINT"], np.array([[sam.cell(c, a) for a in model.sets["A"]]
                                                     for c in model.sets["C"]]), atol=1e-13)


def test_exempt_activity_bears_vat_on_its_inputs(vat):
    b, tv, kappa = vat.base, vat.params["tv"], vat.params["kappa"]
    a = vat.sets["A"].index("act_agr")
    assert kappa[a] == 0
    assert b["PINTA"][a] == pytest.approx((vat.params["ica"][:, a] * (1 + tv)).sum(), abs=1e-14)
    assert b["PINTA"][vat.sets["A"].index("act_man")] == pytest.approx(1.0, abs=1e-14)


def test_gdp_identity_and_homogeneity_with_vat(vat, cases):
    for name, solution in cases.items():
        assert solution.converged, name
        assert abs(solution.gdp_gap()) < 1e-9, name
    double = vat.solve(Closure(), fixed={"CPI": 2.0}, tol=1e-12)
    for name in ("PQ", "PA", "W", "YG", "EH"):
        assert np.allclose(double[name], 2 * vat.base[name], rtol=1e-10), name
    for name in ("QA", "QH", "QINT", "TVADJ"):
        assert np.allclose(double[name], vat.base[name], rtol=1e-10), name


def test_vat_rise_raises_revenue_and_consumer_prices(vat, cases):
    s, b = cases["vat_rate_up20"], vat.base
    assert vat_revenue(s.values, s.params)[0] > vat_revenue(b, vat.params)[0]
    assert s["GSAV"][0] > b["GSAV"][0]
    assert s["CPI"][0] == pytest.approx(1.0)
    # Prices before VAT fall relative to prices paid by final users
    assert np.all(final_price(s.values, s.params) / s["PQ"] > final_price(b, vat.params) / b["PQ"])


def test_full_credits_lower_input_costs_of_exempt_activities(vat, cases):
    s = cases["vat_credit_full"]
    a = vat.sets["A"].index("act_agr")
    assert s["PINTA"][a] / s["PQ"].mean() < vat.base["PINTA"][a]


def test_vat_shares_rewrite_moves_part_of_the_sales_tax():
    m = synthetic_mapping()
    m.vat_shares = VAT_SHARES
    sam, mapping, notes = prepare(SAM.from_csv(SYNTHETIC_SAM), m)
    assert mapping.vattax == "_vatshare"
    assert notes["vat"] == pytest.approx(0.5 * 12 + 10)
    assert sam.cell("_vatshare", "com_man") == 6 and sam.cell("tax_sal", "com_man") == 6
    assert sam.cell("_vatshare", "com_ser") == 10 and sam.cell("tax_sal", "com_ser") == 0
    assert sam.cell("gov", "_vatshare") == 16 and sam.cell("gov", "tax_sal") == 14
    assert np.abs(sam.imbalances()).max() < 1e-12
    model = vatshare_model()
    assert model.solve(Closure()).iterations == 0


def test_vat_errors():
    m = vat_mapping()
    m.vat_shares = 0.5
    with pytest.raises(SAMError, match="not both"):
        Model(SAM.from_csv(VAT_SAM), m, **TEST_ELASTICITIES)
    with pytest.raises(ValueError, match="between 0 and 1"):
        vat_model(vat_credit=1.5)
    with pytest.raises(ValueError, match="not activities"):
        vat_model(vat_credit={"act_xyz": 0.5})


# ---------------------------------------------------------------------------
# Tax replacement (12.1)
# ---------------------------------------------------------------------------

def test_replacement_closures_hold_government_savings(cases):
    for name, adj in (("rep_tariff_removal_sales", "TQADJ"), ("rep_tariff_removal_direct", "TINSADJ"),
                      ("vat_tariff_removal_vat", "TVADJ"), ("vat_rate_cut_import", "TMADJ")):
        s = cases[name]
        assert s["GSAV"][0] == pytest.approx(s.model.base["GSAV"][0], abs=1e-12), name
        assert s[adj][0] > 1, name
        others = {"TQADJ", "TMADJ", "TVADJ", "TINSADJ"} - {adj}
        assert all(s[o][0] == 1 for o in others), name


def test_fixgsav_direct_is_the_old_fixed_savings_closure():
    std = synthetic_model()
    p = {"tm": np.zeros_like(std.params["tm"])}
    a = std.solve(Closure(government="fixgsav"), params=p, tol=1e-12)
    b = std.solve(Closure(government="fixgsav direct"), params=p, tol=1e-12)
    for name in a.values:
        assert np.array_equal(a[name], b[name]), name


def test_replacement_needs_a_tax_with_revenue():
    std = synthetic_model()
    with pytest.raises(ValueError, match="raises no revenue"):
        std.solve(Closure(government="fixgsav vat"))
    with pytest.raises(ValueError):
        Closure(government="fixgsav export")


def test_sales_tax_replacement_matches_the_lost_tariff_revenue(cases):
    s = cases["rep_tariff_removal_sales"]
    model, b = s.model, s.model.base
    rows = {(t, m): (x0, x) for t, m, e, x0, x in report(s)}
    tariff0 = rows[("government", "tax_import")][0]
    assert rows[("government", "tax_import")][1] == 0
    assert rows[("government", "tax_sales")][1] > rows[("government", "tax_sales")][0]
    assert s["YG"][0] - s["EG"][0] == pytest.approx(b["YG"][0] - b["EG"][0], abs=1e-12)
    assert tariff0 > 0


# ---------------------------------------------------------------------------
# Public debt and interest (12.3)
# ---------------------------------------------------------------------------

def test_debt_calibration_splits_transfers_and_keeps_the_base():
    plain, debt = institutions_model(), debt_model()
    p = debt.params
    domestic = DEBT["debt"]["domestic"] * DEBT["interest"]["domestic"]
    foreign = DEBT["debt"]["foreign"] * DEBT["interest"]["foreign"]
    assert np.allclose(p["hold"], plain.params["trdg"] / plain.params["trdg"].sum())
    assert np.allclose(p["trdg"] + p["hold"] * domestic, plain.params["trdg"], atol=1e-14)
    assert float(p["trrg"]) + foreign == pytest.approx(float(plain.params["trrg"]), abs=1e-14)
    assert float(p["phi"]) == pytest.approx(40 / 140)
    for name in plain.base:
        assert np.allclose(debt.base[name], plain.base[name], atol=1e-13), name
    assert debt.solve(Closure()).iterations == 0


def test_debt_errors():
    with pytest.raises(SAMError, match="smaller than"):
        debt_model(debt={"domestic": 1000.0, "foreign": 40.0})
    with pytest.raises(SAMError, match="rest of the world"):
        debt_model(debt={"domestic": 100.0, "foreign": 400.0})
    with pytest.raises(ValueError, match="sum to one"):
        debt_model(debt_holders={"hhd": 0.5})
    with pytest.raises(ValueError, match="not domestic or foreign"):
        debt_model(debt={"external": 10.0})


def test_interest_shocks_change_the_balance(cases):
    base = debt_model().base
    up, relief = cases["debt_rate_up"], cases["debt_relief"]
    assert up["GSAV"][0] < base["GSAV"][0] < relief["GSAV"][0]
    rows = {(t, m): x for t, m, e, x0, x in report(up)}
    assert rows[("debt", "interest_foreign")] == pytest.approx(2 * 0.03 * 40 * up["EXR"][0])
    gsav = up["GSAV"][0]
    assert rows[("debt", "primary_balance")] == pytest.approx(
        gsav + rows[("debt", "interest_domestic")] + rows[("debt", "interest_foreign")])


@pytest.fixture(scope="module")
def debt_run():
    common = {"capital": {"cap": (0.05, 0.15)}, "factor_growth": {"lab": 0.02}, "population_growth": 0.02,
              "government_growth": 0.03, "foreign_growth": 0.01}
    return run(debt_model(), Dynamics(periods=4, tfp_growth=0.01, **common),
               Closure(factors={"cap": "specific"}))


def test_debt_accumulates_deficits(debt_run):
    sols = debt_run.solutions
    for t in range(1, len(sols)):
        prev, cur = sols[t - 1], sols[t]
        deficit = -prev["GSAV"][0]
        phi = float(prev.params["phi"])
        assert float(cur.params["ddebt"]) == pytest.approx(float(prev.params["ddebt"]) + (1 - phi) * deficit, rel=1e-14)
        assert float(cur.params["fdebt"]) == pytest.approx(
            float(prev.params["fdebt"]) + phi * deficit / prev["EXR"][0], rel=1e-14)
        rows = {m: x for tb, m, e, x0, x in report(prev) if tb == "debt"}
        assert rows["debt_domestic"] == pytest.approx(float(cur.params["ddebt"]), rel=1e-14)
        assert rows["debt_foreign_fc"] == pytest.approx(float(cur.params["fdebt"]), rel=1e-14)


def test_interest_is_paid_on_the_stock_at_the_start_of_the_period(debt_run):
    for sol in debt_run.solutions:
        rows = {m: x for tb, m, e, x0, x in report(sol) if tb == "debt"}
        assert rows["interest_domestic"] == pytest.approx(0.05 * float(sol.params["ddebt"]), rel=1e-14)
        assert rows["interest_foreign"] == pytest.approx(0.03 * float(sol.params["fdebt"]) * sol["EXR"][0], rel=1e-14)


def test_a_surplus_repays_debt():
    model = debt_model()
    settings = Dynamics(periods=2)

    def raise_taxes(t, p, fx):
        p["tins0"] = model.params["tins0"] * 1.5

    r = run(model, settings, Closure(), raise_taxes)
    assert r.solutions[1]["GSAV"][0] > 0
    assert float(r.solutions[2].params["ddebt"]) < float(r.solutions[1].params["ddebt"])
    assert float(r.solutions[2].params["fdebt"]) < float(r.solutions[1].params["fdebt"])


def test_without_debt_the_dynamics_are_unchanged():
    model = institutions_model()
    assert float(model.params["debt"]) == 0
    r = run(model, Dynamics(periods=2, government_growth=0.03), Closure())
    assert all(float(s.params["ddebt"]) == 0 and float(s.params["fdebt"]) == 0 for s in r.solutions)
