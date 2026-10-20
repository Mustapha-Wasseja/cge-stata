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
    "GADJ": "", "WFDIST": "FA", "WALRAS": "", "QT": "C", "QER": "C",
    "YSHI": "", "SHIADJ": "", "QSHI": "C", "EFF": "F", "HS": "",
    "TQADJ": "", "TMADJ": "", "TVADJ": "",
    "PWE": "C", "QHA": "AH",
    "LSW": "F", "LSM": "F",
    "DW": "F",
}

# Tax scaling factors freed by each government closure (version 0.3.1)
INSTRUMENTS = {"direct": ("TINSADJ", "tins0"), "sales": ("TQADJ", "tq"), "import": ("TMADJ", "tm"),
               "vat": ("TVADJ", "tv")}

# Variables measured in local currency: they scale with the numeraire.
NOMINAL = ("PA", "PVA", "PINTA", "PX", "PD", "PE", "PM", "PQ", "W", "EXR", "CPI", "DPI",
           "YF", "YIF", "YI", "EH", "YG", "EG", "GSAV", "WALRAS", "YSHI")

CLOSURE_OPTIONS = {
    "external": ("flexexr", "fixexr"),
    # fixgsav with the instrument that adjusts (version 0.3.1); fixgsav alone
    # means direct taxes, as before
    "government": ("flexgsav", "fixgsav", "fixgsav direct", "fixgsav sales", "fixgsav import",
                   "fixgsav vat"),
    "savinv": ("savings", "investment"),
    "numeraire": ("cpi", "dpi"),
}
FACTOR_OPTIONS = ("mobile", "specific", "unemployed", "wagecurve", "minwage")


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

    @property
    def instrument(self) -> str | None:
        """Tax that adjusts under fixed government savings (None under flexgsav)."""
        if self.government == "flexgsav":
            return None
        parts = self.government.split()
        return parts[1] if len(parts) > 1 else "direct"

    def fixed(self, model: "Model") -> dict[str, np.ndarray]:
        """Boolean arrays marking the variables held fixed under this closure."""
        fixed = {name: np.zeros(value.shape, dtype=bool) for name, value in model.base.items()}
        fixed["GADJ"][:] = True
        fixed["FSAV" if self.external == "flexexr" else "EXR"][:] = True
        for adj, _ in INSTRUMENTS.values():
            fixed[adj][:] = True
        if self.government != "flexgsav":
            fixed["GSAV"][:] = True
            adj, rate = INSTRUMENTS[self.instrument]
            if not np.any(model.params[rate] != 0):
                raise ValueError(f"government closure: the {self.instrument} tax raises no revenue in the base")
            fixed[adj][:] = False
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
            elif option == "unemployed":
                fixed["W"][k] = True
                fixed["WFDIST"][k, :] = True
            else:
                # Labour-market regimes (model_spec.md, Section 14)
                pp = model.params
                if not pp["inlf"][k]:
                    raise ValueError(f"{factor}: {option} needs a labour force: give its unemployment rate")
                if option == "wagecurve" and not pp["epsw"][k] > 0:
                    raise ValueError(f"{factor}: the wage curve needs an elasticity")
                if option == "minwage" and not pp["hasmin"][k]:
                    raise ValueError(f"{factor}: give a minimum wage")
                fixed["WFDIST"][k, :] = True
                fixed["LSW" if option == "wagecurve" else "LSM"][k] = True
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


def _credit_shares(value, labels: list[str]) -> np.ndarray:
    """VAT credit share of each activity (default 1, full credit)."""
    if value is None:
        return np.ones(len(labels))
    if isinstance(value, dict):
        unknown = [a for a in value if a not in labels]
        if unknown:
            raise ValueError(f"vat_credit: {unknown} are not activities")
        out = np.array([float(value.get(a, 1.0)) for a in labels])
    else:
        out = np.full(len(labels), float(value))
    if np.any(out < 0) or np.any(out > 1):
        raise ValueError("VAT credit shares must lie between 0 and 1")
    return out


def _vat_rate(vat: float, values: np.ndarray, liab: np.ndarray, label: str) -> float:
    """tv such that sum(values * tv * liab / (1 + tv * liab)) = vat (model_spec.md,
    12.2), by Newton's method from the first-order value."""
    base = float(values @ liab)
    if base == 0:
        raise SAMError(f"VAT is recorded on {label} but no use of it bears VAT")
    tv = vat / base
    for _ in range(100):
        f = float(values @ (tv * liab / (1 + tv * liab))) - vat
        df = float(values @ (liab / (1 + tv * liab) ** 2))
        step = f / df
        tv -= step
        if abs(step) <= 1e-15 * max(1.0, abs(tv)):
            break
    else:
        raise SAMError(f"the VAT rate of {label} could not be calibrated")
    if np.any(1 + tv * liab <= 0):
        raise SAMError(f"the VAT rate of {label} is below -100 per cent")
    return tv


def _equations(v: dict, p: dict, s: dict) -> dict[str, tuple[np.ndarray, np.ndarray, np.ndarray]]:
    """Left side, right side and existence mask of every equation block."""
    ce, cm, fa, cd, cx, ct, cr = s["ce"], s["cm"], s["fa"], s["cd"], s["cx"], s["ct"], s["cr"]
    # Version 0.3.2: export-only commodities (cxe), domestic sales (cdo),
    # composite supply (cq) and finite export demand (ced)
    cxe, ced = s["cxe"], s["ced"]
    cdo = cx & ~cxe
    cq = cdo | cm
    every_c = np.ones_like(ce)
    every_a = np.ones_like(cd)
    nH = v["EH"].size
    nD = v["YI"].size
    one = np.ones(1, dtype=bool)

    eq: dict[str, tuple[np.ndarray, np.ndarray, np.ndarray]] = {}
    # Rates after scaling (version 0.3.1); PH is the price paid by final users,
    # including VAT, and vint the VAT that activities cannot recover
    tq, tm, tv = p["tq"] * v["TQADJ"], p["tm"] * v["TMADJ"], p["tv"] * v["TVADJ"]
    ph = v["PQ"] * (1 + tv)
    vint = np.outer(tv, 1 - p["kappa"])
    # World export prices: a variable where export demand is finite (13.2)
    pwe = np.where(ced, v["PWE"], p["pwe"])
    # Price paid by domestic buyers of domestic output, with domestic margins (13.4)
    pdd = v["PD"] + v["PQ"] @ p["icd"]
    # 5.1 Price block
    eq["P1"] = (v["PM"], p["pwm"] * (1 + tm) * v["EXR"] + v["PQ"] @ p["ici"], cm)
    eq["P2"] = (v["PE"], pwe * (1 - p["te"]) * v["EXR"] - v["PQ"] @ p["ice"], ce)
    margin_cost = (v["PQ"] @ p["icm"]) * v["QQ"]   # sum over c' of PQ[c'] icm[c', c] QQ[c]
    eq["P3"] = (v["PQ"] * (1 - tq) * v["QQ"],
                np.where(cdo, pdd * v["QD"], 0.0) + np.where(cm, v["PM"] * v["QM"], 0.0) + margin_cost,
                cq)
    eq["P4"] = (v["PX"] * v["QX"], np.where(cdo, v["PD"] * v["QD"], 0.0) + np.where(ce, v["PE"] * v["QE"], 0.0), cx)
    eq["P5"] = (v["PA"], p["theta"] @ v["PX"], every_a)
    eq["P6"] = (v["PINTA"], (p["ica"] * (1 + vint)).T @ v["PQ"], every_a)
    eq["P7"] = (v["PA"] * (1 - p["ta"]) * v["QA"], v["PVA"] * v["QVA"] + v["PINTA"] * v["QINTA"], every_a)
    eq["P8"] = (v["CPI"], np.atleast_1d(p["cwts"] @ ph), one)
    eq["P9"] = (v["DPI"], np.atleast_1d(p["dwts"] @ v["PD"]), one)

    # 5.2 Production block
    lt, cda = s["lt"], s["cda"]
    eq["Q1"] = (v["QVA"], p["iva"] * v["QA"], lt)
    eq["Q2"] = (v["QINTA"], p["inta"] * v["QA"], lt)
    # CES or Cobb-Douglas top nest (masked elements may be undefined)
    ra, da, dac = p["rho_a"], p["delta_a"], p["deltac_a"]
    ces_out = p["aa"] * (da * v["QVA"] ** (-ra) + dac * v["QINTA"] ** (-ra)) ** (-1 / ra)
    cd_out = p["aa"] * v["QVA"] ** da * v["QINTA"] ** dac
    eq["Q1C"] = (v["QA"], np.where(cda, cd_out, ces_out), ~lt)
    eq["Q2C"] = (np.where(cda, v["PVA"] * v["QVA"] * dac, v["QVA"]),
                 np.where(cda, v["PINTA"] * v["QINTA"] * da,
                          v["QINTA"] * ((v["PINTA"] / v["PVA"]) * da / dac) ** (1 / (1 + ra))), ~lt)
    # Factors in efficiency units (version 0.1.14), and days worked (0.3.4)
    z = (p["af"] * v["EFF"] * v["DW"])[:, None]
    qf = np.where(fa, z * v["QF"], 1.0)
    rho = np.where(cd, 1.0, p["rho_va"])
    ces_sum = (p["delta_va"] * qf ** (-rho)).sum(axis=0)
    q3_ces = p["ad"] * ces_sum ** (-1.0 / rho)
    q3_cd = p["ad"] * np.prod(qf ** p["delta_va"], axis=0)
    eq["Q3"] = (v["QVA"], np.where(cd, q3_cd, q3_ces), every_a)
    wage = v["W"][:, None] * v["WFDIST"]
    pvaqva = v["PVA"] * v["QVA"]
    q4_ces = pvaqva / ces_sum * p["delta_va"] * qf ** (-rho - 1) * z
    eq["Q4"] = (np.where(cd, wage * v["QF"], wage),
                np.where(cd, p["delta_va"] * pvaqva, q4_ces), fa)
    # Health services and factor efficiency (version 0.1.14)
    eta = p["eta_h"]
    hs = np.where(s["hc"], v["QH"].sum(axis=1) + v["QG"] + v["QSHI"], 0.0).sum()
    eq["H1"] = (v["HS"], np.atleast_1d(hs), np.atleast_1d(s["hlink"]))
    eq["H2"] = (v["EFF"], (v["HS"] / p["hs0"]) ** eta, eta != 0)
    # Days lost to illness (Section 15.2)
    ratio = v["HS"][0] / p["hs0"]
    eq["H3"] = (v["DW"], (1 - p["sick"] * ratio ** p["eps_s"]) / (1 - p["sick0"]), s["ins"])
    # Intermediate inputs and household purchases exist only where the SAM has a flow
    eq["Q5"] = (v["QINT"], p["ica"] * v["QINTA"][None, :], s["qint"])
    # Marketed output: home consumption does not reach the market (13.1)
    eq["Q6"] = (v["QX"], p["theta"].T @ (v["QA"] - v["QHA"].sum(axis=1)), cx)

    # 5.3 Trade block
    # 1 - delta is stored (deltac_*) rather than computed: when one share is close to
    # one, the subtraction would lose most significant digits
    rt, dt, dtc = p["rho_t"], p["delta_t"], p["deltac_t"]
    eq["T1"] = (v["QX"], p["at"] * (dt * v["QE"] ** rt + dtc * v["QD"] ** rt) ** (1 / rt), ce & ~cxe)
    eq["T2"] = (v["QE"], v["QD"] * ((v["PE"] / v["PD"]) * dtc / dt) ** (1 / (rt - 1)), ce & ~cxe)
    eq["T3"] = (v["QX"], v["QD"], cx & ~ce)
    eq["T3E"] = (v["QX"], v["QE"], cxe)
    rq, dq, dqc = p["rho_q"], p["delta_q"], p["deltac_q"]
    eq["T4"] = (v["QQ"], p["aq"] * (dq * v["QM"] ** (-rq) + dqc * v["QD"] ** (-rq)) ** (-1 / rq), cm & cdo)
    eq["T5"] = (v["QM"], v["QD"] * ((pdd / v["PM"]) * dq / dqc) ** (1 / (1 + rq)), cm & cdo)
    eq["T6"] = (v["QQ"], p["aq"] * v["QD"], cdo & ~cm)
    eq["T7"] = (v["QQ"], p["aq"] * v["QM"], cm & ~cdo)
    eq["T8"] = (v["QT"], p["icm"] @ v["QQ"] + p["icd"] @ v["QD"] + p["ici"] @ v["QM"] + p["ice"] @ v["QE"], ct)
    eq["T9"] = (v["QER"], p["qer"] * (v["PQ"] / (v["EXR"] * p["pwe"])) ** (-p["sigma_t"]), cr)
    with np.errstate(all="ignore"):
        eq["T10"] = (v["QE"], p["qe0"] * (v["PWE"] / p["pwe"]) ** (-p["eta_e"]), ced)

    # 5.4 Institution block. DY is income after direct taxes and savings.
    DY = (1 - v["MPS"]) * (1 - v["TINS"]) * v["YI"]
    eq["I1"] = (v["YF"], (wage * v["QF"]).sum(axis=1) + p["trfr"] * v["EXR"],
                np.ones(v["YF"].shape, dtype=bool))
    # Health insurance contributions are taken before factor income is distributed
    shi = s["shi_row"]
    yif = p["shif"] * ((1 - p["tshi"]) * v["YF"])[None, :]
    if shi >= 0:
        yif[shi] = p["tshi"] * v["YF"]
    eq["I2"] = (v["YIF"], yif, np.ones(v["YIF"].shape, dtype=bool))
    eq["I3"] = (v["YI"], v["YIF"][:nD].sum(axis=1) + p["shii"] @ DY + p["trdg"] * v["CPI"]
                + p["trdr"] * v["EXR"] + p["hold"] * p["rd"] * p["ddebt"], np.ones(nD, dtype=bool))
    eq["I4"] = (v["EH"], p["hc"] * DY[:nH], np.ones(nH, dtype=bool))
    supernumerary = v["EH"] - ph @ p["gamma"] - v["PA"] @ p["gammah"]
    eq["I5"] = (ph[:, None] * v["QH"],
                ph[:, None] * p["gamma"] + p["beta"] * supernumerary[None, :], s["qh"])
    # Home consumption at producer prices (13.1)
    eq["I5H"] = (v["PA"][:, None] * v["QHA"],
                 v["PA"][:, None] * p["gammah"] + p["betah"] * supernumerary[None, :], s["qha"])
    eq["I6"] = (v["QINV"], p["qinv"] * v["IADJ"], every_c)
    eq["I7"] = (v["QG"], p["qg"] * v["GADJ"], every_c)
    revenue = (v["TINS"] @ v["YI"] + (tq * v["PQ"] * v["QQ"]).sum()
               + (tm * p["pwm"] * v["QM"]).sum() * v["EXR"]
               + (p["te"] * pwe * v["QE"]).sum() * v["EXR"]
               + (p["ta"] * v["PA"] * v["QA"]).sum() + vat_revenue(v, p)
               + v["YIF"][nD].sum() + p["trgr"] * v["EXR"] + p["trgg"] * v["CPI"])
    eq["I8"] = (v["YG"], revenue, one)
    eq["I9"] = (v["EG"], np.atleast_1d(ph @ v["QG"]) + (p["trdg"].sum() + p["trgg"] + p["trshi"]) * v["CPI"]
                + p["trrg"] * v["EXR"] + p["rd"] * p["ddebt"] + p["rf"] * p["fdebt"] * v["EXR"], one)
    eq["I10"] = (v["TINS"], p["tins0"] * v["TINSADJ"], np.ones(nD, dtype=bool))
    eq["I11"] = (v["MPS"], p["mps0"] * v["MPSADJ"], np.ones(nD, dtype=bool))
    # Health insurance fund (version 0.1.13)
    has_shi = np.atleast_1d(shi >= 0)
    eq["I12"] = (v["YSHI"], np.atleast_1d(v["YIF"][shi].sum() if shi >= 0 else 0.0)
                 + p["trshi"] * v["CPI"] + p["trshir"] * v["EXR"], has_shi)
    eq["I13"] = (v["QSHI"], p["qshi"] * v["SHIADJ"], s["qshi"])
    eq["I14"] = (np.atleast_1d(ph @ v["QSHI"]), (1 - p["sshi"]) * v["YSHI"], has_shi)

    # 5.5 System constraints (S6 is imposed through the closure)
    # Labour-market regimes (Section 14): wage curve (L1) and minimum wage (L2)
    inlf = s["inlf"]
    unemp = 1 - v["QFS"] / p["qlf"]
    rwage = v["W"] / v["CPI"]
    with np.errstate(all="ignore"):
        eq["L1"] = (rwage, p["wref"] * (unemp / p["u0"]) ** (-p["epsw"]) + v["LSW"], inlf)
    a, b = unemp, rwage / p["wmin"] - 1
    eq["L2"] = (a + b - np.sqrt(a ** 2 + b ** 2 + 2 * p["mu"]), v["LSM"], inlf)
    eq["S1"] = (np.where(fa, v["QF"], 0.0).sum(axis=1), v["QFS"], np.ones(v["QFS"].shape, dtype=bool))
    eq["S2"] = (v["QQ"], v["QINT"].sum(axis=1) + v["QH"].sum(axis=1) + v["QG"] + v["QINV"]
                + np.where(ct, v["QT"], 0.0) + np.where(cr, v["QER"], 0.0) + v["QSHI"], cq)
    eq["S3"] = ((p["pwm"] * v["QM"]).sum() + (v["YIF"][nD + 1].sum() + p["shir"] @ DY) / v["EXR"]
                + p["trrg"] + p["rf"] * p["fdebt"],
                (pwe * v["QE"]).sum() + np.where(cr, v["PQ"] * v["QER"], 0.0).sum() / v["EXR"]
                + p["trdr"].sum() + p["trfr"].sum() + p["trgr"] + p["trshir"] + v["FSAV"], one)
    eq["S4"] = (v["YG"], v["EG"] + v["GSAV"], one)
    eq["S5"] = ((v["MPS"] * (1 - v["TINS"])) @ v["YI"] + v["GSAV"] + p["sshi"] * v["YSHI"]
                + v["EXR"] * v["FSAV"],
                np.atleast_1d(ph @ v["QINV"]) + v["WALRAS"], one)
    return eq


def world_export_price(model, v: dict, p: dict) -> np.ndarray:
    """World export prices: PWE where export demand is finite, else pwe (13.2)."""
    return np.where(model.struct["ced"], v["PWE"], p["pwe"])


def final_price(v: dict, p: dict) -> np.ndarray:
    """PH: the price paid by final users, including VAT (version 0.3.1)."""
    return v["PQ"] * (1 + p["tv"] * v["TVADJ"])


def vat_revenue(v: dict, p: dict) -> np.ndarray:
    """Net VAT: on final demand, and on the inputs activities cannot recover (I8)."""
    tv = p["tv"] * v["TVADJ"]
    base = (v["QH"].sum(axis=1) + v["QG"] + v["QINV"] + v["QSHI"]
            + (v["QINT"] * (1 - p["kappa"])[None, :]).sum(axis=1))
    return np.atleast_1d((tv * v["PQ"] * base).sum())


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
        ph = final_price(v, p)
        pwe = world_export_price(self.model, v, p)
        expenditure = (ph @ (v["QH"].sum(axis=1) + v["QG"] + v["QINV"] + v["QSHI"]) + v["PQ"] @ v["QER"]
                       + v["PA"] @ v["QHA"].sum(axis=1)
                       + exr * (pwe @ v["QE"]) - exr * (p["pwm"] @ v["QM"]))
        income = (v["PVA"] @ v["QVA"] + (p["tq"] * v["TQADJ"] * v["PQ"] * v["QQ"]).sum()
                  + exr * (p["tm"] * v["TMADJ"] * p["pwm"] * v["QM"]).sum()
                  + exr * (p["te"] * pwe * v["QE"]).sum() + (p["ta"] * v["PA"] * v["QA"]).sum()
                  + vat_revenue(v, p)[0])
        return float(expenditure - income)

    def equivalent_variation(self) -> np.ndarray:
        """Household equivalent variation at base prices (Cobb-Douglas or LES demand)."""
        base, p, v = self.model.base, self.params, self.values
        ph0, ph = final_price(base, self.model.params), final_price(v, p)
        pa0, pa = base["PA"], v["PA"]
        ratio = (np.prod((ph0[:, None] / ph[:, None]) ** p["beta"], axis=0)
                 * np.prod((pa0[:, None] / pa[:, None]) ** p["betah"], axis=0))
        return (ph0 @ p["gamma"] + pa0 @ p["gammah"]
                + (v["EH"] - ph @ p["gamma"] - pa @ p["gammah"]) * ratio - base["EH"])

    def compensating_variation(self) -> np.ndarray:
        """Household compensating variation at simulated prices (Cobb-Douglas or LES
        demand): spending after the shock less the spending that would give base
        utility at the new prices; positive for a gain."""
        base, p, v = self.model.base, self.params, self.values
        ph0, ph = final_price(base, self.model.params), final_price(v, p)
        pa0, pa = base["PA"], v["PA"]
        ratio = (np.prod((ph[:, None] / ph0[:, None]) ** p["beta"], axis=0)
                 * np.prod((pa[:, None] / pa0[:, None]) ** p["betah"], axis=0))
        return (v["EH"] - ph @ p["gamma"] - pa @ p["gammah"]
                - (base["EH"] - ph0 @ p["gamma"] - pa0 @ p["gammah"]) * ratio)


class Model:
    """Calibrated version 0.1 model."""

    def __init__(self, sam: SAM, mapping: Mapping, sigma_va, sigma_q, sigma_t,
                 factor_quantities: dict[tuple[str, str], float] | None = None,
                 income_elasticities=None, frisch=None, sigma_a=None,
                 health_commodities=None, health_elasticities=None, vat_credit=None,
                 debt=None, interest=None, debt_holders=None, foreign_borrowing=None,
                 export_only=None, export_demand=None, unemployment=None, wage_curve=None,
                 min_wage=None, smoothing=1e-10, sick_days=None, sick_elasticity=None,
                 mortality=None, mortality_elasticity=None):
        sam, mapping, self.rewritten = prepare(sam, mapping)
        self.sam = sam
        self.mapping = mapping
        mapping.validate(sam)
        A, C, F, H = mapping.activities, mapping.commodities, mapping.factors, mapping.households
        E = mapping.enterprises
        self.sets = {"A": list(A), "C": list(C), "F": list(F), "H": list(H), "E": list(E),
                     "D": list(H) + list(E),
                     "I": list(H) + list(E) + [mapping.government, mapping.row]
                     + ([mapping.insurance] if mapping.insurance is not None else [])}
        self._calibrate(sam, mapping,
                        _per_element(sigma_va, A, "sigma_va"),
                        _per_element(sigma_q, C, "sigma_q"),
                        _per_element(sigma_t, C, "sigma_t"),
                        factor_quantities, vat_credit, export_only, export_demand)
        self._household_demand(income_elasticities, frisch)
        self._debt(debt, interest, debt_holders, foreign_borrowing)
        self._labour(unemployment, wage_curve, min_wage, smoothing)
        self._top_nest(sigma_a)
        self._health_link(health_commodities, health_elasticities, sick_days, sick_elasticity,
                          mortality, mortality_elasticity)
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
    def _calibrate(self, sam, mapping, sigma_va, sigma_q, sigma_t, factor_quantities, vat_credit=None,
                   export_only=None, export_demand=None):
        A, C, F, H = self.sets["A"], self.sets["C"], self.sets["F"], self.sets["H"]
        I = self.sets["I"]
        gov, sav, row = mapping.government, mapping.savinv, mapping.row
        nA, nC, nF, nH = len(A), len(C), len(F), len(H)
        # Margin accounts by market (13.4): composite supply, domestic sales,
        # imports, exports
        TQ, TD = list(mapping.margin_accounts), list(mapping.domestic_margins)
        TI, TE = list(mapping.import_margins), list(mapping.export_margins)
        T = TQ + TD + TI + TE
        tol = 1e-9 * max(1.0, float(np.abs(sam.values).max()))

        def cell(r, c):
            return 0.0 if r is None or c is None else sam.cell(r, c)

        def vec(rows, cols):
            return np.array([[cell(r, c) for c in cols] for r in rows])

        def fail_if(mask, names, message):
            if np.any(mask):
                raise SAMError(f"{message}: {' '.join(n for n, m in zip(names, mask) if m)}")

        # 7.1 Taxes and trade
        QM0 = vec([row], C)[0]
        cm = QM0 > tol
        tariffs = vec([mapping.imptax], C)[0]
        fail_if(~cm & (np.abs(tariffs) > tol), C, "import tariff recorded on a commodity without imports")
        tm = np.where(cm, tariffs / np.where(cm, QM0, 1.0), 0.0)
        exports = vec(C, [row])[:, 0]
        exported = exports > tol
        export_taxes = vec([mapping.exptax], C)[0]
        fail_if(~exported & (np.abs(export_taxes) > tol), C, "export tax recorded on a commodity without exports")

        QA0 = np.array([sam.col_total(a) for a in A])
        fail_if(QA0 <= tol, A, "every activity needs positive output")
        ta = vec([mapping.acttax], A)[0] / QA0
        MAKE0 = vec(A, C)                      # MAKE0[a, c]: output of c by activity a
        HOME0 = vec(A, H)                      # HOME0[a, h]: home consumption (13.1)
        if np.abs(MAKE0.sum(axis=1) + HOME0.sum(axis=1) - QA0).max() > tol:
            raise SAMError("activity output does not equal its sales to commodities and home consumption")
        fail_if(HOME0 < -tol, A, "negative home consumption of the output of")
        QAM0 = QA0 - HOME0.sum(axis=1)
        fail_if(QAM0 <= tol, A, "an activity needs some marketed output; all the output is consumed at home by")
        theta = MAKE0 / QAM0[:, None]
        QX0 = MAKE0.sum(axis=0)
        cx = QX0 > tol
        fail_if(~cx & ~cm, C, "a commodity has neither domestic output nor imports")
        MG = vec(T, C).reshape(len(T), nC)     # MG[t, c]: margins paid by c to margin account t
        SV = vec(C, T).reshape(nC, len(T))     # SV[c, t]: margin services c bought by account t
        spend = SV.sum(axis=0)
        share = SV / np.where(spend > tol, spend, 1.0)[None, :]
        nq, nd, ni = len(TQ), len(TD), len(TI)
        groups = {"q": slice(0, nq), "d": slice(nq, nq + nd), "i": slice(nq + nd, nq + nd + ni),
                  "e": slice(nq + nd + ni, len(T))}
        margins = {k: MG[g].sum(axis=0) for k, g in groups.items()}
        # Export-only commodities (13.3), chosen by the user
        xo = list(export_only or [])
        unknown = [c for c in xo if c not in C]
        if unknown:
            raise ValueError(f"export_only: {unknown} are not commodities")
        cxe = np.array([c in xo for c in C], dtype=bool)
        net_exports = exports - export_taxes - margins["e"]
        equal = exported & cx & (np.abs(QX0 - net_exports) <= tol)
        fail_if(cxe & ~equal, C, "export-only commodities need exports, net of export taxes and margins, "
                                 "equal to domestic output")
        self.export_only_candidates = [c for c, e, x in zip(C, equal, cxe) if e and not x]
        # Exports at least as large as domestic output are drawn from composite
        # supply (CR, T9); other exports come from domestic output (CE, T1-T2)
        cr = exported & (QX0 - (exports - export_taxes) <= tol) & ~cxe
        fail_if(cr & (np.abs(export_taxes) > tol), C,
                "export tax recorded on a commodity whose exports are at least its domestic output "
                "(give it as export-only if all its output is exported)")
        fail_if(cr & (np.abs(margins["e"]) > tol), C,
                "export margins recorded on a commodity whose exports are drawn from composite supply")
        ce = exported & ~cr
        te = np.where(ce, export_taxes / np.where(ce, exports, 1.0), 0.0)
        QE0 = np.where(ce, net_exports, 0.0)
        QER0 = np.where(cr, exports, 0.0)
        pwe = np.where(ce, exports / np.where(ce, QE0, 1.0), 1.0 / (1.0 - te))
        QD0 = np.where(cx & ~cxe, QX0 - QE0, 0.0)
        cdo = cx & ~cxe
        fail_if(cdo & (QD0 <= tol), C, "a commodity with domestic output needs positive domestic sales "
                                        "(unless all its output is exported: see export-only commodities)")
        for key, base, what in (("d", QD0, "domestic sales"), ("i", QM0, "imports"), ("e", QE0, "exports")):
            fail_if((np.abs(margins[key]) > tol) & (base <= tol), C, f"margins on {what} recorded on a commodity without {what}")
        def rate(key, base):
            return share[:, groups[key]] @ MG[groups[key]] / np.where(base > tol, base, 1.0)[None, :]
        icd, ici, ice = rate("d", QD0), rate("i", QM0), rate("e", QE0)
        PM0 = np.where(cm, 1.0 + tm + ici.sum(axis=0), 0.0)
        PDD0 = 1.0 + icd.sum(axis=0)
        sales_taxes = vec([mapping.saltax], C)[0]
        QQ0 = PDD0 * QD0 + PM0 * QM0 + sales_taxes + margins["q"]
        cq = cdo | cm
        tq = np.where(cq, sales_taxes / np.where(cq, QQ0, 1.0), 0.0)
        QT0 = SV.sum(axis=1)
        ct = QT0 > tol
        icm = share[:, groups["q"]] @ MG[groups["q"]] / np.where(cq, QQ0, 1.0)[None, :]
        # Export demand (13.2): a finite elasticity for the commodities given
        eta_e = np.zeros(nC)
        if export_demand is not None:
            spec = export_demand if isinstance(export_demand, dict) else {c: export_demand for c in np.array(C)[ce]}
            for c, e in spec.items():
                if c not in C:
                    raise ValueError(f"export_demand: {c} is not a commodity")
                k = C.index(c)
                if not ce[k]:
                    raise SAMError(f"export_demand: {c} has no exports from domestic output")
                if not (np.isfinite(e) and e > 0):
                    raise ValueError("export demand elasticities must be positive")
                eta_e[k] = float(e)
        ced = eta_e > 0
        # VAT (model_spec.md, 12.2): rates from the VAT account, then the
        # quantity of each use at PQ = 1
        kappa = _credit_shares(vat_credit, A)
        VINT = vec(C, A)
        VH = vec(C, H)
        vg, vinv = vec(C, [gov])[:, 0], vec(C, [sav])[:, 0]
        vshi = vec(C, [mapping.insurance])[:, 0] if mapping.insurance is not None else np.zeros(nC)
        vat = vec([mapping.vattax], C)[0]
        tv = np.zeros(nC)
        for k in np.flatnonzero(np.abs(vat) > tol):
            values = np.concatenate([VINT[k], VH[k], [vg[k], vinv[k], vshi[k]]])
            liab = np.concatenate([1 - kappa, np.ones(nH + 3)])
            tv[k] = _vat_rate(vat[k], values, liab, C[k])
        QINT0 = VINT / (1 + np.outer(tv, 1 - kappa))
        QH0 = VH / (1 + tv)[:, None]
        qg, qinv, qshi = vg / (1 + tv), vinv / (1 + tv), vshi / (1 + tv)
        demand = QINT0.sum(axis=1) + QH0.sum(axis=1) + qg + qinv + qshi + QT0 + QER0
        if np.abs(QQ0 - demand).max() > tol:
            raise SAMError("composite supply does not equal domestic demand for some commodity")

        # 7.2 Production
        QINTA0 = QINT0.sum(axis=0)
        ica = QINT0 / np.where(QINTA0 > 0, QINTA0, 1.0)
        PINTA0 = (ica * (1 + np.outer(tv, 1 - kappa))).sum(axis=0)
        VA = vec(F, A)
        fa = VA > tol
        if factor_quantities is None:
            W0 = np.ones(nF)
            WFDIST0 = np.ones((nF, nA))
            QF0 = np.where(fa, VA, 0.0)
        else:
            QFq = np.array([[float(factor_quantities.get((f, a), 0.0)) for a in A] for f in F])
            if np.any((QFq > 0) != fa):
                raise SAMError("factor quantities must be positive exactly where factor payments are")
            W0 = VA.sum(axis=1) / QFq.sum(axis=1)
            WFDIST0 = np.where(fa, VA / (W0[:, None] * np.where(fa, QFq, 1.0)), 1.0)
            QF0 = QFq
        QVA0 = VA.sum(axis=0)
        fail_if(QVA0 <= tol, A, "every activity needs positive value added")
        iva = QVA0 / QA0
        inta = QINTA0 / QA0

        cd = np.abs(sigma_va - 1.0) < 1e-12
        rho_va = np.where(cd, 0.0, 1.0 / sigma_va - 1.0)
        delta_va = np.zeros((nF, nA))
        ad = np.zeros(nA)
        w = W0[:, None] * WFDIST0
        for k in range(nA):
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
        delta_t = np.full(nC, 0.5)
        deltac_t = np.full(nC, 0.5)
        at = np.ones(nC)
        for k in np.flatnonzero(ce & ~cxe):
            r = rho_t[k]
            ratio = (QE0[k] / QD0[k]) ** (r - 1)
            delta_t[k] = 1.0 / (1.0 + ratio)
            deltac_t[k] = ratio / (1.0 + ratio)
            at[k] = QX0[k] / (delta_t[k] * QE0[k] ** r + deltac_t[k] * QD0[k] ** r) ** (1 / r)
        if np.any(np.abs(sigma_q[cm & cdo] - 1.0) < 1e-12):
            raise ValueError("version 0.1 needs sigma_q different from 1 for imported commodities")
        rho_q = 1.0 / sigma_q - 1.0
        delta_q = np.full(nC, 0.5)
        deltac_q = np.full(nC, 0.5)
        # non-imported commodities (T6) and commodities imported only (T7)
        aq = np.where(cdo, QQ0 / np.where(cdo, QD0, 1.0), np.where(cm, QQ0 / np.where(cm, QM0, 1.0), 1.0))
        for k in np.flatnonzero(cm & cdo):
            r = rho_q[k]
            ratio = (PM0[k] / PDD0[k]) * (QM0[k] / QD0[k]) ** (1 + r)
            delta_q[k] = ratio / (1 + ratio)
            deltac_q[k] = 1.0 / (1 + ratio)
            aq[k] = QQ0[k] / (delta_q[k] * QM0[k] ** (-r) + deltac_q[k] * QD0[k] ** (-r)) ** (-1 / r)

        # 7.5 Institutions
        D = self.sets["D"]
        YF0 = np.array([sam.row_total(f) for f in F])
        YIF0 = vec(I, F)
        if np.abs(YIF0.sum(axis=0) - YF0).max() > tol:
            raise SAMError("factor income paid out does not equal factor income received")
        # Health insurance contributions as a rate on factor income (model_spec.md, 7.5)
        shi = mapping.insurance
        shi_row = I.index(shi) if shi is not None else -1
        tshi = YIF0[shi_row] / YF0 if shi is not None else np.zeros(nF)
        if np.any(tshi >= 1):
            raise SAMError("health insurance contributions take all the income of a factor")
        shif = YIF0 / ((1 - tshi) * YF0)[None, :]
        if shi is not None:
            shif[shi_row] = 0.0
        trfr = vec(F, [row])[:, 0]
        YI0 = np.array([sam.row_total(d) for d in D])
        dtax = vec([mapping.dirtax], D)[0]
        dsav = vec([sav], D)[0]
        tins0 = dtax / YI0
        mps0 = dsav / ((1 - tins0) * YI0)
        DY0 = YI0 - dtax - dsav
        TR = vec(D, D)                       # TR[d, d'] = transfer from d' to d
        TROW = vec([row], D)[0]
        EH0 = VH.sum(axis=0) + HOME0.sum(axis=0)
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
        beta = VH / np.where(EH0 > 0, EH0, 1.0)[None, :]
        betah = HOME0 / np.where(EH0 > 0, EH0, 1.0)[None, :]
        trdg = vec(D, [gov])[:, 0]
        trdr = vec(D, [row])[:, 0]
        trgr, trrg, trgg = cell(gov, row), cell(row, gov), cell(gov, gov)
        YSHI0 = sam.row_total(shi) if shi is not None else 0.0
        if shi is not None and YSHI0 <= tol:
            raise SAMError("the health insurance fund has no revenue")
        sshi = cell(sav, shi) / YSHI0 if shi is not None else 0.0
        trshi, trshir = cell(shi, gov), cell(shi, row)
        cwts = VH.sum(axis=1) / VH.sum() / (1 + tv)
        dwts = QD0 / QD0.sum()
        self.paired = {a: C[k] for k, a in enumerate(A)}

        self.struct = {"ce": ce, "cm": cm, "fa": fa, "cd": cd, "cx": cx, "ct": ct, "cr": cr,
                       "qint": QINT0 != 0, "qh": QH0 != 0, "shi_row": shi_row, "qshi": qshi != 0,
                       "cxe": cxe, "ced": ced, "qha": HOME0 != 0}
        self.params = {
            "pwm": np.ones(nC), "pwe": pwe, "tm": tm, "te": te, "tq": tq, "ta": ta,
            "theta": theta, "iva": iva, "inta": inta, "ica": ica, "ad": ad, "delta_va": delta_va, "rho_va": rho_va,
            "at": at, "delta_t": delta_t, "deltac_t": deltac_t, "rho_t": rho_t,
            "aq": aq, "delta_q": delta_q, "deltac_q": deltac_q, "rho_q": rho_q,
            "shif": shif, "beta": beta, "gamma": np.zeros_like(beta), "tins0": tins0, "mps0": mps0,
            "shii": shii, "shir": shir, "hc": hc, "trdg": trdg, "trdr": trdr, "trfr": trfr,
            "trgr": np.array(trgr), "trrg": np.array(trrg), "trgg": np.array(trgg),
            "qg": qg, "qinv": qinv, "cwts": cwts, "dwts": dwts, "icm": icm, "qer": QER0,
            "tshi": tshi, "qshi": qshi, "sshi": np.array(sshi), "trshi": np.array(trshi),
            "trshir": np.array(trshir),
            "sigma_va": sigma_va, "sigma_q": sigma_q, "sigma_t": sigma_t,
            "tv": tv, "kappa": kappa,
            # version 0.3.2: margins by market, export demand, home consumption
            "icd": icd, "ici": ici, "ice": ice, "eta_e": eta_e, "qe0": QE0.copy(),
            "betah": betah, "gammah": np.zeros_like(betah),
            # public debt (version 0.3.1): none unless calibrated with debt
            "debt": np.array(0.0), "ddebt": np.array(0.0), "fdebt": np.array(0.0),
            "rd": np.array(0.0), "rf": np.array(0.0), "hold": np.zeros(len(D)), "phi": np.array(0.0),
        }
        s1 = np.ones(1)
        self.base = {
            "PA": np.ones(nA), "PVA": np.ones(nA), "PINTA": PINTA0, "PX": np.ones(nC),
            "PD": np.ones(nC), "PE": np.where(ce, 1.0, 0.0), "PM": PM0, "PQ": np.ones(nC),
            "W": W0, "EXR": s1.copy(), "CPI": np.atleast_1d(cwts @ (1 + tv)), "DPI": np.atleast_1d(dwts.sum()),
            "QA": QA0, "QVA": QVA0, "QINTA": QINTA0, "QF": QF0, "QINT": QINT0, "QX": QX0,
            "QD": QD0, "QE": QE0, "QM": np.where(cm, QM0, 0.0), "QQ": QQ0, "QH": QH0,
            "QG": qg.copy(), "QINV": qinv.copy(), "QFS": QF0.sum(axis=1),
            "YF": YF0, "YIF": YIF0, "YI": YI0, "EH": EH0,
            "YG": np.atleast_1d(sam.row_total(gov)),
            "EG": np.atleast_1d(vg.sum() + trdg.sum() + trgg + trrg + trshi),
            "GSAV": np.atleast_1d(cell(sav, gov)), "FSAV": np.atleast_1d(cell(sav, row)),
            "TINS": tins0.copy(), "MPS": mps0.copy(),
            "TINSADJ": s1.copy(), "MPSADJ": s1.copy(), "IADJ": s1.copy(), "GADJ": s1.copy(),
            "WFDIST": WFDIST0, "WALRAS": np.zeros(1), "QT": QT0, "QER": QER0.copy(),
            "YSHI": np.atleast_1d(YSHI0), "SHIADJ": s1.copy(), "QSHI": qshi.copy(),
            "TQADJ": s1.copy(), "TMADJ": s1.copy(), "TVADJ": s1.copy(),
            "PWE": pwe.copy(), "QHA": HOME0.copy(),
        }
        self.exists = {name: np.ones(value.shape, dtype=bool) for name, value in self.base.items()}
        self.exists["PE"] = ce.copy()
        self.exists["QE"] = ce.copy()
        self.exists["PM"] = cm.copy()
        self.exists["QM"] = cm.copy()
        self.exists["QF"] = fa.copy()
        self.exists["WFDIST"] = fa.copy()
        for name in ("PX", "QX"):
            self.exists[name] = cx.copy()
        for name in ("PD", "QD"):
            self.exists[name] = cdo.copy()
        for name in ("PQ", "QQ"):
            self.exists[name] = cq.copy()
        self.exists["PWE"] = ced.copy()
        self.exists["QHA"] = HOME0 != 0
        self.exists["QT"] = ct.copy()
        self.exists["QER"] = cr.copy()
        self.exists["QINT"] = QINT0 != 0
        self.exists["QH"] = QH0 != 0
        self.exists["YSHI"] = np.atleast_1d(shi is not None)
        self.exists["SHIADJ"] = np.atleast_1d(shi is not None)
        self.exists["QSHI"] = qshi != 0

    def _top_nest(self, sigma_a) -> None:
        """Top nest of production (model_spec.md, 5.2 and 7.3): Leontief (sigma_a = 0,
        the default), Cobb-Douglas (1) or CES between value added and intermediates."""
        A, b = self.sets["A"], self.base
        n = len(A)
        if sigma_a is None:
            sa = np.zeros(n)
        elif isinstance(sigma_a, dict):
            if set(sigma_a) != set(A):
                raise ValueError("sigma_a needs one value for each activity")
            sa = np.array([float(sigma_a[a]) for a in A])
        else:
            sa = np.broadcast_to(np.asarray(sigma_a, dtype=float), (n,)).copy()
        if np.any(~np.isfinite(sa)) or np.any(sa < 0):
            raise ValueError("sigma_a must be zero (Leontief) or positive")
        lt = (sa == 0) | (b["QINTA"] <= 0)
        cda = ~lt & (np.abs(sa - 1.0) < 1e-12)
        rho = np.where(lt | cda, 0.0, 1.0 / np.where(sa > 0, sa, 1.0) - 1.0)
        QVA0, QINTA0, QA0 = b["QVA"], np.where(lt, 1.0, b["QINTA"]), b["QA"]
        PVA0, PINTA0 = b["PVA"], np.where(lt, 1.0, b["PINTA"])
        ratio = (PVA0 / PINTA0) * (QVA0 / QINTA0) ** (1 + rho)
        delta = ratio / (1 + ratio)
        deltac = 1.0 / (1 + ratio)
        value = PVA0 * QVA0 + PINTA0 * QINTA0
        delta = np.where(cda, PVA0 * QVA0 / value, delta)
        deltac = np.where(cda, PINTA0 * QINTA0 / value, deltac)
        with np.errstate(all="ignore"):
            ces = (delta * QVA0 ** (-rho) + deltac * QINTA0 ** (-rho)) ** (-1 / rho)
        aa = np.where(lt, 1.0, np.where(cda, QA0 / (QVA0 ** delta * QINTA0 ** deltac), QA0 / np.where(lt | cda, 1.0, ces)))
        self.struct["lt"], self.struct["cda"] = lt, cda
        self.params.update({"sigma_a": sa, "rho_a": rho, "delta_a": delta, "deltac_a": deltac, "aa": aa})

    def _health_link(self, health_commodities, health_elasticities, sick_days=None, sick_elasticity=None,
                     mortality=None, mortality_elasticity=None) -> None:
        """Factor efficiency (model_spec.md, 5.2 and 7.3): af = 1 and, given health
        commodities and elasticities by factor, EFF = (HS / HS0)^eta. Health
        outcomes (Section 15): days lost to illness and the death rate."""
        C, F, b = self.sets["C"], self.sets["F"], self.base
        nF = len(F)
        hcom = list(health_commodities or [])
        unknown = [c for c in hcom if c not in C]
        if unknown:
            raise ValueError(f"health_commodities: {unknown} are not commodities of the model")
        if health_elasticities is None:
            eta = np.zeros(nF)
        elif isinstance(health_elasticities, dict):
            extra = [f for f in health_elasticities if f not in F]
            if extra:
                raise ValueError(f"health_elasticities: {extra} are not factors of the model")
            eta = np.array([float(health_elasticities.get(f, 0.0)) for f in F])
        else:
            eta = np.broadcast_to(np.asarray(health_elasticities, dtype=float), (nF,)).copy()
        if np.any(~np.isfinite(eta)) or np.any(eta < 0):
            raise ValueError("health elasticities must be zero or positive")
        if np.any(eta != 0) and not hcom:
            raise ValueError("health elasticities need health_commodities")
        # Days lost to illness: base shares and elasticities by factor
        sick_days = dict(sick_days or {})
        extra = [f for f in sick_days if f not in F]
        if extra:
            raise ValueError(f"sick_days: {extra} are not factors of the model")
        ins = np.array([f in sick_days for f in F], dtype=bool)
        s0 = np.array([float(sick_days.get(f, 0.0)) for f in F])
        if np.any(~np.isfinite(s0)) or np.any((s0 < 0) | (s0 >= 1)):
            raise ValueError("sick_days: shares must be at least 0 and below 1")
        if sick_elasticity is None:
            eps_s = np.zeros(nF)
        elif isinstance(sick_elasticity, dict):
            extra = [f for f in sick_elasticity if f not in sick_days]
            if extra:
                raise ValueError(f"sick_elasticity: {extra} have no sick days")
            eps_s = np.array([float(sick_elasticity.get(f, 0.0)) for f in F])
        else:
            eps_s = np.where(ins, float(sick_elasticity), 0.0)
        if np.any(~np.isfinite(eps_s)):
            raise ValueError("sick_elasticity must be finite")
        # The death rate
        if mortality is None:
            if mortality_elasticity is not None:
                raise ValueError("mortality_elasticity needs mortality")
            has_mort, m0, eps_m = False, 0.0, 0.0
        else:
            has_mort, m0 = True, float(mortality)
            eps_m = float(mortality_elasticity or 0.0)
            if not 0 <= m0 < 1 or not np.isfinite(eps_m):
                raise ValueError("mortality must be at least 0 and below 1, with a finite elasticity")
        if (np.any(eps_s != 0) or eps_m != 0) and not hcom:
            raise ValueError("health outcomes with non-zero elasticities need health_commodities")
        hc = np.array([c in hcom for c in C], dtype=bool)
        linked = bool(np.any(eta != 0) or np.any(eps_s != 0) or eps_m != 0)
        hs0 = float(np.where(hc, b["QH"].sum(axis=1) + b["QG"] + b["QSHI"], 0.0).sum())
        if linked and hs0 <= 0:
            raise SAMError("health services have no consumption by households, the government "
                           "or the health insurance fund")
        hs0 = hs0 if linked else 1.0
        self.struct["hc"] = hc
        self.struct["hlink"] = linked
        self.struct["ins"] = ins
        self.struct["hasmort"] = has_mort
        self.params.update({"af": np.ones(nF), "eta_h": eta, "hs0": np.array(hs0),
                            "sick0": s0, "sick": s0.copy(), "eps_s": eps_s, "mort0": np.array(m0),
                            "mort": np.array(m0), "eps_m": np.array(eps_m), "pop": np.array(1.0)})
        b["EFF"] = np.ones(nF)
        b["HS"] = np.atleast_1d(hs0)
        b["DW"] = np.ones(nF)
        self.exists["EFF"] = eta != 0
        self.exists["HS"] = np.atleast_1d(linked)
        self.exists["DW"] = ins.copy()

    def _labour(self, unemployment, wage_curve, min_wage, smoothing) -> None:
        """Labour force, wage curve and minimum wage (model_spec.md, Section 14)."""
        F, b, p = self.sets["F"], self.base, self.params
        nF = len(F)
        unemployment, wage_curve, min_wage = dict(unemployment or {}), dict(wage_curve or {}), dict(min_wage or {})
        for name, spec in (("unemployment", unemployment), ("wage_curve", wage_curve), ("min_wage", min_wage)):
            extra = set(spec) - set(F)
            if extra:
                raise ValueError(f"{name}: {sorted(extra)} are not factors")
        mu = float(smoothing)
        if not mu > 0:
            raise ValueError("smoothing must be positive")
        for f in wage_curve:
            if not float(unemployment.get(f, 0.0)) > 0:
                raise ValueError(f"wage_curve: {f} needs unemployment in the base")
        inlf = np.array([f in unemployment or f in min_wage for f in F], dtype=bool)
        qfs0 = b["QFS"]
        wref = b["W"] / b["CPI"][0]
        u0, qlf, epsw = np.ones(nF), qfs0.copy(), np.zeros(nF)
        wmin, hasmin = wref.copy(), np.zeros(nF, dtype=bool)
        for k, f in enumerate(F):
            if not inlf[k]:
                continue
            u = float(unemployment.get(f, 0.0))
            if not 0 <= u < 1:
                raise ValueError(f"unemployment: the rate of {f} must be at least 0 and below 1")
            if f in min_wage:
                r = float(min_wage[f])
                hasmin[k] = True
                if u > 0:
                    if abs(r - 1) > 1e-12:
                        raise ValueError(f"min_wage: with unemployment of {f} in the base, the floor is the base wage (1)")
                    wmin[k] = wref[k] / (1 + mu / u)
                else:
                    if not 0 < r < 1:
                        raise ValueError(f"min_wage: with full employment of {f} in the base, the floor must be below the base wage")
                    wmin[k] = r * wref[k]
                    u = mu / (1 / r - 1)
            elif u > 0:
                hasmin[k] = True               # by default the floor is the base wage
                wmin[k] = wref[k] / (1 + mu / u)
            if f in wage_curve:
                e = float(wage_curve[f])
                if not e > 0:
                    raise ValueError(f"wage_curve: the elasticity of {f} must be positive")
                epsw[k] = e
            if u <= 0:
                raise ValueError(f"{f}: a labour force needs unemployment in the base or a minimum wage")
            u0[k] = u
            qlf[k] = qfs0[k] / (1 - u)
        p.update({"inlf": inlf.astype(float), "qlf": qlf, "u0": u0, "epsw": epsw, "wref": wref.copy(),
                  "wmin": wmin, "hasmin": hasmin.astype(float), "mu": np.array(mu)})
        self.struct["inlf"] = inlf
        a = 1 - qfs0 / qlf
        bb = (b["W"] / b["CPI"][0]) / wmin - 1
        b["LSW"] = np.zeros(nF)
        b["LSM"] = np.where(inlf, a + bb - np.sqrt(a ** 2 + bb ** 2 + 2 * mu), 0.0)
        self.exists["LSW"] = inlf.copy()
        self.exists["LSM"] = inlf.copy()

    def _debt(self, debt, interest, holders, foreign_borrowing) -> None:
        """Public debt and interest (model_spec.md, 12.3): base transfers from
        government are split into interest on the stated debt and other transfers."""
        if debt is None and interest is None and holders is None and foreign_borrowing is None:
            return
        debt, interest = dict(debt or {}), dict(interest or {})
        for name, spec in (("debt", debt), ("interest", interest)):
            extra = set(spec) - {"domestic", "foreign"}
            if extra:
                raise ValueError(f"{name}: {sorted(extra)} are not domestic or foreign")
        dd, df = float(debt.get("domestic", 0.0)), float(debt.get("foreign", 0.0))
        rd, rf = float(interest.get("domestic", 0.0)), float(interest.get("foreign", 0.0))
        if min(dd, df) < 0 or min(rd, rf) <= -1:
            raise ValueError("debt must be non-negative and interest rates above -1")
        p, D = self.params, self.sets["D"]
        tol = 1e-9 * max(1.0, float(np.abs(self.sam.values).max()))
        if holders is None:
            pos = np.maximum(p["trdg"], 0.0)
            if rd * dd != 0 and pos.sum() <= 0:
                raise SAMError("the government makes no transfers to domestic institutions; give the debt holders")
            hold = pos / pos.sum() if pos.sum() > 0 else np.zeros(len(D))
        else:
            unknown = set(holders) - set(D)
            if unknown:
                raise ValueError(f"debt_holders: {sorted(unknown)} are not domestic institutions")
            hold = np.array([float(holders.get(d, 0.0)) for d in D])
            if np.any(hold < 0) or abs(hold.sum() - 1) > 1e-12:
                raise ValueError("debt holder shares must be non-negative and sum to one")
        trdg = p["trdg"] - hold * rd * dd
        trrg = float(p["trrg"]) - rf * df
        bad = trdg < -tol
        if np.any(bad):
            raise SAMError("government transfers to " + " ".join(d for d, b in zip(D, bad) if b)
                           + " are smaller than their interest on the stated debt")
        if trrg < -tol:
            raise SAMError("government transfers to the rest of the world are smaller than the "
                           "interest on the stated foreign debt")
        if foreign_borrowing is None:
            phi = df / (dd + df) if dd + df > 0 else 0.0
        else:
            phi = float(foreign_borrowing)
        p.update({"trdg": trdg, "trrg": np.array(trrg), "debt": np.array(1.0), "ddebt": np.array(dd),
                  "fdebt": np.array(df), "rd": np.array(rd), "rf": np.array(rf), "hold": hold,
                  "phi": np.array(phi)})

    def _household_demand(self, income_elasticities, frisch) -> None:
        """LES demand (model_spec.md, 7.5) when income elasticities or Frisch parameters are given."""
        if income_elasticities is None and frisch is None:
            return
        if frisch is None:
            raise ValueError("LES demand needs Frisch parameters (frisch)")
        C, H = self.sets["C"], self.sets["H"]
        eps = _per_element(1.0 if income_elasticities is None else income_elasticities, C,
                           "income_elasticities")
        if isinstance(frisch, dict):
            phi = np.array([float(frisch[h]) for h in H])
        else:
            phi = np.broadcast_to(np.asarray(frisch, dtype=float), (len(H),)).copy()
        if np.any(~np.isfinite(phi)) or np.any(phi >= -1):
            raise ValueError("Frisch parameters must be below -1, so that subsistence spending is positive")
        QH0, EH0, QHA0 = self.base["QH"], self.base["EH"], self.base["QHA"]
        if np.any(QH0 < 0):
            raise SAMError("LES demand needs non-negative household consumption")
        w, wh = self.params["beta"], self.params["betah"]
        # Home consumption takes the income elasticity of the activity's paired commodity
        eps_h = np.array([eps[C.index(self.paired[a])] for a in self.sets["A"]])
        b = eps[:, None] * w
        bh = eps_h[:, None] * wh
        total = b.sum(axis=0) + bh.sum(axis=0)
        b = b / np.where(total > 0, total, 1.0)[None, :]
        bh = bh / np.where(total > 0, total, 1.0)[None, :]
        self.params["beta"], self.params["betah"] = b, bh
        ph0 = final_price(self.base, self.params)
        self.params["gamma"] = QH0 + b * (EH0 / phi)[None, :] / ph0[:, None]
        self.params["gammah"] = QHA0 + bh * (EH0 / phi)[None, :] / self.base["PA"][:, None]

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
