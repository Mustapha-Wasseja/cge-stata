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


# Taxes on factor use and income (version 0.5.0): a SYNTHETIC SAM with a
# payroll tax on labour (tax_pay) and a tax on capital income (tax_fy)
FACTOR_TAX_SAM = REPO / "data" / "cge_synthetic_sam_ftax.csv"


def factor_tax_mapping() -> Mapping:
    m = synthetic_mapping()
    m.factor_taxes = {"tax_pay": "lab"}
    m.factor_income_tax = "tax_fy"
    return m


def factor_tax_model(**elasticities) -> Model:
    settings = {**TEST_ELASTICITIES, **elasticities}
    return Model(SAM.from_csv(FACTOR_TAX_SAM), factor_tax_mapping(), **settings)


def factor_tax_cases() -> dict:
    """name -> solution: the standard simulations, a payroll tax halved and
    the tax on capital income doubled (version 0.5.0)."""
    m = factor_tax_model()
    out = {"ftax_" + k: s for k, s in run_simulations(m).items()}
    lab = m.sets["F"].index("lab")
    tf = m.params["tf"].copy()
    tf[lab] *= 0.5
    out["ftax_payroll_cut"] = m.solve(Closure(), tol=1e-12, params={"tf": tf})
    out["ftax_income_tax_up"] = m.solve(Closure(), tol=1e-12, params={"tfy": m.params["tfy"] * 2})
    mixed = factor_tax_model(**MIXED_ELASTICITIES)
    tf = mixed.params["tf"].copy()
    tf[lab] *= 0.5
    out["ftax_mixed_payroll_cut"] = mixed.solve(Closure(), tol=1e-12, params={"tf": tf})
    return out


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


# Fiscal instruments (version 0.3.1, model_spec.md, Section 12): a VAT
# layout with credit shares (act_agr exempt, act_ser half recovered), VAT
# within the sales tax of the standard layout, and public debt in the
# institutions layout. Test values, not estimates.
VAT_SAM = REPO / "data" / "cge_synthetic_sam_vat.csv"
VAT_CREDIT = {"act_agr": 0.0, "act_man": 1.0, "act_ser": 0.5}
VAT_SHARES = {"com_man": 0.5, "com_ser": 1.0}
DEBT = {"debt": {"domestic": 100.0, "foreign": 40.0}, "interest": {"domestic": 0.05, "foreign": 0.03}}


def vat_mapping() -> Mapping:
    m = synthetic_mapping()
    m.vattax = "tax_vat"
    return m


def vat_model(**settings) -> Model:
    settings = {**TEST_ELASTICITIES, "vat_credit": VAT_CREDIT, **settings}
    return Model(SAM.from_csv(VAT_SAM), vat_mapping(), **settings)


def vatshare_model(shares=None, **settings) -> Model:
    m = synthetic_mapping()
    m.vat_shares = VAT_SHARES if shares is None else shares
    return Model(SAM.from_csv(SYNTHETIC_SAM), m, **{**TEST_ELASTICITIES, **settings})


def debt_model(**settings) -> Model:
    return institutions_model(**{**DEBT, **settings})


def fiscal_cases() -> dict:
    """Static fiscal simulations (version 0.3.1): name -> solution."""
    out = {}
    vat = vat_model()
    for name, solution in run_simulations(vat).items():
        out["vat_" + name] = solution
    p = vat.params
    out["vat_rate_up20"] = vat.solve(Closure(), tol=1e-12, params={"tv": p["tv"] * 1.2})
    out["vat_credit_full"] = vat.solve(Closure(), tol=1e-12, params={"kappa": np.ones_like(p["kappa"])})
    notariff = {"tm": np.zeros_like(p["tm"])}
    out["vat_tariff_removal_vat"] = vat.solve(Closure(government="fixgsav vat"), tol=1e-12, params=notariff)
    out["vat_rate_cut_import"] = vat.solve(Closure(government="fixgsav import"), tol=1e-12,
                                           params={"tv": p["tv"] * 0.8})
    std = synthetic_model()
    notariff = {"tm": np.zeros_like(std.params["tm"])}
    out["rep_tariff_removal_sales"] = std.solve(Closure(government="fixgsav sales"), tol=1e-12, params=notariff)
    out["rep_tariff_removal_direct"] = std.solve(Closure(government="fixgsav"), tol=1e-12, params=notariff)
    vshare = vatshare_model()
    out["vshare_tariff_removal"] = vshare.solve(Closure(), tol=1e-12,
                                                params={"tm": np.zeros_like(vshare.params["tm"])})
    # A VAT introduced where the SAM has none: an empty VAT account, then a
    # 10 per cent rate on every commodity
    intro = vatshare_model(shares=0.0)
    out["vintro_vat10"] = intro.solve(Closure(), tol=1e-12, params={"tv": np.full_like(intro.params["tv"], 0.1)})
    debt = debt_model()
    out["debt_rate_up"] = debt.solve(Closure(), tol=1e-12, params={"rf": debt.params["rf"] * 2})
    out["debt_relief"] = debt.solve(Closure(), tol=1e-12, params={"fdebt": debt.params["fdebt"] * 0.5})
    out["debt_tariff_removal_dpi"] = debt.solve(Closure(numeraire="dpi"), tol=1e-12,
                                                params={"tm": np.zeros_like(debt.params["tm"])})
    return out


def debt_relief(t, p, fx):
    """Debt relief in period 2: half the foreign debt is cancelled."""
    if t == 2:
        p["fdebt"] = p["fdebt"] * 0.5


# Trade and household extensions (version 0.3.2, model_spec.md, Section 13):
# home consumption, an export-only cash crop, margins by market and export
# demand elasticities. Test values, not estimates.
HOME_SAM = REPO / "data" / "cge_synthetic_sam_home.csv"
TRADE_SAM = REPO / "data" / "cge_synthetic_sam_trade.csv"
TRADE_SETTINGS = {"export_only": ["com_cash"], "export_demand": {"com_man": 4.0, "com_cash": 2.0}}


def home_model(**settings) -> Model:
    return Model(SAM.from_csv(HOME_SAM), synthetic_mapping(), **{**TEST_ELASTICITIES, **settings})


def trade_mapping(by_market: bool = True) -> Mapping:
    m = synthetic_mapping()
    m.commodities = ["com_agr", "com_man", "com_ser", "com_cash"]
    if by_market:
        m.domestic_margins, m.import_margins, m.export_margins = ["mtrd"], ["mtrm"], ["mtre"]
    else:
        m.margin_accounts = ["mtrd", "mtrm", "mtre"]
    return m


def trade_model(by_market: bool = True, **settings) -> Model:
    return Model(SAM.from_csv(TRADE_SAM), trade_mapping(by_market), **{**TEST_ELASTICITIES, **settings})


def trade_cases() -> dict:
    """Static simulations of the trade and household extensions: name -> solution."""
    out = {}
    home = home_model()
    for name, solution in run_simulations(home).items():
        out["home_" + name] = solution
    home_les = home_model(**LES_SETTINGS)
    out["home_les_tariff_removal"] = home_les.solve(Closure(), tol=1e-12, **simulation_inputs(home_les)["tariff_removal"])
    agr = home.sets["C"].index("com_agr")
    out["home_sales_tax_agr_up"] = home.solve(Closure(), tol=1e-12,
                                              params={"tq": _scaled(home.params["tq"], agr, 2.0)})
    trade = trade_model(**TRADE_SETTINGS)
    for name, solution in run_simulations(trade).items():
        out["trade_" + name] = solution
    C = trade.sets["C"]
    out["trade_world_demand_up10"] = trade.solve(Closure(), tol=1e-12,
                                                 params={"pwe": _scaled(trade.params["pwe"], C.index("com_man"), 1.1)})
    out["trade_cash_price_down20"] = trade.solve(Closure(), tol=1e-12,
                                                 params={"pwe": _scaled(trade.params["pwe"], C.index("com_cash"), 0.8)})
    xonly = trade_model(by_market=False, export_only=["com_cash"])
    out["xonly_tariff_removal"] = xonly.solve(Closure(), tol=1e-12, **simulation_inputs(xonly)["tariff_removal"])
    plain = trade_model(by_market=False)
    out["tradeplain_tariff_removal"] = plain.solve(Closure(), tol=1e-12, **simulation_inputs(plain)["tariff_removal"])
    return out


# Labour-market regimes (version 0.3.3, model_spec.md, Section 14): 15 per
# cent unemployment with a wage curve or a binding minimum wage; full
# employment with a floor at 95 per cent of the base wage; 2 per cent
# unemployment at a binding floor. Test values, not estimates.
WAGE_CURVE = {"unemployment": {"lab": 0.15}, "wage_curve": {"lab": 0.1}}


def labour_inputs(model: Model) -> dict[str, dict]:
    """The standard shocks, with a larger labour force in place of more labour supply."""
    sims = simulation_inputs(model)
    del sims["labour_supply_up5"]
    lab = model.sets["F"].index("lab")
    sims["labour_force_up5"] = {"params": {"qlf": _scaled(model.params["qlf"], lab, 1.05)}}
    return sims


def labour_cases() -> dict:
    """Static simulations under labour-market regimes: name -> solution."""
    out = {}
    wc_closure = Closure(factors={"lab": "wagecurve"})
    mw_closure = Closure(factors={"lab": "minwage"})
    wc = synthetic_model(**WAGE_CURVE)
    for name, shock in labour_inputs(wc).items():
        out["wc_" + name] = wc.solve(wc_closure, tol=1e-12, **shock)
    out["wc_dpi_tariff_removal"] = wc.solve(Closure(numeraire="dpi", factors={"lab": "wagecurve"}), tol=1e-12,
                                            **simulation_inputs(wc)["tariff_removal"])
    mw = synthetic_model(unemployment={"lab": 0.15})
    for name, shock in labour_inputs(mw).items():
        out["mw_" + name] = mw.solve(mw_closure, tol=1e-12, **shock)
    nb = synthetic_model(min_wage={"lab": 0.95})
    out["mwnb_foreign_savings_down20"] = nb.solve(mw_closure, tol=1e-12,
                                                  **simulation_inputs(nb)["foreign_savings_down20"])
    out["mwnb_pwm_up50"] = nb.solve(mw_closure, tol=1e-12, params={"pwm": nb.params["pwm"] * 1.5})
    lo = synthetic_model(unemployment={"lab": 0.02})
    out["mwlo_productivity_up5"] = lo.solve(mw_closure, tol=1e-12, params={"ad": lo.params["ad"] * 1.05})
    return out


# Health outcomes (version 0.3.4, model_spec.md, Section 15): 5 per cent of
# labour's working time lost to illness, a death rate of 10 per 1,000, and
# their elasticities with respect to health services per head. Test values,
# not estimates.
OUTCOMES = {"health_commodities": ["com_hlt"], "sick_days": {"lab": 0.05}, "sick_elasticity": {"lab": -0.4},
            "mortality": 0.01, "mortality_elasticity": -0.3}
DEATHS = {"death_factors": ("lab",), "death_share": 0.3, "working_age": 0.55}


def outcome_cases() -> dict:
    """Static simulations with health outcomes: name -> solution."""
    out = {}
    m = health_model(**OUTCOMES)
    for name, solution in run_simulations(m).items():
        out["hout_" + name] = solution
    p = m.params
    hlt = m.sets["C"].index("com_hlt")
    lab = m.sets["F"].index("lab")
    out["hout_gov_health_up20"] = m.solve(Closure(), tol=1e-12, params={"qg": _scaled(p["qg"], hlt, 1.2)})
    out["hout_epidemic"] = m.solve(Closure(), tol=1e-12, params={"sick": _scaled(p["sick"], lab, 2.0)})
    out["hout_mortality_up50"] = m.solve(Closure(), tol=1e-12, params={"mort": p["mort"] * 1.5})
    out["hout_epidemic_unemployed"] = m.solve(Closure(factors={"lab": "unemployed"}), tol=1e-12,
                                              params={"sick": _scaled(p["sick"], lab, 2.0)})
    both = health_model(**{**OUTCOMES, **HEALTH_LINK})
    out["hboth_gov_health_up20"] = both.solve(Closure(), tol=1e-12,
                                              params={"qg": _scaled(both.params["qg"], hlt, 1.2)})
    return out


# Bounds and complementarity (version 0.4.4, model_spec.md, Section 16). The
# bounds are test values: an import quota 2 per cent above base imports of
# manufactures; an export quota; a limit on the output of services; a limit
# on foreign borrowing under a fixed exchange rate; a government that may
# not borrow (GSAV >= 0); a floor on the nominal wage
def constraint_cases() -> dict:
    """name -> (model, closure, shock, constraints)."""
    from .model import Constraint
    std = synthetic_model()
    b, p = std.base, std.params
    C, A = std.sets["C"], std.sets["A"]
    man, ser = C.index("com_man"), C.index("com_ser")
    notariff = {"params": {"tm": np.zeros_like(p["tm"])}}

    def quota(**kw):
        return [Constraint("QM", ("com_man",), upper=1.02 * b["QM"][man], **kw)]

    no_borrowing = Constraint("GSAV", (), lower=0.0, adjust="GADJ", direction="down")
    health = health_model()
    hlt, ahlt = health.sets["C"].index("com_hlt"), health.sets["A"].index("act_hlt")
    return {
        "con_quota": (std, Closure(), notariff, quota()),
        "con_quota_hhd": (std, Closure(), notariff, quota(rents="hhd")),
        "con_quota_row": (std, Closure(), notariff, quota(rents="row")),
        "con_quota_slack": (std, Closure(), notariff, [Constraint("QM", ("com_man",), upper=2 * b["QM"][man])]),
        "con_quota_base": (std, Closure(), {}, [Constraint("QM", ("com_man",), upper=b["QM"][man])]),
        "con_export_quota": (std, Closure(), {"params": {"pwe": _scaled(p["pwe"], man, 1.2)}},
                             [Constraint("QE", ("com_man",), upper=1.05 * b["QE"][man])]),
        "con_capacity": (std, Closure(), {"params": {"qg": _scaled(p["qg"], ser, 1.5)}},
                         [Constraint("QA", ("act_ser",), upper=1.01 * b["QA"][A.index("act_ser")], rents="cap")]),
        "con_peg_limit": (std, Closure(external="fixexr"), {"params": {"pwe": p["pwe"] * 0.8}},
                          [Constraint("FSAV", (), upper=2 * b["FSAV"][0], adjust="EXR", direction="up")]),
        "con_deficit_spending": (std, Closure(), notariff, [no_borrowing]),
        "con_deficit_tax": (std, Closure(), notariff,
                            [Constraint("GSAV", (), lower=0.0, adjust="TINSADJ", direction="up")]),
        "con_wage_floor": (std, Closure(), {"params": {"pwm": p["pwm"] * 1.1}},
                           [Constraint("W", ("lab",), lower=b["W"][0], adjust="QFS", direction="down")]),
        "con_two": (std, Closure(), notariff, quota() + [no_borrowing]),
        "con_health_capacity": (health, Closure(), {"params": {"qg": _scaled(health.params["qg"], hlt, 1.2)}},
                                [Constraint("QA", ("act_hlt",), upper=1.03 * health.base["QA"][ahlt],
                                            rents="hhd")]),
    }


def constraint_solutions() -> dict:
    return {name: model.solve(closure, tol=1e-12, constraints=cons, **shock)
            for name, (model, closure, shock, cons) in constraint_cases().items()}


def write_regimes(solutions: dict, directory: Path = EXPECTED_DIR) -> list[Path]:
    """Regime of each constraint (version 0.4.4): 1 binding, 0 not."""
    path = directory / "con_regimes.csv"
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["case", "constraint", "binding"])
        for name, solution in solutions.items():
            if name.startswith("con_"):
                for k, binding in enumerate(solution.binding):
                    writer.writerow([name, k + 1, int(binding)])
    return [path]


# Closure swaps (version 0.4.5, model_spec.md, Section 6): government savings
# fixed with government consumption adjusting, and the exchange rate as
# numeraire
def swap_cases() -> dict:
    """name -> solution."""
    std = synthetic_model()
    notariff = {"params": {"tm": np.zeros_like(std.params["tm"])}}
    return {
        "swap_gsav_gadj": std.solve(Closure(swaps=(("GSAV", "GADJ"),)), tol=1e-12, **notariff),
        "swap_exr_numeraire": std.solve(Closure(swaps=(("EXR", "CPI"),)), tol=1e-12, **notariff),
    }


def health_spending_up(t, p, fx):
    """Government purchases of health services 20 per cent higher from period 1."""
    if t == 1:
        hlt = list(health_mapping().commodities).index("com_hlt")
        p["qg"] = _scaled(p["qg"], hlt, 1.2)


# SAM tools (version 0.3.0, docs/sam_tools.md): a SYNTHETIC unbalanced SAM,
# and the institutions layout aggregated to two sectors and one household
UNBALANCED_SAM = REPO / "data" / "cge_synthetic_sam_unbal.csv"
AGGREGATION = {"act_nag": ["act_man", "act_ser"], "com_nag": ["com_man", "com_ser"], "hh": ["hhd", "npi"]}


def balance_cases() -> dict:
    """Balanced SAMs compared by the Stata suite: name -> (SAM, info)."""
    from .samtools import cross_entropy, ras
    unbal = SAM.from_csv(UNBALANCED_SAM)
    return {
        "ras": ras(unbal, tol=1e-12),
        "ras_fixed": ras(unbal, targets="rows", totals={"gov": 71.0},
                         fixed=["hhd:lab", "com_man:sav", "ent:cap"], tol=1e-12),
        "ce": cross_entropy(unbal, tol=1e-12),
        "ce_totals": cross_entropy(unbal, totals={"act_agr": 97.0, "hhd": 290.0},
                                   fixed=["row:*", "hhd:lab"], tol=1e-12),
    }


def aggregated_sam() -> SAM:
    from .samtools import aggregate
    return aggregate(SAM.from_csv(INSTITUTIONS_SAM), AGGREGATION)


def aggregated_mapping() -> Mapping:
    return Mapping(activities=["act_agr", "act_nag"], commodities=["com_agr", "com_nag"],
                   factors=["lab", "cap"], households=["hh"], enterprises=["ent"],
                   government="gov", savinv="sav", row="row", dirtax="tax_dir",
                   saltax="tax_sal", imptax="tax_imp")


def aggregated_model(**elasticities) -> Model:
    settings = {**TEST_ELASTICITIES, **elasticities}
    return Model(aggregated_sam(), aggregated_mapping(), **settings)


def write_samtools(directory: Path = EXPECTED_DIR) -> list[Path]:
    """Balanced and aggregated SAMs (version 0.3.0)."""
    from .samtools import write_sam
    written = []
    for name, (sam, info) in balance_cases().items():
        path = directory / f"samtools_{name}.csv"
        write_sam(sam, path)
        written.append(path)
    path = directory / "samtools_agg.csv"
    write_sam(aggregated_sam(), path)
    written.append(path)
    return written


def multiplier_cases() -> dict:
    """SAM multipliers (version 0.4.1): name -> (model, settings); settings are
    the arguments of cge_ref.multipliers.multipliers()."""
    return {
        "std": (synthetic_model(), {"decompose": True}),
        "inst": (institutions_model(), {"decompose": True}),
        "health": (health_model(), {"decompose": True}),
        "sut": (sut_model(), {"decompose": True}),
        # the government in the institutions block and the enterprise exogenous
        "inst_gov": (institutions_model(), {"endogenous": ["gov"], "exogenous": ["ent"], "decompose": True}),
        # without decomposition
        "std_plain": (synthetic_model(), {}),
    }


def write_multipliers(directory: Path = EXPECTED_DIR) -> list[Path]:
    """Accounting multipliers and, where defined, their decomposition: one row
    per pair of endogenous accounts."""
    from .multipliers import from_model
    written = []
    for name, (model, settings) in multiplier_cases().items():
        r = from_model(model, **settings)
        path = directory / f"multipliers_{name}.csv"
        parts = ["transfer", "open_loop", "closed_loop"] if r.parts else []
        with path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle, lineterminator="\n")
            writer.writerow(["row", "column", "multiplier"] + parts)
            for i, a in enumerate(r.labels):
                for j, b in enumerate(r.labels):
                    writer.writerow([a, b, f"{r.M[i, j]:.15g}"] + [f"{r.parts[k][i, j]:.15g}" for k in parts])
        written.append(path)
    return written


def spa_cases() -> dict:
    """Structural path analysis (version 0.4.2): name -> (model, origin,
    destination, maxlength, threshold)."""
    return {
        "health": (health_model(), "com_hlt", "hhd", 6, 0.001),
        "std": (synthetic_model(), "com_agr", "hhd", 6, 0.001),
        "inst": (institutions_model(), "com_ser", "npi", 8, 0.0001),
        "sut_all": (sut_model(), "com_fuel", "hhd", 12, 0.0),
    }


def write_spa(directory: Path = EXPECTED_DIR) -> list[Path]:
    """Paths, with direct influence, path multiplier and total influence, and
    the global influence on the first line."""
    from .multipliers import from_model, structural_paths
    written = []
    for name, (model, origin, destination, maxlength, threshold) in spa_cases().items():
        glob, paths = structural_paths(from_model(model), origin, destination, maxlength, threshold)
        path = directory / f"spa_{name}.csv"
        with path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle, lineterminator="\n")
            writer.writerow(["path", "length", "direct", "multiplier", "total"])
            writer.writerow(["_global", 0, f"{glob:.15g}", 1, f"{glob:.15g}"])
            for q in paths:
                writer.writerow([" > ".join(q.poles), len(q.poles) - 1, f"{q.direct:.15g}",
                                 f"{q.multiplier:.15g}", f"{q.total:.15g}"])
        written.append(path)
    return written


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
            "sut_import_price_up10", "eff_contribution_up50", "vat_rate_up20",
            "vat_tariff_removal_vat", "rep_tariff_removal_sales", "debt_rate_up", "debt_relief",
            "home_tariff_removal", "home_les_tariff_removal", "trade_world_demand_up10",
            "wc_tariff_removal", "mwnb_pwm_up50", "hout_gov_health_up20", "hout_epidemic",
            "hout_mortality_up50", "hboth_gov_health_up20", "con_quota_row", "con_capacity",
            "con_export_quota", "ftax_payroll_cut")


def dynamic_cases() -> dict:
    """Dynamic runs compared by the Stata suite (version 0.2.0): name ->
    (model, settings, closure, shocks)."""
    from .dynamics import Dynamics
    specific = Closure(factors={"cap": "specific"})
    std = synthetic_model()
    common = {"capital": {"cap": (0.05, 0.15)}, "factor_growth": {"lab": 0.02}, "population_growth": 0.02,
              "government_growth": 0.03, "foreign_growth": 0.01}
    inst = institutions_model(income_elasticities=LES_SETTINGS["income_elasticities"], frisch=[-2.0, -3.0])
    health = health_model(**HEALTH_LINK)
    return {
        "dyn_std": (std, Dynamics(periods=4, tfp_growth=0.01, **common), specific, None),
        "dyn_target": (std, Dynamics(periods=4, gdp_target=0.04, **common), specific, None),
        "dyn_inst": (inst, Dynamics(periods=4, capital={"cap": (0.06, 0.12)}, factor_growth={"lab": 0.025},
                                    population_growth=0.025, government_growth=0.03, foreign_growth=0.02,
                                    tfp_growth={"act_agr": 0.02, "act_man": 0.01, "act_ser": 0.0}),
                     Closure(), None),
        "dyn_health": (health, Dynamics(periods=4, gdp_target=0.03, **common), specific, None),
        # Public debt (version 0.3.1): deficits are borrowed; debt relief in period 2
        "dyn_debt": (debt_model(), Dynamics(periods=4, tfp_growth=0.01, **common), specific, None),
        "dyn_debt_relief": (debt_model(), Dynamics(periods=4, tfp_growth=0.01, **common), specific,
                            debt_relief),
        # Home consumption with LES demand (version 0.3.2): subsistence grows with population
        "dyn_home": (home_model(**LES_SETTINGS), Dynamics(periods=4, tfp_growth=0.01, **common), specific, None),
        # A wage curve (version 0.3.3): the labour force grows at 2 per cent
        "dyn_wc": (synthetic_model(**WAGE_CURVE), Dynamics(periods=4, tfp_growth=0.01, **common),
                   Closure(factors={"cap": "specific", "lab": "wagecurve"}), None),
        # Health outcomes and deaths (version 0.3.4): a baseline, and more
        # government health services from period 1
        "dyn_hout": (health_model(**OUTCOMES), Dynamics(periods=4, tfp_growth=0.01, **common, **DEATHS),
                     specific, None),
        "dyn_hout_health": (health_model(**OUTCOMES), Dynamics(periods=4, tfp_growth=0.01, **common, **DEATHS),
                            specific, health_spending_up),
    }


def write_dynamic(directory: Path = EXPECTED_DIR) -> list[Path]:
    """Expected results of the dynamic runs: one file per run and period, and
    the efficiency factors of each run."""
    from .dynamics import Dynamics, run
    written = []
    runs = {}
    for name, (model, settings, closure, shocks) in dynamic_cases().items():
        runs[name] = run(model, settings, closure, shocks)
    # A donor exit from the fund from period 2, with the baseline's efficiency path
    model, settings, closure, _ = dynamic_cases()["dyn_health"]

    def donor_exit(t, p, fx):
        if t >= 2:
            p["trshir"] = np.array(0.0)

    exit_settings = Dynamics(**{**settings.__dict__, "gdp_target": None, "tfp_path": runs["dyn_health"].tfp_path})
    runs["dyn_health_exit"] = run(model, exit_settings, closure, donor_exit)
    for name, r in runs.items():
        for t, sol in enumerate(r.solutions):
            path = directory / f"{name}_p{t}.csv"
            write_results(sol, path)
            written.append(path)
            if name.startswith("dyn_debt") or name.startswith("dyn_hout"):
                path = directory / f"report_{name}_p{t}.csv"
                write_report(sol, path)
                written.append(path)
        path = directory / f"{name}_tfp.csv"
        with path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle, lineterminator="\n")
            writer.writerow(["period", "lambda"])
            for t, lam in enumerate(r.tfp_path, start=1):
                writer.writerow([t, f"{lam:.15g}"])
        written.append(path)
    return written


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
    # An aggregated SAM (version 0.3.0)
    for name, solution in run_simulations(aggregated_model()).items():
        solutions["agg_" + name] = solution
    # Fiscal instruments (version 0.3.1); trade and household extensions (0.3.2)
    solutions.update(fiscal_cases())
    solutions.update(trade_cases())
    # Labour-market regimes (0.3.3); health outcomes (0.3.4)
    solutions.update(labour_cases())
    solutions.update(outcome_cases())
    # Bounds and complementarity (0.4.4); closure swaps (0.4.5)
    solutions.update(constraint_solutions())
    solutions.update(swap_cases())
    # Taxes on factor use and income (0.5.0)
    solutions.update(factor_tax_cases())
    written = (write_dynamic(directory) + write_samtools(directory) + write_multipliers(directory)
               + write_spa(directory) + write_regimes(solutions, directory))
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
