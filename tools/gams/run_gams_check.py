"""Check the model against an independent GAMS implementation (from version 0.1.16).

tools/gams/cge_model.gms implements docs/model_spec.md in GAMS, written from
the specification. This script, for every case of the Python test suite:

1. prepares the SAM with the reference model's layout rewrites (Section 7.0)
   and writes it, with the mapping and the elasticities supplied by the user,
   to a GAMS include file -- no calibrated value is passed to GAMS;
2. runs GAMS, which calibrates, solves the base and saves a work file;
3. solves every scenario in GAMS (cge_scenario.gms), with shocks expressed as
   changes to GAMS's own calibrated parameters and fixed variables;
4. compares the GAMS base and solution with the expected results that the
   Stata suite also matches (tests/expected), and, for alternative closures,
   with the Python reference.

Usage (GAMS with PATH required):
    python tools/gams/run_gams_check.py [--gams C:/GAMS/54/gams.exe] [--work DIR]
        [--solver path|conopt|knitro|ipopt] [--type cns|nlp] [--only TEXT]

The model files are those installed with the package (ado/cge_model.gms,
cge_closure.gms, cge_write.gms and cge_solve.gms), which cge_gams also uses.

Writes tools/gams/gams_check_results.csv (one row per scenario). GAMS listing
files stay in the work directory (outside Dropbox by default); they name the
licence holder and are not part of the repository.
"""

from __future__ import annotations

import argparse
import csv
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(REPO / "reference"))

from cge_ref import Closure  # noqa: E402
from cge_ref import scenarios as sc  # noqa: E402

EXPECTED = REPO / "tests" / "expected"
# The model files are installed with the package (ado/); the restart file
# for scenarios is part of the check
MODEL_FILES = ("cge_model.gms", "cge_closure.gms", "cge_write.gms", "cge_solve.gms")
CHECK_FILES = ("cge_scenario.gms",)
# Python parameter names and their GAMS names (shockable parameters)
PARAMS = {"pwm": "pwm", "pwe": "pwe", "tm": "tm", "te": "te", "tq": "tq", "ta": "ta", "ad": "ad",
          "qg": "qgbar", "qinv": "qinvbar", "trdg": "trdg", "trdr": "trdr", "trfr": "trfr",
          "trgr": "trgr", "trrg": "trrg", "tshi": "tshi", "qshi": "qshibar", "trshi": "trshi",
          "trshir": "trshir", "af": "af", "tv": "tv", "kappa": "kappa", "rd": "rd", "rf": "rf",
          "ddebt": "ddebt", "fdebt": "fdebt", "qlf": "qlf", "wmin": "wmin", "wref": "wref",
          "sick": "sick", "tfy": "tfy"}
PARAM_SETS = {"pwm": "C", "pwe": "C", "tm": "C", "te": "C", "tq": "C", "ta": "A", "ad": "A", "qg": "C",
              "qinv": "C", "trdg": "D", "trdr": "D", "trfr": "F", "tshi": "F", "qshi": "C", "af": "F",
              "tv": "C", "kappa": "A", "qlf": "F", "wmin": "F", "wref": "F", "sick": "F", "tfy": "F"}
FIXED_SETS = {"QFS": "F", "FSAV": "", "EXR": "", "GSAV": "", "IADJ": "", "MPSADJ": "", "TINSADJ": "",
              "CPI": "", "DPI": "", "W": "F", "GADJ": ""}


def q(label: str) -> str:
    return "'" + label + "'"


def num(x) -> str:
    """A number at full precision, in a form GAMS reads."""
    return repr(float(x))


def gams_set(name: str, elements, domain: str = "AC") -> str:
    body = ", ".join(q(e) for e in elements)
    return f"set {name}({domain}) / {body} /;"


def write_data(model, les: dict | None, path: Path, vat_credit=None, debt: dict | None = None,
               trade: dict | None = None, labour: dict | None = None, outcomes: dict | None = None,
               fq: dict | None = None) -> None:
    """The prepared SAM, the mapping and the settings supplied by the user (elasticities,
    VAT credit shares, debt and interest rates, unemployment rates, wage-curve
    elasticities and minimum wages, and the shares of working time lost to
    illness and their elasticities) as a GAMS include file."""
    m, sam, S, p = model.mapping, model.sam, model.sets, model.params
    lines = ["* data for cge_model.gms, written by run_gams_check.py",
             "set AC 'accounts' / " + ", ".join(q(a) for a in sam.labels) + " /;"]
    trade = trade or {}
    roles = {"A": S["A"], "C": S["C"], "F": S["F"], "H": S["H"], "E": S["E"], "T": m.margin_accounts,
             "TD": m.domestic_margins, "TIM": m.import_margins, "TEX": m.export_margins,
             "XO": list(trade.get("export_only", [])),
             "GOVS": [m.government], "ROWS": [m.row], "SAVS": [m.savinv],
             "SHIS": [m.insurance] if m.insurance else [], "DTAXS": [m.dirtax] if m.dirtax else [],
             "STAXS": [m.saltax] if m.saltax else [], "MTAXS": [m.imptax] if m.imptax else [],
             "ETAXS": [m.exptax] if m.exptax else [], "ATAXS": [m.acttax] if m.acttax else [],
             "VTAXS": [m.vattax] if m.vattax else [],
             "HCOM": [c for c, h in zip(S["C"], model.struct["hc"]) if h],
             # taxes on factor use and income (version 0.5.0)
             "FTAXS": list(m.factor_taxes),
             "FYTAXS": [m.factor_income_tax] if m.factor_income_tax else []}
    lines += [gams_set(k, v) for k, v in roles.items()]
    cells = [f"{q(r)}.{q(c)} {num(sam.values[i, j])}" for i, r in enumerate(sam.labels)
             for j, c in enumerate(sam.labels) if sam.values[i, j] != 0]
    lines.append("parameter SAM(AC, AC) /\n" + ",\n".join(cells) + "\n/;")
    pairs = [f"{q(acc)}.{q(f)} 1" for acc, f in m.factor_taxes.items()]
    lines.append("parameter ftfac(AC, AC) /" + (" " + ", ".join(pairs) if pairs else "") + " /;")
    # nests of value added (version 0.5.1): members and elasticities
    N, st = S["N"], model.struct
    members = ([f"{q(N[n])}.{q(f)}" for f, n in zip(S["F"], st["nest_f"]) if n >= 0]
               + [f"{q(N[n])}.{q(c)}" for c, n in zip(S["C"], st["nest_c"]) if n >= 0])
    lines.append("set NST(*) 'nests of value added' / " + ", ".join(q(n) for n in N) + " /;")
    lines.append("set NSTF(NST, AC) / " + ", ".join(members) + " /;")
    lines.append("parameter signest(NST) / " + ", ".join(f"{q(n)} {num(s)}" for n, s in zip(N, p["sigma_n"])) + " /;")

    def param(name, labels, values):
        body = ", ".join(f"{q(e)} {num(v)}" for e, v in zip(labels, values) if v != 0)
        return f"parameter {name}(AC) / {body} /;"

    lines.append(param("sigva", S["A"], p["sigma_va"]))
    lines.append(param("sigq", S["C"], p["sigma_q"]))
    lines.append(param("sigt", S["C"], p["sigma_t"]))
    lines.append(param("siga", S["A"], p["sigma_a"]))
    # output from several activities (version 0.5.2): 0 for perfect substitutes
    lines.append(param("sigac", S["C"], p["sigma_ac"]))
    lines.append(param("eta", S["F"], p["eta_h"]))
    if les:
        lines.append(param("incel", S["C"], [les["income_elasticities"][c] for c in S["C"]]))
        frisch = les["frisch"]
        frisch = [frisch] * len(S["H"]) if np.ndim(frisch) == 0 else list(frisch)
        lines.append(param("frisch", S["H"], frisch))
        lines.append("scalar les / 1 /;")
        # home goods: the income elasticity of the activity's paired commodity
        lines.append(param("incelh", S["A"], [les["income_elasticities"][model.paired[a]] for a in S["A"]]))
    else:
        lines += ["parameter incel(AC) / /;", "parameter frisch(AC) / /;", "scalar les / 0 /;",
                  "parameter incelh(AC) / /;"]
    demand = trade.get("export_demand", {})
    lines.append(param("etae", S["C"], [demand.get(c, 0.0) for c in S["C"]]))
    # VAT credit shares by activity (1, full credit, unless given)
    credit = {a: 1.0 for a in S["A"]}
    if isinstance(vat_credit, dict):
        credit.update(vat_credit)
    elif vat_credit is not None:
        credit = {a: float(vat_credit) for a in S["A"]}
    lines.append(param("kappain", S["A"], [credit[a] for a in S["A"]]))
    # Public debt: the stocks and rates given by the user; holders and the
    # foreign share of borrowing are left to their defaults
    debt = debt or {}
    stocks, rates = debt.get("debt", {}), debt.get("interest", {})
    lines += [f"scalar debtin / {1 if debt else 0} /;",
              f"scalar ddebtin / {num(stocks.get('domestic', 0.0))} /;",
              f"scalar fdebtin / {num(stocks.get('foreign', 0.0))} /;",
              f"scalar rdin / {num(rates.get('domestic', 0.0))} /;",
              f"scalar rfin / {num(rates.get('foreign', 0.0))} /;",
              "scalar holdgiven / 0 /;", "parameter holdin(AC) / /;",
              "scalar phigiven / 0 /;", "scalar phiin / 0 /;"]
    # Labour-market regimes (Section 14)
    labour = labour or {}
    un, wc, mw = labour.get("unemployment", {}), labour.get("wage_curve", {}), labour.get("min_wage", {})
    F = S["F"]
    lines.append(param("unin", F, [un.get(f, 0.0) for f in F]))
    lines.append(param("ungiven", F, [1.0 if f in un else 0.0 for f in F]))
    lines.append(param("wcin", F, [wc.get(f, 0.0) for f in F]))
    lines.append(param("mwin", F, [mw.get(f, 0.0) for f in F]))
    lines.append(param("mwgiven", F, [1.0 if f in mw else 0.0 for f in F]))
    lines.append(f"scalar muin / {num(labour.get('smoothing', 1e-10))} /;")
    # Health outcomes (Section 15): the death rate does not enter the equations
    outcomes = outcomes or {}
    sick, sickel = outcomes.get("sick_days", {}), outcomes.get("sick_elasticity", {})
    lines.append(param("sickin", F, [sick.get(f, 0.0) for f in F]))
    lines.append(param("sickgiven", F, [1.0 if f in sick else 0.0 for f in F]))
    lines.append(param("sickelin", F, [sickel.get(f, 0.0) for f in F]))
    lines.append(f"scalar mortelin / {num(outcomes.get('mortality_elasticity') or 0.0)} /;")
    # Factor quantities (from version 0.4.3): base factor use where given
    if fq:
        cells = [f"{q(f)}.{q(a)} {num(v)}" for (f, a), v in fq.items() if v != 0]
        lines += ["scalar fqgiven / 1 /;", "parameter fqin(AC, AC) /\n" + ",\n".join(cells) + "\n/;"]
    else:
        lines += ["scalar fqgiven / 0 /;", "parameter fqin(AC, AC) / /;"]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def shock_statements(model, shock: dict, closure: Closure) -> tuple[str, str]:
    """GAMS statements for a scenario: parameter changes and the closure; then
    changes to fixed variables. Changes are ratios to the base where the base
    is not zero, so GAMS applies them to its own calibrated values."""
    S = {**model.sets, "": [""]}
    par, var = ["* parameter changes and closure"], ["* fixed-variable changes"]
    for name, new in shock.get("params", {}).items():
        if name == "tf":
            # taxes on factor use, by factor and activity (version 0.5.0)
            for i, f in enumerate(model.sets["F"]):
                for k, a in enumerate(model.sets["A"]):
                    b0, b1 = model.params["tf"][i, k], np.asarray(new)[i, k]
                    if b1 != b0:
                        target = f"tf({q(f)}, {q(a)})"
                        par.append(f"{target} = {num(b1 / b0)} * {target};" if b0 != 0 else f"{target} = {num(b1)};")
            continue
        base = np.atleast_1d(model.params[name])
        new = np.atleast_1d(new)
        labels = S[PARAM_SETS.get(name, "")]
        g = PARAMS[name]
        for k, label in enumerate(labels):
            if new[k] == base[k]:
                continue
            target = f"{g}({q(label)})" if label else g
            rhs = f"{num(new[k] / base[k])} * {target}" if base[k] != 0 else num(new[k])
            par.append(f"{target} = {rhs};")
    cl = {"external": ("clext", ["flexexr", "fixexr"]),
          "government": ("clgov", ["flexgsav", "fixgsav", "fixgsav sales", "fixgsav import", "fixgsav vat"]),
          "savinv": ("clsi", ["savings", "investment"]), "numeraire": ("clnum", ["cpi", "dpi"])}
    for attr, (flag, options) in cl.items():
        value = getattr(closure, attr)
        value = "fixgsav" if value == "fixgsav direct" else value
        par.append(f"{flag} = {options.index(value) + 1};")
    codes = {"mobile": 1, "specific": 2, "unemployed": 3, "wagecurve": 4, "minwage": 5}
    for f in model.sets["F"]:
        par.append(f"fclo({q(f)}) = {codes[closure.factors.get(f, 'mobile')]};")
    # Closure swaps (version 0.4.5): fixed at their current levels, or freed
    for fix, free in closure.swaps:
        for spec, freed in ((fix, False), (free, True)):
            name, k = model.position(spec)
            ref, level = gams_ref(model, name, k)
            g = "PWEV" if name == "PWE" else name
            idx = ref[len(g):]
            var += ([f"{g}.lo{idx} = -inf;", f"{g}.up{idx} = inf;"] if freed else [f"{g}.fx{idx} = {level};"])
    for name, new in shock.get("fixed", {}).items():
        base = np.atleast_1d(model.base[name]).ravel()
        new = np.atleast_1d(new).ravel()
        labels = S[FIXED_SETS[name]]
        for k, label in enumerate(labels):
            if new[k] == base[k]:
                continue
            target = f"{name}.fx({q(label)})" if label else f"{name}.fx"
            level = f"{name}.l({q(label)})" if label else f"{name}.l"
            rhs = f"{num(new[k] / base[k])} * {level}" if base[k] != 0 else num(new[k])
            var.append(f"{target} = {rhs};")
    return "\n".join(par) + "\n", "\n".join(var) + "\n"


def gams_ref(model, name: str, k: int) -> tuple[str, str]:
    """A variable element as GAMS writes it, and its level."""
    e1, e2 = model.element_labels(name)[k]
    g = "PWEV" if name == "PWE" else name
    idx = "" if not e1 else (f"({q(e1)})" if not e2 else f"({q(e1)}, {q(e2)})")
    return g + idx, g + ".l" + idx


def constraint_statements(model, cons, closure: Closure) -> str:
    """Constraints (model_spec.md, Section 16) as a mixed complementarity
    problem: for each, a slack SLK >= 0 paired with the bound,
    sigma (b - Y) / sY >= 0, and the adjusting variable freed and linked to
    its fixed level, X = xbar + delta sX SLK; then model cgecon."""
    fixed = closure.fixed(model)
    lines = ["* constraints, written by run_gams_check.py"]
    pairs = []
    rec = {"RM": "rmto", "RE": "reto", "RA": "rato"}
    for k, c in enumerate(cons, 1):
        r = model._constraint(c, fixed)
        (yname, yi), (xname, xi) = r["y"], r["x"]
        y, _ = gams_ref(model, yname, yi)
        x, xl = gams_ref(model, xname, xi)
        xg = "PWEV" if xname == "PWE" else xname
        idx = x[len(xg):]
        lines += [f"positive variable SLK{k};", f"equations BND{k}, LNK{k};", f"scalar xbar{k};",
                  f"xbar{k} = {xl};",
                  f"BND{k}.. ({num(r['sigma'])}) * (({num(r['bound'])}) - {y}) / {num(r['sy'])} =g= 0;",
                  f"LNK{k}.. {x} =e= xbar{k} + ({num(r['delta'])}) * {num(r['sx'])} * SLK{k};",
                  f"{xg}.lo{idx} = -inf;", f"{xg}.up{idx} = inf;", f"SLK{k}.l = 0;"]
        if c.rents is not None:
            el = model.element_labels(xname)[xi][0]
            lines += [f"{rec[xname]}(AC, {q(el)}) = 0;", f"{rec[xname]}({q(c.rents)}, {q(el)}) = 1;"]
        pairs += [f"LNK{k}", f"BND{k}.SLK{k}"]
    lines += ["model cgecon / cge, " + ", ".join(pairs) + " /;", "cgecon.optfile = cge.optfile;"]
    return "\n".join(lines) + "\n"


def run_gams(gams: str, args: list[str], cwd: Path) -> None:
    r = subprocess.run([gams, *args, "lo=0"], cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        lst = cwd / (Path(args[0]).stem + ".lst")
        tail = lst.read_text(encoding="utf-8", errors="replace")[-3000:] if lst.exists() else r.stdout[-3000:]
        raise RuntimeError(f"GAMS failed ({r.returncode}) on {args[0]} in {cwd}:\n{tail}")


def read_gams(path: Path) -> tuple[float, dict]:
    status, values = None, {}
    with path.open(encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            if row["variable"] == "__status__":
                status = float(row["value"])
            else:
                values[(row["variable"], row["element1"], row["element2"])] = float(row["value"])
    return status, values


def read_expected(name: str) -> list[tuple]:
    with (EXPECTED / f"{name}.csv").open(encoding="utf-8") as handle:
        return [((r["variable"], r["element1"], r["element2"]), float(r["base"]), float(r["value"]))
                for r in csv.DictReader(handle)]


def compare(reference: list[tuple], base: dict, value: dict) -> dict:
    out = {"rows": len(reference), "missing": 0, "base_maxrel": 0.0, "value_maxrel": 0.0, "walras_abs": 0.0}
    for key, b, v in reference:
        if key not in base or key not in value:
            out["missing"] += 1
            continue
        if key[0] == "WALRAS":
            out["walras_abs"] = max(out["walras_abs"], abs(value[key] - v))
            continue
        out["base_maxrel"] = max(out["base_maxrel"], abs(base[key] - b) / max(1.0, abs(b)))
        out["value_maxrel"] = max(out["value_maxrel"], abs(value[key] - v) / max(1.0, abs(v)))
    return out


def cases() -> list[dict]:
    """Every expected-results case of cge_ref.scenarios.write_expected, and
    alternative closures checked against the Python reference."""
    std = sc.synthetic_model()
    out = []

    def add(label, model, shocks, prefix="", les=None, closure=None, python=False, vat=None, debt=None,
            trade=None, labour=None, outcomes=None, fq=None, cons=None):
        out.append({"label": label, "model": model, "shocks": shocks, "prefix": prefix, "les": les,
                    "closure": closure or Closure(), "python": python, "vat": vat, "debt": debt,
                    "trade": trade, "labour": labour, "outcomes": outcomes, "fq": fq, "cons": cons})

    add("standard", std, sc.simulation_inputs(std))
    mixed = sc.synthetic_model(**sc.MIXED_ELASTICITIES)
    add("mixed", mixed, {"tariff_removal": sc.simulation_inputs(mixed)["tariff_removal"]}, "mixed_")
    inst = sc.institutions_model()
    add("institutions", inst, sc.simulation_inputs(inst), "inst_")
    nest = sc.synthetic_model(sigma_a=sc.TOP_NEST)
    add("top nest", nest, sc.simulation_inputs(nest), "nest_")
    les = sc.synthetic_model(**sc.LES_SETTINGS)
    add("LES", les, sc.simulation_inputs(les), "les_", les=sc.LES_SETTINGS)
    inst_les_settings = {"income_elasticities": sc.LES_SETTINGS["income_elasticities"], "frisch": [-2.0, -3.0]}
    inst_les = sc.institutions_model(**inst_les_settings)
    add("institutions LES", inst_les, {"tariff_removal": sc.simulation_inputs(inst_les)["tariff_removal"]},
        "inst_les_", les=inst_les_settings)
    add("spending", std, {"gov_ser_up20": {"params": {
        "qg": sc._scaled(std.params["qg"], std.sets["C"].index("com_ser"), 1.2)}}})
    add("transfers", inst, {"inst_transfers_abroad_down50": {"params": {"trdr": inst.params["trdr"] * 0.5}}})
    for label, model, prefix in (("margins", sc.margins_model(), "margins_"),
                                 ("territorial", sc.territorial_model(), "tc_"),
                                 ("multi-product", sc.multiproduct_model(), "mp_"),
                                 ("non-imported", sc.nonimported_model(), "cnm_"),
                                 ("supply-use", sc.sut_model(), "sut_")):
        add(label, model, sc.simulation_inputs(model), prefix)
    health = sc.health_model()
    lab = health.sets["F"].index("lab")
    shocks = sc.simulation_inputs(health)
    shocks["contribution_up50"] = {"params": {"tshi": sc._scaled(health.params["tshi"], lab, 1.5)}}
    shocks["gov_transfer_up50"] = {"params": {"trshi": health.params["trshi"] * 1.5}}
    add("insurance fund", health, shocks, "shi_")
    eff = sc.health_model(**sc.HEALTH_LINK)
    hlt = eff.sets["C"].index("com_hlt")
    shocks = sc.simulation_inputs(eff)
    shocks["gov_health_up20"] = {"params": {"qg": sc._scaled(eff.params["qg"], hlt, 1.2)}}
    shocks["contribution_up50"] = {"params": {"tshi": sc._scaled(eff.params["tshi"], lab, 1.5)}}
    shocks["labour_efficiency_down2"] = {"params": {"af": sc._scaled(eff.params["af"], lab, 0.98)}}
    add("health link", eff, shocks, "eff_")
    # Fiscal instruments (version 0.3.1, model_spec.md, Section 12)
    vat = sc.vat_model()
    p = vat.params
    shocks = sc.simulation_inputs(vat)
    shocks["rate_up20"] = {"params": {"tv": p["tv"] * 1.2}}
    shocks["credit_full"] = {"params": {"kappa": np.ones_like(p["kappa"])}}
    add("VAT", vat, shocks, "vat_", vat=sc.VAT_CREDIT)
    add("VAT, VAT replaces tariffs", vat, {"tariff_removal_vat": {"params": {"tm": np.zeros_like(p["tm"])}}},
        "vat_", closure=Closure(government="fixgsav vat"), vat=sc.VAT_CREDIT)
    add("VAT, tariffs replace VAT", vat, {"rate_cut_import": {"params": {"tv": p["tv"] * 0.8}}},
        "vat_", closure=Closure(government="fixgsav import"), vat=sc.VAT_CREDIT)
    notariff = {"tariff_removal_sales": {"params": {"tm": np.zeros_like(std.params["tm"])}}}
    add("sales tax replaces tariffs", std, notariff, "rep_", closure=Closure(government="fixgsav sales"))
    notariff = {"tariff_removal_direct": {"params": {"tm": np.zeros_like(std.params["tm"])}}}
    add("direct tax replaces tariffs", std, notariff, "rep_", closure=Closure(government="fixgsav"))
    vshare = sc.vatshare_model()
    add("VAT within the sales tax", vshare,
        {"tariff_removal": {"params": {"tm": np.zeros_like(vshare.params["tm"])}}}, "vshare_")
    intro = sc.vatshare_model(shares=0.0)
    add("VAT introduced", intro, {"vat10": {"params": {"tv": np.full_like(intro.params["tv"], 0.1)}}}, "vintro_")
    debt = sc.debt_model()
    p = debt.params
    add("public debt", debt, {"rate_up": {"params": {"rf": p["rf"] * 2}},
                              "relief": {"params": {"fdebt": p["fdebt"] * 0.5}}}, "debt_", debt=sc.DEBT)
    add("public debt, DPI numeraire", debt,
        {"tariff_removal_dpi": {"params": {"tm": np.zeros_like(p["tm"])}}}, "debt_",
        closure=Closure(numeraire="dpi"), debt=sc.DEBT)
    # Trade and household extensions (version 0.3.2, model_spec.md, Section 13)
    home = sc.home_model()
    shocks = sc.simulation_inputs(home)
    agr = home.sets["C"].index("com_agr")
    shocks["sales_tax_agr_up"] = {"params": {"tq": sc._scaled(home.params["tq"], agr, 2.0)}}
    add("home consumption", home, shocks, "home_")
    home_les = sc.home_model(**sc.LES_SETTINGS)
    add("home consumption, LES", home_les, {"les_tariff_removal": sc.simulation_inputs(home_les)["tariff_removal"]},
        "home_", les=sc.LES_SETTINGS)
    trade = sc.trade_model(**sc.TRADE_SETTINGS)
    C = trade.sets["C"]
    shocks = sc.simulation_inputs(trade)
    shocks["world_demand_up10"] = {"params": {"pwe": sc._scaled(trade.params["pwe"], C.index("com_man"), 1.1)}}
    shocks["cash_price_down20"] = {"params": {"pwe": sc._scaled(trade.params["pwe"], C.index("com_cash"), 0.8)}}
    add("trade", trade, shocks, "trade_", trade=sc.TRADE_SETTINGS)
    xonly = sc.trade_model(by_market=False, export_only=["com_cash"])
    add("export-only", xonly, {"tariff_removal": sc.simulation_inputs(xonly)["tariff_removal"]}, "xonly_",
        trade={"export_only": ["com_cash"]})
    plain = sc.trade_model(by_market=False)
    add("trade, composite margins", plain, {"tariff_removal": sc.simulation_inputs(plain)["tariff_removal"]},
        "tradeplain_")
    # Labour-market regimes (version 0.3.3, model_spec.md, Section 14)
    wcs = sc.WAGE_CURVE
    wc = sc.synthetic_model(**wcs)
    add("wage curve", wc, sc.labour_inputs(wc), "wc_", closure=Closure(factors={"lab": "wagecurve"}), labour=wcs)
    add("wage curve, DPI numeraire", wc, {"tariff_removal": sc.simulation_inputs(wc)["tariff_removal"]}, "wc_dpi_",
        closure=Closure(numeraire="dpi", factors={"lab": "wagecurve"}), labour=wcs)
    mwc = Closure(factors={"lab": "minwage"})
    settings = {"unemployment": {"lab": 0.15}}
    mw = sc.synthetic_model(**settings)
    add("minimum wage", mw, sc.labour_inputs(mw), "mw_", closure=mwc, labour=settings)
    settings = {"min_wage": {"lab": 0.95}}
    nb = sc.synthetic_model(**settings)
    add("minimum wage, full employment", nb,
        {"foreign_savings_down20": sc.simulation_inputs(nb)["foreign_savings_down20"],
         "pwm_up50": {"params": {"pwm": nb.params["pwm"] * 1.5}}}, "mwnb_", closure=mwc, labour=settings)
    settings = {"unemployment": {"lab": 0.02}}
    lo = sc.synthetic_model(**settings)
    add("minimum wage, low unemployment", lo, {"productivity_up5": {"params": {"ad": lo.params["ad"] * 1.05}}},
        "mwlo_", closure=mwc, labour=settings)
    # Health outcomes (version 0.3.4, model_spec.md, Section 15)
    out_settings = sc.OUTCOMES
    hout = sc.health_model(**out_settings)
    hlt, lab = hout.sets["C"].index("com_hlt"), hout.sets["F"].index("lab")
    shocks = sc.simulation_inputs(hout)
    shocks["gov_health_up20"] = {"params": {"qg": sc._scaled(hout.params["qg"], hlt, 1.2)}}
    shocks["epidemic"] = {"params": {"sick": sc._scaled(hout.params["sick"], lab, 2.0)}}
    add("health outcomes", hout, shocks, "hout_", outcomes=out_settings)
    add("health outcomes, unemployed labour", hout,
        {"epidemic_unemployed": {"params": {"sick": sc._scaled(hout.params["sick"], lab, 2.0)}}}, "hout_",
        closure=Closure(factors={"lab": "unemployed"}), outcomes=out_settings)
    both = sc.health_model(**{**out_settings, **sc.HEALTH_LINK})
    add("health outcomes and efficiency", both,
        {"gov_health_up20": {"params": {"qg": sc._scaled(both.params["qg"], hlt, 1.2)}}}, "hboth_",
        outcomes=out_settings)
    # Factor quantities (version 0.4.3): wages and wage distortions differ
    # from one in the base; CES and mixed elasticities, compared with the
    # Python reference
    workers = {("lab", "act_agr"): 80.0, ("lab", "act_man"): 20.0, ("lab", "act_ser"): 30.0,
               ("cap", "act_agr"): 37.0, ("cap", "act_man"): 40.0, ("cap", "act_ser"): 50.0}
    for label, settings in (("factor quantities", {}), ("factor quantities, mixed", sc.MIXED_ELASTICITIES)):
        fqm = sc.synthetic_model(factor_quantities=workers, **settings)
        sims = sc.simulation_inputs(fqm)
        pick = {k: sims[k] for k in ("tariff_removal", "labour_supply_up5", "agri_productivity_up5")}
        add(label, fqm, pick, "fq_" if not settings else "fqmix_", python=True, fq=workers)
    fqu = sc.synthetic_model(factor_quantities=workers, unemployment={"lab": 0.1})
    add("factor quantities, minimum wage", fqu,
        {"import_price_up10": sc.simulation_inputs(fqu)["import_price_up10"]}, "fqmw_", python=True,
        closure=Closure(factors={"lab": "minwage"}), labour={"unemployment": {"lab": 0.1}}, fq=workers)
    # Taxes on factor use and income (version 0.5.0, model_spec.md, Section 17.1)
    ftm = sc.factor_tax_model()
    lab = ftm.sets["F"].index("lab")
    tf = ftm.params["tf"].copy()
    tf[lab] *= 0.5
    shocks = {**sc.simulation_inputs(ftm), "payroll_cut": {"params": {"tf": tf}},
              "income_tax_up": {"params": {"tfy": ftm.params["tfy"] * 2}}}
    add("factor taxes", ftm, shocks, "ftax_")
    ftmix = sc.factor_tax_model(**sc.MIXED_ELASTICITIES)
    tf = ftmix.params["tf"].copy()
    tf[lab] *= 0.5
    add("factor taxes, mixed", ftmix, {"mixed_payroll_cut": {"params": {"tf": tf}}}, "ftax_")
    # Nests of value added (version 0.5.1, model_spec.md, Section 17.2)
    vn = sc.nest_model()
    add("nests", vn, sc.nest_shocks(vn), "vnest_")
    vnmix = sc.nest_model(**sc.NEST_MIXED)
    shocks = sc.nest_shocks(vnmix)
    add("nests, mixed", vnmix, {"mixed_" + k: shocks[k] for k in ("energy_price_up50", "skilled_supply_up10")},
        "vnest_")
    add("nests, specific capital", vn, {"specific_energy_price_up50": sc.nest_shocks(vn)["energy_price_up50"]},
        "vnest_", closure=Closure(factors={"cap": "specific"}))
    vnvat = sc.vat_model(**sc.NEST_VAT)
    add("nests, VAT", vnvat, {"vat_rate_up20": {"params": {"tv": vnvat.params["tv"] * 1.2}}}, "vnest_",
        vat=sc.VAT_CREDIT)
    # Output of a commodity from several activities (version 0.5.2, Section 17.3)
    xm = sc.multiproduct_model(**sc.OUTPUT_CES)
    add("output from activities", xm, sc.simulation_inputs(xm), "xac_")
    xcd = sc.multiproduct_model(sigma_ac={"com_man": 1.0})
    add("output from activities, Cobb-Douglas", xcd,
        {"cd_agri_productivity_up5": sc.simulation_inputs(xcd)["agri_productivity_up5"]}, "xac_")
    xmix = sc.multiproduct_model(**sc.MIXED_ELASTICITIES, **sc.OUTPUT_CES)
    add("output from activities, mixed", xmix,
        {"mixed_agri_productivity_up5": sc.simulation_inputs(xmix)["agri_productivity_up5"]}, "xac_")
    # Closure swaps (version 0.4.5, model_spec.md, Section 6)
    notariff = {"params": {"tm": np.zeros_like(std.params["tm"])}}
    add("swaps", std, {"swap_gsav_gadj": notariff}, closure=Closure(swaps=(("GSAV", "GADJ"),)))
    add("swaps", std, {"swap_exr_numeraire": notariff}, closure=Closure(swaps=(("EXR", "CPI"),)))
    # Bounds and complementarity (version 0.4.4, model_spec.md, Section 16):
    # solved by PATH as a mixed complementarity problem, against the expected
    # results of the Python reference, which finds the regimes by an
    # active-set method
    for name, (model, closure, shock, cons) in sc.constraint_cases().items():
        add("constraints", model, {name: shock}, closure=closure, cons=cons)
    # Alternative closures, compared with the Python reference
    alt1 = Closure(external="fixexr", government="fixgsav", savinv="investment", numeraire="dpi",
                   factors={"cap": "specific"})
    alt2 = Closure(factors={"lab": "unemployed"})
    for label, model, les_settings in (("standard", std, None), ("institutions", inst, None),
                                       ("health link", eff, None), ("LES", les, sc.LES_SETTINGS)):
        sims = sc.simulation_inputs(model)
        pick = {k: sims[k] for k in ("tariff_removal", "import_price_up10", "agri_productivity_up5")}
        add(label + ", closure 1", model, pick, "alt1_", les=les_settings, closure=alt1, python=True)
        pick = {k: sims[k] for k in ("tariff_removal", "foreign_savings_down20")}
        add(label + ", closure 2", model, pick, "alt2_", les=les_settings, closure=alt2, python=True)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--gams", default=shutil.which("gams") or r"C:\GAMS\54\gams.exe")
    ap.add_argument("--work", default=str(Path(tempfile.gettempdir()) / "cge_gams_check"))
    # Another solver or model type (from version 0.4.3), e.g. --solver conopt,
    # or --solver ipopt --type nlp; and a filter on the case labels
    ap.add_argument("--solver", default="path")
    ap.add_argument("--type", default="cns", choices=("cns", "nlp"))
    ap.add_argument("--only", default="", help="run only the cases whose label contains this text")
    args = ap.parse_args()
    solver = [f"--cgesolver={args.solver}", f"--cgetype={args.type}"]
    work = Path(args.work)
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    rows = []
    t0 = time.time()
    for n, case in enumerate(cases()):
        if args.only and args.only not in case["label"]:
            continue
        d = work / f"case{n:02d}"
        d.mkdir()
        for f in MODEL_FILES:
            shutil.copy(REPO / "ado" / f, d / f)
        for f in CHECK_FILES:
            shutil.copy(HERE / f, d / f)
        model = case["model"]
        write_data(model, case["les"], d / "data.inc", case["vat"], case["debt"], case["trade"], case["labour"],
                   case["outcomes"], case["fq"])
        # Constraints need a mixed complementarity problem (MCP), with PATH
        csolver = [f"--cgesolver={args.solver}", "--cgetype=mcp"] if case["cons"] else solver
        run_gams(args.gams, ["cge_model.gms", "--data=data.inc", "--out=base.csv", "s=work", *csolver], d)
        bstatus, base = read_gams(d / "base.csv")
        for name, shock in case["shocks"].items():
            full = case["prefix"] + name
            par, var = shock_statements(model, shock, case["closure"])
            (d / f"{full}_p.inc").write_text(par, encoding="utf-8")
            (d / f"{full}_v.inc").write_text(var, encoding="utf-8")
            extra = []
            if case["cons"]:
                (d / f"{full}_c.inc").write_text(constraint_statements(model, case["cons"], case["closure"]),
                                                 encoding="utf-8")
                extra = [f"--cons={full}_c.inc"]
            run_gams(args.gams, ["cge_scenario.gms", "r=work", f"--name={full}", f"--shockpar={full}_p.inc",
                                 f"--shockvar={full}_v.inc", f"--out={full}.csv", f"o={full}.lst", *csolver,
                                 *extra], d)
            status, value = read_gams(d / f"{full}.csv")
            if case["python"]:
                sol = model.solve(case["closure"], tol=1e-12, **shock)
                reference = [((v, e1, e2), b, x) for v, e1, e2, b, x in sol.rows()]
            else:
                reference = read_expected(full)
            res = compare(reference, base, value)
            rows.append({"case": case["label"], "scenario": full,
                         "reference": "Python" if case["python"] else "tests/expected",
                         "gams_modelstat": int(status), **res})
            r = rows[-1]
            print(f"{case['label']:28s} {full:36s} status {r['gams_modelstat']:2d}  rows {r['rows']:4d}  "
                  f"missing {r['missing']}  base {r['base_maxrel']:.1e}  value {r['value_maxrel']:.1e}  "
                  f"WALRAS {r['walras_abs']:.1e}", flush=True)
    out = HERE / ("gams_check_results.csv" if args.solver == "path" and not args.only
                  else f"gams_check_results_{args.solver}.csv")
    with out.open("w", newline="", encoding="utf-8") as handle:
        w = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
        w.writeheader()
        for r in rows:
            w.writerow({k: (f"{v:.3e}" if isinstance(v, float) else v) for k, v in r.items()})
    worst = max(r["value_maxrel"] for r in rows)
    bad = [r for r in rows if r["missing"] or r["value_maxrel"] > 1e-6 or r["base_maxrel"] > 1e-9
           or r["gams_modelstat"] not in (1, 2, 15, 16)]
    print(f"\n{len(rows)} scenarios in {time.time() - t0:.0f} s; largest relative difference {worst:.2e}; "
          f"{len(bad)} failure(s). Results: {out}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
