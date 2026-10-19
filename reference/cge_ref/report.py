"""Standard report measures (docs/model_spec.md, Section 9; version 0.1.15).

``report(solution)`` returns one row per measure: (table, measure, element,
base, value). Real measures are valued at base prices, and at base world prices
for trade; nominal measures at current prices. Equivalent and compensating
variations are zero in the base. The Stata command cge_report must reproduce
these rows.
"""

from __future__ import annotations

import numpy as np

from .model import final_price, vat_revenue


def _measures(model, v: dict, p: dict) -> list[tuple[str, str, str, float]]:
    b, p0, S = model.base, model.params, model.sets
    exr, exr0 = v["EXR"][0], b["EXR"][0]
    # Final demand at final-user prices, including VAT; exports from composite
    # supply at PQ (version 0.3.1)
    final = v["QH"].sum(axis=1) + v["QG"] + v["QINV"] + v["QSHI"]
    ph, ph0 = final_price(v, p), final_price(b, p0)
    rows: list[tuple[str, str, str, float]] = []

    def add(table: str, measure: str, element: str, value) -> None:
        rows.append((table, measure, element, float(value)))

    gdp_n = (ph @ final + v["PQ"] @ v["QER"] + exr * (p["pwe"] @ v["QE"])
             - exr * (p["pwm"] @ v["QM"]))
    gdp_r = (ph0 @ final + b["PQ"] @ v["QER"] + exr0 * (p0["pwe"] @ v["QE"])
             - exr0 * (p0["pwm"] @ v["QM"]))
    add("macro", "gdp_nominal", "", gdp_n)
    add("macro", "gdp_real", "", gdp_r)
    add("macro", "gdp_deflator", "", gdp_n / gdp_r)
    add("macro", "consumption_real", "", ph0 @ v["QH"].sum(axis=1))
    add("macro", "government_real", "", ph0 @ v["QG"])
    add("macro", "investment_real", "", ph0 @ v["QINV"])
    add("macro", "insurance_fund_real", "", ph0 @ v["QSHI"])
    add("macro", "exports_real", "", exr0 * (p0["pwe"] @ v["QE"]) + b["PQ"] @ v["QER"])
    add("macro", "imports_real", "", exr0 * (p0["pwm"] @ v["QM"]))
    add("macro", "value_added_real", "", b["PVA"] @ v["QVA"])
    add("macro", "cpi", "", v["CPI"][0])
    add("macro", "dpi", "", v["DPI"][0])
    add("macro", "exchange_rate", "", exr)
    add("macro", "real_exchange_rate", "", exr / v["DPI"][0])
    add("macro", "private_savings", "", (v["MPS"] * (1 - v["TINS"])) @ v["YI"])
    add("macro", "investment_value", "", ph @ v["QINV"])
    add("macro", "foreign_savings", "", v["FSAV"][0])

    add("government", "revenue", "", v["YG"][0])
    add("government", "spending", "", v["EG"][0])
    add("government", "savings", "", v["GSAV"][0])
    add("government", "tax_direct", "", v["TINS"] @ v["YI"])
    add("government", "tax_sales", "", (p["tq"] * v["TQADJ"] * v["PQ"] * v["QQ"]).sum())
    add("government", "tax_import", "", exr * (p["tm"] * v["TMADJ"] * p["pwm"] * v["QM"]).sum())
    add("government", "tax_export", "", exr * (p["te"] * p["pwe"] * v["QE"]).sum())
    add("government", "tax_activity", "", (p["ta"] * v["PA"] * v["QA"]).sum())
    add("government", "tax_vat", "", vat_revenue(v, p)[0])

    # Public debt (model_spec.md, 12.3): stocks at the end of the period
    if p0["debt"] != 0:
        gsav = v["GSAV"][0]
        int_d, int_f = p["rd"] * p["ddebt"], p["rf"] * p["fdebt"] * exr
        end_d = p["ddebt"] + (1 - p["phi"]) * (-gsav)
        end_f = p["fdebt"] + p["phi"] * (-gsav) / exr
        add("debt", "interest_domestic", "", int_d)
        add("debt", "interest_foreign", "", int_f)
        add("debt", "primary_balance", "", gsav + int_d + int_f)
        add("debt", "debt_domestic", "", end_d)
        add("debt", "debt_foreign", "", end_f * exr)
        add("debt", "debt_foreign_fc", "", end_f)
        add("debt", "debt_total", "", end_d + end_f * exr)
        add("debt", "debt_gdp", "", 100 * (end_d + end_f * exr) / gdp_n)

    for k, d in enumerate(S["D"]):
        add("institutions", "income", d, v["YI"][k])
    for k, h in enumerate(S["H"]):
        add("institutions", "consumption", h, v["EH"][k])

    for k, f in enumerate(S["F"]):
        add("factors", "wage", f, v["W"][k])
        add("factors", "real_wage", f, v["W"][k] / v["CPI"][0])
        add("factors", "income", f, v["YF"][k])
        add("factors", "supply", f, v["QFS"][k])

    for k, a in enumerate(S["A"]):
        add("activities", "output", a, v["QA"][k])
        add("activities", "price", a, v["PA"][k])
        add("activities", "value_added", a, v["QVA"][k])

    for k, c in enumerate(S["C"]):
        add("commodities", "supply", c, v["QQ"][k])
        add("commodities", "price", c, v["PQ"][k])
        add("commodities", "output", c, v["QX"][k])
        add("commodities", "domestic_sales", c, v["QD"][k])
        add("commodities", "exports", c, v["QE"][k] + v["QER"][k])
        add("commodities", "imports", c, v["QM"][k])

    if model.exists["HS"].any():
        add("health", "health_services", "", v["HS"][0])
        for k, f in enumerate(S["F"]):
            if model.exists["EFF"][k]:
                add("health", "efficiency", f, v["EFF"][k])
    if model.exists["YSHI"].any():
        add("health", "fund_revenue", "", v["YSHI"][0])
        add("health", "fund_volume", "", v["SHIADJ"][0])
    return rows


def report(solution) -> list[tuple[str, str, str, float, float]]:
    """(table, measure, element, base, value) for every report measure."""
    model = solution.model
    base = _measures(model, model.base, model.params)
    value = _measures(model, solution.values, solution.params)
    out = [(t, m, e, b, x) for (t, m, e, b), (_, _, _, x) in zip(base, value)]
    ev, cv = solution.equivalent_variation(), solution.compensating_variation()
    for k, h in enumerate(model.sets["H"]):
        out.append(("welfare", "equivalent_variation", h, 0.0, float(ev[k])))
        out.append(("welfare", "compensating_variation", h, 0.0, float(cv[k])))
    return out
