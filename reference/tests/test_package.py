"""The Stata package file: at most 100 files, each of them present, and the
bundles that stand for the small files current (tools/bundle_files.py).

Stata's net install stops with "package file too long" (error 640) for a
package file of more than 100 files, as it did for versions 0.21.0 to 0.27.0.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import bundle_files  # noqa: E402


def _files():
    lines = (ROOT / "cge.pkg").read_text(encoding="utf-8").splitlines()
    return [line.split(None, 1)[1].strip() for line in lines if line[:2] in ("f ", "F ")]


def test_package_has_at_most_100_files():
    assert len(_files()) <= 100


def test_package_files_exist():
    missing = [f for f in _files() if not (ROOT / f).exists()]
    assert missing == []


def test_bundles_are_current():
    assert bundle_files.check(ROOT) == []


def test_help_source_lines_fit_the_stata_viewer():
    # Long physical lines can lose characters and expose SMCL tags in the
    # Windows Viewer even when smcl2txt renders the same file correctly.
    # Keep a margin below the Viewer failure boundary observed at 244 bytes.
    oversized = [
        f"{path.name}:{number} ({len(line)} bytes)"
        for path in sorted((ROOT / "ado").glob("*.sthlp"))
        for number, line in enumerate(path.read_bytes().splitlines(), 1)
        if len(line) > 200
    ]
    assert oversized == []
