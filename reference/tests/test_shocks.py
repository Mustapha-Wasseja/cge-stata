"""Shocks to spending by product and to transfers (version 0.1.10)."""

import numpy as np

from cge_ref import Closure
from cge_ref.scenarios import institutions_model, synthetic_model


def test_government_spending_on_one_product():
    m = synthetic_model()
    ser = m.sets["C"].index("com_ser")
    qg = m.params["qg"].copy()
    qg[ser] *= 1.2
    s = m.solve(Closure(), params={"qg": qg})
    assert s.converged
    assert np.isclose(s["QG"][ser], 1.2 * m.base["QG"][ser])
    others = [k for k in range(len(qg)) if k != ser]
    assert np.allclose(s["QG"][others], m.base["QG"][others])
    assert s["EG"][0] > m.base["EG"][0] and s["GSAV"][0] < m.base["GSAV"][0]
    assert abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8


def test_transfers_from_abroad():
    m = institutions_model()
    s = m.solve(Closure(), params={"trdr": m.params["trdr"] * 0.5})
    assert s.converged
    hhd = m.sets["D"].index("hhd")
    assert s["EXR"][0] > 1                      # less foreign exchange: depreciation
    assert s["YI"][hhd] / s["CPI"][0] < m.base["YI"][hhd]
    assert abs(s["WALRAS"][0]) < 1e-8 and abs(s.gdp_gap()) < 1e-8
