"""Build the elasticity library (data/cge_elasticities.csv and
data/cge_elasticity_sources.csv) from the published sources (version 0.3.5).

Tables are read from the source PDFs by word position and checked:

- Devarajan, Go and Robinson (2023), Appendix Tables A1 and A2: each
  estimate, standard error and t-statistic must agree (t = estimate / s.e.,
  within the rounding of the printed values); departures printed in the
  source are recorded in the notes.
- Muhammad, Seale, Meade and Regmi (2011), Appendix table 1: each income
  elasticity must lie within the range implied by the marginal share in
  Appendix table 7 and the coefficient beta in Table 3, eta = theta /
  (theta - beta), given the rounding of the printed values (cells the
  authors computed from actual budget shares are exempt).

Single values (factor substitution, the wage curve, the Frisch parameter and
mortality elasticities) are entered below with their locations, read from
the sources as described in tools/elasticities/README.md.

The PDFs are not part of the repository. Usage:

    python tools/elasticities/build_library.py --devarajan PDF --muhammad PDF [--check]

With --check the library is rebuilt in memory and compared with the files in
data/, which must agree exactly; the exit code is 1 otherwise.
"""

from __future__ import annotations

import argparse
import csv
import io
import re
import sys
import unicodedata
from pathlib import Path

import fitz  # PyMuPDF

REPO = Path(__file__).resolve().parents[2]
ENTRIES = REPO / "data" / "cge_elasticities.csv"
SOURCES = REPO / "data" / "cge_elasticity_sources.csv"
FIELDS = ["id", "parameter", "country", "country_name", "category", "value", "se", "lower", "upper",
          "published", "definition", "method", "observations", "period", "source", "location", "check", "notes"]
NUM = re.compile(r"^-?\d+\.\d+$")

# African countries (ISO 3166-1 alpha-3)
AFRICA = ("DZA AGO BEN BWA BFA BDI CPV CMR CAF TCD COM COD COG CIV DJI EGY GNQ ERI SWZ ETH GAB GMB GHA GIN "
          "GNB KEN LSO LBR LBY MDG MWI MLI MRT MUS MAR MOZ NAM NER NGA RWA STP SEN SYC SLE SOM ZAF SSD SDN "
          "TZA TGO TUN UGA ZMB ZWE").split()

SOURCE_ROWS = [
    {"source": "DGR2023", "authors": "Devarajan, S.; Go, D. S.; Robinson, S.", "year": "2023",
     "title": "Trade Elasticities in Aggregate Models: Estimates for 191 Countries",
     "publication": "World Bank Policy Research Working Paper 10490",
     "url": "https://documents1.worldbank.org/curated/en/099524306202324085/pdf/IDU01ba09ebe0931f04f070a11c0471fc38ea0e2.pdf",
     "version": "working paper PDF (44 pages)"},
    {"source": "MSMR2011", "authors": "Muhammad, A.; Seale, J. L., Jr.; Meade, B.; Regmi, A.", "year": "2011",
     "title": "International Evidence on Food Consumption Patterns: An Update Using 2005 International "
              "Comparison Program Data",
     "publication": "USDA Economic Research Service, Technical Bulletin TB-1929",
     "url": "https://www.govinfo.gov/content/pkg/GOVPUB-A-PURL-gpo15030/pdf/GOVPUB-A-PURL-gpo15030.pdf",
     "version": "report PDF (59 pages)"},
    {"source": "HO2024", "authors": "Hosni, M.; Ouakil, H.", "year": "2024",
     "title": "Estimation de l'élasticité de substitution entre le capital et le travail de l'économie "
              "africaine : une analyse en données de panel",
     "publication": "Revue AME 6(3): 247-269",
     "url": "https://www.researchgate.net/publication/383862691", "version": "journal PDF (23 pages)"},
    {"source": "BO1995", "authors": "Blanchflower, D. G.; Oswald, A. J.", "year": "1995",
     "title": "An Introduction to the Wage Curve", "publication": "Journal of Economic Perspectives 9(3): 153-167",
     "url": "https://doi.org/10.1257/jep.9.3.153", "version": "journal pages (JSTOR scan)"},
    {"source": "KK2006", "authors": "Kingdon, G. G.; Knight, J.", "year": "2006",
     "title": "How Flexible are Wages in Response to Local Unemployment in South Africa?",
     "publication": "ILR Review 59(3): 471-495", "url": "https://doi.org/10.1177/001979390605900308",
     "version": "published abstract"},
    {"source": "BGG2007", "authors": "Bokhari, F. A. S.; Gai, Y.; Gottret, P.", "year": "2007",
     "title": "Government Health Expenditures and Health Outcomes", "publication": "Health Economics 16(3): 257-273",
     "url": "https://doi.org/10.1002/hec.1157", "version": "published abstract"},
]

# Single values: (id, parameter, country, country_name, category, value, se, lower, upper, published,
# definition, method, observations, period, source, location, check, notes)
SINGLE = [
    ("HO2024-KL-AFR", "sigmava", "AFR", "30 African countries (pooled)", "capital-labour", "0.5897", "0.0275",
     "0.535", "0.643", "0.5897 (rounded to 0.58 in the abstract)",
     "elasticity of substitution between capital and labour, CES production function (Arrow et al. 1961 approach)",
     "fixed effects, corrected for heteroscedasticity and autocorrelation", "", "1970-2017", "HO2024",
     "Tableau 9, p. 264; abstract, p. 247", "rendered page",
     "economy-wide estimate, not by activity; the bounds are the 95 per cent interval"),
    ("BO1995-WC", "wagecurve", "WLD", "12 countries (international microdata)", "", "0.1", "", "0.08", "0.11",
     "-0.1 (ln w = -0.1 ln U); -0.08 to -0.11 for Britain, Canada and the United States",
     "elasticity of pay with respect to the local unemployment rate, in absolute value", "regional wage equations",
     "", "", "BO1995", "pp. 154-155", "rendered page",
     "the package takes the absolute value; the bounds are the range for Britain, Canada and the United States"),
    ("KK2006-WC-ZAF", "wagecurve", "ZAF", "South Africa", "", "0.1", "", "", "",
     "about -0.1", "elasticity of wages with respect to local unemployment rates, in absolute value",
     "wage equations, South African Living Standards Survey", "", "1993", "KK2006", "abstract",
     "publisher abstract", "the package takes the absolute value"),
    ("BGG2007-U5M", "mortelas", "DEV", "developing countries (cross-country)", "under-five mortality", "-0.33", "",
     "-0.42", "-0.25", "mean -0.33, range -0.25 to -0.42",
     "elasticity of under-five mortality with respect to government health expenditure per capita",
     "instrumental variables (GMM-H2SL), health expenditure and income endogenous", "", "", "BGG2007", "abstract",
     "publisher abstract",
     "not the crude death rate with respect to health services per head of the package (Section 15.3): a "
     "different outcome and driver"),
    ("BGG2007-MMR", "mortelas", "DEV", "developing countries (cross-country)", "maternal mortality", "-0.50", "",
     "-0.52", "-0.42", "mean -0.50, range -0.42 to -0.52",
     "elasticity of maternal mortality with respect to government health expenditure per capita",
     "instrumental variables (GMM-H2SL), health expenditure and income endogenous", "", "", "BGG2007", "abstract",
     "publisher abstract",
     "not the crude death rate with respect to health services per head of the package (Section 15.3): a "
     "different outcome and driver"),
]

MUHAMMAD_CATS = ["food", "clothing", "housing", "furnishings", "health", "transport", "recreation", "education",
                 "other"]
CAT_LABELS = {"food": "food, beverages and tobacco", "clothing": "clothing and footwear",
              "housing": "housing and utilities", "furnishings": "furnishings, household equipment and maintenance",
              "health": "medical and health", "transport": "transport and communication",
              "recreation": "recreation and culture", "education": "education", "other": "other goods and services"}
BETA = {"food": -0.108, "clothing": -0.002, "housing": 0.011, "furnishings": 0.003, "health": 0.020,
        "transport": 0.022, "recreation": 0.026, "education": -0.002, "other": 0.030}
# Names in Muhammad et al. (2011); the name of Sao Tome and Principe wraps,
# so only its second line is attached to the row
MUHAMMAD_ISO = {
    "Congo, Dem. Rep.": "COD", "Burundi": "BDI", "Liberia": "LBR", "Zimbabwe": "ZWE", "Ethiopia": "ETH",
    "Guinea-Bissau": "GNB", "Niger": "NER", "Mozambique": "MOZ", "Malawi": "MWI", "Rwanda": "RWA", "Chad": "TCD",
    "Angola": "AGO", "Gambia, The": "GMB", "Central African Republic": "CAF", "Mali": "MLI", "Tanzania": "TZA",
    "Sierra Leone": "SLE", "Guinea": "GIN", "Burkina Faso": "BFA", "Zambia": "ZMB", "Madagascar": "MDG",
    "Uganda": "UGA", "Togo": "TGO", "Congo, Rep.": "COG", "Ghana": "GHA", "Mauritania": "MRT",
    "Côte d’Ivoire": "CIV", "Benin": "BEN", "Djibouti": "DJI", "Nigeria": "NGA", "Senegal": "SEN",
    "Kenya": "KEN", "Principe": "STP", "Cameroon": "CMR", "Sudan": "SDN", "Lesotho": "LSO", "Morocco": "MAR",
    "Cape Verde": "CPV", "Namibia": "NAM", "Botswana": "BWA", "Gabon": "GAB", "Equatorial Guinea": "GNQ",
    "Swaziland": "SWZ", "Egypt, Arab Rep.": "EGY", "Tunisia": "TUN", "South Africa": "ZAF", "Mauritius": "MUS"}
DISPLAY = {"STP": "São Tomé and Príncipe"}


def lines(page):
    out = {}
    for x0, y0, x1, y1, t, *_ in page.get_text("words"):
        out.setdefault(round((y0 + y1) / 2, 1), []).append((x0, t))
    return {y: sorted(ws) for y, ws in sorted(out.items())}


def printed_page(page, offset: int) -> str:
    """The page number printed on a PDF page, which is the PDF page number less
    offset; a page that prints no number takes that value."""
    first = page.get_text().strip().split("\n")[0].strip()
    expected = page.number + 1 - offset
    if first.isdigit() and int(first) != expected:
        raise SystemExit(f"PDF page {page.number + 1} prints page {first}, not {expected}")
    return str(expected)


def num(z: str) -> float:
    z = re.sub(r"[^0-9.\-]", "", z)
    return float(z) if z else float("nan")


def devarajan(pdf: str) -> tuple[list[dict], list[str]]:
    d = fitz.open(pdf)

    def table(pages, c):
        rows = []
        for pno in pages:
            page = d[pno - 1]
            L = lines(page)
            ys = list(L)
            for y in ys:
                ws = L[y]
                vals = [t for x, t in ws if c[0][0] <= x <= c[0][1] and NUM.match(t)]
                if not vals:
                    continue
                get = lambda lo, hi: [t for x, t in ws if lo <= x <= hi]
                name = []
                for y2 in ys:
                    if abs(y2 - y) <= 8:
                        name += [t for x, t in L[y2] if x < c[0][0] - 2]
                se, ts, nob, meth = get(*c[1]), get(*c[2]), get(*c[3]), get(*c[4])
                rows.append({"pdf": pno, "page": printed_page(page, 2), "country": " ".join(name), "value": vals[0],
                             "se": se[0] if se else "", "t": ts[0] if ts else "", "nob": nob[0] if nob else "",
                             "method": " ".join(meth)})
        return rows

    codes = {}
    for pno in range(40, 45):
        for y, ws in lines(d[pno - 1]).items():
            code = [t for x, t in ws if re.fullmatch(r"[A-Z]{3}", t) and 235 < x < 260]
            period = [t for x, t in ws if re.fullmatch(r"\d{4}-\d{4}", t)]
            name = " ".join(t for x, t in ws if x < 235)
            if code and name:
                codes[name] = (code[0], period[0] if period else "")
    a1 = table(range(27, 33), ((115, 135), (150, 175), (190, 225), (230, 250), (255, 300)))
    a2 = table(range(33, 40), ((98, 118), (132, 160), (170, 205), (210, 232), (236, 280)))
    out, problems = [], []
    for par, tab, rows in (("sigmaq", "A1", a1), ("sigmat", "A2", a2)):
        for r in rows:
            if r["country"] not in codes:
                continue
            iso, period = codes[r["country"]]
            if iso not in AFRICA:
                continue
            v, se, t = num(r["value"]), num(r["se"]), num(r["t"])
            tol = 0.0005 / se * (1 + abs(t)) + 0.0006
            ok = abs(v / se - t) <= tol
            note = "" if ok else (f"the t-statistic printed in the source ({r['t']}) is not the estimate divided "
                                  f"by its standard error ({v / se:.3f})")
            if not ok and iso not in KNOWN_T_ERRORS.get(par, ()):
                problems.append(f"{tab} {r['country']}: t check fails ({r})")
            name = "Armington" if par == "sigmaq" else "CET"
            out.append({
                "id": f"DGR2023-{'ARM' if par == 'sigmaq' else 'CET'}-{iso}", "parameter": par, "country": iso,
                "country_name": r["country"], "category": "aggregate", "value": r["value"], "se": r["se"],
                "lower": "", "upper": "",
                "published": f"{r['value']} (s.e. {r['se']}, t {r['t']})",
                "definition": (f"aggregate {name} elasticity between {'imports and domestic goods' if par == 'sigmaq' else 'exports and domestic sales'}, "
                               "estimated from national accounts series"),
                "method": r["method"], "observations": r["nob"], "period": period, "source": "DGR2023",
                "location": f"Appendix Table {tab}, p. {r['page']} (PDF p. {r['pdf']}); data period from Table A3",
                "check": "t-statistic agrees with estimate / s.e." if ok else "t-statistic disagrees (see notes)",
                "notes": "; ".join(x for x in (note, "aggregate elasticities are lower than sector ones (the source, "
                                               "PDF p. 20); set the level, not every sector") if x)})
    return out, problems


# Departures from t = estimate / s.e. that are in the source itself (checked on
# the rendered page): DR Congo's CET is printed as 0.503, s.e. 0.245, t 56.713
KNOWN_T_ERRORS = {"sigmat": ("COD",)}


def muhammad(pdf: str) -> tuple[list[dict], list[str]]:
    d = fitz.open(pdf)
    numre = re.compile(r"^(-?\d+\.\d+)(a?)$")

    def table(pages, extra):
        rows = []
        for pno in pages:
            page = d[pno - 1]
            W = [(x0, (y0 + y1) / 2, t) for x0, y0, x1, y1, t, *_ in page.get_text("words")]
            head = [w for w in W if w[2] == "Recreation"][0][1]
            hl = sorted((x, t) for x, y, t in W if abs(y - head) < 2 and t not in ("Country", "&"))
            labels = extra + MUHAMMAD_CATS
            anchors = [x for x, t in hl]
            if len(anchors) != len(labels):
                raise SystemExit(f"page {pno}: unexpected header {hl}")
            nums = sorted((y, x, t) for x, y, t in W if numre.match(t) and y > head + 5)
            groups = []
            for y, x, t in nums:
                if groups and abs(y - groups[-1][0]) <= 2.5:
                    groups[-1][1].append((x, t))
                else:
                    groups.append([y, [(x, t)]])
            for y, cells in groups:
                name = " ".join(t for x, yy, t in sorted(W, key=lambda w: (w[1], w[0]))
                                if x < anchors[0] - 10 and abs(yy - y) <= 8)
                row = {"pdf": pno, "page": printed_page(page, 6), "country": name}
                for x, t in cells:
                    k = min(range(len(anchors)), key=lambda i: abs(anchors[i] - x))
                    m = numre.match(t)
                    row[labels[k]] = m.group(1)
                    row[labels[k] + "_flag"] = m.group(2)
                rows.append(row)
        return rows

    t1, t7 = table(range(28, 32), []), table(range(52, 56), ["income"])
    problems = []
    if len(t1) != len(t7):
        problems.append("tables 1 and 7 have different numbers of rows")
    for a, b in zip(t1, t7):
        if a["country"] != b["country"] and not a["country"].endswith(b["country"]) \
                and a["country"].replace("’", "'") != b["country"]:
            problems.append(f"rows of tables 1 and 7 do not align: {a['country']} / {b['country']}")
    out = []
    for a, b in zip(t1, t7):
        iso = MUHAMMAD_ISO.get(a["country"])
        if iso is None:
            continue
        for c in MUHAMMAD_CATS:
            v, flag = a[c], a[c + "_flag"]
            check = "within the range implied by marginal share and beta"
            if flag:
                check = "not checked: computed by the authors from actual budget shares"
            else:
                th, be = float(b[c]), BETA[c]
                etas = [(th + dt) / (th + dt - be - db) for dt in (-0.0005, 0.0005) for db in (-0.0005, 0.0005)
                        if th + dt - be - db > 0]
                if not etas or not min(etas) - 0.0005 <= float(v) <= max(etas) + 0.0005:
                    problems.append(f"table 1 {a['country']} {c}: {v} outside {etas}")
            out.append({
                "id": f"MSMR2011-INC-{iso}-{c}", "parameter": "incelas", "country": iso,
                "country_name": DISPLAY.get(iso, a["country"]), "category": c, "value": v, "se": "", "lower": "",
                "upper": "", "published": v + (" (note a)" if flag else ""),
                "definition": f"income (total expenditure) elasticity of demand for {CAT_LABELS[c]}, at geometric "
                              "mean prices",
                "method": "Florida-PI demand system, maximum likelihood, 144 countries", "observations": "",
                "period": "2005", "source": "MSMR2011",
                "location": f"Appendix table 1, p. {a['page']} (PDF p. {a['pdf']})", "check": check,
                "notes": ("the estimated budget share was negative, so the authors computed this value from the "
                          "actual budget share (Appendix table 1, note a)") if flag else ""})
    frisch = {
        "id": "MSMR2011-FRISCH", "parameter": "frisch", "country": "WLD", "country_name": "144 countries (pooled)",
        "category": "", "value": f"{1 / -0.732:.4f}", "se": "", "lower": "", "upper": "",
        "published": "income flexibility phi = -0.732 (s.e. 0.034)",
        "definition": "Frisch parameter, the inverse of the income flexibility phi (the inverse of the income "
                      "elasticity of the marginal utility of income)",
        "method": "Florida-PI demand system, maximum likelihood", "observations": "144", "period": "2005",
        "source": "MSMR2011", "location": "Table 3, p. 12 (PDF p. 18)", "check": "rendered page; derived as 1/phi",
        "notes": "phi is assumed constant across countries in the source; the source system is not an LES"}
    # The value of phi is read from the page, so that the check binds to it
    page = d[17].get_text()
    if "Income flexibility" not in page or "-0.732" not in page or "0.034" not in page:
        problems.append("Table 3: income flexibility -0.732 (0.034) not found on PDF p. 18")
    return out + [frisch], problems


def single_rows() -> list[dict]:
    return [dict(zip(FIELDS, row)) for row in SINGLE]


def ascii(text: str) -> str:
    """Plain ASCII, which Stata 13 displays: accents are dropped."""
    text = text.replace("’", "'").replace("–", "-")
    return unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")


def to_csv(rows: list[dict], fields: list[str]) -> str:
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=fields, lineterminator="\n")
    w.writeheader()
    for r in rows:
        w.writerow({k: ascii(str(r.get(k, ""))) for k in fields})
    return buf.getvalue()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--devarajan", required=True)
    ap.add_argument("--muhammad", required=True)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    dev, p1 = devarajan(args.devarajan)
    muh, p2 = muhammad(args.muhammad)
    problems = p1 + p2
    rows = dev + muh + single_rows()
    ids = [r["id"] for r in rows]
    if len(ids) != len(set(ids)):
        problems.append("duplicate ids")
    entries = to_csv(rows, FIELDS)
    sources = to_csv(SOURCE_ROWS, ["source", "authors", "year", "title", "publication", "url", "version"])
    for p in problems:
        print("PROBLEM:", p)
    counts = {}
    for r in rows:
        counts[r["parameter"]] = counts.get(r["parameter"], 0) + 1
    print(f"{len(rows)} entries: " + ", ".join(f"{k} {v}" for k, v in counts.items()))
    if args.check:
        same = (ENTRIES.read_text(encoding="utf-8") == entries and SOURCES.read_text(encoding="utf-8") == sources)
        print("library files agree with the sources" if same else "library files DIFFER from the sources")
        sys.exit(0 if same and not problems else 1)
    if problems:
        sys.exit(1)
    ENTRIES.write_text(entries, encoding="utf-8")
    SOURCES.write_text(sources, encoding="utf-8")
    print(f"wrote {ENTRIES} and {SOURCES}")


if __name__ == "__main__":
    main()
