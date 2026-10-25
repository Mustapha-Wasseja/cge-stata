"""cge-stata: links to SciPy through Stata's Python integration (from version
0.27.0; Stata 16 and later, with Python and SciPy). An experimental
prototype: SuperLU factorises the Jacobians of Newton's method
(cge_options, linsolver(python)) and HiGHS solves linear and mixed-integer
programmes of standalone models (cge_solve, solver(highs)). Mata writes the
data to binary files of little-endian doubles and reads the results back
the same way; return codes and statistics go back as Stata scalars.

Author: Mustapha Wasseja Mohammed
"""
import numpy as np
import sfi
from scipy.sparse import csc_matrix
from scipy.sparse.linalg import splu

_lu = {}
_nfactor = [0]


def _doubles(fn):
    return np.fromfile(fn, dtype="<f8")


def _put(fn, x):
    np.asarray(x, dtype="<f8").tofile(fn)


def _matrix(trip, nz, nr, nc):
    """A sparse matrix from triplets stacked as rows, columns, values."""
    t = trip[:3 * nz].reshape(3, nz)
    return csc_matrix((t[2], (t[0].astype(np.int64) - 1, t[1].astype(np.int64) - 1)), shape=(nr, nc))


def lu_factor(key, fn, n, nz):
    """Factorise the n x n matrix of nz triplets in file fn; CGE_PYRC is 0,
    or 1 if it is singular. Duplicate entries are summed."""
    A = _matrix(_doubles(fn), int(nz), int(n), int(n))
    try:
        _lu[key] = splu(A)
        _nfactor[0] += 1
        rc = 0
    except RuntimeError:
        _lu.pop(key, None)
        rc = 1
    sfi.Scalar.setValue("CGE_PYRC", rc)


def lu_count():
    """The number of factorisations so far, in scalar CGE_PYNF."""
    sfi.Scalar.setValue("CGE_PYNF", _nfactor[0])


def lu_solve(key, fin, fout):
    """Solve with the factors of key for the right side in fin, into fout."""
    _put(fout, _lu[key].solve(_doubles(fin)))


def highs(fn, fout, n, m, nz, nint):
    """A linear or mixed-integer programme: minimise c'z subject to A z = b
    and l <= z <= u, z_i integer where flagged. File fn holds the triplets of
    A, then b (m), c (n), l (n), u (n) and the integer flags (n), with
    infinite bounds as +-1e300. fout receives z, then the marginals of the
    equations (m; 0 for a mixed-integer programme). Scalars: CGE_PYRC
    (0 optimal, 1 limit, 2 infeasible, 3 unbounded, 4 other), CGE_HOBJ,
    CGE_HIT (iterations or nodes), CGE_HGAP and CGE_HBND (for a MIP)."""
    from scipy.optimize import Bounds, LinearConstraint, linprog, milp
    n, m, nz = int(n), int(m), int(nz)
    raw = _doubles(fn)
    k = 3 * nz
    A = _matrix(raw, nz, m, n)
    b = raw[k:k + m]
    c = raw[k + m:k + m + n]
    lo = raw[k + m + n:k + m + 2 * n]
    up = raw[k + m + 2 * n:k + m + 3 * n]
    integ = raw[k + m + 3 * n:k + m + 4 * n]
    lo = np.where(lo <= -1e299, -np.inf, lo)
    up = np.where(up >= 1e299, np.inf, up)
    marg = np.zeros(m)
    gap = bnd = np.nan
    if int(nint) > 0:
        res = milp(c, constraints=[LinearConstraint(A, b, b)] if m else None, bounds=Bounds(lo, up),
                   integrality=integ.astype(int), options={"mip_rel_gap": 0})
        nit = getattr(res, "mip_node_count", 0) or 0
        gap = getattr(res, "mip_gap", np.nan)
        bnd = getattr(res, "mip_dual_bound", np.nan)
    else:
        res = linprog(c, A_eq=A if m else None, b_eq=b if m else None, bounds=list(zip(lo, up)), method="highs")
        nit = getattr(res, "nit", 0) or 0
        if res.status == 0 and m:
            marg = np.asarray(res.eqlin.marginals)
    st = int(res.status)
    rc = {0: 0, 1: 1, 2: 2, 3: 3}.get(st, 4)
    # without a solution, zeros: the return code tells
    z = res.x if res.x is not None else np.zeros(n)
    _put(fout, np.concatenate([np.asarray(z, dtype=float), marg]))
    sfi.Scalar.setValue("CGE_PYRC", rc)
    sfi.Scalar.setValue("CGE_HOBJ", float(res.fun) if res.fun is not None else sfi.Missing.getValue())
    sfi.Scalar.setValue("CGE_HIT", float(nit))
    sfi.Scalar.setValue("CGE_HGAP", float(gap) if gap is not None and gap == gap else sfi.Missing.getValue())
    sfi.Scalar.setValue("CGE_HBND", float(bnd) if bnd is not None and bnd == bnd else sfi.Missing.getValue())
