"""The elasticity library (version 0.3.5): structure, sources and the checks
that can be made without the source documents."""

import pytest

from cge_ref import elasticities as el


@pytest.fixture(scope="module")
def entries():
    return el.load()


def test_library_has_no_problems():
    assert el.problems() == []


def test_coverage(entries):
    arm = {e["country"] for e in el.select(entries, "sigmaq")}
    cet = {e["country"] for e in el.select(entries, "sigmat")}
    assert len(arm) == 51 and arm == cet
    # Somalia, South Sudan and Sudan are not in Devarajan et al. (2023)
    assert set(el.AFRICA) - arm == {"SOM", "SSD", "SDN"}
    inc = el.select(entries, "incelas")
    countries = {e["country"] for e in inc}
    assert len(countries) == 47 and len(inc) == 47 * 9
    for c in countries:
        assert {e["category"] for e in el.select(inc, country=c)} == set(el.CATEGORIES)


def test_known_values(entries):
    """Values read from the sources (Devarajan et al. Tables A1 and A2 for
    Togo; Muhammad et al. Appendix table 1 for Sierra Leone; Table 3; Hosni
    and Ouakil Tableau 9)."""
    get = lambda i: float(el.select(entries, ids=i)[0]["value"])
    assert get("DGR2023-ARM-TGO") == 0.620
    assert get("DGR2023-CET-TGO") == 0.542
    assert get("MSMR2011-INC-SLE-health") == 2.031
    assert get("MSMR2011-FRISCH") == pytest.approx(1 / -0.732, abs=5e-5)
    assert get("HO2024-KL-AFR") == 0.5897


def test_source_inconsistency_is_noted(entries):
    cod = el.select(entries, ids="DGR2023-CET-COD")[0]
    assert "56.713" in cod["published"] and "t-statistic printed in the source" in cod["notes"]


def test_problems_are_found(entries):
    bad = [dict(e) for e in entries[:3]]
    bad[0]["value"] = "0.999"            # differs from the published value
    bad[1]["source"] = "NONE"
    bad[2]["parameter"] = "sigmax"
    found = el.problems(bad, el.sources())
    assert any("differs from the published value" in p for p in found)
    assert any("NONE is not in the sources file" in p for p in found)
    assert any("unknown parameter sigmax" in p for p in found)


def test_select(entries):
    rows = el.select(entries, "incelas", country=["TGO", "SLE"], category="food")
    assert sorted(e["id"] for e in rows) == ["MSMR2011-INC-SLE-food", "MSMR2011-INC-TGO-food"]
    assert el.select(entries, "wagecurve", country="ZAF")[0]["source"] == "KK2006"
