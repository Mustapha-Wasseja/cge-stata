"""cge-stata: links to SciPy through Stata's Python integration (from version
0.27.0; Stata 16 and later, with Python and SciPy). An experimental
prototype: SuperLU factorises the Jacobians of Newton's method
(cge_options, linsolver(python)) and HiGHS solves linear and mixed-integer
programmes of standalone models (cge_solve, solver(highs)); from version
0.41.0, IPOPT solves nonlinear programmes through cyipopt (cge_solve,
solver(ipopt)), asking Mata for each value it needs. Mata writes the
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


def ipopt(fin, fout, n, m, nnz, tol, maxit, exact, trace, tlim):
    """A nonlinear programme by IPOPT through cyipopt (from version 0.41.0):
    minimise f(z) subject to c(z) = 0 and l <= z <= u, in the package's
    scaled variables. File fin holds z0, l, u (+-1e300 where none) and the
    rows and columns (from 1) of the structure of the Jacobian. Each value
    that IPOPT asks for is found by Mata: z goes to the Mata matrix
    cge__ipz (and, for the Hessian, the multipliers and the objective's
    factor to cge__ipl), _cge_ipcb runs, and the values come back in
    cge__ipo; Stata's missing values come back as NaN, which IPOPT treats as
    errors of evaluation. fout receives z and the multipliers of the
    equations. Scalars: CGE_PYRC, IPOPT's status (99 if it gave none);
    CGE_HIT, the iterations; CGE_HOBJ, the objective."""
    import cyipopt
    n, m, nnz = int(n), int(m), int(nnz)
    raw = _doubles(fin)
    z0 = raw[:n].copy()
    lo = np.where(raw[n:2 * n] <= -1e299, -1e20, raw[n:2 * n])
    up = np.where(raw[2 * n:3 * n] >= 1e299, 1e20, raw[2 * n:3 * n])
    jr = raw[3 * n:3 * n + nnz].astype(np.int64) - 1
    jc = raw[3 * n + nnz:3 * n + 2 * nnz].astype(np.int64) - 1
    # the lower triangle of the Hessian, column by column, the order of
    # Mata's vech()
    hc, hr = np.triu_indices(n)
    nh = n * (n + 1) // 2
    iters = [0]

    def call(k, z, size, extra=None):
        try:
            sfi.Mata.store("cge__ipz", [[float(v)] for v in z])
            if extra is not None:
                sfi.Mata.store("cge__ipl", [[float(v)] for v in extra])
            sfi.SFIToolkit.stata("mata: _cge_ipcb(%d)" % k)
            v = np.asarray(sfi.Mata.get("cge__ipo"), dtype=float).ravel() if size else np.zeros(0)
        except Exception:
            v = np.full(size, np.nan)
        if v.size != size:
            v = np.full(size, np.nan)
        # Stata's missing values
        v[v >= 8.98e307] = np.nan
        return v

    class _Problem:
        def objective(self, z):
            return float(call(1, z, 1)[0])

        def gradient(self, z):
            return call(2, z, n)

        def constraints(self, z):
            return call(3, z, m)

        def jacobian(self, z):
            return call(4, z, nnz)

        def jacobianstructure(self):
            return (jr, jc)

        def hessianstructure(self):
            return (hr, hc)

        def hessian(self, z, lagrange, obj_factor):
            return call(5, z, nh, np.concatenate([np.asarray(lagrange, dtype=float), [float(obj_factor)]]))

        def intermediate(self, alg_mod, iter_count, *args):
            iters[0] = int(iter_count)
            return True

    prob = cyipopt.Problem(n=n, m=m, problem_obj=_Problem(), lb=lo, ub=up, cl=np.zeros(m), cu=np.zeros(m))
    prob.add_option("sb", "yes")
    prob.add_option("print_level", 5 if int(trace) else 0)
    prob.add_option("tol", float(tol))
    prob.add_option("max_iter", int(maxit))
    if not int(exact):
        prob.add_option("hessian_approximation", "limited-memory")
    if float(tlim) >= 0:
        prob.add_option("max_wall_time", max(float(tlim), 1e-3))
    z, info = prob.solve(z0)
    mult = np.asarray(info.get("mult_g", np.zeros(m)), dtype=float)
    _put(fout, np.concatenate([np.asarray(z, dtype=float), mult if mult.size == m else np.zeros(m)]))
    sfi.Scalar.setValue("CGE_PYRC", int(info.get("status", 99)))
    sfi.Scalar.setValue("CGE_HIT", float(iters[0]))
    obj = info.get("obj_val", None)
    sfi.Scalar.setValue("CGE_HOBJ", float(obj) if obj is not None and obj == obj else sfi.Missing.getValue())
