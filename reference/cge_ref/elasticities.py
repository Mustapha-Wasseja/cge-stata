"""The elasticity library (version 0.3.5, docs/elasticities.md): published
estimates with their sources, in data/cge_elasticities.csv and
data/cge_elasticity_sources.csv. This module loads and checks the files; the
Stata command cge_elasticities reads the same files."""

from __future__ import annotations

import csv
import re
from pathlib import Path

DATA = Path(__file__).resolve().parents[2] / "data"
ENTRIES = DATA / "cge_elasticities.csv"
SOURCES = DATA / "cge_elasticity_sources.csv"
FIELDS = ["id", "parameter", "country", "country_name", "category", "value", "se", "lower", "upper",
          "published", "definition", "method", "observations", "period", "source", "location", "check", "notes"]
SOURCE_FIELDS = ["source", "authors", "year", "title", "publication", "url", "version"]
PARAMETERS = ("sigmaq", "sigmat", "sigmava", "incelas", "frisch", "wagecurve", "mortelas", "sickelas")
GROUPS = ("AFR", "WLD", "DEV")
AFRICA = ("DZA AGO BEN BWA BFA BDI CPV CMR CAF TCD COM COD COG CIV DJI EGY GNQ ERI SWZ ETH GAB GMB GHA GIN "
          "GNB KEN LSO LBR LBY MDG MWI MLI MRT MUS MAR MOZ NAM NER NGA RWA STP SEN SYC SLE SOM ZAF SSD SDN "
          "TZA TGO TUN UGA ZMB ZWE").split()
CATEGORIES = ("food", "clothing", "housing", "furnishings", "health", "transport", "recreation", "education",
              "other")


def _read(path: Path) -> tuple[list[str], list[dict]]:
    with path.open(encoding="ascii", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def load(path: Path = ENTRIES) -> list[dict]:
    return _read(path)[1]


def sources(path: Path = SOURCES) -> list[dict]:
    return _read(path)[1]


def select(entries: list[dict], parameter=None, country=None, category=None, source=None, ids=None) -> list[dict]:
    """Entries that match every filter given (each a value or a list of values)."""
    def as_set(v):
        return None if v is None else {v} if isinstance(v, str) else set(v)
    p, c, k, s, i = map(as_set, (parameter, country, category, source, ids))
    return [e for e in entries if (p is None or e["parameter"] in p) and (c is None or e["country"] in c)
            and (k is None or e["category"] in k) and (s is None or e["source"] in s)
            and (i is None or e["id"] in i)]


def problems(entries: list[dict] | None = None, srcs: list[dict] | None = None) -> list[str]:
    """Every departure from the library's rules; empty when the files are sound."""
    out = []
    head, entries_ = _read(ENTRIES) if entries is None else (FIELDS, entries)
    shead, srcs_ = _read(SOURCES) if srcs is None else (SOURCE_FIELDS, srcs)
    entries, srcs = entries_, srcs_
    if head != FIELDS:
        out.append(f"entry columns are {head}")
    if shead != SOURCE_FIELDS:
        out.append(f"source columns are {shead}")
    known = {s["source"] for s in srcs}
    ids = [e["id"] for e in entries]
    if len(ids) != len(set(ids)):
        out.append("entry ids are not unique")
    for e in entries:
        i = e["id"]
        if e["parameter"] not in PARAMETERS:
            out.append(f"{i}: unknown parameter {e['parameter']}")
        if e["country"] not in AFRICA and e["country"] not in GROUPS:
            out.append(f"{i}: country {e['country']} is neither African nor a group")
        if e["source"] not in known:
            out.append(f"{i}: source {e['source']} is not in the sources file")
        for f in ("value", "published", "definition", "location", "check"):
            if not e[f]:
                out.append(f"{i}: no {f}")
        try:
            v = float(e["value"])
        except ValueError:
            out.append(f"{i}: value {e['value']} is not a number")
            continue
        if e["se"] and not float(e["se"]) > 0:
            out.append(f"{i}: standard error must be positive")
        lo, hi = (float(e["lower"]) if e["lower"] else None), (float(e["upper"]) if e["upper"] else None)
        if lo is not None and hi is not None and not lo <= v <= hi:
            out.append(f"{i}: value outside its bounds")
        if e["parameter"] in ("sigmaq", "sigmat", "sigmava", "incelas", "wagecurve") and not v > 0:
            out.append(f"{i}: value must be positive")
        if e["parameter"] == "incelas" and e["category"] not in CATEGORIES:
            out.append(f"{i}: unknown category {e['category']}")
        if e["parameter"] == "frisch" and not v < -1:
            out.append(f"{i}: a Frisch parameter must be below -1")
        # Devarajan et al.: the t-statistic printed with each estimate
        m = re.fullmatch(r"(-?[\d.]+) \(s\.e\. ([\d.]+), t ([\d.]+)\*?\)", e["published"])
        if e["source"] == "DGR2023":
            if not m:
                out.append(f"{i}: published value not in the form 'v (s.e. s, t t)'")
            else:
                pv, se, t = map(float, m.groups())
                ok = abs(pv / se - t) <= 0.0005 / se * (1 + t) + 0.0006
                if pv != v or float(e["se"]) != se:
                    out.append(f"{i}: value or s.e. differs from the published value")
                if not ok and "t-statistic printed in the source" not in e["notes"]:
                    out.append(f"{i}: t-statistic disagrees with value / s.e. and no note says so")
    for e in entries:
        if any(ord(ch) > 127 for ch in "".join(e.values())):
            out.append(f"{e['id']}: not plain ASCII")
    used = {e["source"] for e in entries}
    out += [f"source {s} is not used" for s in known - used]
    return out
