"""Check cge_gdx (version 0.10.0): GDX files written by GAMS from Stata's model
and read back through gdxdump, and the GDX file of a scenario solved by GAMS.

1. Stata (batch mode) writes the GAMS program of the GDX file and the scripts
   that read it back with gdxdump, and exports a scenario with cge_gams;
2. GAMS writes the GDX file, solves the exported scenario and writes its
   solution as a GDX file; gdxdump writes the symbols as CSV files;
3. Stata reads them and compares the SAM, the calibrated parameters and the
   levels with its own (exactly, through hexadecimal floats), and GAMS's
   solution with Stata's.

Usage (Stata for Windows and GAMS required):
    python tools/gams/run_gdx_check.py [--stata PATH] [--gams PATH] [--work DIR]

Writes tools/gams/gdx_check_results.csv. The Stata logs and GAMS listings stay
in the work directory (outside Dropbox by default): they name the licence
holders and are not part of the repository.
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
REPO = HERE.parents[1]
sys.path.insert(0, str(HERE))
from run_export_check import find_stata  # noqa: E402


def run_stata(stata: str, work: Path, phase: str, gams: str) -> None:
    wrapper = work / f"{phase}.do"
    wrapper.write_text(
        "version 13.0\n"
        f'adopath ++ "{(REPO / "ado").as_posix()}"\n'
        f'adopath ++ "{(REPO / "data").as_posix()}"\n'
        f'do "{(HERE / "gdx_check.do").as_posix()}" {phase} "{work.as_posix()}" "{Path(gams).as_posix()}"\n',
        encoding="utf-8")
    subprocess.run([stata, "/e", "do", wrapper.name], cwd=work, check=True)
    lines = (work / f"{phase}.log").read_text(encoding="utf-8", errors="replace").strip().splitlines()
    if not lines or lines[-1].startswith("r("):
        raise RuntimeError(f"Stata stopped with an error in the {phase} phase; see {work / (phase + '.log')}")


def run_script(script: Path) -> None:
    r = subprocess.run(["cmd", "/c", str(script)], cwd=script.parent, capture_output=True, text=True)
    print(f"{script.name:28s} return code {r.returncode}", flush=True)
    if r.returncode:
        raise RuntimeError(f"{script} failed: {r.stdout}{r.stderr}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stata", default=None)
    ap.add_argument("--gams", default=shutil.which("gams") or r"C:\GAMS\54\gams.exe")
    ap.add_argument("--work", default=str(Path(tempfile.gettempdir()) / "cge_gdx_check"))
    args = ap.parse_args()
    stata = args.stata or find_stata()
    work = Path(args.work)
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    t0 = time.time()

    run_stata(stata, work, "prepare", args.gams)
    # GAMS writes the GDX file of the model, and solves the exported scenario
    # with its solution as a GDX file
    run_script(work / "m_write.cmd")
    r = subprocess.run([args.gams, "cge_run.gms", "lo=0", "gdx=sol.gdx"], cwd=work / "exp", capture_output=True, text=True)
    print(f"{'GAMS exp':28s} return code {r.returncode}", flush=True)
    # gdxdump writes each symbol read
    for script in sorted(work.glob("m_*.cmd")) + sorted((work / "exp").glob("sol_*.cmd")):
        if script.name != "m_write.cmd":
            run_script(script)
    run_stata(stata, work, "compare", args.gams)

    res = work / "gdx_check.csv"
    with res.open(encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    out = HERE / "gdx_check_results.csv"
    with out.open("w", newline="", encoding="utf-8") as handle:
        w = csv.DictWriter(handle, fieldnames=["check", "N", "maxdiff"], lineterminator="\n")
        w.writeheader()
        for row in rows:
            w.writerow({"check": row["check"], "N": int(float(row["N"])), "maxdiff": f"{float(row['maxdiff']):.3e}"})
    # the round trip is exact; GAMS's solution agrees to its tolerance
    bad = [row for row in rows if (row["check"].startswith("GAMS") or row["check"] == "SAM from GAMS")
           and float(row["maxdiff"]) > 1e-9
           or not (row["check"].startswith("GAMS") or row["check"] == "SAM from GAMS") and float(row["maxdiff"]) != 0]
    for row in rows:
        print(f"{row['check']:16s} values {int(float(row['N'])):5d}  largest relative difference {float(row['maxdiff']):.2e}")
    print(f"\n{len(rows)} checks in {time.time() - t0:.0f} s; {len(bad)} failure(s). Results: {out}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
