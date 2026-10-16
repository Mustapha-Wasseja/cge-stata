"""Write the Mata code that saves and loads a model (cge_save, cge_use).

The members of the structures cge_par and cge_model are read from
ado/cge_mata.mata, and the functions that write and read every member are
written between the markers "BEGIN GENERATED: model input-output" and
"END GENERATED: model input-output" in the same file. Run this script after
changing either structure; reference/tests/test_mata_io.py fails when the
generated code is out of date.

Each member is saved as a (name, value) pair, so a file saved by an older
version can be read by a newer one: members it lacks keep their defaults.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

MATA = Path(__file__).resolve().parents[1] / "ado" / "cge_mata.mata"
BEGIN = "// BEGIN GENERATED: model input-output (tools/gen_mata_io.py; do not edit by hand)"
END = "// END GENERATED: model input-output"


def members(text: str, struct: str) -> list[tuple[str, str, str]]:
    """(eltype, orgtype, name) of every member of a structure, in order."""
    body = re.search(r"struct %s \{(.*?)\n\}" % struct, text, re.S).group(1)
    out = []
    for line in body.splitlines():
        line = line.split("//")[0].strip()
        if not line:
            continue
        m = re.match(r"(real|string|struct cge_par)\s+(scalar|colvector|rowvector|matrix)\s+(.*)", line)
        if not m:
            raise SystemExit(f"cannot parse member line in struct {struct}: {line!r}")
        for name in m.group(3).split(","):
            out.append((m.group(1), m.group(2), name.strip()))
    return out


def empty(eltype: str, orgtype: str) -> str:
    miss = '""' if eltype == "string" else "."
    return {"colvector": f"J(0, 1, {miss})", "rowvector": f"J(1, 0, {miss})",
            "matrix": f"J(0, 0, {miss})", "scalar": miss}[orgtype]


def assign(target: str, eltype: str, orgtype: str) -> str:
    # Empty values keep the declared orientation; a scalar saved empty is missing
    return f"{target} = (rows(v) * cols(v) == 0 ? {empty(eltype, orgtype)} : v)"


def generate(text: str) -> str:
    par = members(text, "cge_par")
    model = members(text, "cge_model")
    lines = [BEGIN, ""]
    lines += ["void _cge_par_write(real scalar fh, struct cge_par scalar p, string scalar prefix)", "{"]
    lines += [f'    _cge_io_put(fh, prefix + "{n}", p.{n})' for _, _, n in par]
    lines += ["}", ""]
    lines += ["real scalar _cge_par_member(struct cge_par scalar p, string scalar name, transmorphic matrix v)",
              "{"]
    for k, (e, o, n) in enumerate(par):
        lines.append(f'    {"if" if k == 0 else "else if"} (name == "{n}") {assign("p." + n, e, o)}')
    lines += ["    else return(0)", "    return(1)", "}", ""]
    lines += ["void _cge_model_write(real scalar fh, struct cge_model scalar M)", "{", "    real scalar k"]
    for e, o, n in model:
        if e == "struct cge_par":
            if o == "scalar":
                lines.append(f'    _cge_par_write(fh, M.{n}, "{n}.")')
            else:
                lines.append(f'    _cge_io_put(fh, "{n}.count", cols(M.{n}))')
                lines.append(f'    for (k = 1; k <= cols(M.{n}); k++) '
                             f'_cge_par_write(fh, M.{n}[k], "{n}." + strofreal(k) + ".")')
        else:
            lines.append(f'    _cge_io_put(fh, "{n}", M.{n})')
    lines += ["}", ""]
    # Members of structure type (p0, p, simp) are read by _cge_use into fresh
    # structures, each assigned once: in Stata 13, reading an element of a
    # structure vector back, changing it and storing it again can hang Mata
    structs = [(o, n) for e, o, n in model if e == "struct cge_par"]
    if structs != [("scalar", "p0"), ("scalar", "p"), ("rowvector", "simp")]:
        raise SystemExit("cge_model's structure members changed; update _cge_use and this script")
    lines += ["real scalar _cge_model_member(struct cge_model scalar M, string scalar name, transmorphic matrix v)",
              "{"]
    first = True
    for e, o, n in model:
        if e == "struct cge_par":
            continue
        kw = "if" if first else "else if"
        first = False
        lines.append(f'    {kw} (name == "{n}") {assign("M." + n, e, o)}')
    lines += ["    else return(0)", "    return(1)", "}", "", END]
    return "\n".join(lines)


def updated(text: str) -> str:
    block = generate(text)
    if BEGIN in text:
        start = text.index(BEGIN)
        stop = text.index(END) + len(END)
        return text[:start] + block + text[stop:]
    # First generation: before the closing "end" of the Mata block
    idx = text.rstrip().rfind("\nend")
    return text[:idx] + "\n\n" + block + "\n" + text[idx:]


if __name__ == "__main__":
    text = MATA.read_text(encoding="utf-8")
    new = updated(text)
    if "--check" in sys.argv:
        sys.exit(0 if new == text else 1)
    MATA.write_text(new, encoding="utf-8", newline="\n")
    print(f"updated {MATA}")
