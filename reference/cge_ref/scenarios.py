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


def write_expected(directory: Path = EXPECTED_DIR) -> list[Path]:
    """Solve the standard simulations and write one CSV file per simulation."""
    directory.mkdir(parents=True, exist_ok=True)
    solutions = run_simulations(synthetic_model())
    mixed = synthetic_model(**MIXED_ELASTICITIES)
    solutions["mixed_tariff_removal"] = mixed.solve(
        Closure(), tol=1e-12, **simulation_inputs(mixed)["tariff_removal"])
    for name, solution in run_simulations(institutions_model()).items():
        solutions["inst_" + name] = solution
    for name, solution in run_simulations(margins_model()).items():
        solutions["margins_" + name] = solution
    written = []
    for name, solution in solutions.items():
        if not solution.converged:
            raise RuntimeError(f"simulation {name} did not converge")
        path = directory / f"{name}.csv"
        write_results(solution, path)
        written.append(path)
    return written


if __name__ == "__main__":
    for path in write_expected():
        print(f"Wrote {path}")
    sys.exit(0)
