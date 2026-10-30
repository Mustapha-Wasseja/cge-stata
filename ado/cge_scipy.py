"""cge-stata: links to SciPy through Stata's Python integration (from version
0.27.0; Stata 16 and later, with Python and SciPy). An experimental
prototype: SuperLU factorises the Jacobians of Newton's method
(cge_options, linsolver(python)) and HiGHS solves linear and mixed-integer
programmes of standalone models (cge_solve, solver(highs)); from version
0.41.0, IPOPT solves nonlinear programmes through cyipopt (cge_solve,
solver(ipopt)), asking Mata for each value it needs; from version 0.42.0,
SCIP solves nonlinear and mixed-integer programmes to global optimality
through PySCIPOpt (cge_solve, solver(scip)). Mata writes the
data to binary files of little-endian doubles and reads the results back
the same way; return codes and statistics go back as Stata scalars.

Author: Mustapha Wasseja Mohammed
"""
import numpy as np
try:
    import sfi
except ImportError:
    # the separate process of solver(scip) runs outside Stata, without
    # SciPy, whose import takes longer than SCIP's
    sfi = None
else:
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


def _scip_expr(rows, xs):
    """A PySCIPOpt expression from postfix rows (type, value, arguments): 1 a
    number, 2 the free variable at a position (from 1), 4 an operator (1 + 2
    - 3 * 4 / 5 ^), 5 negation, 6 a function (1 exp, 2 ln, 3 sqrt), 10 a
    function of its arguments (3 abs, 4 sqr, 5 log10). Numbers are folded;
    returns the value or expression and whether it is a number. A power
    whose exponent is not a number is exp(b ln a); one of more than a single
    term, to a power above 2, stays a power rather than its expansion."""
    import math
    from pyscipopt import exp, log, sqrt
    from pyscipopt.scip import Expr, buildGenExprObj
    st = []
    for c, v, k in rows:
        c = int(c)
        if c == 1:
            st.append((float(v), True))
        elif c == 2:
            st.append((xs[int(v) - 1], False))
        elif c == 4:
            b, bc = st.pop()
            a, ac = st.pop()
            op = int(v)
            if ac and bc:
                r = {1: lambda: a + b, 2: lambda: a - b, 3: lambda: a * b,
                     4: lambda: a / b, 5: lambda: a ** b}[op]()
                if isinstance(r, complex):
                    raise ValueError("a power of a negative number")
                st.append((r, True))
            elif op == 1:
                st.append((a + b, False))
            elif op == 2:
                st.append((a - b, False))
            elif op == 3:
                st.append((a * b, False))
            elif op == 4:
                st.append((a * (1.0 / b) if bc else a / b, False))
            elif bc:
                if b == 0:
                    st.append((1.0, True))
                elif b == 1:
                    st.append((a, False))
                elif isinstance(a, Expr) and float(b).is_integer() and 0 < b <= 2:
                    st.append((a ** int(b), False))
                else:
                    st.append((buildGenExprObj(a) ** float(b), False))
            elif ac:
                if a <= 0:
                    raise ValueError("a power of a number that is not positive")
                st.append((exp(b * math.log(a)), False))
            else:
                st.append((exp(b * log(a)), False))
        elif c == 5:
            a, ac = st.pop()
            st.append((-a, ac))
        elif c == 6:
            a, ac = st.pop()
            f = int(v)
            if ac:
                st.append(((math.exp, math.log, math.sqrt)[f - 1](a), True))
            else:
                st.append(((exp, log, sqrt)[f - 1](a), False))
        elif c == 10:
            a, ac = st.pop()
            f = int(v)
            if ac:
                st.append(({3: abs, 4: lambda u: u * u, 5: math.log10}[f](a), True))
            elif f == 3:
                st.append((abs(buildGenExprObj(a)), False))
            elif f == 4:
                st.append((a * a, False))
            else:
                st.append((log(a) * (1.0 / math.log(10.0)), False))
        else:
            raise ValueError("an element that SCIP's expressions do not take")
    return st[0]


def _scip_solve(fin, fout, n, m, nt, feastol, nodes, gap, trace, tlim):
    """A programme by SCIP through PySCIPOpt (from version 0.42.0), to global
    optimality within SCIP's tolerances: minimise s f(x) subject to the
    scaled equations (L(x) - R(x)) / e = 0, l <= x <= u and the integer and
    binary variables, in the variables' own units. File fin holds l, u (+-1e300
    where none), the type of each variable (0 continuous, 1 integer, 2
    binary), the start, the scales e of the equations, the number of postfix
    rows of the objective and of each side of each equation, and the rows
    (type, value, arguments), with the parameters and the fixed variables as
    numbers; the objective's rows are s f. A nonlinear objective is the
    variable t of the epigraph s f(x) <= t. The start goes to SCIP as a
    partial solution. fout receives the best solution. Returns SCIP's
    status (0 optimal, 1 infeasible, 2 unbounded, 3 infeasible or unbounded,
    4 a node limit, 5 the time limit, 6 the gap, 7 the memory limit, 8 an
    interrupt, 9 other, 10 an expression that cannot be built, 11 an
    equation without variables that does not hold), 1 with a solution, the
    LP iterations, the nodes and the dual bound (1e300 if none)."""
    from pyscipopt import Model
    from pyscipopt.scip import Expr
    n, m, nt = int(n), int(m), int(nt)
    raw = _doubles(fin)
    lo = raw[:n]
    up = raw[n:2 * n]
    ty = raw[2 * n:3 * n]
    z0 = raw[3 * n:4 * n]
    esc = raw[4 * n:4 * n + m]
    p = 4 * n + m
    lens = raw[p:p + 1 + 2 * m].astype(np.int64)
    T = raw[p + 1 + 2 * m:p + 1 + 2 * m + 3 * nt].reshape(nt, 3)
    mod = Model()
    if not int(trace):
        mod.hideOutput()
    xs = []
    for j in range(n):
        vt = ("C", "I", "B")[int(ty[j])]
        lb = None if lo[j] <= -1e299 else float(lo[j])
        ub = None if up[j] >= 1e299 else float(up[j])
        if vt == "B":
            lb = 0.0 if lb is None else max(0.0, lb)
            ub = 1.0 if ub is None else min(1.0, ub)
        xs.append(mod.addVar(name="x%d" % (j + 1), vtype=vt, lb=lb, ub=ub))
    starts = np.concatenate([[0], np.cumsum(lens)])
    try:
        f, fc = _scip_expr(T[starts[0]:starts[1]], xs)
        for k in range(m):
            a, ac = _scip_expr(T[starts[1 + 2 * k]:starts[2 + 2 * k]], xs)
            b, bc = _scip_expr(T[starts[2 + 2 * k]:starts[3 + 2 * k]], xs)
            if ac and bc:
                if abs((a - b) / esc[k]) > float(feastol):
                    return (11, 0, 0, 0, 1e300)
                continue
            mod.addCons((a - b) * (1.0 / esc[k]) == 0)
    except (ValueError, ZeroDivisionError, OverflowError, TypeError):
        return (10, 0, 0, 0, 1e300)
    if fc:
        mod.setObjective(0, "minimize")
    elif isinstance(f, Expr) and f.degree() <= 1:
        mod.setObjective(f, "minimize")
    else:
        t = mod.addVar(name="t", lb=None, ub=None)
        mod.addCons(f - t <= 0)
        mod.setObjective(t, "minimize")
    mod.setParam("numerics/feastol", float(feastol))
    mod.setParam("limits/nodes", int(nodes))
    mod.setParam("limits/gap", float(gap))
    if float(tlim) >= 0:
        mod.setParam("limits/time", max(float(tlim), 1e-3))
    sol = mod.createPartialSol()
    for j in range(n):
        mod.setSolVal(sol, xs[j], float(z0[j]))
    mod.addSol(sol, free=True)
    mod.optimize()
    status = mod.getStatus()
    code = {"optimal": 0, "infeasible": 1, "unbounded": 2, "inforunbd": 3, "nodelimit": 4,
            "totalnodelimit": 4, "stallnodelimit": 4, "timelimit": 5, "gaplimit": 6,
            "memlimit": 7, "userinterrupt": 8}.get(status, 9)
    hsol = 0
    if mod.getNSols() > 0:
        best = mod.getBestSol()
        _put(fout, np.asarray([mod.getSolVal(best, v) for v in xs], dtype=float))
        hsol = 1
    db = mod.getDualbound()
    return (code, hsol, float(mod.getNLPIterations()), float(mod.getNNodes()), float(db) if abs(db) < 1e19 else 1e300)


def _scip_main(argv):
    """The separate process of scip(): fin fout fstat and the arguments of
    _scip_solve; fstat receives what it returns."""
    fin, fout, fstat = argv[:3]
    r = _scip_solve(fin, fout, *[float(v) for v in argv[3:]])
    _put(fstat, np.asarray(r, dtype=float))


def scip(fin, fout, fstat, n, m, nt, feastol, nodes, gap, trace, tlim):
    """cge_solve, solver(scip) (from version 0.42.0): _scip_solve in a
    separate Python process, the interpreter of Stata's Python. SCIP's
    libraries bring a runtime of OpenMP that cannot share Stata's process
    with Stata's own, and SCIP needs nothing from Mata while it solves. The
    process loads this file by its path and writes its results to fstat;
    with trace, its output is displayed when it ends. Scalars: CGE_PYRC,
    SCIP's status as _scip_solve returns it, or 12 if the process failed;
    CGE_HSOL, 1 with a solution; CGE_HIT, the LP iterations; CGE_HNOD, the
    nodes; CGE_HBND, the dual bound."""
    import os
    import subprocess
    import sys
    exe = os.path.join(sys.base_prefix, "python.exe")
    if not os.path.isfile(exe):
        exe = os.path.join(sys.base_prefix, "bin", "python3")
    if not os.path.isfile(exe):
        exe = sys.executable
    code = ("import importlib.util as u, sys; s = u.spec_from_file_location('cge_scipy', %r); "
            "c = u.module_from_spec(s); s.loader.exec_module(c); c._scip_main(sys.argv[1:])" % os.path.abspath(__file__))
    args = [fin, fout, fstat] + [repr(float(v)) for v in (n, m, nt, feastol, nodes, gap, trace, tlim)]
    if os.path.exists(fstat):
        os.remove(fstat)
    try:
        r = subprocess.run([exe] + (["-P"] if sys.version_info >= (3, 11) else []) + ["-c", code] + args,
                           cwd=os.path.dirname(os.path.abspath(fin)), stdin=subprocess.DEVNULL,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True,
                           creationflags=(0x08000000 if os.name == "nt" else 0))
        out, err, ok = r.stdout, r.stderr, r.returncode == 0
    except OSError as e:
        out, err, ok = "", str(e), False
    if int(trace):
        if out:
            print(out)
        if err:
            print(err)
    st = _doubles(fstat) if ok and os.path.exists(fstat) else np.zeros(0)
    if st.size != 5:
        sfi.Scalar.setValue("CGE_PYRC", 12)
        return
    sfi.Scalar.setValue("CGE_HSOL", float(st[1]))
    sfi.Scalar.setValue("CGE_HIT", float(st[2]))
    sfi.Scalar.setValue("CGE_HNOD", float(st[3]))
    sfi.Scalar.setValue("CGE_HBND", float(st[4]) if st[4] < 1e299 else sfi.Missing.getValue())
    sfi.Scalar.setValue("CGE_PYRC", int(st[0]))
