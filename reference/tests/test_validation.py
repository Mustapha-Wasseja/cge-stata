"""Validation checks of docs/model_spec.md, Section 8, and simulation behaviour."""

import csv
import itertools

import numpy as np
import pytest

from cge_ref import VARIABLES, Closure
from cge_ref.model import NOMINAL
from cge_ref.scenarios import (EXPECTED_DIR, run_simulations, simulation_inputs,
                               synthetic_model, write_expected)


@pytest.fixture(scope="module")
def model():
    return synthetic_model()


@pytest.fixture(scope="module")
def simulations(model):
    return run_simulations(model)


def _close(a, b, rel=1e-8):
    a, b = np.asarray(a, dtype=float), np.asarray(b, dtype=float)
    return np.all(np.abs(a - b) <= rel * np.maximum(1.0, np.abs(b)))


# Check 3: homogeneity
def test_homogeneity(model):
    solution = model.solve(fixed={"CPI": 2.0})
    assert solution.converged
    for name in VARIABLES:
        exists = model.exists[name]
        factor = 2.0 if name in NOMINAL else 1.0
        assert _close(solution[name][exists], factor * model.base[name][exists]), name


# Check 4: Walras's law, plus the GDP identity
def test_walras_and_gdp_identity(simulations):
    for name, solution in simulations.items():
        assert solution.converged, name
        assert abs(solution["WALRAS"][0]) < 1e-8, name
        assert abs(solution.gdp_gap()) < 1e-8, name


# Dual check: prices equal unit cost or unit revenue functions derived
# independently of the first-order conditions used in the model.
def _unit_costs(solution):
    s, p, st = solution, solution.params, solution.model.struct
    w = s["W"][:, None] * s["WFDIST"]
    sva, fa = p["sigma_va"], st["fa"]
    va_cost = np.empty(sva.size)
    for k in range(sva.size):
        m, d = fa[:, k], p["delta_va"][fa[:, k], k]
        if st["cd"][k]:
            va_cost[k] = np.prod((w[m, k] / d) ** d) / p["ad"][k]
        else:
            sg = sva[k]
            va_cost[k] = (d ** sg * w[m, k] ** (1 - sg)).sum() ** (1 / (1 - sg)) / p["ad"][k]
    sq, dq, dqc = p["sigma_q"], p["delta_q"], p["deltac_q"]
    arm_cost = (dq ** sq * s["PM"] ** (1 - sq) + dqc ** sq * s["PD"] ** (1 - sq)) ** (1 / (1 - sq)) / p["aq"]
    stt, dt, dtc = p["sigma_t"], p["delta_t"], p["deltac_t"]
    cet_revenue = ((dt ** -stt * s["PE"] ** (1 + stt) + dtc ** -stt * s["PD"] ** (1 + stt))
                   ** (1 / (1 + stt)) / p["at"])
    return va_cost, arm_cost, cet_revenue


@pytest.mark.parametrize("sigma_va", [0.8, 1.0])
def test_prices_equal_dual_unit_costs(sigma_va):
    m = synthetic_model(sigma_va=sigma_va)
    st = m.struct
    for name, solution in run_simulations(m).items():
        va_cost, arm_cost, cet_revenue = _unit_costs(solution)
        s, p = solution, solution.params
        assert _close(s["PVA"], va_cost, rel=1e-9), name
        assert _close((s["PQ"] * (1 - p["tq"]))[st["cm"]], arm_cost[st["cm"]], rel=1e-9), name
        assert _close(s["PX"][st["ce"]], cet_revenue[st["ce"]], rel=1e-9), name


# Check 5: robust start
@pytest.mark.parametrize("seed", range(5))
def test_perturbed_start_returns_base(model, seed):
    rng = np.random.default_rng(seed)
    start = {k: v * (1 + rng.uniform(-0.1, 0.1, size=v.shape)) for k, v in model.base.items()}
    solution = model.solve(start=start)
    assert solution.converged
    for name in VARIABLES:
        assert _close(solution[name], model.base[name], rel=1e-7), name


# Check 6: every closure is square and reproduces the base
FACTOR_CLOSURES = [{}, {"lab": "unemployed"}, {"cap": "specific"},
                   {"lab": "unemployed", "cap": "specific"}]
MACRO_CLOSURES = list(itertools.product(("flexexr", "fixexr"), ("flexgsav", "fixgsav"),
                                        ("savings", "investment"), ("cpi", "dpi")))


@pytest.mark.parametrize("macro", MACRO_CLOSURES, ids=lambda m: "-".join(m))
@pytest.mark.parametrize("factors", FACTOR_CLOSURES, ids=lambda f: "-".join(f"{k}:{v}" for k, v in f.items()) or "mobile")
def test_closure_reproduces_base(model, macro, factors):
    external, government, savinv, numeraire = macro
    closure = Closure(external, government, savinv, numeraire, factors)
    solution = model.solve(closure)
    assert solution.converged and solution.iterations == 0


def test_unfixed_variable_cannot_be_set(model):
    with pytest.raises(ValueError, match="not fixed"):
        model.solve(Closure(external="flexexr"), fixed={"EXR": 1.1})


# Check 7: stored results for the Stata comparison are current
def test_expected_files_are_current(tmp_path):
    for path in write_expected(tmp_path):
        with path.open(newline="") as fresh, (EXPECTED_DIR / path.name).open(newline="") as stored:
            new_rows, old_rows = list(csv.reader(fresh)), list(csv.reader(stored))
        # Label columns must match exactly and values to a tolerance; a SAM file
        # (samtools_*) has one label column, a multiplier file two, a results
        # file three
        nlab = 1 if path.name.startswith("samtools_") else 2 if path.name.startswith("multipliers_") else 3
        assert new_rows[0] == old_rows[0], path.name
        assert [r[:nlab] for r in new_rows] == [r[:nlab] for r in old_rows], path.name
        new = np.array([[float(x) for x in r[nlab:]] for r in new_rows[1:]])
        old = np.array([[float(x) for x in r[nlab:]] for r in old_rows[1:]])
        assert _close(new, old, rel=1e-10), path.name


# Direction of effects in the standard simulations (default closure)
def test_tariff_removal(model, simulations):
    s, b = simulations["tariff_removal"], model.base
    assert s["QM"].sum() > b["QM"].sum()
    assert s["EXR"][0] > b["EXR"][0]
    assert s["GSAV"][0] < b["GSAV"][0]
    assert s["IADJ"][0] < 1.0


def test_import_price_rise(model, simulations):
    s = simulations["import_price_up10"]
    assert s["QM"].sum() < model.base["QM"].sum()
    assert s.equivalent_variation()[0] < 0


def test_labour_supply_rise(model, simulations):
    s, b = simulations["labour_supply_up5"], model.base
    lab, cap = model.sets["F"].index("lab"), model.sets["F"].index("cap")
    assert s["W"][lab] < b["W"][lab] and s["W"][cap] > b["W"][cap]
    assert np.all(s["QVA"] > b["QVA"])
    assert s.equivalent_variation()[0] > 0


def test_foreign_savings_fall(model, simulations):
    s = simulations["foreign_savings_down20"]
    assert s["IADJ"][0] < 1.0
    assert s["EXR"][0] > 1.0
    assert (s.params["pwe"] @ s["QE"]) > (model.params["pwe"] @ model.base["QE"])


def test_agricultural_productivity_gain(model, simulations):
    s, b = simulations["agri_productivity_up5"], model.base
    agr = model.sets["A"].index("act_agr")
    assert s["QA"][agr] > b["QA"][agr]
    assert s["PX"][agr] < b["PX"][agr]


# Alternative closures change the adjusting variable as intended
def test_fixed_exchange_rate_closure(model):
    shock = simulation_inputs(model)["tariff_removal"]
    s = model.solve(Closure(external="fixexr"), **shock)
    assert s.converged and s["EXR"][0] == 1.0
    assert s["FSAV"][0] > model.base["FSAV"][0]


def test_fixed_government_savings_closure(model):
    shock = simulation_inputs(model)["tariff_removal"]
    s = model.solve(Closure(government="fixgsav"), **shock)
    assert s.converged and s["GSAV"][0] == model.base["GSAV"][0]
    assert s["TINSADJ"][0] > 1.0


def test_investment_driven_closure(model):
    shock = simulation_inputs(model)["foreign_savings_down20"]
    s = model.solve(Closure(savinv="investment"), **shock)
    assert s.converged and s["IADJ"][0] == 1.0
    assert s["MPSADJ"][0] > 1.0


def test_unemployment_closure(model):
    shock = simulation_inputs(model)["agri_productivity_up5"]
    s = model.solve(Closure(factors={"lab": "unemployed"}), **shock)
    lab = model.sets["F"].index("lab")
    assert s.converged and s["W"][lab] == model.base["W"][lab]
    assert s["QFS"][lab] != model.base["QFS"][lab]


def test_specific_capital_closure(model):
    shock = simulation_inputs(model)["labour_supply_up5"]
    s = model.solve(Closure(factors={"cap": "specific"}), **shock)
    cap = model.sets["F"].index("cap")
    assert s.converged and np.allclose(s["QF"][cap], model.base["QF"][cap])
    assert np.ptp(s["WFDIST"][cap]) > 1e-6
