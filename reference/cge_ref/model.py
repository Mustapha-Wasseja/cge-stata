"""Python reference implementation of the cge-stata version 0.1 model.

Equation labels (P1, Q3, T2, ...) and calibration steps follow
docs/model_spec.md. The Stata/Mata implementation must reproduce the results
of this module.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterator

import numpy as np

from .sam import SAM, Mapping, SAMError, prepare
from .solver import solve_system

# Index sets of each variable. A activities, C commodities, F factors,
# H households, I institutions receiving factor income (households, then the
# government, then the rest of the world). An empty string marks a scalar.
VARIABLES: dict[str, str] = {
    "PA": "A", "PVA": "A", "PINTA": "A", "PX": "C", "PD": "C", "PE": "C", "PM": "C",
    "PQ": "C", "W": "F", "EXR": "", "CPI": "", "DPI": "",
    "QA": "A", "QVA": "A", "QINTA": "A", "QF": "FA", "QINT": "CA", "QX": "C", "QD": "C",
    "QE": "C", "QM": "C", "QQ": "C", "QH": "CH", "QG": "C", "QINV": "C", "QFS": "F",
    "YF": "F", "YIF": "IF", "YI": "D", "EH": "H", "YG": "", "EG": "", "GSAV": "",
    "FSAV": "", "TINS": "D", "MPS": "D", "TINSADJ": "", "MPSADJ": "", "IADJ": "",
    "GADJ": "", "WFDIST": "FA", "WALRAS": "",
}

# Variables measured in local currency: they scale with the numeraire.
NOMINAL = ("PA", "PVA", "PINTA", "PX", "PD", "PE", "PM", "PQ", "W", "EXR", "CPI", "DPI",
           "YF", "YIF", "YI", "EH", "YG", "EG", "GSAV", "WALRAS")

CLOSURE_OPTIONS = {
    "external": ("flexexr", "fixexr"),
    "government": ("flexgsav", "fixgsav"),
    "savinv": ("savings", "investment"),
    "numeraire": ("cpi", "dpi"),
}
FACTOR_OPTIONS = ("mobile", "specific", "unemployed")


@dataclass
class Closure:
    """Model closure (docs/model_spec.md, Section 6). Defaults are listed first."""

    external: str = "flexexr"
    government: str = "flexgsav"
    savinv: str = "savings"
    numeraire: str = "cpi"
    factors: dict[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        for name, options in CLOSURE_OPTIONS.items():
            if getattr(self, name) not in options:
                raise ValueError(f"{name} closure must be one of {options}")
        for factor, option in self.factors.items():
            if option not in FACTOR_OPTIONS:
                raise ValueError(f"factor closure for {factor} must be one of {FACTOR_OPTIONS}")

    def fixed(self, model: "Model") -> dict[str, np.ndarray]:
        """Boolean arrays marking the variables held fixed under this closure."""
        fixed = {name: np.zeros(value.shape, dtype=bool) for name, value in model.base.items()}
        fixed["GADJ"][:] = True
        fixed["FSAV" if self.external == "flexexr" else "EXR"][:] = True
        fixed["TINSADJ" if self.government == "flexgsav" else "GSAV"][:] = True
        fixed["MPSADJ" if self.savinv == "savings" else "IADJ"][:] = True
        fixed["CPI" if self.numeraire == "cpi" else "DPI"][:] = True

        unknown = set(self.factors) - set(model.sets["F"])
        if unknown:
            raise ValueError(f"unknown factors in closure: {sorted(unknown)}")
        for k, factor in enumerate(model.sets["F"]):
            option = self.factors.get(factor, "mobile")
            if option == "mobile":
                fixed["QFS"][k] = True
                fixed["WFDIST"][k, :] = True
            elif option == "specific":
                fixed["W"][k] = True
                fixed["QF"][k, :] = True
            else:
                fixed["W"][k] = True
                fixed["WFDIST"][k, :] = True
        return fixed


def _per_element(value, labels: list[str], name: str) -> np.ndarray:
    if isinstance(value, dict):
        missing = [label for label in labels if label not in value]
        extra = [key for key in value if key not in labels]
        if missing or extra:
            raise ValueError(f"{name}: missing {missing}, unknown {extra}")
        array = np.array([float(value[label]) for label in labels])
    else:
        array = np.asarray(value, dtype=float)
        if array.ndim == 0:
            array = np.full(len(labels), float(array))
        elif array.shape != (len(labels),):
            raise ValueError(f"{name} needs {len(labels)} values")
    if not np.all(np.isfinite(array)) or np.any(array <= 0):
        raise ValueError(f"{name} must be positive and finite")
    return array


def _equations(v: dict, p: dict, s: dict) -> dict[str, tuple[np.ndarray, np.ndarray, np.ndarray]]:
    """Left side, right side and existence mask of every equation block."""
    ce, cm, fa, cd = s["ce"], s["cm"], s["fa"], s["cd"]
    every_c = np.ones_like(ce)
    every_a = np.ones_like(cd)
    nH = v["EH"].size
    nD = v["YI"].size
    one = np.ones(1, dtype=bool)

    eq: dict[str, tuple[np.ndarray, np.ndarray, np.ndarray]] = {}
    # 5.1 Price block
    eq["P1"] = (v["PM"], p["pwm"] * (1 + p["tm"]) * v["EXR"], cm)
    eq["P2"] = (v["PE"], p["pwe"] * (1 - p["te"]) * v["EXR"], ce)
    eq["P3"] = (v["PQ"] * (1 - p["tq"]) * v["QQ"],
                v["PD"] * v["QD"] + np.where(cm, v["PM"] * v["QM"], 0.0), every_c)
    eq["P4"] = (v["PX"] * v["QX"], v["PD"] * v["QD"] + np.where(ce, v["PE"] * v["QE"], 0.0), every_c)
    eq["P5"] = (v["PA"], p["theta"] @ v["PX"], every_a)
    eq["P6"] = (v["PINTA"], p["ica"].T @ v["PQ"], every_a)
    eq["P7"] = (v["PA"] * (1 - p["ta"]) * v["QA"], v["PVA"] * v["QVA"] + v["PINTA"] * v["QINTA"], every_a)
    eq["P8"] = (v["CPI"], np.atleast_1d(p["cwts"] @ v["PQ"]), one)
    eq["P9"] = (v["DPI"], np.atleast_1d(p["dwts"] @ v["PD"]), one)

    # 5.2 Production block
    eq["Q1"] = (v["QVA"], p["iva"] * v["QA"], every_a)
    eq["Q2"] = (v["QINTA"], p["inta"] * v["QA"], every_a)
    qf = np.where(fa, v["QF"], 1.0)
    rho = np.where(cd, 1.0, p["rho_va"])
    ces_sum = (p["delta_va"] * qf ** (-rho)).sum(axis=0)
    q3_ces = p["ad"] * ces_sum ** (-1.0 / rho)
    q3_cd = p["ad"] * np.prod(qf ** p["delta_va"], axis=0)
    eq["Q3"] = (v["QVA"], np.where(cd, q3_cd, q3_ces), every_a)
    wage = v["W"][:, None] * v["WFDIST"]
    pvaqva = v["PVA"] * v["QVA"]
    q4_ces = pvaqva / ces_sum * p["delta_va"] * qf ** (-rho - 1)
    eq["Q4"] = (np.where(cd, wage * v["QF"], wage),
                np.where(cd, p["delta_va"] * pvaqva, q4_ces), fa)
    eq["Q5"] = (v["QINT"], p["ica"] * v["QINTA"][None, :], np.ones(p["ica"].shape, dtype=bool))
    eq["Q6"] = (v["QX"], p["theta"].T @ v["QA"], every_c)

    # 5.3 Trade block
    rt, dt = p["rho_t"], p["delta_t"]
    eq["T1"] = (v["QX"], p["at"] * (dt * v["QE"] ** rt + (1 - dt) * v["QD"] ** rt) ** (1 / rt), ce)
    eq["T2"] = (v["QE"], v["QD"] * ((v["PE"] / v["PD"]) * (1 - dt) / dt) ** (1 / (rt - 1)), ce)
    eq["T3"] = (v["QX"], v["QD"], ~ce)
    rq, dq = p["rho_q"], p["delta_q"]
    eq["T4"] = (v["QQ"], p["aq"] * (dq * v["QM"] ** (-rq) + (1 - dq) * v["QD"] ** (-rq)) ** (-1 / rq), cm)
    eq["T5"] = (v["QM"], v["QD"] * ((v["PD"] / v["PM"]) * dq / (1 - dq)) ** (1 / (1 + rq)), cm)
    eq["T6"] = (v["QQ"], p["aq"] * v["QD"], ~cm)

    # 5.4 Institution block. DY is income after direct taxes and savings.
    DY = (1 - v["MPS"]) * (1 - v["TINS"]) * v["YI"]
    eq["I1"] = (v["YF"], (wage * v["QF"]).sum(axis=1) + p["trfr"] * v["EXR"],
                np.ones(v["YF"].shape, dtype=bool))
    eq["I2"] = (v["YIF"], p["shif"] * v["YF"][None, :], np.ones(v["YIF"].shape, dtype=bool))
    eq["I3"] = (v["YI"], v["YIF"][:nD].sum(axis=1) + p["shii"] @ DY + p["trdg"] * v["CPI"]
                + p["trdr"] * v["EXR"], np.ones(nD, dtype=bool))
    eq["I4"] = (v["EH"], p["hc"] * DY[:nH], np.ones(nH, dtype=bool))
    eq["I5"] = (v["PQ"][:, None] * v["QH"], p["beta"] * v["EH"][None, :], np.ones(v["QH"].shape, dtype=bool))
    eq["I6"] = (v["QINV"], p["qinv"] * v["IADJ"], every_c)
    eq["I7"] = (v["QG"], p["qg"] * v["GADJ"], every_c)
    revenue = (v["TINS"] @ v["YI"] + (p["tq"] * v["PQ"] * v["QQ"]).sum()
               + (p["tm"] * p["pwm"] * v["QM"]).sum() * v["EXR"]
               + (p["te"] * p["pwe"] * v["QE"]).sum() * v["EXR"]
               + (p["ta"] * v["PA"] * v["QA"]).sum()
               + v["YIF"][nD].sum() + p["trgr"] * v["EXR"] + p["trgg"] * v["CPI"])
    eq["I8"] = (v["YG"], revenue, one)
    eq["I9"] = (v["EG"], np.atleast_1d(v["PQ"] @ v["QG"]) + (p["trdg"].sum() + p["trgg"]) * v["CPI"]
                + p["trrg"] * v["EXR"], one)
    eq["I10"] = (v["TINS"], p["tins0"] * v["TINSADJ"], np.ones(nD, dtype=bool))
    eq["I11"] = (v["MPS"], p["mps0"] * v["MPSADJ"], np.ones(nD, dtype=bool))

    # 5.5 System constraints (S6 is imposed through the closure)
    eq["S1"] = (np.where(fa, v["QF"], 0.0).sum(axis=1), v["QFS"], np.ones(v["QFS"].shape, dtype=bool))
    eq["S2"] = (v["QQ"], v["QINT"].sum(axis=1) + v["QH"].sum(axis=1) + v["QG"] + v["QINV"], every_c)
    eq["S3"] = ((p["pwm"] * v["QM"]).sum() + (v["YIF"][nD + 1].sum() + p["shir"] @ DY) / v["EXR"]
                + p["trrg"],
                (p["pwe"] * v["QE"]).sum() + p["trdr"].sum() + p["trfr"].sum() + p["trgr"] + v["FSAV"], one)
    eq["S4"] = (v["YG"], v["EG"] + v["GSAV"], one)
    eq["S5"] = ((v["MPS"] * (1 - v["TINS"])) @ v["YI"] + v["GSAV"] + v["EXR"] * v["FSAV"],
                np.atleast_1d(v["PQ"] @ v["QINV"]) + v["WALRAS"], one)
    return eq


@dataclass
class Solution:
    model: "Model"
    values: dict[str, np.ndarray]
    params: dict[str, np.ndarray]
    closure: Closure
    converged: bool
    iterations: int
    max_residual: float
    method: str

    def __getitem__(self, name: str) -> np.ndarray:
        return self.values[name]

    def rows(self) -> Iterator[tuple[str, str, str, float, float]]:
        """(variable, element 1, element 2, base, value) for every existing element."""
        for name in VARIABLES:
            labels = self.model.element_labels(name)
            exists = self.model.exists[name].ravel()
            base = self.model.base[name].ravel()
            value = self.values[name].ravel()
            for k, (e1, e2) in enumerate(labels):
                if exists[k]:
                    yield name, e1, e2, float(base[k]), float(value[k])

    def gdp_gap(self) -> float:
        """Expenditure-side GDP minus income-side GDP; zero at any solution."""
        v, p = self.values, self.params
        exr = v["EXR"][0]
        expenditure = (v["PQ"] @ (v["QH"].sum(axis=1) + v["QG"] + v["QINV"])
                       + exr * (p["pwe"] @ v["QE"]) - exr * (p["pwm"] @ v["QM"]))
        income = (v["PVA"] @ v["QVA"] + (p["tq"] * v["PQ"] * v["QQ"]).sum()
                  + exr * (p["tm"] * p["pwm"] * v["QM"]).sum()
                  + exr * (p["te"] * p["pwe"] * v["QE"]).sum() + (p["ta"] * v["PA"] * v["QA"]).sum())
        return float(expenditure - income)

    def equivalent_variation(self) -> np.ndarray:
        """Household equivalent variation at base prices (Cobb-Douglas demand)."""
        base, p = self.model.base, self.params
        ratio = np.prod((base["PQ"][:, None] / self.values["PQ"][:, None]) ** p["beta"], axis=0)
        return self.values["EH"] * ratio - base["EH"]


class Model:
    """Calibrated version 0.1 model."""

    def __init__(self, sam: SAM, mapping: Mapping, sigma_va, sigma_q, sigma_t,
                 factor_quantities: dict[tuple[str, str], float] | None = None):
        sam, mapping, self.rewritten = prepare(sam, mapping)
        self.sam = sam
        self.mapping = mapping
        mapping.validate(sam)
        A, C, F, H = mapping.activities, mapping.commodities, mapping.factors, mapping.households
        E = mapping.enterprises
        self.sets = {"A": list(A), "C": list(C), "F": list(F), "H": list(H), "E": list(E),
                     "D": list(H) + list(E),
                     "I": list(H) + list(E) + [mapping.government, mapping.row]}
        self._calibrate(sam, mapping,
                        _per_element(sigma_va, A, "sigma_va"),
                        _per_element(sigma_q, C, "sigma_q"),
                        _per_element(sigma_t, C, "sigma_t"),
                        factor_quantities)
        self.var_scale = {k: np.where(np.abs(b) > 1e-12, np.abs(b), 1.0) for k, b in self.base.items()}
        with np.errstate(all="ignore"):      # masked elements may divide by zero
            eqs = _equations(self.base, self.params, self.struct)
        self.eq_masks = {k: np.broadcast_to(mask, np.shape(lhs)).copy() for k, (lhs, _, mask) in eqs.items()}
        self.eq_scale = {}
        for k, (lhs, rhs, _) in eqs.items():
            magnitude = np.maximum(np.abs(np.broadcast_to(lhs, np.shape(lhs))), np.abs(rhs))
            self.eq_scale[k] = np.where(magnitude > 1e-9, magnitude, 1.0)
        self.n_equations = int(sum(mask.sum() for mask in self.eq_masks.values()))

    # ------------------------------------------------------------------
    # Calibration (docs/model_spec.md, Section 7)
    # ------------------------------------------------------------------
    def _calibrate(self, sam, mapping, sigma_va, sigma_q, sigma_t, factor_quantities):
        A, C, F, H = self.sets["A"], self.sets["C"], self.sets["F"], self.sets["H"]
        I = self.sets["I"]
        gov, sav, row = mapping.government, mapping.savinv, mapping.row
        n, nF, nH = len(A), len(F), len(H)
        tol = 1e-9 * max(1.0, float(np.abs(sam.values).max()))

        def cell(r, c):
            return 0.0 if r is None or c is None else sam.cell(r, c)

        def vec(rows, cols):
            return np.array([[cell(r, c) for c in cols] for r in rows])

        # 7.1 Taxes and trade
        QM0 = vec([row], C)[0]
        cm = QM0 > tol
        tariffs = vec([mapping.imptax], C)[0]
        if np.any(~cm & (np.abs(tariffs) > tol)):
            raise SAMError("import tariff recorded on a commodity without imports")
        tm = np.where(cm, tariffs / np.where(cm, QM0, 1.0), 0.0)
        exports = vec(C, [row])[:, 0]
        ce = exports > tol
        export_taxes = vec([mapping.exptax], C)[0]
        if np.any(~ce & (np.abs(export_taxes) > tol)):
            raise SAMError("export tax recorded on a commodity without exports")
        te = np.where(ce, export_taxes / np.where(ce, exports, 1.0), 0.0)
        QE0 = np.where(ce, exports - export_taxes, 0.0)
        pwe = 1.0 / (1.0 - te)

        QA0 = np.array([sam.col_total(a) for a in A])
        if np.any(QA0 <= tol):
            raise SAMError("every activity needs positive output")
        ta = vec([mapping.acttax], A)[0] / QA0
        MAKE0 = vec(A, C)                      # MAKE0[a, c]: output of c by activity a
        if np.abs(MAKE0.sum(axis=1) - QA0).max() > tol:
            raise SAMError("activity output does not equal its sales to commodities")
        theta = MAKE0 / QA0[:, None]
        QX0 = MAKE0.sum(axis=0)
        QD0 = QX0 - QE0
        if np.any(QD0 <= tol):
            raise SAMError("version 0.1 needs positive domestic sales of every commodity")
        PM0 = np.where(cm, 1.0 + tm, 0.0)
        sales_taxes = vec([mapping.saltax], C)[0]
        QQ0 = QD0 + PM0 * QM0 + sales_taxes
        tq = sales_taxes / QQ0
        demand = (vec(C, A).sum(axis=1) + vec(C, H).sum(axis=1)
                  + vec(C, [gov])[:, 0] + vec(C, [sav])[:, 0])
        if np.abs(QQ0 - demand).max() > tol:
            raise SAMError("composite supply does not equal domestic demand for some commodity")

        # 7.2 Production
        QINT0 = vec(C, A)
        QINTA0 = QINT0.sum(axis=0)
        ica = QINT0 / np.where(QINTA0 > 0, QINTA0, 1.0)
        VA = vec(F, A)
        fa = VA > tol
        if factor_quantities is None:
            W0 = np.ones(nF)
            WFDIST0 = np.ones((nF, n))
            QF0 = np.where(fa, VA, 0.0)
        else:
            QFq = np.array([[float(factor_quantities.get((f, a), 0.0)) for a in A] for f in F])
            if np.any((QFq > 0) != fa):
                raise SAMError("factor quantities must be positive exactly where factor payments are")
            W0 = VA.sum(axis=1) / QFq.sum(axis=1)
            WFDIST0 = np.where(fa, VA / (W0[:, None] * np.where(fa, QFq, 1.0)), 1.0)
            QF0 = QFq
        QVA0 = VA.sum(axis=0)
        if np.any(QVA0 <= tol):
            raise SAMError("every activity needs positive value added")
        iva = QVA0 / QA0
        inta = QINTA0 / QA0

        cd = np.abs(sigma_va - 1.0) < 1e-12
        rho_va = np.where(cd, 0.0, 1.0 / sigma_va - 1.0)
        delta_va = np.zeros((nF, n))
        ad = np.zeros(n)
        w = W0[:, None] * WFDIST0
        for k in range(n):
            m = fa[:, k]
            if cd[k]:
                d = VA[m, k] / QVA0[k]
                delta_va[m, k] = d
                ad[k] = QVA0[k] / np.prod(QF0[m, k] ** d)
            else:
                r = rho_va[k]
                num = w[m, k] * QF0[m, k] ** (1 + r)
                d = num / num.sum()
                delta_va[m, k] = d
                ad[k] = QVA0[k] / (d * QF0[m, k] ** (-r)).sum() ** (-1 / r)

        # 7.3 CET and Armington functions (base prices PD = PE = 1)
        rho_t = 1.0 / sigma_t + 1.0
        delta_t = np.full(n, 0.5)
        at = np.ones(n)
        for k in np.flatnonzero(ce):
            r = rho_t[k]
            delta_t[k] = 1.0 / (1.0 + (QE0[k] / QD0[k]) ** (r - 1))
            at[k] = QX0[k] / (delta_t[k] * QE0[k] ** r + (1 - delta_t[k]) * QD0[k] ** r) ** (1 / r)
        if np.any(np.abs(sigma_q[cm] - 1.0) < 1e-12):
            raise ValueError("version 0.1 needs sigma_q different from 1 for imported commodities")
        rho_q = 1.0 / sigma_q - 1.0
        delta_q = np.full(n, 0.5)
        aq = QQ0 / QD0                     # non-imported commodities (T6)
        for k in np.flatnonzero(cm):
            r = rho_q[k]
            ratio = PM0[k] * (QM0[k] / QD0[k]) ** (1 + r)
            delta_q[k] = ratio / (1 + ratio)
            aq[k] = QQ0[k] / (delta_q[k] * QM0[k] ** (-r) + (1 - delta_q[k]) * QD0[k] ** (-r)) ** (-1 / r)

        # 7.5 Institutions
        D = self.sets["D"]
        YF0 = np.array([sam.row_total(f) for f in F])
        YIF0 = vec(I, F)
        if np.abs(YIF0.sum(axis=0) - YF0).max() > tol:
            raise SAMError("factor income paid out does not equal factor income received")
        shif = YIF0 / YF0[None, :]
        trfr = vec(F, [row])[:, 0]
        YI0 = np.array([sam.row_total(d) for d in D])
        dtax = vec([mapping.dirtax], D)[0]
        dsav = vec([sav], D)[0]
        tins0 = dtax / YI0
        mps0 = dsav / ((1 - tins0) * YI0)
        DY0 = YI0 - dtax - dsav
        TR = vec(D, D)                       # TR[d, d'] = transfer from d' to d
        TROW = vec([row], D)[0]
        QH0 = vec(C, H)
        EH0 = QH0.sum(axis=0)
        uses = TR.sum(axis=0) + TROW + np.concatenate([EH0, np.zeros(len(D) - nH)])
        gross = (np.abs(TR).sum(axis=0) + np.abs(TROW)
                 + np.concatenate([np.abs(EH0), np.zeros(len(D) - nH)]))
        if np.any((np.abs(DY0) <= tol) & (gross > tol)):
            raise SAMError("an institution makes transfers or consumes but has no income "
                           "after direct taxes and savings")
        if np.abs(uses - DY0).max() > tol:
            raise SAMError("institution payments do not equal income")
        safe = np.where(np.abs(DY0) > tol, DY0, 1.0)
        shii = TR / safe[None, :]
        shir = TROW / safe
        hc = EH0 / safe[:nH]
        if EH0.sum() <= tol:
            raise SAMError("households have no consumption")
        beta = QH0 / np.where(EH0 > 0, EH0, 1.0)[None, :]
        trdg = vec(D, [gov])[:, 0]
        trdr = vec(D, [row])[:, 0]
        trgr, trrg, trgg = cell(gov, row), cell(row, gov), cell(gov, gov)
        qg = vec(C, [gov])[:, 0]
        qinv = vec(C, [sav])[:, 0]
        cwts = QH0.sum(axis=1) / QH0.sum()
        dwts = QD0 / QD0.sum()

        self.struct = {"ce": ce, "cm": cm, "fa": fa, "cd": cd}
        self.params = {
            "pwm": np.ones(n), "pwe": pwe, "tm": tm, "te": te, "tq": tq, "ta": ta,
            "theta": theta, "iva": iva, "inta": inta, "ica": ica, "ad": ad, "delta_va": delta_va, "rho_va": rho_va,
            "at": at, "delta_t": delta_t, "rho_t": rho_t, "aq": aq, "delta_q": delta_q, "rho_q": rho_q,
            "shif": shif, "beta": beta, "tins0": tins0, "mps0": mps0,
            "shii": shii, "shir": shir, "hc": hc, "trdg": trdg, "trdr": trdr, "trfr": trfr,
            "trgr": np.array(trgr), "trrg": np.array(trrg), "trgg": np.array(trgg),
            "qg": qg, "qinv": qinv, "cwts": cwts, "dwts": dwts,
            "sigma_va": sigma_va, "sigma_q": sigma_q, "sigma_t": sigma_t,
        }
        s1 = np.ones(1)
        self.base = {
            "PA": np.ones(n), "PVA": np.ones(n), "PINTA": ica.sum(axis=0), "PX": np.ones(n),
            "PD": np.ones(n), "PE": np.where(ce, 1.0, 0.0), "PM": PM0, "PQ": np.ones(n),
            "W": W0, "EXR": s1.copy(), "CPI": np.atleast_1d(cwts.sum()), "DPI": np.atleast_1d(dwts.sum()),
            "QA": QA0, "QVA": QVA0, "QINTA": QINTA0, "QF": QF0, "QINT": QINT0, "QX": QX0,
            "QD": QD0, "QE": QE0, "QM": np.where(cm, QM0, 0.0), "QQ": QQ0, "QH": QH0,
            "QG": qg.copy(), "QINV": qinv.copy(), "QFS": QF0.sum(axis=1),
            "YF": YF0, "YIF": YIF0, "YI": YI0, "EH": EH0,
            "YG": np.atleast_1d(sam.row_total(gov)),
            "EG": np.atleast_1d(qg.sum() + trdg.sum() + trgg + trrg),
            "GSAV": np.atleast_1d(cell(sav, gov)), "FSAV": np.atleast_1d(cell(sav, row)),
            "TINS": tins0.copy(), "MPS": mps0.copy(),
            "TINSADJ": s1.copy(), "MPSADJ": s1.copy(), "IADJ": s1.copy(), "GADJ": s1.copy(),
            "WFDIST": WFDIST0, "WALRAS": np.zeros(1),
        }
        self.exists = {name: np.ones(value.shape, dtype=bool) for name, value in self.base.items()}
        self.exists["PE"] = ce.copy()
        self.exists["QE"] = ce.copy()
        self.exists["PM"] = cm.copy()
        self.exists["QM"] = cm.copy()
        self.exists["QF"] = fa.copy()
        self.exists["WFDIST"] = fa.copy()

    # ------------------------------------------------------------------
    # Residuals and solution
    # ------------------------------------------------------------------
    def residuals(self, values: dict, params: dict | None = None) -> dict[str, np.ndarray]:
        """Scaled residuals of every equation block, existing elements only."""
        out = {}
        with np.errstate(all="ignore"):      # masked elements may divide by zero
            eqs = _equations(values, self.params if params is None else params, self.struct)
            for k, (lhs, rhs, _) in eqs.items():
                out[k] = ((lhs - rhs) / self.eq_scale[k])[self.eq_masks[k]]
        return out

    def max_residual(self, values: dict, params: dict | None = None) -> float:
        res = self.residuals(values, params)
        return float(max(np.max(np.abs(r)) if r.size else 0.0 for r in res.values()))

    def element_labels(self, name: str) -> list[tuple[str, str]]:
        index = VARIABLES[name]
        if index == "":
            return [("", "")]
        if len(index) == 1:
            return [(label, "") for label in self.sets[index]]
        return [(a, b) for a in self.sets[index[0]] for b in self.sets[index[1]]]

    def solve(self, closure: Closure | None = None, params: dict | None = None,
              fixed: dict | None = None, start: dict | None = None,
              tol: float = 1e-10, max_iter: int = 100) -> Solution:
        """Solve the model under a closure, with changed parameters or fixed variables."""
        closure = closure or Closure()
        p = {k: np.array(v, dtype=float, copy=True) for k, v in self.params.items()}
        for name, value in (params or {}).items():
            if name not in p:
                raise KeyError(f"unknown parameter {name}")
            p[name] = np.broadcast_to(np.asarray(value, dtype=float), p[name].shape).copy()

        is_fixed = closure.fixed(self)
        free = {k: self.exists[k] & ~is_fixed[k] for k in VARIABLES}

        # Free variables start from `start` (default: the base); fixed and
        # non-existent elements are held at their base values unless set in `fixed`.
        start = start or self.base
        values = {k: np.where(free[k], np.asarray(start[k], dtype=float), self.base[k]) for k in VARIABLES}
        for name, value in (fixed or {}).items():
            new = np.broadcast_to(np.asarray(value, dtype=float), values[name].shape)
            changed = (new != self.base[name]) & self.exists[name]
            if np.any(changed & ~is_fixed[name]):
                raise ValueError(f"{name} is not fixed under this closure, so it cannot be set")
            values[name] = np.where(is_fixed[name] & self.exists[name], new, values[name])

        n_free = int(sum(mask.sum() for mask in free.values()))
        if n_free != self.n_equations:
            raise ValueError(f"closure is not square: {n_free} free variables, {self.n_equations} equations")

        z0 = np.concatenate([values[k][free[k]] / self.var_scale[k][free[k]] for k in VARIABLES])

        def unpack(z: np.ndarray) -> dict:
            out = {k: v.copy() for k, v in values.items()}
            pos = 0
            for k in VARIABLES:
                count = int(free[k].sum())
                out[k][free[k]] = z[pos:pos + count] * self.var_scale[k][free[k]]
                pos += count
            return out

        def F(z: np.ndarray) -> np.ndarray:
            res = self.residuals(unpack(z), p)
            return np.concatenate(list(res.values()))

        result = solve_system(F, z0, tol=tol, max_iter=max_iter)
        return Solution(self, unpack(result.z), p, closure, result.converged,
                        result.iterations, result.max_residual, result.method)
