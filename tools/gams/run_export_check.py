"""Check cge_gams (version 0.4.3): the models that Stata writes are solved in
GAMS and give Stata's solutions.

For every case of export_check.do:
1. Stata (batch mode) calibrates the model, solves the case and writes it with
   cge_gams to its own folder;
2. GAMS solves each exported model (cge_run.gms) with the chosen solver;
3. Stata solves each case again and compares it with the GAMS results
   (cge_gams ..., compare noexport).

Usage (Stata for Windows and GAMS required):
    python tools/gams/run_export_check.py [--stata PATH] [--gams PATH] [--work DIR]
        [--solver path|conopt|knitro|ipopt|nlpec] [--type cns|nlp|mcp]

Writes tools/gams/export_check_results.csv, one row per case and solver (a run
replaces the rows of its solver). Stata logs and GAMS listings stay in the work directory
(outside Dropbox by default): they name the licence holders and are not part
of the repository.
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

HERE = Path(__file__).resolve().parent
# Cases of export_check.do with constraints
MCP_CASES = ("quota", "capacity", "peglimit", "nodeficit", "wagefloor", "inequalities", "pairs")
REPO = HERE.parents[1]


def find_stata() -> str:
    for root in (Path(r"C:\Program Files"), Path(r"C:\Program Files (x86)")):
        for d in sorted(root.glob("Stata*"), reverse=True):
            for exe in sorted(d.glob("Stata*-64.exe")):
                if "_old" not in exe.name:
                    return str(exe)
    raise SystemExit("Stata not found; give --stata")


def run_stata(stata: str, work: Path, phase: str) -> None:
    wrapper = work / f"{phase}.do"
    wrapper.write_text(
        "version 13.0\n"
        f'adopath ++ "{(REPO / "ado").as_posix()}"\n'
        f'adopath ++ "{(REPO / "data").as_posix()}"\n'
        f'do "{(HERE / "export_check.do").as_posix()}" {phase} "{work.as_posix()}"\n', encoding="utf-8")
    subprocess.run([stata, "/e", "do", wrapper.name], cwd=work, check=True)
    # A batch run that stops with an error ends its log with the return code
    lines = (work / f"{phase}.log").read_text(encoding="utf-8", errors="replace").strip().splitlines()
    if not lines or lines[-1].startswith("r("):
        raise RuntimeError(f"Stata stopped with an error in the {phase} phase; see {work / (phase + '.log')}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stata", default=None)
    ap.add_argument("--gams", default=shutil.which("gams") or r"C:\GAMS\54\gams.exe")
    ap.add_argument("--work", default=str(Path(tempfile.gettempdir()) / "cge_export_check"))
    ap.add_argument("--solver", default="path")
    ap.add_argument("--type", default="cns", choices=("cns", "nlp", "mcp"))
    args = ap.parse_args()
    stata = args.stata or find_stata()
    work = Path(args.work)
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    t0 = time.time()

    run_stata(stata, work, "export")
    folders = sorted(d for d in work.iterdir() if (d / "cge_run.gms").exists())
    if not folders:
        raise SystemExit(f"Stata exported no model; see {work / 'export.log'}")
    # Scenarios with constraints (version 0.4.4) are mixed complementarity
    # problems: they are solved only by MCP solvers, with --cgetype=mcp
    mcp_solvers = ("path", "nlpec", "miles")
    skipped = []
    for d in folders:
        constrained = "positive variable" in (d / "cge_constraints.inc").read_text(encoding="utf-8")
        if constrained and args.solver not in mcp_solvers:
            skipped.append(d.name)
            continue
        gtype = "mcp" if constrained else args.type
        r = subprocess.run([args.gams, "cge_run.gms", "lo=0", f"--cgesolver={args.solver}",
                            f"--cgetype={gtype}"], cwd=d, capture_output=True, text=True)
        print(f"GAMS {d.name:14s} return code {r.returncode}", flush=True)
    folders = [d for d in folders if d.name not in skipped]
    run_stata(stata, work, "compare")

    res = work / "export_check.csv"
    if not res.exists():
        raise SystemExit(f"Stata wrote no comparison; see {work / 'compare.log'}")
    with res.open(encoding="utf-8") as handle:
        rows = [r for r in csv.DictReader(handle) if r["case"] not in skipped]
    # One file for every solver: the rows of this solver replace earlier ones,
    # including those of the cases with constraints, which are solved as MCP
    # whatever the type
    out = HERE / "export_check_results.csv"
    fields = ["case", "solver", "type", "gams_modelstat", "values", "base_maxrel", "value_maxrel"]
    kept = []
    if out.exists():
        with out.open(encoding="utf-8") as handle:
            kept = [r for r in csv.DictReader(handle)
                    if r["solver"] != args.solver or (r["type"] != args.type and r["case"] not in MCP_CASES)]
    new = [{"case": r["case"], "solver": args.solver, "type": "mcp" if r["case"] in MCP_CASES else args.type,
            "gams_modelstat": int(float(r["modelstat"])), "values": int(float(r["N"])),
            "base_maxrel": f"{float(r['base_maxdiff']):.3e}", "value_maxrel": f"{float(r['maxdiff']):.3e}"}
           for r in rows]
    with out.open("w", newline="", encoding="utf-8") as handle:
        w = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        w.writeheader()
        for r in kept + new:
            w.writerow(r)
    bad = [r for r in rows if float(r["modelstat"]) not in (1, 2, 15, 16) or float(r["maxdiff"]) > 1e-8
           or float(r["base_maxdiff"]) > 1e-9]
    for r in rows:
        print(f"{r['case']:14s} status {int(float(r['modelstat'])):2d}  values {int(float(r['N'])):4d}  "
              f"base {float(r['base_maxdiff']):.1e}  value {float(r['maxdiff']):.1e}")
    worst = max(float(r["maxdiff"]) for r in rows)
    print(f"\n{len(rows)} cases in {time.time() - t0:.0f} s; largest relative difference {worst:.2e}; "
          f"{len(bad)} failure(s). Results: {out}")
    sys.exit(1 if bad or len(rows) != len(folders) else 0)


if __name__ == "__main__":
    main()
