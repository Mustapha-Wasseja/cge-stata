# Building and checking the elasticity library

`build_library.py` writes `data/cge_elasticities.csv` and
`data/cge_elasticity_sources.csv` from the published sources (see
[docs/elasticities.md](../../docs/elasticities.md)). The source documents are
not part of the repository; obtain them from the publishers:

| Source | Document | Used for |
|---|---|---|
| Devarajan, Go and Robinson (2023) | World Bank Policy Research Working Paper 10490, PDF of 44 pages | Appendix Tables A1 to A3 (read by the script) |
| Muhammad, Seale, Meade and Regmi (2011) | USDA ERS Technical Bulletin TB-1929, PDF of 59 pages | Table 3 and Appendix tables 1 and 7 (read by the script) |
| Hosni and Ouakil (2024) | *Revue AME* 6(3): 247-269 | Tableau 9, p. 264 (entered in the script) |
| Blanchflower and Oswald (1995) | *Journal of Economic Perspectives* 9(3): 153-167 | pp. 154-155 (entered in the script) |
| Kingdon and Knight (2006) | *ILR Review* 59(3): 471-495 | abstract (entered in the script) |
| Bokhari, Gai and Gottret (2007) | *Health Economics* 16(3): 257-273 | abstract (entered in the script) |

The URLs are in `data/cge_elasticity_sources.csv`.

## Commands

Python 3.10 or later with PyMuPDF (`pip install pymupdf`):

```
python tools/elasticities/build_library.py --devarajan PATH.pdf --muhammad PATH.pdf
python tools/elasticities/build_library.py --devarajan PATH.pdf --muhammad PATH.pdf --check
```

The first writes the two files. The second rebuilds them in memory and
compares them with the files in `data/`, so that the shipped values are
checked against the sources; it exits with code 1 if they differ or if a check
fails. The checks are described in docs/elasticities.md: the t-statistic of
every trade elasticity, and the marginal-share identity for every income
elasticity. The script stops if a page number printed in a PDF does not
follow the expected offset (PDF page less 2 for Devarajan et al., less 6 for
Muhammad et al.).

The CI tests (`reference/tests/test_elasticities.py`) check the files without
the sources: columns, sources, values and bounds, the published t-statistics,
coverage, and known values.

## Result (20 October 2026)

531 entries: 51 Armington and 51 CET elasticities, 423 income elasticities,
the Frisch parameter, capital-labour substitution, 2 wage-curve and 2
mortality elasticities. Every trade elasticity passes the t-statistic check
except the CET of the Democratic Republic of Congo, whose printed t-statistic
is inconsistent in the source (noted in the entry); all 408 checkable income
elasticities pass the marginal-share check (15 more were computed by the
authors from actual budget shares). `--check` reports that the files
agree with the sources.
