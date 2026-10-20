"""SAM accounting multipliers and their decomposition (version 0.4.1;
docs/sam_tools.md, Section 6)."""

import numpy as np
import pytest

from cge_ref.multipliers import from_model, multipliers
from cge_ref.sam import SAM, Mapping, SAMError
from cge_ref.scenarios import health_model, institutions_model, sut_model, synthetic_model


def toy():
    """A circular SAM worked by hand: the activity pays half its income to
    labour and half in taxes; labour pays all of its income to the household;
    the household spends 80 per cent on the commodity and saves 20 per cent;
    the commodity is supplied by the activity."""
    labels = ["act", "com", "lab", "hhd", "gov", "sav", "row"]
    S = np.zeros((7, 7))
    def put(r, c, v):
        S[labels.index(r), labels.index(c)] = v
    put("com", "act", 0.0)
    put("act", "com", 100)      # the commodity is bought from the activity
    put("lab", "act", 50)
    put("gov", "act", 50)       # a leakage
    put("hhd", "lab", 50)
    put("com", "hhd", 40)
    put("sav", "hhd", 10)
    put("com", "gov", 50)
    put("com", "sav", 10)
    return SAM(labels, S), Mapping(activities=["act"], commodities=["com"], factors=["lab"], households=["hhd"],
                                   government="gov", savinv="sav", row="row")


def test_hand_worked_case():
    sam, m = toy()
    r = multipliers(sam, m, decompose=True)
    assert r.labels == ["act", "com", "lab", "hhd"]
    # a unit injection into the commodity: y_com = 1 / (1 - 0.5 * 1 * 0.8)
    j = r.index("com")
    k = 1 / (1 - 0.5 * 0.8)
    assert r.M[r.index("com"), j] == pytest.approx(k)
    assert r.M[r.index("act"), j] == pytest.approx(k)
    assert r.M[r.index("lab"), j] == pytest.approx(0.5 * k)
    assert r.M[r.index("hhd"), j] == pytest.approx(0.5 * k)
    # the transfer effect within production (commodity -> activity) is 1; the
    # open-loop effects reach factors and households; the closed loop is k - 1
    assert r.parts["transfer"][r.index("act"), j] == pytest.approx(1.0)
    assert r.parts["open_loop"][r.index("lab"), j] == pytest.approx(0.5)
    assert r.parts["open_loop"][r.index("hhd"), j] == pytest.approx(0.5)
    assert r.parts["closed_loop"][r.index("com"), j] == pytest.approx(k - 1)


@pytest.mark.parametrize("make", [synthetic_model, institutions_model, health_model, sut_model])
def test_identities(make):
    r = from_model(make(), decompose=True)
    n = len(r.labels)
    I = np.eye(n)
    assert np.allclose(r.M @ (I - r.A), I, atol=1e-12)
    p = r.parts
    assert np.allclose(p["M3"] @ p["M2"] @ p["M1"], r.M, atol=1e-12)
    assert np.allclose(I + p["transfer"] + p["open_loop"] + p["closed_loop"], r.M, atol=1e-12)
    # spending leaks from the endogenous accounts taken together: the spectral
    # radius of A is below one (a column may sum to more than one when the
    # account has a negative exogenous cell, such as dissaving)
    assert max(abs(np.linalg.eigvals(r.A))) < 1
    # multipliers are at least the injection and non-negative here
    assert (np.diag(r.M) >= 1 - 1e-12).all() and (r.M >= -1e-12).all()


def test_injection():
    model = health_model()
    r = from_model(model)
    dy = r.inject({"com_hlt": 100.0})
    assert np.allclose(dy, 100 * r.M[:, r.index("com_hlt")])
    # with no leakage from activities except to factors and taxes, output rises
    # by at least the injection
    assert dy[r.index("act_hlt")] >= 100


def test_accounts_and_blocks():
    model = institutions_model()
    r = from_model(model)
    assert r.labels[-3:] == ["hhd", "npi", "ent"]
    assert list(r.blocks[-3:]) == [3, 3, 3]
    g = from_model(model, endogenous=["gov"], exogenous=["ent"], decompose=True)
    assert "ent" not in g.labels and g.labels[-1] == "gov" and g.blocks[-1] == 3
    s = from_model(sut_model())
    margins = sut_model().mapping.margin_accounts
    assert margins and all(s.blocks[s.index(a)] == 1 for a in margins)


def test_errors():
    model = synthetic_model()
    with pytest.raises(SAMError, match="not an endogenous account"):
        from_model(model, exogenous=["gov"])
    with pytest.raises(SAMError, match="already endogenous"):
        from_model(model, endogenous=["hhd"])
    with pytest.raises(SAMError, match="not an endogenous account"):
        from_model(model).inject({"gov": 1.0})
    # an activity paying a household breaks the circular structure
    sam, m = toy()
    sam.values[sam.labels.index("hhd"), sam.labels.index("act")] = 5
    sam.values[sam.labels.index("gov"), sam.labels.index("act")] = 45
    multipliers(sam, m)
    with pytest.raises(SAMError, match="circular block structure"):
        multipliers(sam, m, decompose=True)
    # a tax account paid by commodities, in the institutions block
    with pytest.raises(SAMError, match="circular block structure"):
        from_model(model, endogenous=["tax_sal"], decompose=True)
