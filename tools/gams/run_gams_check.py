"""Check the model against an independent GAMS implementation (version 0.1.16).

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
GAMS_FILES = ("cge_model.gms", "cge_scenario.gms", "closure.gms", "write.gms")
# Python parameter names and their GAMS names (shockable parameters)
PARAMS = {"pwm": "pwm", "pwe": "pwe", "tm": "tm", "te": "te", "tq": "tq", "ta": "ta", "ad": "ad",
          "qg": "qgbar", "qinv": "qinvbar", "trdg": "trdg", "trdr": "trdr", "trfr": "trfr",
          "trgr": "trgr", "trrg": "trrg", "tshi": "tshi", "qshi": "qshibar", "trshi": "trshi",
          "trshir": "trshir", "af": "af", "tv": "tv", "kappa": "kappa", "rd": "rd", "rf": "rf",
          "ddebt": "ddebt", "fdebt": "fdebt"}
PARAM_SETS = {"pwm": "C", "pwe": "C", "tm": "C", "te": "C", "tq": "C", "ta": "A", "ad": "A", "qg": "C",
              "qinv": "C", "trdg": "D", "trdr": "D", "trfr": "F", "tshi": "F", "qshi": "C", "af": "F",
              "tv": "C", "kappa": "A"}
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


def write_data(model, les: dict | None, path: Path, vat_credit=None, debt: dict | None = None) -> None:
    """The prepared SAM, the mapping and the settings supplied by the user (elasticities,
    VAT credit shares, debt and interest rates) as a GAMS include file."""
    m, sam, S, p = model.mapping, model.sam, model.sets, model.params
    lines = ["* data for cge_model.gms, written by run_gams_check.py",
             "set AC 'accounts' / " + ", ".join(q(a) for a in sam.labels) + " /;"]
    roles = {"A": S["A"], "C": S["C"], "F": S["F"], "H": S["H"], "E": S["E"], "T": m.margin_accounts,
             "GOVS": [m.government], "ROWS": [m.row], "SAVS": [m.savinv],
             "SHIS": [m.insurance] if m.insurance else [], "DTAXS": [m.dirtax] if m.dirtax else [],
             "STAXS": [m.saltax] if m.saltax else [], "MTAXS": [m.imptax] if m.imptax else [],
             "ETAXS": [m.exptax] if m.exptax else [], "ATAXS": [m.acttax] if m.acttax else [],
             "VTAXS": [m.vattax] if m.vattax else [],
             "HCOM": [c for c, h in zip(S["C"], model.struct["hc"]) if h]}
    lines += [gams_set(k, v) for k, v in roles.items()]
    cells = [f"{q(r)}.{q(c)} {num(sam.values[i, j])}" for i, r in enumerate(sam.labels)
             for j, c in enumerate(sam.labels) if sam.values[i, j] != 0]
    lines.append("parameter SAM(AC, AC) /\n" + ",\n".join(cells) + "\n/;")

    def param(name, labels, values):
        body = ", ".join(f"{q(e)} {num(v)}" for e, v in zip(labels, values) if v != 0)
        return f"parameter {name}(AC) / {body} /;"

    lines.append(param("sigva", S["A"], p["sigma_va"]))
    lines.append(param("sigq", S["C"], p["sigma_q"]))
    lines.append(param("sigt", S["C"], p["sigma_t"]))
    lines.append(param("siga", S["A"], p["sigma_a"]))
    lines.append(param("eta", S["F"], p["eta_h"]))
    if les:
        lines.append(param("incel", S["C"], [les["income_elasticities"][c] for c in S["C"]]))
        frisch = les["frisch"]
        frisch = [frisch] * len(S["H"]) if np.ndim(frisch) == 0 else list(frisch)
        lines.append(param("frisch", S["H"], frisch))
        lines.append("scalar les / 1 /;")
    else:
        lines += ["parameter incel(AC) / /;", "parameter frisch(AC) / /;", "scalar les / 0 /;"]
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
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def shock_statements(model, shock: dict, closure: Closure) -> tuple[str, str]:
    """GAMS statements for a scenario: parameter changes and the closure; then
    changes to fixed variables. Changes are ratios to the base where the base
    is not zero, so GAMS applies them to its own calibrated values."""
    S = {**model.sets, "": [""]}
    par, var = ["* parameter changes and closure"], ["* fixed-variable changes"]
    for name, new in shock.get("params", {}).items():
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
    codes = {"mobile": 1, "specific": 2, "unemployed": 3}
    for f in model.sets["F"]:
        par.append(f"fclo({q(f)}) = {codes[closure.factors.get(f, 'mobile')]};")
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

    def add(label, model, shocks, prefix="", les=None, closure=None, python=False, vat=None, debt=None):
        out.append({"label": label, "model": model, "shocks": shocks, "prefix": prefix, "les": les,
                    "closure": closure or Closure(), "python": python, "vat": vat, "debt": debt})

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
    args = ap.parse_args()
    work = Path(args.work)
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    rows = []
    t0 = time.time()
    for n, case in enumerate(cases()):
        d = work / f"case{n:02d}"
        d.mkdir()
        for f in GAMS_FILES:
            shutil.copy(HERE / f, d / f)
        model = case["model"]
        write_data(model, case["les"], d / "data.inc", case["vat"], case["debt"])
        run_gams(args.gams, ["cge_model.gms", "--data=data.inc", "--out=base.csv", "s=work"], d)
        bstatus, base = read_gams(d / "base.csv")
        for name, shock in case["shocks"].items():
            full = case["prefix"] + name
            par, var = shock_statements(model, shock, case["closure"])
            (d / f"{full}_p.inc").write_text(par, encoding="utf-8")
            (d / f"{full}_v.inc").write_text(var, encoding="utf-8")
            run_gams(args.gams, ["cge_scenario.gms", "r=work", f"--name={full}", f"--shockpar={full}_p.inc",
                                 f"--shockvar={full}_v.inc", f"--out={full}.csv", f"o={full}.lst"], d)
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
    out = HERE / "gams_check_results.csv"
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
