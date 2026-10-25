"""Write the bundles that the Stata package installs in place of many small files.

Stata's package files take at most 100 files: beyond that, net install stops
with "package file too long" (error 640). The package therefore installs the
SYNTHETIC SAMs, the model library and the GAMS model as three text files,
each a series of sections that begin with a line "@@@ name", which
cge_synthetic, cge_modlib and cge_gams read through _cge_bundle_get. The
sources stay as files in the repository. Run this script after changing any
of them; reference/tests/test_package.py fails when a bundle is out of date
or cge.pkg lists more than 100 files.

    python tools/bundle_files.py          write the bundles
    python tools/bundle_files.py --check  report bundles that are out of date
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAMS = ("cge_model.gms", "cge_closure.gms", "cge_write.gms", "cge_solve.gms")


def sources(root: Path) -> dict[str, list[Path]]:
    """The files of each bundle, in a fixed order."""
    return {
        "data/cge_synthetic_sams.txt": sorted((root / "data").glob("cge_synthetic_sam*.csv")),
        "ado/cge_ml_library.txt": sorted((root / "ado").glob("cge_ml_*.do")),
        "ado/cge_gams_model.txt": [root / "ado" / f for f in GAMS],
    }


def build(name: str, files: list[Path]) -> str:
    """The text of a bundle: a header, then each file as a section."""
    out = [f"* cge-stata: {name}, the files below in sections that begin with @@@ (written by tools/bundle_files.py; do not edit)"]
    for f in files:
        text = f.read_text(encoding="utf-8").replace("\r\n", "\n")
        if any(line.startswith("@@@ ") for line in text.split("\n")):
            raise SystemExit(f"{f}: a line begins with '@@@ ', which marks the sections of a bundle")
        out.append(f"@@@ {f.name}")
        out.append(text.rstrip("\n"))
    return "\n".join(out) + "\n"


def check(root: Path = ROOT) -> list[str]:
    """The bundles that are missing or out of date."""
    bad = []
    for name, files in sources(root).items():
        p = root / name
        if not p.exists() or p.read_text(encoding="utf-8").replace("\r\n", "\n") != build(name, files):
            bad.append(name)
    return bad


def main() -> None:
    if "--check" in sys.argv:
        bad = check()
        for name in bad:
            print(f"out of date: {name}")
        raise SystemExit(1 if bad else 0)
    for name, files in sources(ROOT).items():
        (ROOT / name).write_text(build(name, files), encoding="utf-8", newline="\n")
        print(f"wrote {name}: {len(files)} file(s)")


if __name__ == "__main__":
    main()
