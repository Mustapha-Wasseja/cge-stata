"""Solve the MPSGE models of tests/data/mpsge with GAMS/MPSGE (version 0.44.0).

Each program there writes the MPSGE model that tests/test_mpsge.do reads with
cge_mpsge using, solves its scenarios with GAMS's MPSGE and PATH, and writes
the levels to <name>.csv. This script runs every program in a work
directory and collects the levels in tests/expected/mpsge_gams.csv, which
the Stata test compares with its own solutions.

Usage (GAMS required; the models are small enough for a demonstration
licence of MPSGE):
    python tools/gams/run_mpsge_check.py [--gams PATH] [--work DIR]

GAMS listings stay in the work directory (outside Dropbox by default): they
name the licence holder and are not part of the repository.
"""

from __future__ import annotations

import argparse
import csv
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
MODELS = REPO / "tests" / "data" / "mpsge"
OUT = REPO / "tests" / "expected" / "mpsge_gams.csv"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--gams", default=shutil.which("gams") or "gams")
    ap.add_argument("--work", default=None)
    a = ap.parse_args()
    work = Path(a.work) if a.work else Path(tempfile.mkdtemp(prefix="cge_mpsge_check_"))
    work.mkdir(parents=True, exist_ok=True)
    rows = []
    for gms in sorted(MODELS.glob("*.gms")):
        d = work / gms.stem
        d.mkdir(exist_ok=True)
        shutil.copy(gms, d / gms.name)
        r = subprocess.run([a.gams, gms.name, "lo=2"], cwd=d)
        res = d / (gms.stem + ".csv")
        if r.returncode != 0 or not res.exists():
            print(f"{gms.name}: GAMS failed (return code {r.returncode}); see {d}", file=sys.stderr)
            return 1
        lst = (d / (gms.stem + ".lst")).read_text(errors="replace")
        bad = [ln for ln in lst.splitlines() if "MODEL STATUS" in ln and not ln.rstrip().endswith("Optimal")]
        if bad:
            print(f"{gms.name}: a solve did not end optimal: {bad[0].strip()}", file=sys.stderr)
            return 1
        with res.open(newline="") as fh:
            for line in csv.reader(fh):
                if line:
                    rows.append([x.strip() for x in line])
        print(f"{gms.name}: {sum(1 for r_ in rows if r_[0] == gms.stem)} levels")
    with OUT.open("w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["model", "scenario", "variable", "element", "value"])
        w.writerows(rows)
    print(f"wrote {OUT} ({len(rows)} rows); listings in {work}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
