"""Scale benchmark (version 0.2.0): synthetic SAMs of increasing size are read,
mapped, calibrated and solved in Stata, with the reduced system and, for the
smaller ones, the full system. With --gams (from version 0.6.2), each model is
also exported, solved by GAMS with PATH and timed, and its GAMS solution is
imported into Stata, checked against the model's equations and compared with
Stata's.

Usage: python tools/bench/run_bench.py [--stata EXE] [--sizes 40x5,80x10,...] [--full-up-to N]
    [--gams GAMS.EXE] [--linsolver dense|sparse|auto] [--out CSV]

From version 0.10.1, --linsolver chooses the linear solver of Newton's steps
(cge_options, linsolver()); the dense LU by default.

Writes tools/bench/bench_results.csv, or the file given with --out. The SAMs, do-files, Stata logs and GAMS
listings go to a temporary directory; Stata logs contain the licence serial,
and GAMS listings the licence holder, and are not kept.
"""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]

DO = """version 13.0
clear all
set more off
set linesize 255
adopath ++ "{ado}"
timer clear
timer on 1
quietly cge_sam using "{sam}", labels(account) clear
quietly cge_map, activities({acts}) commodities({coms}) factors(lab_f lab_i cap) households({hhs}) ///
    enterprises(ent) government(gov) savinv(sav) row(row) dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
timer off 1
timer on 2
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
timer off 2
local neq = r(N_equations)
{lin}
cge_shock tm, value(0)
timer on 3
cge_solve, name(reduced)
timer off 3
local nsol = r(N_solved)
local it = r(iterations)
local jac = r(jacobians)
local res = r(max_residual)
quietly timer list
display "BENCH reduced neq `neq' nsolved `nsol' iterations `it' jacobians `jac' residual `res' map " r(t1) " calibrate " r(t2) " solve " r(t3)
{full}
{export}
"""

# From version 0.6.2: the model and scenario for GAMS, and the model saved for
# the import of GAMS's solution
EXPORT = """quietly cge_gams using "{gdir}", sim(reduced) replace
quietly cge_save using "{model}", replace
"""

IMPORT = """version 13.0
clear all
set more off
set linesize 255
adopath ++ "{ado}"
quietly cge_use using "{model}"
cge_gams using "{gdir}", sim(reduced) noexport import(gams)
local res = r(max_residual)
local stat = r(modelstat)
quietly cge_results, sim(reduced) clear nodisplay
rename value v_stata
tempfile st
quietly save `st'
quietly cge_results, sim(gams) clear nodisplay
quietly merge 1:1 variable element1 element2 using `st', nogenerate
generate double rel = abs(v_stata - value) / max(1, abs(v_stata)) if variable != "WALRAS"
quietly summarize rel
display "BENCH gams status `stat' residual `res' agreement " r(max)
"""

FULL = """timer on 4
cge_solve, name(full) full
timer off 4
quietly timer list
display "BENCH full nsolved " r(N_solved) " iterations " r(iterations) " jacobians " r(jacobians) " solve " r(t4)
quietly cge_results, sim(reduced) clear nodisplay
rename value v_reduced
tempfile red
quietly save `red'
quietly cge_results, sim(full) clear nodisplay
quietly merge 1:1 variable element1 element2 using `red', nogenerate
generate double rel = abs(v_reduced - value) / max(1, abs(value)) if variable != "WALRAS"
quietly summarize rel
display "BENCH agreement " r(max)
"""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stata", default=r"C:\Program Files (x86)\Stata13\Stata-64.exe")
    ap.add_argument("--sizes", default="40x5,80x10,120x10,160x20,200x20")
    ap.add_argument("--full-up-to", type=int, default=120)
    ap.add_argument("--gams", default=None, help="gams.exe: also solve each model with GAMS (PATH)")
    ap.add_argument("--linsolver", default="", choices=("", "dense", "sparse", "auto", "python"))
    ap.add_argument("--out", default=str(HERE / "bench_results.csv"))
    args = ap.parse_args()
    import sys
    sys.path.insert(0, str(HERE))
    import gen_large_sam as gen

    work = Path(tempfile.gettempdir()) / "cge_bench"
    work.mkdir(exist_ok=True)
    rows = []
    for size in args.sizes.split(","):
        n, h = (int(v) for v in size.split("x"))
        labels, sam = gen.build(n, h)
        csvp = work / f"sam_{n}x{h}.csv"
        gen.write(csvp, labels, sam)
        acts = " ".join(l for l in labels if re.fullmatch(r"a\d+", l))
        coms = " ".join(l for l in labels if re.fullmatch(r"c\d+", l))
        hhs = " ".join(l for l in labels if l.startswith("hh"))
        do = work / f"bench_{n}x{h}.do"
        gdir, model = work / f"gams_{n}x{h}", work / f"model_{n}x{h}.cgem"
        export = EXPORT.format(gdir=gdir.as_posix(), model=model.as_posix()) if args.gams else ""
        do.write_text(DO.format(ado=(REPO / "ado").as_posix(), sam=csvp.as_posix(), acts=acts, coms=coms,
                                hhs=hhs, full=FULL if n <= args.full_up_to else "", export=export,
                                lin=f"quietly cge_options, linsolver({args.linsolver})" if args.linsolver else ""),
                      encoding="utf-8")
        subprocess.run([args.stata, "/e", "do", do.name], cwd=work, check=True)
        log = (work / f"bench_{n}x{h}.log").read_text(encoding="utf-8", errors="replace")
        rec = {"activities": n, "households": h, "accounts": len(labels)}
        m = re.search(r"^BENCH reduced neq (\d+) nsolved (\d+) iterations (\d+) jacobians (\d+) residual (\S+) "
                      r"map (\S+) calibrate (\S+) solve (\S+)", log, re.M)
        if not m:
            raise SystemExit(f"benchmark {size} failed; see {work / do.with_suffix('.log').name}")
        rec.update(equations=int(m[1]), solved_reduced=int(m[2]), iterations=int(m[3]), jacobians=int(m[4]),
                   residual=float(m[5]), seconds_read_map=float(m[6]), seconds_calibrate=float(m[7]),
                   seconds_solve_reduced=float(m[8]))
        m = re.search(r"^BENCH full nsolved (\d+) iterations (\d+) jacobians (\d+) solve (\S+)", log, re.M)
        rec["seconds_solve_full"] = float(m[4]) if m else None
        m = re.search(r"^BENCH agreement (\S+)", log, re.M)
        rec["max_rel_diff_full"] = float(m[1]) if m else None
        if args.gams:
            # GAMS calibrates, solves the base and the scenario; the time is the whole run
            t0 = time.time()
            subprocess.run([args.gams, "cge_run.gms", "lo=0"], cwd=gdir, check=True)
            rec["seconds_gams_total"] = round(time.time() - t0, 1)
            imp = work / f"import_{n}x{h}.do"
            imp.write_text(IMPORT.format(ado=(REPO / "ado").as_posix(), model=model.as_posix(),
                                         gdir=gdir.as_posix()), encoding="utf-8")
            subprocess.run([args.stata, "/e", "do", imp.name], cwd=work, check=True)
            log = (work / f"import_{n}x{h}.log").read_text(encoding="utf-8", errors="replace")
            m = re.search(r"^BENCH gams status (\S+) residual (\S+) agreement (\S+)", log, re.M)
            if not m:
                raise SystemExit(f"import {size} failed; see {work / imp.with_suffix('.log').name}")
            rec.update(gams_modelstat=float(m[1]), gams_residual_in_stata=float(m[2]),
                       max_rel_diff_gams=float(m[3]))
        rows.append(rec)
        print(rec, flush=True)
    out = Path(args.out)
    with out.open("w", newline="", encoding="utf-8") as handle:
        w = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
