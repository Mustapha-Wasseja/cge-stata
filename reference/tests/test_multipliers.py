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


# Structural path analysis (version 0.4.2; docs/sam_tools.md, Section 7)
from cge_ref.multipliers import structural_paths  # noqa: E402


def test_paths_hand_worked_case():
    sam, m = toy()
    r = multipliers(sam, m)
    glob, paths = structural_paths(r, "com", "hhd")
    # one path: com -> act -> lab -> hhd, direct 1 * 0.5 * 1; its poles are all
    # the accounts, so the path multiplier is 1 / det(I - A) = 1 / 0.6
    assert len(paths) == 1 and paths[0].poles == ["com", "act", "lab", "hhd"]
    assert paths[0].direct == pytest.approx(0.5)
    assert paths[0].multiplier == pytest.approx(1 / 0.6)
    assert paths[0].total == pytest.approx(glob)


@pytest.mark.parametrize("make,origin,destination", [
    (synthetic_model, "com_agr", "hhd"), (health_model, "com_hlt", "hhd"),
    (institutions_model, "com_ser", "npi"), (institutions_model, "lab", "ent"),
    (sut_model, "com_fuel", "hhd")])
def test_total_influences_add_up_to_the_multiplier(make, origin, destination):
    r = from_model(make())
    glob, paths = structural_paths(r, origin, destination, maxlength=len(r.labels), threshold=0)
    assert glob == r.M[r.index(destination), r.index(origin)]
    assert sum(p.total for p in paths) == pytest.approx(glob, rel=1e-12)
    # every path is elementary and ends at the destination
    for p in paths:
        assert len(set(p.poles)) == len(p.poles) and p.poles[0] == origin and p.poles[-1] == destination


def test_path_multiplier_is_a_ratio_of_determinants():
    r = from_model(health_model())
    glob, paths = structural_paths(r, "com_hlt", "hhd")
    n = len(r.labels)
    full = np.linalg.det(np.eye(n) - r.A)
    for p in paths:
        keep = [k for k in range(n) if r.labels[k] not in p.poles]
        sub = np.linalg.det((np.eye(n) - r.A)[np.ix_(keep, keep)])
        assert p.multiplier == pytest.approx(sub / full, rel=1e-10)
        direct = np.prod([r.A[r.index(b), r.index(a)] for a, b in zip(p.poles, p.poles[1:])])
        assert p.direct == pytest.approx(direct, rel=1e-14)


def test_path_limits():
    r = from_model(health_model())
    glob, paths = structural_paths(r, "com_hlt", "hhd", maxlength=3)
    assert all(len(p.poles) <= 4 for p in paths)
    glob, paths = structural_paths(r, "com_hlt", "hhd", threshold=0.1)
    assert all(abs(p.direct) >= 0.1 * abs(glob) for p in paths)
    with pytest.raises(SAMError, match="must differ"):
        structural_paths(r, "hhd", "hhd")
    with pytest.raises(SAMError, match="endogenous"):
        structural_paths(r, "gov", "hhd")
