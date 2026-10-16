"""Synthetic-SAM model and the standard simulations of model_spec.md, check 7.

Results of these simulations are written to tests/expected/ so that the Stata
test suite can compare its own results with the reference implementation.
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

import numpy as np

from .model import Closure, Model, Solution
from .sam import SAM, Mapping

REPO = Path(__file__).resolve().parents[2]
SYNTHETIC_SAM = REPO / "data" / "cge_synthetic_sam.csv"
EXPECTED_DIR = REPO / "tests" / "expected"

# Elasticities used for the reference simulations (test values, not estimates).
TEST_ELASTICITIES = {"sigma_va": 0.8, "sigma_q": 2.0, "sigma_t": 2.0}

# Sector-specific elasticities, including a Cobb-Douglas value-added case
# (act_man), for an additional cross-implementation comparison.
MIXED_ELASTICITIES = {
    "sigma_va": {"act_agr": 0.5, "act_man": 1.0, "act_ser": 1.5},
    "sigma_q": {"com_agr": 0.6, "com_man": 3.0, "com_ser": 1.2},
    "sigma_t": {"com_agr": 0.7, "com_man": 4.0, "com_ser": 1.0},
}


# LES household demand (version 0.1.11): test values, not estimates.
LES_SETTINGS = {"income_elasticities": {"com_agr": 0.6, "com_man": 1.0, "com_ser": 1.4}, "frisch": -2.0}


# Top nest (version 0.1.12): Leontief, CES and Cobb-Douglas in one model.
TOP_NEST = {"act_agr": 0.0, "act_man": 0.5, "act_ser": 1.0}


def synthetic_mapping() -> Mapping:
    return Mapping(
        activities=["act_agr", "act_man", "act_ser"],
        commodities=["com_agr", "com_man", "com_ser"],
        factors=["lab", "cap"],
        households=["hhd"],
        government="gov",
        savinv="sav",
        row="row",
        dirtax="tax_dir",
        saltax="tax_sal",
        imptax="tax_imp",
    )


def synthetic_model(**elasticities) -> Model:
    settings = {**TEST_ELASTICITIES, **elasticities}
    return Model(SAM.from_csv(SYNTHETIC_SAM), synthetic_mapping(), **settings)


INSTITUTIONS_SAM = REPO / "data" / "cge_synthetic_sam_inst.csv"


def institutions_mapping() -> Mapping:
    """Mapping of the institutions layout: a non-profit institution (npi) as a
    second household, and one enterprise (ent)."""
    m = synthetic_mapping()
    m.households = ["hhd", "npi"]
    m.enterprises = ["ent"]
    return m


def institutions_model(**elasticities) -> Model:
    settings = {**TEST_ELASTICITIES, **elasticities}
    return Model(SAM.from_csv(INSTITUTIONS_SAM), institutions_mapping(), **settings)


MARGINS_SAM = REPO / "data" / "cge_synthetic_sam_margins.csv"


def margins_mapping() -> Mapping:
    """Mapping of the margins layout: act_ser's margins are netted out of its output."""
    m = synthetic_mapping()
    m.margins = ["act_ser"]
    return m


def margins_model(**elasticities) -> Model:
    settings = {**TEST_ELASTICITIES, **elasticities}
    return Model(SAM.from_csv(MARGINS_SAM), margins_mapping(), **settings)


TERRITORIAL_SAM = REPO / "data" / "cge_synthetic_sam_tc.csv"
MULTIPRODUCT_SAM = REPO / "data" / "cge_synthetic_sam_mp.csv"


def territorial_mapping() -> Mapping:
    """Mapping of the territorial layout: com_tc and act_tc are the correction."""
    m = synthetic_mapping()
    m.territorial = ["com_tc", "act_tc"]
    return m


def territorial_model(**elasticities) -> Model:
    settings = {**TEST_ELASTICITIES, **elasticities}
    return Model(SAM.from_csv(TERRITORIAL_SAM), territorial_mapping(), **settings)


def multiproduct_model(**elasticities) -> Model:
    settings = {**TEST_ELASTICITIES, **elasticities}
    return Model(SAM.from_csv(MULTIPRODUCT_SAM), synthetic_mapping(), **settings)


NONIMPORTED_SAM = REPO / "data" / "cge_synthetic_sam_cnm.csv"


def nonimported_model(**elasticities) -> Model:
    settings = {**TEST_ELASTICITIES, **elasticities}
    return Model(SAM.from_csv(NONIMPORTED_SAM), synthetic_mapping(), **settings)


SUT_SAM = REPO / "data" / "cge_synthetic_sam_sut.csv"


def sut_mapping() -> Mapping:
    """Mapping of the supply-use layout: margin accounts trd and trp, a stock-change
    account dstk, and com_fuel (imported only) listed after the paired commodities."""
    m = synthetic_mapping()
    m.commodities = ["com_agr", "com_man", "com_ser", "com_fuel"]
    m.savinv = "s-i"
    m.margin_accounts = ["trd", "trp"]
    m.stocks = ["dstk"]
    return m


def sut_model(**elasticities) -> Model:
    settings = {**TEST_ELASTICITIES, **elasticities}
    return Model(SAM.from_csv(SUT_SAM), sut_mapping(), **settings)


HEALTH_SAM = REPO / "data" / "cge_synthetic_sam_health.csv"
# Labour efficiency linked to health services (version 0.1.14)
HEALTH_LINK = {"health_commodities": ["com_hlt"], "health_elasticities": {"lab": 0.3}}


def health_mapping() -> Mapping:
    """Mapping of the health layout: health services act_hlt and com_hlt, and a
    social health insurance fund shi."""
    m = synthetic_mapping()
    m.activities = ["act_agr", "act_man", "act_ser", "act_hlt"]
    m.commodities = ["com_agr", "com_man", "com_ser", "com_hlt"]
    m.insurance = "shi"
    return m


def health_model(**elasticities) -> Model:
    settings = {**TEST_ELASTICITIES, **elasticities}
    return Model(SAM.from_csv(HEALTH_SAM), health_mapping(), **settings)


def _scaled(array: np.ndarray, index: int, factor: float) -> np.ndarray:
    out = np.array(array, dtype=float, copy=True)
    out[index] *= factor
    return out


def simulation_inputs(model: Model) -> dict[str, dict]:
    """Shocks of model_spec.md, check 7, all under the default closure."""
    base, p = model.base, model.params
    lab = model.sets["F"].index("lab")
    agr = model.sets["A"].index("act_agr")
    return {
        "tariff_removal": {"params": {"tm": np.zeros_like(p["tm"])}},
        "import_price_up10": {"params": {"pwm": p["pwm"] * 1.10}},
        "labour_supply_up5": {"fixed": {"QFS": _scaled(base["QFS"], lab, 1.05)}},
        "foreign_savings_down20": {"fixed": {"FSAV": base["FSAV"] * 0.80}},
        "agri_productivity_up5": {"params": {"ad": _scaled(p["ad"], agr, 1.05)}},
    }


def run_simulations(model: Model, closure: Closure | None = None) -> dict[str, Solution]:
    closure = closure or Closure()
    return {name: model.solve(closure, tol=1e-12, **shock)
            for name, shock in simulation_inputs(model).items()}


def write_results(solution: Solution, path: Path) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["variable", "element1", "element2", "base", "value"])
        for name, e1, e2, base, value in solution.rows():
            writer.writerow([name, e1, e2, f"{base:.15g}", f"{value:.15g}"])


def write_report(solution: Solution, path: Path) -> None:
    from .report import report
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["table", "measure", "element", "base", "value"])
        for table, measure, element, base, value in report(solution):
            writer.writerow([table, measure, element, f"{base:.15g}", f"{value:.15g}"])


# Simulations whose standard report (version 0.1.15) is also compared
REPORTED = ("tariff_removal", "inst_transfers_abroad_down50", "les_import_price_up10",
            "sut_import_price_up10", "eff_contribution_up50")


def write_expected(directory: Path = EXPECTED_DIR) -> list[Path]:
    """Solve the standard simulations and write one CSV file per simulation."""
    directory.mkdir(parents=True, exist_ok=True)
    solutions = run_simulations(synthetic_model())
    mixed = synthetic_model(**MIXED_ELASTICITIES)
    solutions["mixed_tariff_removal"] = mixed.solve(
        Closure(), tol=1e-12, **simulation_inputs(mixed)["tariff_removal"])
    for name, solution in run_simulations(institutions_model()).items():
        solutions["inst_" + name] = solution
    for name, solution in run_simulations(synthetic_model(sigma_a=TOP_NEST)).items():
        solutions["nest_" + name] = solution
    for name, solution in run_simulations(synthetic_model(**LES_SETTINGS)).items():
        solutions["les_" + name] = solution
    inst_les = institutions_model(income_elasticities=LES_SETTINGS["income_elasticities"], frisch=[-2.0, -3.0])
    solutions["inst_les_tariff_removal"] = inst_les.solve(
        Closure(), tol=1e-12, **simulation_inputs(inst_les)["tariff_removal"])
    # Spending and transfer shocks (version 0.1.10): government purchases of
    # com_ser up 20 per cent; transfers from abroad to households and the
    # enterprise halved
    std = synthetic_model()
    solutions["gov_ser_up20"] = std.solve(
        Closure(), tol=1e-12, params={"qg": _scaled(std.params["qg"], std.sets["C"].index("com_ser"), 1.2)})
    inst = institutions_model()
    solutions["inst_transfers_abroad_down50"] = inst.solve(
        Closure(), tol=1e-12, params={"trdr": inst.params["trdr"] * 0.5})
    for name, solution in run_simulations(margins_model()).items():
        solutions["margins_" + name] = solution
    for name, solution in run_simulations(territorial_model()).items():
        solutions["tc_" + name] = solution
    for name, solution in run_simulations(multiproduct_model()).items():
        solutions["mp_" + name] = solution
    for name, solution in run_simulations(nonimported_model()).items():
        solutions["cnm_" + name] = solution
    for name, solution in run_simulations(sut_model()).items():
        solutions["sut_" + name] = solution
    # Health insurance fund (version 0.1.13): the standard shocks, a higher
    # contribution rate on labour income and larger government transfers to the fund
    health = health_model()
    for name, solution in run_simulations(health).items():
        solutions["shi_" + name] = solution
    lab = health.sets["F"].index("lab")
    solutions["shi_contribution_up50"] = health.solve(
        Closure(), tol=1e-12, params={"tshi": _scaled(health.params["tshi"], lab, 1.5)})
    solutions["shi_gov_transfer_up50"] = health.solve(
        Closure(), tol=1e-12, params={"trshi": health.params["trshi"] * 1.5})
    # Labour efficiency linked to health services (version 0.1.14): the standard
    # shocks, more government health services, a higher contribution rate and an
    # exogenous fall in labour efficiency
    eff = health_model(**HEALTH_LINK)
    for name, solution in run_simulations(eff).items():
        solutions["eff_" + name] = solution
    hlt = eff.sets["C"].index("com_hlt")
    lab = eff.sets["F"].index("lab")
    solutions["eff_gov_health_up20"] = eff.solve(
        Closure(), tol=1e-12, params={"qg": _scaled(eff.params["qg"], hlt, 1.2)})
    solutions["eff_contribution_up50"] = eff.solve(
        Closure(), tol=1e-12, params={"tshi": _scaled(eff.params["tshi"], lab, 1.5)})
    solutions["eff_labour_efficiency_down2"] = eff.solve(
        Closure(), tol=1e-12, params={"af": _scaled(eff.params["af"], lab, 0.98)})
    written = []
    for name, solution in solutions.items():
        if not solution.converged:
            raise RuntimeError(f"simulation {name} did not converge")
        path = directory / f"{name}.csv"
        write_results(solution, path)
        written.append(path)
        if name in REPORTED:
            path = directory / f"report_{name}.csv"
            write_report(solution, path)
            written.append(path)
    return written


if __name__ == "__main__":
    for path in write_expected():
        print(f"Wrote {path}")
    sys.exit(0)
