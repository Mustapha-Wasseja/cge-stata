"""Build the cge-stata Reference Manual from its LaTeX sources (docs/manual/tex).

Usage:
    python tools/build_manual.py                       the whole manual, to docs/manual/cge-stata-manual.pdf
    python tools/build_manual.py --entry cge_solve     one command entry, on its own (for checking)
    python tools/build_manual.py --examples [names]    run the do-files in docs/manual/tex/examples in
                                                       Stata and write their output to docs/manual/tex/output

An example do-file marks each piece of output that the manual shows:

    *>> solve_notariff
    cge_solve, name(notariff)
    *<<

and the manual shows it with \\stlog{solve_notariff}. Stata logs begin with the
licence details, so the logs are kept in a temporary directory and only the
marked lines are written; a line that names a path, a user or a licence stops
the build.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
TEX = REPO / "docs" / "manual" / "tex"
MAIN = "cge-stata-manual"
PDF = REPO / "docs" / "manual" / f"{MAIN}.pdf"
# Text that must never reach the manual from a Stata log
FORBIDDEN = re.compile(r"(?i)users[\\/]|appdata|dropbox|serial|licen[cs]e|licensed|world bank|uneca")


def find_pdflatex() -> str:
    exe = shutil.which("pdflatex")
    if exe:
        return exe
    tiny = Path(os.environ.get("APPDATA", "")) / "TinyTeX" / "bin" / "windows" / "pdflatex.exe"
    if tiny.exists():
        return str(tiny)
    raise SystemExit("pdflatex not found")


def find_stata() -> str:
    for p in (r"C:\Program Files (x86)\Stata13\Stata-64.exe", r"C:\Program Files\StataNow19\StataMP-64.exe"):
        if Path(p).exists():
            return p
    raise SystemExit("Stata not found; give --stata")


def latex(source: str, outdir: Path, passes: int = 3) -> Path:
    """Run pdflatex in docs/manual/tex, writing to outdir; returns the log path."""
    exe = find_pdflatex()
    env = dict(os.environ)
    # Reproducible dates and document ID: the date of the last commit
    try:
        stamp = subprocess.run(["git", "log", "-1", "--format=%ct"], cwd=REPO, capture_output=True,
                               text=True, check=True).stdout.strip()
        if stamp:
            env["SOURCE_DATE_EPOCH"] = stamp
            env["FORCE_SOURCE_DATE"] = "1"
    except (OSError, subprocess.CalledProcessError):
        pass
    stem = Path(source).stem
    log = outdir / f"{stem}.log"
    for k in range(passes):
        r = subprocess.run([exe, "-interaction=nonstopmode", "-halt-on-error", "-file-line-error",
                            f"-output-directory={outdir}", source], cwd=TEX, env=env,
                           capture_output=True, text=True, encoding="utf-8", errors="replace")
        if r.returncode != 0:
            text = log.read_text(encoding="utf-8", errors="replace") if log.exists() else r.stdout
            errs = [l for l in text.splitlines() if l.startswith(("!", "./", "l.")) or ".tex:" in l]
            print("\n".join(errs[-25:]))
            raise SystemExit(f"pdflatex failed on pass {k + 1}; see {log}")
        text = log.read_text(encoding="utf-8", errors="replace")
        if k >= 1 and "Rerun to get" not in text and "Label(s) may have changed" not in text:
            break
    return log


def report(log: Path) -> None:
    text = log.read_text(encoding="utf-8", errors="replace")
    undef = sorted(set(re.findall(r"(?:Reference|Citation) `([^']+)' on page \d+ undefined", text)))
    # The file of each overfull line: the last source file opened before it
    over, cur = [], "?"
    for m in re.finditer(r"\(\./([^\s()]+\.tex)|Overfull \\hbox \((\d+\.?\d*)pt too wide\)[^\n]*lines? (\d+)", text):
        if m.group(1):
            cur = m.group(1)
        else:
            over.append((float(m.group(2)), cur, m.group(3)))
    big = [o for o in over if o[0] > 2]
    print(f"undefined references or citations: {len(undef)}" + (f" ({', '.join(undef[:12])})" if undef else ""))
    print(f"overfull lines: {len(over)}, of which over 2pt: {len(big)}")
    for w, f, l in big[:40]:
        print(f"  {w:6.1f}pt  {f}, line {l}")
    m = re.search(r"Output written on .*\((\d+) pages", text)
    if m:
        print(f"pages: {m.group(1)}")


def build_all(keep: bool) -> None:
    out = Path(tempfile.mkdtemp(prefix="cge_manual_"))
    log = latex(f"{MAIN}.tex", out)
    report(log)
    shutil.copyfile(out / f"{MAIN}.pdf", PDF)
    print(f"wrote {PDF}")
    if not keep:
        shutil.rmtree(out, ignore_errors=True)


def build_entry(name: str, dest: Path | None) -> None:
    src = TEX / "ref" / f"{name}.tex"
    if not src.exists():
        raise SystemExit(f"no entry {src}")
    out = Path(tempfile.mkdtemp(prefix=f"cge_entry_{name}_"))
    wrapper = out / f"entry_{name}.tex"
    wrapper.write_text("\\documentclass[10pt,oneside,openany]{book}\n\\usepackage{cgestyle}\n"
                       "\\begin{document}\\mainmatter\n"
                       f"\\input{{ref/{name}}}\n\\end{{document}}\n", encoding="utf-8")
    log = latex(str(wrapper), out, passes=2)
    report(log)
    pdf = out / f"entry_{name}.pdf"
    target = dest or (out / f"{name}.pdf")
    if dest:
        shutil.copyfile(pdf, dest)
    else:
        pdf.replace(target)
    print(f"wrote {target} (references to other parts of the manual show as ??)")


def run_examples(names: list[str], stata: str) -> None:
    files = sorted((TEX / "examples").glob("*.do"))
    if names:
        files = [f for f in files if f.stem in names]
        missing = set(names) - {f.stem for f in files}
        if missing:
            raise SystemExit(f"no example do-file: {', '.join(sorted(missing))}")
    for do in files:
        work = Path(tempfile.mkdtemp(prefix=f"cge_ex_{do.stem}_"))
        wrapper = work / "manual_example.do"
        wrapper.write_text("version 13.0\nclear all\nset more off\nset linesize 100\n"
                           f'adopath ++ "{(REPO / "ado").as_posix()}"\n'
                           f'adopath ++ "{(REPO / "data").as_posix()}"\n'
                           f'do "{do.as_posix()}"\n', encoding="utf-8")
        subprocess.run([stata, "/e", "do", wrapper.name], cwd=work, check=True)
        log = (work / "manual_example.log").read_text(encoding="utf-8", errors="replace").splitlines()
        tail = [l for l in log if l.strip()][-1:] or [""]
        if tail[0].startswith("r("):
            body = [l for l in log[-40:] if not FORBIDDEN.search(l)]
            print("\n".join(body))
            raise SystemExit(f"{do.name} stopped with an error")
        tags = extract(log, work)
        for tag, lines in tags.items():
            bad = [l for l in lines if FORBIDDEN.search(l)]
            if bad:
                raise SystemExit(f"{do.name}, {tag}: output names a path, user or licence: {bad[0]!r}")
            wide = [l for l in lines if len(l) > 110]
            if wide:
                print(f"  {tag}: {len(wide)} line(s) longer than 110 characters, too wide for the page")
            (TEX / "output" / f"{tag}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
        print(f"{do.name}: {len(tags)} piece(s) of output: {', '.join(tags)}")
        # Graphs that an example exports as fig_*.pdf or fig_*.png are the
        # manual's figures (from version 0.9.6)
        figs = sorted(work.glob("fig_*.pdf")) + sorted(work.glob("fig_*.png"))
        if figs:
            (TEX / "figures").mkdir(exist_ok=True)
            for f in figs:
                shutil.copyfile(f, TEX / "figures" / f.name)
            print(f"  {len(figs)} figure(s): {', '.join(f.name for f in figs)}")
        shutil.rmtree(work, ignore_errors=True)


def extract(log: list[str], work: Path) -> dict[str, list[str]]:
    tags: dict[str, list[str]] = {}
    cur, buf = None, []
    for line in log:
        m = re.match(r"^\. \*>> *(\S+)\s*$", line)
        if m:
            cur, buf = m.group(1), []
            continue
        if cur and re.match(r"^\. \*<<\s*$", line):
            while buf and buf[-1].strip() in ("", "."):
                buf.pop()
            while buf and buf[0].strip() == "":
                buf.pop(0)
            if cur in tags:
                raise SystemExit(f"output {cur} is marked twice")
            tags[cur] = buf
            cur = None
            continue
        if cur is not None:
            # An error shown as Stata shows it: "capture noisily cmd" is displayed as
            # "cmd", and the line that displays its return code is not shown
            if re.match(r'^\. di(splay)? as err(or)? "r\(" _rc "\);"\s*$', line):
                continue
            # A wider line size for one piece of output is not shown
            if re.match(r"^\. set linesize \d+\s*$", line):
                continue
            line = re.sub(r"^\. capture noisily ", ". ", line)
            buf.append(line.replace(work.as_posix(), ".").replace(str(work), ".").rstrip())
    if cur is not None:
        raise SystemExit(f"output {cur} has no end marker *<<")
    return tags


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--entry", help="build one command entry of Part III on its own")
    ap.add_argument("--out", help="with --entry: where to write the PDF")
    ap.add_argument("--examples", nargs="*", help="run the example do-files (all, or those named)")
    ap.add_argument("--stata", help="Stata executable for --examples")
    ap.add_argument("--keep", action="store_true", help="keep the build directory")
    args = ap.parse_args()
    if args.examples is not None:
        run_examples(args.examples, args.stata or find_stata())
        return
    if args.entry:
        build_entry(args.entry, Path(args.out) if args.out else None)
        return
    build_all(args.keep)


if __name__ == "__main__":
    main()
