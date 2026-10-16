"""The Mata code that saves and loads a model is generated from the structure
definitions (tools/gen_mata_io.py); it must be up to date (version 0.1.15)."""

import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]


def test_generated_io_code_is_current():
    result = subprocess.run([sys.executable, str(REPO / "tools" / "gen_mata_io.py"), "--check"])
    assert result.returncode == 0, "run python tools/gen_mata_io.py"


def test_versions_agree():
    ado = (REPO / "ado" / "cge.ado").read_text(encoding="utf-8")
    mata = (REPO / "ado" / "cge_mata.mata").read_text(encoding="utf-8")
    pkg = re.search(r'local version "([0-9.]+)"', ado).group(1)
    lib = re.search(r'string scalar _cge_version\(\)\s*\{\s*return\("([0-9.]+)"\)', mata).group(1)
    assert pkg == lib
