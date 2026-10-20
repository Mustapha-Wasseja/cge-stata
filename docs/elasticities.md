# Elasticity library (from version 0.3.5)

The model's free parameters (elasticities of substitution and
transformation, income elasticities, the Frisch parameter, the wage-curve
elasticity and the health-outcome elasticities of Sections 14 and 15) have no
defaults: they are part of the specification and must be stated. The library
records published estimates, with the source, the table and page where each
is printed, its definition, and the check made when it was read. The command
`cge_elasticities` lists or loads entries, or returns them as options for
`cge_calibrate`; nothing is applied without a command.

## Contents

| Parameter | Entries | Coverage | Source |
|---|---|---|---|
| `sigmaq` | 51 | aggregate Armington elasticity, African countries (series to 2018) | Devarajan, Go and Robinson (2023), Appendix Table A1 |
| `sigmat` | 51 | aggregate CET elasticity, the same countries | Devarajan, Go and Robinson (2023), Appendix Table A2 |
| `incelas` | 423 | income elasticities for nine categories, 47 African countries (2005) | Muhammad, Seale, Meade and Regmi (2011), Appendix table 1 |
| `frisch` | 1 | inverse of the income flexibility, 144 countries pooled | Muhammad et al. (2011), Table 3 |
| `sigmava` | 1 | capital-labour substitution, 30 African countries pooled (1970-2017) | Hosni and Ouakil (2024), Tableau 9 |
| `wagecurve` | 2 | international (12 countries) and South Africa (1993) | Blanchflower and Oswald (1995); Kingdon and Knight (2006) |
| `mortelas` | 2 | under-five and maternal mortality with respect to government health expenditure, developing countries | Bokhari, Gai and Gottret (2007) |

Somalia, South Sudan and Sudan are not covered by Devarajan et al. (2023);
Muhammad et al. (2011) cover 47 African countries (the 2005 ICP round, without
Comoros, which the authors exclude).

Files: `data/cge_elasticities.csv` (one row per entry) and
`data/cge_elasticity_sources.csv` (one row per source). They are plain ASCII,
which Stata 13 displays, so accents are dropped (for example, "Cote
d'Ivoire").

| Column | Content |
|---|---|
| `id` | entry, for example `DGR2023-ARM-TGO` |
| `parameter` | the `cge_calibrate` option the value is for |
| `country`, `country_name` | ISO 3166 alpha-3 code, or a group: `AFR` Africa, `WLD` international, `DEV` developing countries; the name as printed |
| `category` | `aggregate` for the trade elasticities; the consumption category for income elasticities (`food`, `clothing`, `housing`, `furnishings`, `health`, `transport`, `recreation`, `education`, `other`) |
| `value`, `se`, `lower`, `upper` | the value in the package's convention, its standard error, and bounds where the source gives them |
| `published` | the value as printed |
| `definition`, `method`, `observations`, `period` | what was estimated, how, and on what data |
| `source`, `location` | the source and where the value is printed |
| `check`, `notes` | the check made, and qualifications |

The package's conventions differ from some sources in two places: the
wage-curve elasticity is the absolute value of the published negative
elasticity (Section 14.2), and the Frisch parameter is the inverse of the
published income flexibility (-1 / 0.732 = -1.3661).

## How the values were read and checked

The two multi-country tables are read from the source PDFs by word position
(`tools/elasticities/build_library.py`), with a check on every value:

- **Devarajan et al. (2023).** Each estimate is printed with its standard
  error and t-statistic. The t-statistic must equal the estimate divided by the
  standard error, within the rounding of the printed values; 101 of the 102
  African entries pass. One fails in the source itself: the CET elasticity of the Democratic Republic of
  Congo is printed as 0.503 with standard error 0.245 and t-statistic 56.713,
  although 0.503 / 0.245 = 2.05 (checked on the rendered page). The entry keeps
  the printed values and a note.
- **Muhammad et al. (2011).** Each income elasticity is eta = theta / (theta -
  beta), with the marginal share theta in Appendix table 7 and the coefficient
  beta in Table 3. All 408 African entries that can be checked lie within the
  range that the rounding of theta and beta allows (so do those of the other
  countries); the 15 that the authors computed from actual budget shares (note
  a of the table) cannot be checked this way and are marked.

The values also agree with an earlier, separate reading of the same tables
for Sierra Leone, Togo, Botswana, Ethiopia and Guinea (55 values). The other
values were read from the rendered source pages (Hosni and Ouakil;
Blanchflower and Oswald; the Frisch parameter) or from the published abstracts
(Kingdon and Knight; Bokhari et al.).

Not included:

- Anyanwu and Erhijakpor (2009, *African Development Review* 21(2)): only the
  2007 conference version could be checked, and its tables do not align
  reliably.
- The World Bank chapter by Bokhari, Gai and Gottret (in *Health Financing
  Revisited*, 2006) reports different elasticities from a model with donor
  funding; the library uses the journal article.
- Default parameters of global models (for example GTAP) and values derived
  from IFPRI SAMs or models. A user who holds such values can add them in a
  file of the same layout (`cge_elasticities ... using`).

## Using the values

- **Definitions.** Match the definition, coverage and period before using a
  value. The mortality elasticities of Bokhari et al. are with respect to
  government health expenditure per head, not the death rate with respect to
  health services per head of `mortelas()` (Section 15.3); they are recorded
  for reference.
- **Aggregate and sector values.** Aggregate trade elasticities are lower than
  sector ones, because aggregate imports and exports are composites of many
  goods (Devarajan et al. 2023). They set a level rather than every sector's
  value; using one aggregate value for every commodity is a strong
  simplification.
- **Income elasticities.** They come from a cross-country demand system for
  2005 (the Florida-PI model), evaluated for each country, not from the
  country's household survey. They map to model commodities through the nine
  categories (`map()`, `others()`).
- **Uncertainty.** Standard errors and bounds can guide `cge_sensitivity`.

## Updating the library

`tools/elasticities/README.md` gives the source documents and the commands to
rebuild the files and to check them against the sources.

## References

Blanchflower, D. G. and A. J. Oswald (1995). An introduction to the wage curve.
*Journal of Economic Perspectives* 9(3): 153-167.

Bokhari, F. A. S., Y. Gai and P. Gottret (2007). Government health expenditures
and health outcomes. *Health Economics* 16(3): 257-273.

Devarajan, S., D. S. Go and S. Robinson (2023). Trade elasticities in aggregate
models: estimates for 191 countries. World Bank Policy Research Working Paper
10490.

Hosni, M. and H. Ouakil (2024). Estimation de l'élasticité de substitution
entre le capital et le travail de l'économie africaine : une analyse en données
de panel. *Revue AME* 6(3): 247-269.

Kingdon, G. G. and J. Knight (2006). How flexible are wages in response to local
unemployment in South Africa? *ILR Review* 59(3): 471-495.

Muhammad, A., J. L. Seale Jr., B. Meade and A. Regmi (2011). *International
Evidence on Food Consumption Patterns: An Update Using 2005 International
Comparison Program Data*. Technical Bulletin TB-1929, Economic Research
Service, U.S. Department of Agriculture.
