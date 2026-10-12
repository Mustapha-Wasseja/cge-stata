*! cge_mata.mata  v0.1.0  2026-10-12
*! cge-stata: Mata library (model structure, calibration, equations, solver)
*! Equation labels and calibration steps follow docs/model_spec.md
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

version 13.0

mata:

// =====================================================================
// Structures
// =====================================================================

struct cge_par {
    real colvector pwm, pwe, tm, te, tq, ta
    real colvector iva, inta, ad, rva, sva
    real matrix    ica, dva
    real colvector at, dt, rt, aq, dq, rq, sq, st
    real matrix    shif, beta
    real colvector tins0, mps0, trhg, trhr, qg, qinv, cwts, dwts
    real scalar    trgr
}

struct cge_model {
    // SAM and account mapping
    string colvector labels
    real matrix      S
    real scalar      mapped, calibrated
    real colvector   iA, iC, iF, iH
    real scalar      igov, isav, irow, idirtax, isaltax, iimptax, iexptax, iacttax
    string colvector A, C, F, H, I
    real scalar      n, nF, nH, nI
    // model structure
    real colvector   ce, cm, cd
    real matrix      fa
    // parameters: base (p0) and current, including shocks (p)
    struct cge_par scalar p0, p
    // variable layout; all variables are stacked in one vector x
    string colvector vname, vset
    real colvector   voff, vrows, vcols
    real colvector   x0, xcur, xscale, exists, fixed, nominal, positive
    // equation blocks
    string colvector ename
    real colvector   elen, escale, emask
    real scalar      neq
    // closure
    string scalar    c_ext, c_gov, c_si, c_num
    string colvector c_fac
    // stored simulations
    string colvector simname, simclosure, simmethod
    real matrix      simx
    struct cge_par rowvector simp
    real colvector   simconv, simiter, simres
}

string scalar _cge_version()
{
    return("0.1.0")
}

// =====================================================================
// Storage of the model in a Mata global
// =====================================================================

struct cge_model scalar _cge_load()
{
    pointer() scalar q
    q = findexternal("cge__model")
    if (q == NULL) {
        errprintf("no SAM in memory; load one with cge_sam\n")
        exit(459)
    }
    return(*q)
}

void _cge_store(struct cge_model scalar M)
{
    pointer() scalar q
    if ((q = findexternal("cge__model")) == NULL) q = crexternal("cge__model")
    *q = M
}

void _cge_need(struct cge_model scalar M, string scalar what)
{
    if (what == "mapped" & !M.mapped) {
        errprintf("assign SAM accounts to model roles with cge_map first\n")
        exit(459)
    }
    if (what == "calibrated" & !M.calibrated) {
        errprintf("calibrate the model with cge_calibrate first\n")
        exit(459)
    }
}

// =====================================================================
// Small utilities
// =====================================================================

real scalar _cge_find(string colvector set, string scalar label)
{
    real scalar k
    for (k = 1; k <= rows(set); k++) if (set[k] == label) return(k)
    return(0)
}

// Submatrix of the SAM; an index of 0 (unmapped tax account) gives zeros.
real matrix _cge_sub(real matrix S, real colvector r, real colvector c)
{
    real matrix out
    real scalar i, j
    out = J(rows(r), rows(c), 0)
    for (i = 1; i <= rows(r); i++) {
        for (j = 1; j <= rows(c); j++) {
            if (r[i] > 0 & c[j] > 0) out[i, j] = S[r[i], c[j]]
        }
    }
    return(out)
}

real colvector _cge_elast(string scalar spec, real scalar n, string scalar name)
{
    real rowvector v
    v = strtoreal(tokens(spec))
    if (cols(v) == 1) v = J(1, n, v)
    if (cols(v) != n) {
        errprintf("%s() needs 1 or %f values\n", name, n)
        exit(198)
    }
    if (hasmissing(v) | min(v) <= 0) {
        errprintf("%s() values must be positive\n", name)
        exit(198)
    }
    return(v')
}

void _cge_fail(string scalar msg, real scalar rc)
{
    errprintf("%s\n", msg)
    exit(rc)
}

// =====================================================================
// Variable layout
// =====================================================================

void _cge_dims(struct cge_model scalar M, string scalar set, real scalar r, real scalar c)
{
    real scalar first, second
    if (set == "") {
        r = 1
        c = 1
        return
    }
    first = _cge_setsize(M, substr(set, 1, 1))
    second = (strlen(set) == 2 ? _cge_setsize(M, substr(set, 2, 1)) : 1)
    r = first
    c = second
}

real scalar _cge_setsize(struct cge_model scalar M, string scalar s)
{
    if (s == "A" | s == "C") return(M.n)
    if (s == "F") return(M.nF)
    if (s == "H") return(M.nH)
    if (s == "I") return(M.nI)
    _cge_fail("cge internal error: unknown set " + s, 3498)
}

void _cge_layout(struct cge_model scalar M)
{
    real scalar k, r, c, off
    M.vname = ("PA","PVA","PINTA","PX","PD","PE","PM","PQ","W","EXR","CPI","DPI",
               "QA","QVA","QINTA","QF","QINT","QX","QD","QE","QM","QQ","QH","QG","QINV","QFS",
               "YF","YIF","YH","EH","YG","EG","GSAV","FSAV","TINS","MPS","TINSADJ","MPSADJ",
               "IADJ","GADJ","WFDIST","WALRAS")'
    M.vset  = ("A","A","A","C","C","C","C","C","F","","","",
               "A","A","A","FA","CA","C","C","C","C","C","CH","C","C","F",
               "F","IF","H","H","","","","","H","H","","",
               "","","FA","")'
    M.voff = J(rows(M.vname), 1, 0)
    M.vrows = M.voff
    M.vcols = M.voff
    off = 0
    for (k = 1; k <= rows(M.vname); k++) {
        _cge_dims(M, M.vset[k], r, c)
        M.voff[k] = off
        M.vrows[k] = r
        M.vcols[k] = c
        off = off + r * c
    }
}

real scalar _cge_vidx(struct cge_model scalar M, string scalar name)
{
    return(_cge_find(M.vname, name))
}

real colvector _cge_vpos(struct cge_model scalar M, real scalar k)
{
    return(M.voff[k] :+ (1::M.vrows[k] * M.vcols[k]))
}

real matrix _cge_v(struct cge_model scalar M, real colvector x, real scalar k)
{
    return(colshape(x[|M.voff[k] + 1 \ M.voff[k] + M.vrows[k] * M.vcols[k]|]', M.vcols[k]))
}

void _cge_setv(struct cge_model scalar M, real colvector x, string scalar name, real matrix value)
{
    real scalar k
    k = _cge_vidx(M, name)
    if (rows(value) != M.vrows[k] | cols(value) != M.vcols[k]) {
        _cge_fail("cge internal error: wrong dimensions for " + name, 3200)
    }
    x[|M.voff[k] + 1 \ M.voff[k] + M.vrows[k] * M.vcols[k]|] = colshape(value, 1)
}

// Labels of the elements of variable k, in storage order
void _cge_vlabels(struct cge_model scalar M, real scalar k, string colvector e1, string colvector e2)
{
    string scalar set
    string colvector s1, s2
    real scalar i, j
    set = M.vset[k]
    if (set == "") {
        e1 = ""
        e2 = ""
        return
    }
    s1 = (substr(set, 1, 1) == "A" ? M.A : (substr(set, 1, 1) == "C" ? M.C :
         (substr(set, 1, 1) == "F" ? M.F : (substr(set, 1, 1) == "H" ? M.H : M.I))))
    if (strlen(set) == 1) {
        e1 = s1
        e2 = J(rows(s1), 1, "")
        return
    }
    s2 = (substr(set, 2, 1) == "A" ? M.A : (substr(set, 2, 1) == "F" ? M.F : M.H))
    e1 = J(rows(s1) * rows(s2), 1, "")
    e2 = e1
    for (i = 1; i <= rows(s1); i++) {
        for (j = 1; j <= rows(s2); j++) {
            e1[(i - 1) * rows(s2) + j] = s1[i]
            e2[(i - 1) * rows(s2) + j] = s2[j]
        }
    }
}

// =====================================================================
// SAM input and account mapping (model_spec.md, Section 7.0)
// =====================================================================

void _cge_sam(string scalar labelvar, string scalar accounts)
{
    struct cge_model scalar M
    string colvector labels, names
    real matrix S
    real scalar nmiss, maxdiff

    labels = st_sdata(., labelvar)
    names = tokens(accounts)'
    if (rows(names) == 0) _cge_fail("no numeric account variables found", 459)
    S = st_data(., accounts)
    if (rows(S) != cols(S)) {
        errprintf("SAM is not square: %f rows and %f account columns\n", rows(S), cols(S))
        exit(459)
    }
    if (labels != names) {
        _cge_fail("row labels in " + labelvar + " must match the account variable names, in the same order", 459)
    }
    nmiss = missing(S)
    if (nmiss) S = editmissing(S, 0)
    maxdiff = max(abs(rowsum(S) - colsum(S)'))

    M.labels = labels
    M.S = S
    M.mapped = 0
    M.calibrated = 0
    _cge_store(M)

    printf("{txt}SAM read: {res}%f{txt} accounts, total {res}%g\n", rows(S), sum(S))
    if (nmiss) printf("{txt}Blank cells treated as zero: {res}%f\n", nmiss)
    printf("{txt}Largest row-column imbalance: {res}%9.3e\n", maxdiff)
    st_numscalar("r(N_accounts)", rows(S))
    st_numscalar("r(total)", sum(S))
    st_numscalar("r(maxdiff)", maxdiff)
    st_numscalar("r(N_blank)", nmiss)
}

real colvector _cge_lookup(struct cge_model scalar M, string scalar list, string scalar what)
{
    string rowvector tok
    real colvector idx
    real scalar k
    tok = tokens(list)
    idx = J(cols(tok), 1, 0)
    for (k = 1; k <= cols(tok); k++) {
        idx[k] = _cge_find(M.labels, tok[k])
        if (idx[k] == 0) _cge_fail("account " + tok[k] + " (" + what + ") is not in the SAM", 111)
    }
    return(idx)
}

void _cge_map(string scalar acts, string scalar coms, string scalar facs, string scalar hhs,
              string scalar gov, string scalar sav, string scalar row, string scalar dirtax,
              string scalar saltax, string scalar imptax, string scalar exptax, string scalar acttax)
{
    struct cge_model scalar M
    real colvector role, iA, iC
    real matrix allowed, negok, S
    string rowvector rolename
    real scalar i, j, k, tol, nacc, rr, rc
    string colvector taxacc
    real colvector taxidx

    M = _cge_load()
    S = M.S
    nacc = rows(M.labels)
    rolename = ("activity", "commodity", "factor", "household", "government",
                "savings-investment", "rest of world", "direct tax", "sales tax",
                "import tax", "export tax", "activity tax")

    M.iA = _cge_lookup(M, acts, "activity")
    M.iC = _cge_lookup(M, coms, "commodity")
    M.iF = _cge_lookup(M, facs, "factor")
    M.iH = _cge_lookup(M, hhs, "household")
    M.igov = _cge_lookup(M, gov, "government")
    M.isav = _cge_lookup(M, sav, "savings-investment")
    M.irow = _cge_lookup(M, row, "rest of world")
    taxacc = (dirtax \ saltax \ imptax \ exptax \ acttax)
    taxidx = J(5, 1, 0)
    for (k = 1; k <= 5; k++) {
        if (taxacc[k] != "") taxidx[k] = _cge_lookup(M, taxacc[k], rolename[7 + k])
    }
    M.idirtax = taxidx[1]
    M.isaltax = taxidx[2]
    M.iimptax = taxidx[3]
    M.iexptax = taxidx[4]
    M.iacttax = taxidx[5]

    if (rows(M.iA) != rows(M.iC)) _cge_fail("version 0.1 needs one commodity for each activity", 198)

    // Role of every account; an account may have only one role
    role = J(nacc, 1, 0)
    _cge_assign(M, role, M.iA, 1, rolename)
    _cge_assign(M, role, M.iC, 2, rolename)
    _cge_assign(M, role, M.iF, 3, rolename)
    _cge_assign(M, role, M.iH, 4, rolename)
    _cge_assign(M, role, M.igov, 5, rolename)
    _cge_assign(M, role, M.isav, 6, rolename)
    _cge_assign(M, role, M.irow, 7, rolename)
    for (k = 1; k <= 5; k++) if (taxidx[k] > 0) _cge_assign(M, role, taxidx[k], 7 + k, rolename)

    tol = 1e-8 * max((1, max(abs(S))))
    for (i = 1; i <= nacc; i++) {
        if (role[i] == 0 & (max(abs(S[i, .])) > tol | max(abs(S[., i])) > tol)) {
            _cge_fail("account " + M.labels[i] + " has flows but is not mapped to a role", 459)
        }
    }
    if (max(abs(rowsum(S) - colsum(S)')) > tol) {
        errprintf("SAM is not balanced (largest row-column difference %9.3e)\n", max(abs(rowsum(S) - colsum(S)')))
        exit(459)
    }

    // Supported flows (row role, column role)
    allowed = J(12, 12, 0)
    allowed[1, 2] = 1
    allowed[2, 1] = 1; allowed[3, 1] = 1; allowed[12, 1] = 1
    allowed[7, 2] = 1; allowed[10, 2] = 1; allowed[9, 2] = 1; allowed[11, 2] = 1
    allowed[2, 4] = 1; allowed[2, 5] = 1; allowed[2, 6] = 1; allowed[2, 7] = 1
    allowed[4, 3] = 1; allowed[5, 3] = 1; allowed[7, 3] = 1
    allowed[4, 5] = 1; allowed[4, 7] = 1; allowed[5, 7] = 1
    allowed[8, 4] = 1; allowed[6, 4] = 1
    allowed[5, 8] = 1; allowed[5, 9] = 1; allowed[5, 10] = 1; allowed[5, 11] = 1; allowed[5, 12] = 1
    allowed[6, 5] = 1; allowed[6, 7] = 1
    // Cells that may be negative
    negok = J(12, 12, 0)
    negok[(6, 8, 9, 10, 11, 12), .] = J(6, 12, 1)
    negok[4, 5] = 1; negok[4, 7] = 1; negok[5, 7] = 1
    negok[5, (8, 9, 10, 11, 12)] = J(1, 5, 1)

    for (i = 1; i <= nacc; i++) {
        for (j = 1; j <= nacc; j++) {
            if (abs(S[i, j]) <= tol) continue
            rr = role[i]
            rc = role[j]
            if (!allowed[rr, rc]) {
                _cge_fail("flow from " + M.labels[j] + " (" + rolename[rc] + ") to " + M.labels[i] +
                          " (" + rolename[rr] + ") is not represented in the version 0.1 model", 459)
            }
            if (rr == 1) {
                k = _cge_find(M.labels[M.iA], M.labels[i])
                if (M.iC[k] != j) {
                    _cge_fail("activity " + M.labels[i] + " receives payment from " + M.labels[j] +
                              ", but it is paired with " + M.labels[M.iC[k]], 459)
                }
            }
            if (S[i, j] < 0 & !negok[rr, rc]) {
                _cge_fail("negative flow from " + M.labels[j] + " to " + M.labels[i], 459)
            }
        }
    }

    M.A = M.labels[M.iA]
    M.C = M.labels[M.iC]
    M.F = M.labels[M.iF]
    M.H = M.labels[M.iH]
    M.I = M.H \ M.labels[M.igov] \ M.labels[M.irow]
    M.n = rows(M.iA)
    M.nF = rows(M.iF)
    M.nH = rows(M.iH)
    M.nI = M.nH + 2
    M.mapped = 1
    M.calibrated = 0
    _cge_store(M)
    printf("{txt}Accounts mapped: {res}%f{txt} activities, {res}%f{txt} factors, {res}%f{txt} households\n",
           M.n, M.nF, M.nH)
}

void _cge_assign(struct cge_model scalar M, real colvector role, real colvector idx, real scalar code,
                 string rowvector rolename)
{
    real scalar k
    for (k = 1; k <= rows(idx); k++) {
        if (role[idx[k]] != 0) {
            _cge_fail("account " + M.labels[idx[k]] + " is mapped to both " + rolename[role[idx[k]]] +
                      " and " + rolename[code], 198)
        }
        role[idx[k]] = code
    }
}

// =====================================================================
// Equations (model_spec.md, Section 5)
// =====================================================================

void _cge_put(struct cge_model scalar M, real colvector L, real colvector R, real colvector K,
              real scalar record, string scalar name, real matrix lhs, real matrix rhs, real matrix mask)
{
    if (rows(lhs) != rows(rhs) | cols(lhs) != cols(rhs) | rows(lhs) != rows(mask) | cols(lhs) != cols(mask)) {
        _cge_fail("cge internal error: equation block " + name + " is not conformable", 3200)
    }
    L = L \ colshape(lhs, 1)
    R = R \ colshape(rhs, 1)
    K = K \ colshape(mask, 1)
    if (record) {
        M.ename = M.ename \ name
        M.elen = M.elen \ rows(lhs) * cols(lhs)
    }
}

void _cge_eq(struct cge_model scalar M, struct cge_par scalar p, real colvector x,
             real colvector L, real colvector R, real colvector K, real scalar record)
{
    real matrix PA, PVA, PINTA, PX, PD, PE, PM, PQ, W, EXR, CPI, DPI
    real matrix QA, QVA, QINTA, QF, QINT, QX, QD, QE, QM, QQ, QH, QG, QINV, QFS
    real matrix YF, YIF, YH, EH, YG, EG, GSAV, FSAV, TINS, MPS, TINSADJ, MPSADJ
    real matrix IADJ, GADJ, WFDIST, WALRAS
    real matrix qf, rho, cessum, q3, wage, pvaqva, lhs, rhs
    real colvector oneA, oneC, oneF, oneH
    real scalar k, nH

    PA = _cge_v(M, x, 1);     PVA = _cge_v(M, x, 2);    PINTA = _cge_v(M, x, 3)
    PX = _cge_v(M, x, 4);     PD = _cge_v(M, x, 5);     PE = _cge_v(M, x, 6)
    PM = _cge_v(M, x, 7);     PQ = _cge_v(M, x, 8);     W = _cge_v(M, x, 9)
    EXR = _cge_v(M, x, 10);   CPI = _cge_v(M, x, 11);   DPI = _cge_v(M, x, 12)
    QA = _cge_v(M, x, 13);    QVA = _cge_v(M, x, 14);   QINTA = _cge_v(M, x, 15)
    QF = _cge_v(M, x, 16);    QINT = _cge_v(M, x, 17);  QX = _cge_v(M, x, 18)
    QD = _cge_v(M, x, 19);    QE = _cge_v(M, x, 20);    QM = _cge_v(M, x, 21)
    QQ = _cge_v(M, x, 22);    QH = _cge_v(M, x, 23);    QG = _cge_v(M, x, 24)
    QINV = _cge_v(M, x, 25);  QFS = _cge_v(M, x, 26);   YF = _cge_v(M, x, 27)
    YIF = _cge_v(M, x, 28);   YH = _cge_v(M, x, 29);    EH = _cge_v(M, x, 30)
    YG = _cge_v(M, x, 31);    EG = _cge_v(M, x, 32);    GSAV = _cge_v(M, x, 33)
    FSAV = _cge_v(M, x, 34);  TINS = _cge_v(M, x, 35);  MPS = _cge_v(M, x, 36)
    TINSADJ = _cge_v(M, x, 37); MPSADJ = _cge_v(M, x, 38); IADJ = _cge_v(M, x, 39)
    GADJ = _cge_v(M, x, 40);  WFDIST = _cge_v(M, x, 41); WALRAS = _cge_v(M, x, 42)

    L = J(0, 1, .)
    R = J(0, 1, .)
    K = J(0, 1, .)
    if (record) {
        M.ename = J(0, 1, "")
        M.elen = J(0, 1, .)
    }
    oneA = J(M.n, 1, 1)
    oneC = J(M.n, 1, 1)
    oneF = J(M.nF, 1, 1)
    oneH = J(M.nH, 1, 1)
    nH = M.nH

    // 5.1 Price block
    _cge_put(M, L, R, K, record, "P1", PM, p.pwm :* (1 :+ p.tm) :* EXR, M.cm)
    _cge_put(M, L, R, K, record, "P2", PE, p.pwe :* (1 :- p.te) :* EXR, M.ce)
    _cge_put(M, L, R, K, record, "P3", PQ :* (1 :- p.tq) :* QQ, PD :* QD + M.cm :* PM :* QM, oneC)
    _cge_put(M, L, R, K, record, "P4", PX :* QX, PD :* QD + M.ce :* PE :* QE, oneC)
    _cge_put(M, L, R, K, record, "P5", PA, PX, oneA)
    _cge_put(M, L, R, K, record, "P6", PINTA, p.ica' * PQ, oneA)
    _cge_put(M, L, R, K, record, "P7", PA :* (1 :- p.ta) :* QA, PVA :* QVA + PINTA :* QINTA, oneA)
    _cge_put(M, L, R, K, record, "P8", CPI, p.cwts' * PQ, 1)
    _cge_put(M, L, R, K, record, "P9", DPI, p.dwts' * PD, 1)

    // 5.2 Production block
    _cge_put(M, L, R, K, record, "Q1", QVA, p.iva :* QA, oneA)
    _cge_put(M, L, R, K, record, "Q2", QINTA, p.inta :* QA, oneA)
    qf = M.fa :* QF + (1 :- M.fa)
    rho = (M.cd + (1 :- M.cd) :* p.rva)'
    cessum = colsum(p.dva :* (qf :^ (-rho)))
    q3 = (p.ad' :* (cessum :^ (-1 :/ rho)))'
    for (k = 1; k <= M.n; k++) {
        if (M.cd[k]) q3[k] = p.ad[k] * exp(colsum(p.dva[., k] :* ln(qf[., k])))
    }
    _cge_put(M, L, R, K, record, "Q3", QVA, q3, oneA)
    wage = W :* WFDIST
    pvaqva = (PVA :* QVA)'
    lhs = wage
    rhs = (pvaqva :/ cessum) :* p.dva :* (qf :^ (-rho :- 1))
    for (k = 1; k <= M.n; k++) {
        if (M.cd[k]) {
            lhs[., k] = wage[., k] :* QF[., k]
            rhs[., k] = p.dva[., k] :* pvaqva[k]
        }
    }
    _cge_put(M, L, R, K, record, "Q4", lhs, rhs, M.fa)
    _cge_put(M, L, R, K, record, "Q5", QINT, p.ica :* QINTA', J(M.n, M.n, 1))
    _cge_put(M, L, R, K, record, "Q6", QX, QA, oneC)

    // 5.3 Trade block
    _cge_put(M, L, R, K, record, "T1", QX,
             p.at :* (p.dt :* (QE :^ p.rt) + (1 :- p.dt) :* (QD :^ p.rt)) :^ (1 :/ p.rt), M.ce)
    _cge_put(M, L, R, K, record, "T2", QE,
             QD :* (((PE :/ PD) :* (1 :- p.dt) :/ p.dt) :^ (1 :/ (p.rt :- 1))), M.ce)
    _cge_put(M, L, R, K, record, "T3", QX, QD, 1 :- M.ce)
    _cge_put(M, L, R, K, record, "T4", QQ,
             p.aq :* (p.dq :* (QM :^ (-p.rq)) + (1 :- p.dq) :* (QD :^ (-p.rq))) :^ (-1 :/ p.rq), M.cm)
    _cge_put(M, L, R, K, record, "T5", QM,
             QD :* (((PD :/ PM) :* p.dq :/ (1 :- p.dq)) :^ (1 :/ (1 :+ p.rq))), M.cm)
    _cge_put(M, L, R, K, record, "T6", QQ, QD, 1 :- M.cm)

    // 5.4 Institution block
    _cge_put(M, L, R, K, record, "I1", YF, rowsum(wage :* QF), oneF)
    _cge_put(M, L, R, K, record, "I2", YIF, p.shif :* YF', J(M.nI, M.nF, 1))
    _cge_put(M, L, R, K, record, "I3", YH,
             rowsum(YIF[|1, 1 \ nH, M.nF|]) + p.trhg :* CPI + p.trhr :* EXR, oneH)
    _cge_put(M, L, R, K, record, "I4", EH, (1 :- MPS) :* (1 :- TINS) :* YH, oneH)
    _cge_put(M, L, R, K, record, "I5", PQ :* QH, p.beta :* EH', J(M.n, nH, 1))
    _cge_put(M, L, R, K, record, "I6", QINV, p.qinv :* IADJ, oneC)
    _cge_put(M, L, R, K, record, "I7", QG, p.qg :* GADJ, oneC)
    _cge_put(M, L, R, K, record, "I8", YG,
             TINS' * YH + sum(p.tq :* PQ :* QQ) + sum(p.tm :* p.pwm :* QM) * EXR
             + sum(p.te :* p.pwe :* QE) * EXR + sum(p.ta :* PA :* QA)
             + sum(YIF[nH + 1, .]) + p.trgr * EXR, 1)
    _cge_put(M, L, R, K, record, "I9", EG, PQ' * QG + sum(p.trhg) * CPI, 1)
    _cge_put(M, L, R, K, record, "I10", TINS, p.tins0 :* TINSADJ, oneH)
    _cge_put(M, L, R, K, record, "I11", MPS, p.mps0 :* MPSADJ, oneH)

    // 5.5 System constraints (S6 is imposed through the closure)
    _cge_put(M, L, R, K, record, "S1", rowsum(M.fa :* QF), QFS, oneF)
    _cge_put(M, L, R, K, record, "S2", QQ, rowsum(QINT) + rowsum(QH) + QG + QINV, oneC)
    _cge_put(M, L, R, K, record, "S3", sum(p.pwm :* QM) + sum(YIF[nH + 2, .]) / EXR,
             sum(p.pwe :* QE) + sum(p.trhr) + p.trgr + FSAV, 1)
    _cge_put(M, L, R, K, record, "S4", YG, EG + GSAV, 1)
    _cge_put(M, L, R, K, record, "S5", (MPS :* (1 :- TINS))' * YH + GSAV + EXR * FSAV,
             PQ' * QINV + WALRAS, 1)
}

// Scaled residuals of the existing equation elements. Mata's sum functions
// treat missing values as zero, so points with non-positive prices or
// quantities are rejected explicitly.
real colvector _cge_resid(struct cge_model scalar M, struct cge_par scalar p, real colvector x)
{
    real colvector L, R, K
    if (min(x[M.positive]) <= 0 | hasmissing(x)) return(J(M.neq, 1, .))
    _cge_eq(M, p, x, L, R, K, 0)
    return(select((L - R) :/ M.escale, M.emask))
}

real scalar _cge_maxres(struct cge_model scalar M, struct cge_par scalar p, real colvector x)
{
    real colvector r
    r = _cge_resid(M, p, x)
    if (hasmissing(r)) return(.)
    return(max(abs(r)))
}

// =====================================================================
// Calibration (model_spec.md, Section 7)
// =====================================================================

void _cge_calibrate(string scalar s_va, string scalar s_q, string scalar s_t, string scalar fqname)
{
    struct cge_model scalar M
    struct cge_par scalar p
    real matrix S, VA, QINT0, QF0, QFq, WFD0, dva, YIF0, QH0, w
    real colvector sva, sq, st, QM0, cm, tariffs, tm, exports, ce, etax, te, QE0, pwe
    real colvector QA0, ta, QX0, QD0, PM0, stax, QQ0, tq, demand, QINTA0, W0, QVA0
    real colvector cd, rva, ad, rt, dt, at, rq, dq, aq, YF0, YH0, tins0, mps0, EH0
    real colvector m, d, num, x0, L, R, K, mag
    real scalar n, nF, nH, tol, k, r, ratio, total, maxres

    M = _cge_load()
    _cge_need(M, "mapped")
    S = M.S
    n = M.n
    nF = M.nF
    nH = M.nH
    tol = 1e-9 * max((1, max(abs(S))))

    sva = _cge_elast(s_va, n, "sigmava")
    sq = _cge_elast(s_q, n, "sigmaq")
    st = _cge_elast(s_t, n, "sigmat")

    // 7.2 Taxes and trade
    QM0 = _cge_sub(S, M.irow, M.iC)'
    cm = QM0 :> tol
    tariffs = _cge_sub(S, M.iimptax, M.iC)'
    if (max((1 :- cm) :* (abs(tariffs) :> tol))) _cge_fail("import tariff recorded on a commodity without imports", 459)
    tm = cm :* tariffs :/ (cm :* QM0 + (1 :- cm))
    exports = _cge_sub(S, M.iC, M.irow)
    ce = exports :> tol
    etax = _cge_sub(S, M.iexptax, M.iC)'
    if (max((1 :- ce) :* (abs(etax) :> tol))) _cge_fail("export tax recorded on a commodity without exports", 459)
    te = ce :* etax :/ (ce :* exports + (1 :- ce))
    QE0 = ce :* (exports - etax)
    pwe = 1 :/ (1 :- te)

    QA0 = colsum(S[., M.iA])'
    if (min(QA0) <= tol) _cge_fail("every activity needs positive output", 459)
    ta = _cge_sub(S, M.iacttax, M.iA)' :/ QA0
    QX0 = QA0
    QD0 = QX0 - QE0
    if (min(QD0) <= tol) _cge_fail("version 0.1 needs positive domestic sales of every commodity", 459)
    PM0 = cm :* (1 :+ tm)
    stax = _cge_sub(S, M.isaltax, M.iC)'
    QQ0 = QD0 + PM0 :* QM0 + stax
    tq = stax :/ QQ0
    demand = rowsum(_cge_sub(S, M.iC, M.iA)) + rowsum(_cge_sub(S, M.iC, M.iH)) +
             _cge_sub(S, M.iC, M.igov) + _cge_sub(S, M.iC, M.isav)
    if (max(abs(QQ0 - demand)) > tol) _cge_fail("composite supply does not equal domestic demand for some commodity", 459)

    // 7.3 Production
    QINT0 = _cge_sub(S, M.iC, M.iA)
    QINTA0 = colsum(QINT0)'
    p.ica = QINT0 :/ (QINTA0' + (QINTA0' :<= 0))
    VA = _cge_sub(S, M.iF, M.iA)
    M.fa = VA :> tol
    if (fqname == "") {
        W0 = J(nF, 1, 1)
        WFD0 = J(nF, n, 1)
        QF0 = M.fa :* VA
    }
    else {
        QFq = st_matrix(fqname)
        if (rows(QFq) != nF | cols(QFq) != n) {
            errprintf("matrix %s must have %f rows (factors) and %f columns (activities)\n", fqname, nF, n)
            exit(503)
        }
        if (max(abs((QFq :> 0) - M.fa))) _cge_fail("factor quantities must be positive exactly where factor payments are", 459)
        W0 = rowsum(VA) :/ rowsum(QFq)
        WFD0 = M.fa :* (VA :/ (W0 :* QFq + (1 :- M.fa))) + (1 :- M.fa)
        QF0 = QFq
    }
    QVA0 = colsum(VA)'
    if (min(QVA0) <= tol) _cge_fail("every activity needs positive value added", 459)
    p.iva = QVA0 :/ QA0
    p.inta = QINTA0 :/ QA0

    cd = abs(sva :- 1) :< 1e-12
    rva = (1 :- cd) :* (1 :/ sva :- 1)
    dva = J(nF, n, 0)
    ad = J(n, 1, 0)
    w = W0 :* WFD0
    for (k = 1; k <= n; k++) {
        m = select((1::nF), M.fa[., k])
        if (cd[k]) {
            d = VA[m, k] :/ QVA0[k]
            dva[m, k] = d
            ad[k] = QVA0[k] / exp(sum(d :* ln(QF0[m, k])))
        }
        else {
            r = rva[k]
            num = w[m, k] :* (QF0[m, k] :^ (1 + r))
            d = num :/ sum(num)
            dva[m, k] = d
            ad[k] = QVA0[k] / (sum(d :* (QF0[m, k] :^ (-r))))^(-1 / r)
        }
    }

    // 7.4 CET and Armington functions (base prices PD = PE = 1)
    rt = 1 :/ st :+ 1
    dt = J(n, 1, 0.5)
    at = J(n, 1, 1)
    for (k = 1; k <= n; k++) {
        if (!ce[k]) continue
        r = rt[k]
        dt[k] = 1 / (1 + (QE0[k] / QD0[k])^(r - 1))
        at[k] = QX0[k] / (dt[k] * QE0[k]^r + (1 - dt[k]) * QD0[k]^r)^(1 / r)
    }
    if (max(cm :* (abs(sq :- 1) :< 1e-12))) _cge_fail("version 0.1 needs sigmaq different from 1 for imported commodities", 198)
    rq = 1 :/ sq :- 1
    dq = J(n, 1, 0.5)
    aq = J(n, 1, 1)
    for (k = 1; k <= n; k++) {
        if (!cm[k]) continue
        r = rq[k]
        ratio = PM0[k] * (QM0[k] / QD0[k])^(1 + r)
        dq[k] = ratio / (1 + ratio)
        aq[k] = QQ0[k] / (dq[k] * QM0[k]^(-r) + (1 - dq[k]) * QD0[k]^(-r))^(-1 / r)
    }

    // 7.5 Institutions
    YIF0 = _cge_sub(S, M.iH \ M.igov \ M.irow, M.iF)
    YF0 = rowsum(VA)
    if (max(abs(colsum(YIF0)' - YF0)) > tol) _cge_fail("factor income paid out does not equal factor income received", 459)
    p.shif = YIF0 :/ YF0'
    YH0 = rowsum(S[M.iH, .])
    tins0 = _cge_sub(S, M.idirtax, M.iH)' :/ YH0
    mps0 = _cge_sub(S, M.isav, M.iH)' :/ ((1 :- tins0) :* YH0)
    QH0 = _cge_sub(S, M.iC, M.iH)
    EH0 = colsum(QH0)'
    if (max(abs(EH0 - (1 :- mps0) :* (1 :- tins0) :* YH0)) > tol) {
        _cge_fail("household spending does not equal income less direct tax and savings", 459)
    }
    p.beta = QH0 :/ EH0'
    p.trhg = _cge_sub(S, M.iH, M.igov)
    p.trhr = _cge_sub(S, M.iH, M.irow)
    p.trgr = S[M.igov, M.irow]
    p.qg = _cge_sub(S, M.iC, M.igov)
    p.qinv = _cge_sub(S, M.iC, M.isav)
    p.cwts = rowsum(QH0) :/ sum(QH0)
    p.dwts = QD0 :/ sum(QD0)

    p.pwm = J(n, 1, 1)
    p.pwe = pwe
    p.tm = tm
    p.te = te
    p.tq = tq
    p.ta = ta
    p.ad = ad
    p.dva = dva
    p.rva = rva
    p.sva = sva
    p.at = at
    p.dt = dt
    p.rt = rt
    p.aq = aq
    p.dq = dq
    p.rq = rq
    p.sq = sq
    p.st = st
    p.tins0 = tins0
    p.mps0 = mps0
    M.ce = ce
    M.cm = cm
    M.cd = cd
    M.p0 = p
    M.p = p

    // Base values of all variables
    _cge_layout(M)
    total = M.voff[rows(M.voff)] + 1
    x0 = J(total, 1, 0)
    _cge_setv(M, x0, "PA", J(n, 1, 1))
    _cge_setv(M, x0, "PVA", J(n, 1, 1))
    _cge_setv(M, x0, "PINTA", colsum(p.ica)')
    _cge_setv(M, x0, "PX", J(n, 1, 1))
    _cge_setv(M, x0, "PD", J(n, 1, 1))
    _cge_setv(M, x0, "PE", ce)
    _cge_setv(M, x0, "PM", PM0)
    _cge_setv(M, x0, "PQ", J(n, 1, 1))
    _cge_setv(M, x0, "W", W0)
    _cge_setv(M, x0, "EXR", 1)
    _cge_setv(M, x0, "CPI", sum(p.cwts))
    _cge_setv(M, x0, "DPI", sum(p.dwts))
    _cge_setv(M, x0, "QA", QA0)
    _cge_setv(M, x0, "QVA", QVA0)
    _cge_setv(M, x0, "QINTA", QINTA0)
    _cge_setv(M, x0, "QF", QF0)
    _cge_setv(M, x0, "QINT", QINT0)
    _cge_setv(M, x0, "QX", QX0)
    _cge_setv(M, x0, "QD", QD0)
    _cge_setv(M, x0, "QE", QE0)
    _cge_setv(M, x0, "QM", cm :* QM0)
    _cge_setv(M, x0, "QQ", QQ0)
    _cge_setv(M, x0, "QH", QH0)
    _cge_setv(M, x0, "QG", p.qg)
    _cge_setv(M, x0, "QINV", p.qinv)
    _cge_setv(M, x0, "QFS", rowsum(QF0))
    _cge_setv(M, x0, "YF", YF0)
    _cge_setv(M, x0, "YIF", YIF0)
    _cge_setv(M, x0, "YH", YH0)
    _cge_setv(M, x0, "EH", EH0)
    _cge_setv(M, x0, "YG", sum(S[M.igov, .]))
    _cge_setv(M, x0, "EG", sum(p.qg) + sum(p.trhg))
    _cge_setv(M, x0, "GSAV", S[M.isav, M.igov])
    _cge_setv(M, x0, "FSAV", S[M.isav, M.irow])
    _cge_setv(M, x0, "TINS", tins0)
    _cge_setv(M, x0, "MPS", mps0)
    _cge_setv(M, x0, "TINSADJ", 1)
    _cge_setv(M, x0, "MPSADJ", 1)
    _cge_setv(M, x0, "IADJ", 1)
    _cge_setv(M, x0, "GADJ", 1)
    _cge_setv(M, x0, "WFDIST", WFD0)
    _cge_setv(M, x0, "WALRAS", 0)
    M.x0 = x0
    M.xcur = x0
    M.xscale = abs(x0) :* (abs(x0) :> 1e-12) + (abs(x0) :<= 1e-12)

    M.exists = J(total, 1, 1)
    _cge_setv(M, M.exists, "PE", ce)
    _cge_setv(M, M.exists, "QE", ce)
    _cge_setv(M, M.exists, "PM", cm)
    _cge_setv(M, M.exists, "QM", cm)
    _cge_setv(M, M.exists, "QF", M.fa)
    _cge_setv(M, M.exists, "WFDIST", M.fa)

    M.nominal = J(total, 1, 0)
    for (k = 1; k <= rows(M.vname); k++) {
        if (anyof(("PA","PVA","PINTA","PX","PD","PE","PM","PQ","W","EXR","CPI","DPI",
                   "YF","YIF","YH","EH","YG","EG","GSAV","WALRAS"), M.vname[k])) {
            M.nominal[_cge_vpos(M, k)] = J(M.vrows[k] * M.vcols[k], 1, 1)
        }
    }
    M.positive = J(0, 1, .)
    for (k = 1; k <= rows(M.vname); k++) {
        if (anyof(("PA","PVA","PINTA","PX","PD","PE","PM","PQ","W","EXR","CPI","DPI",
                   "QA","QVA","QINTA","QF","QX","QD","QE","QM","QQ"), M.vname[k])) {
            m = _cge_vpos(M, k)
            M.positive = M.positive \ select(m, M.exists[m] :* (x0[m] :> 0))
        }
    }

    // Equation masks and scales, from the base point
    _cge_eq(M, p, x0, L, R, K, 1)
    M.emask = K
    mag = rowmax((abs(L), abs(R)))
    M.escale = mag :* (mag :> 1e-9) + (mag :<= 1e-9)
    M.neq = sum(K)

    M.calibrated = 1
    M.simname = J(0, 1, "")
    M.simclosure = J(0, 1, "")
    M.simmethod = J(0, 1, "")
    M.simx = J(total, 0, .)
    M.simp = cge_par(1, 0)
    M.simconv = J(0, 1, .)
    M.simiter = J(0, 1, .)
    M.simres = J(0, 1, .)
    M.c_fac = J(nF, 1, "mobile")
    _cge_closure_apply(M, "flexexr", "flexgsav", "savings", "cpi", M.c_fac)

    // Benchmark replication (model_spec.md, check 2)
    maxres = _cge_maxres(M, p, x0)
    if (maxres > 1e-9 | maxres >= .) {
        errprintf("benchmark replication failed: largest scaled residual %9.3e\n", maxres)
        exit(9)
    }
    _cge_store(M)

    printf("{txt}Calibrated: {res}%f{txt} equations, {res}%f{txt} free variables\n", M.neq, M.neq)
    printf("{txt}Benchmark replication: largest scaled residual {res}%9.3e\n", maxres)
    st_numscalar("r(N_equations)", M.neq)
    st_numscalar("r(max_residual)", maxres)
}

// =====================================================================
// Closure (model_spec.md, Section 6)
// =====================================================================

void _cge_fix(struct cge_model scalar M, real colvector fixed, string scalar name, real scalar row)
{
    real scalar k
    real colvector pos
    k = _cge_vidx(M, name)
    pos = _cge_vpos(M, k)
    if (row > 0) pos = M.voff[k] :+ ((row - 1) * M.vcols[k] :+ (1::M.vcols[k]))
    fixed[pos] = J(rows(pos), 1, 1)
}

void _cge_closure_apply(struct cge_model scalar M, string scalar ext, string scalar gov,
                        string scalar si, string scalar num, string colvector fac)
{
    real colvector fixed
    real scalar k, nfree

    fixed = J(rows(M.x0), 1, 0)
    _cge_fix(M, fixed, "GADJ", 0)
    if (ext == "flexexr") _cge_fix(M, fixed, "FSAV", 0)
    else if (ext == "fixexr") _cge_fix(M, fixed, "EXR", 0)
    else _cge_fail("external() must be flexexr or fixexr", 198)
    if (gov == "flexgsav") _cge_fix(M, fixed, "TINSADJ", 0)
    else if (gov == "fixgsav") _cge_fix(M, fixed, "GSAV", 0)
    else _cge_fail("government() must be flexgsav or fixgsav", 198)
    if (si == "savings") _cge_fix(M, fixed, "MPSADJ", 0)
    else if (si == "investment") _cge_fix(M, fixed, "IADJ", 0)
    else _cge_fail("savinv() must be savings or investment", 198)
    if (num == "cpi") _cge_fix(M, fixed, "CPI", 0)
    else if (num == "dpi") _cge_fix(M, fixed, "DPI", 0)
    else _cge_fail("numeraire() must be cpi or dpi", 198)
    for (k = 1; k <= M.nF; k++) {
        if (fac[k] == "mobile") {
            _cge_fix(M, fixed, "QFS", k)
            _cge_fix(M, fixed, "WFDIST", k)
        }
        else if (fac[k] == "specific") {
            _cge_fix(M, fixed, "W", k)
            _cge_fix(M, fixed, "QF", k)
        }
        else if (fac[k] == "unemployed") {
            _cge_fix(M, fixed, "W", k)
            _cge_fix(M, fixed, "WFDIST", k)
        }
        else _cge_fail("factor closure must be mobile, specific or unemployed", 198)
    }
    nfree = sum(M.exists :* (1 :- fixed))
    if (nfree != M.neq) {
        errprintf("closure is not square: %f free variables, %f equations\n", nfree, M.neq)
        exit(459)
    }
    M.fixed = fixed
    M.c_ext = ext
    M.c_gov = gov
    M.c_si = si
    M.c_num = num
    M.c_fac = fac
}

string scalar _cge_closure_text(struct cge_model scalar M)
{
    string scalar s
    real scalar k
    s = M.c_ext + " " + M.c_gov + " " + M.c_si + " " + M.c_num
    for (k = 1; k <= M.nF; k++) s = s + " " + M.F[k] + ":" + M.c_fac[k]
    return(s)
}

void _cge_closure(string scalar ext, string scalar gov, string scalar si, string scalar num,
                  string scalar facspec, real scalar facgiven)
{
    struct cge_model scalar M
    string rowvector tok
    string colvector fac
    string scalar f, mode
    real scalar k, pos, idx

    M = _cge_load()
    _cge_need(M, "calibrated")
    if (ext == "") ext = M.c_ext
    if (gov == "") gov = M.c_gov
    if (si == "") si = M.c_si
    if (num == "") num = M.c_num
    fac = M.c_fac
    if (facgiven) {
        fac = J(M.nF, 1, "mobile")
        tok = tokens(facspec)
        for (k = 1; k <= cols(tok); k++) {
            pos = strpos(tok[k], ":")
            if (pos == 0) _cge_fail("factors() entries take the form factor:mobile, factor:specific or factor:unemployed", 198)
            f = substr(tok[k], 1, pos - 1)
            mode = substr(tok[k], pos + 1, .)
            idx = _cge_find(M.F, f)
            if (idx == 0) _cge_fail(f + " is not a factor of the model", 111)
            fac[idx] = mode
        }
    }
    _cge_closure_apply(M, ext, gov, si, num, fac)
    _cge_store(M)
    _cge_closure_show(M)
}

void _cge_closure_show(struct cge_model scalar M)
{
    real scalar k
    printf("{txt}Closure\n")
    printf("{txt}  external account     {res}%s\n", M.c_ext)
    printf("{txt}  government           {res}%s\n", M.c_gov)
    printf("{txt}  savings-investment   {res}%s\n", M.c_si)
    printf("{txt}  numeraire            {res}%s\n", M.c_num)
    for (k = 1; k <= M.nF; k++) printf("{txt}  factor %-13s {res}%s\n", M.F[k], M.c_fac[k])
    st_global("r(closure)", _cge_closure_text(M))
}

// =====================================================================
// Shocks
// =====================================================================

real colvector _cge_par_get(struct cge_par scalar p, string scalar name)
{
    if (name == "tm")  return(p.tm)
    if (name == "te")  return(p.te)
    if (name == "tq")  return(p.tq)
    if (name == "ta")  return(p.ta)
    if (name == "pwm") return(p.pwm)
    if (name == "pwe") return(p.pwe)
    if (name == "ad")  return(p.ad)
    _cge_fail("cge internal error: unknown parameter " + name, 3498)
}

void _cge_par_set(struct cge_par scalar p, string scalar name, real colvector v)
{
    if (name == "tm")       p.tm = v
    else if (name == "te")  p.te = v
    else if (name == "tq")  p.tq = v
    else if (name == "ta")  p.ta = v
    else if (name == "pwm") p.pwm = v
    else if (name == "pwe") p.pwe = v
    else if (name == "ad")  p.ad = v
}

real colvector _cge_elements(string colvector set, string scalar elems, string scalar what)
{
    string rowvector tok
    real colvector idx
    real scalar k
    if (elems == "" | elems == "all") return((1::rows(set)))
    tok = tokens(elems)
    idx = J(cols(tok), 1, 0)
    for (k = 1; k <= cols(tok); k++) {
        idx[k] = _cge_find(set, tok[k])
        if (idx[k] == 0) _cge_fail(tok[k] + " is not one of the " + what + " of the model", 111)
    }
    return(idx)
}

void _cge_shock(string scalar target, string scalar elems, string scalar mode, real scalar value)
{
    struct cge_model scalar M
    real colvector v, idx, pos, okpos
    real scalar k, i
    string scalar set

    M = _cge_load()
    _cge_need(M, "calibrated")

    if (target == "reset") {
        M.p = M.p0
        M.xcur = M.x0
        _cge_store(M)
        printf("{txt}All shocks removed\n")
        return
    }

    if (anyof(("tm", "te", "tq", "pwm", "pwe"), target)) {
        idx = _cge_elements(M.C, elems, "commodities")
    }
    else if (anyof(("ta", "ad"), target)) {
        idx = _cge_elements(M.A, elems, "activities")
    }
    else idx = J(0, 1, .)

    if (rows(idx)) {
        v = _cge_par_get(M.p, target)
        v[idx] = (mode == "scale" ? v[idx] :* value : J(rows(idx), 1, value))
        _cge_par_set(M.p, target, v)
        _cge_store(M)
        printf("{txt}Parameter {res}%s{txt} changed for %f element(s)\n", target, rows(idx))
        return
    }

    k = _cge_vidx(M, target)
    if (k == 0) {
        _cge_fail(target + " is not a shockable parameter (tm te tq ta pwm pwe ad) or model variable", 198)
    }
    set = M.vset[k]
    if (set == "") {
        if (elems != "" & elems != "all") _cge_fail(target + " has no elements", 198)
        pos = _cge_vpos(M, k)
    }
    else if (strlen(set) == 1) {
        idx = _cge_elements((set == "A" ? M.A : (set == "C" ? M.C : (set == "F" ? M.F : M.H))), elems, "elements")
        pos = M.voff[k] :+ idx
    }
    else if (set == "FA") {
        idx = _cge_elements(M.F, elems, "factors")
        pos = J(0, 1, .)
        for (i = 1; i <= rows(idx); i++) pos = pos \ (M.voff[k] :+ ((idx[i] - 1) * M.n :+ (1::M.n)))
    }
    else _cge_fail(target + " cannot be shocked", 198)

    okpos = select(pos, M.exists[pos])
    if (min(M.fixed[okpos]) == 0) {
        _cge_fail(target + " is not fixed under the current closure, so it cannot be set", 459)
    }
    M.xcur[okpos] = (mode == "scale" ? M.xcur[okpos] :* value : J(rows(okpos), 1, value))
    _cge_store(M)
    printf("{txt}Variable {res}%s{txt} changed for %f element(s)\n", target, rows(okpos))
}

// =====================================================================
// Solver
// =====================================================================

real colvector _cge_F(struct cge_model scalar M, struct cge_par scalar p, real colvector xfix,
                      real colvector free, real colvector z)
{
    real colvector x
    x = xfix
    x[free] = z :* M.xscale[free]
    return(_cge_resid(M, p, x))
}

real matrix _cge_jacobian(struct cge_model scalar M, struct cge_par scalar p, real colvector xfix,
                          real colvector free, real colvector z)
{
    real matrix Jac
    real colvector zp, zm
    real scalar j, h
    Jac = J(M.neq, rows(z), .)
    for (j = 1; j <= rows(z); j++) {
        h = 1e-6 * max((1, abs(z[j])))
        zp = z
        zm = z
        zp[j] = zp[j] + h
        zm[j] = zm[j] - h
        Jac[., j] = (_cge_F(M, p, xfix, free, zp) - _cge_F(M, p, xfix, free, zm)) / (2 * h)
    }
    return(Jac)
}

// Newton-Raphson with a backtracking line search; returns 1 on convergence.
real scalar _cge_newton(struct cge_model scalar M, struct cge_par scalar p, real colvector xfix,
                        real colvector free, real colvector z, real scalar tol, real scalar maxit,
                        real scalar trace, real scalar iter, real scalar err)
{
    real colvector f, fn, dz, zn
    real matrix Jac
    real scalar norm0, step, it

    f = _cge_F(M, p, xfix, free, z)
    iter = 0
    err = .
    if (hasmissing(f)) return(0)
    for (it = 0; it <= maxit; it++) {
        err = max(abs(f))
        iter = it
        if (trace) printf("{txt}Iteration %f: largest scaled residual = {res}%9.3e\n", it, err)
        if (err < tol) return(1)
        if (it == maxit) return(0)
        Jac = _cge_jacobian(M, p, xfix, free, z)
        if (hasmissing(Jac)) return(0)
        dz = lusolve(Jac, -f)
        if (hasmissing(dz)) return(0)
        norm0 = norm(f)
        step = 1
        while (step >= 1e-8) {
            zn = z + step * dz
            fn = _cge_F(M, p, xfix, free, zn)
            if (!hasmissing(fn)) {
                if (norm(fn) <= (1 - 1e-4 * step) * norm0) break
            }
            step = step / 2
        }
        if (step < 1e-8) return(0)
        z = zn
        f = fn
    }
    return(0)
}

void _cge_solvenl_eval(real colvector z, real colvector y, struct cge_model scalar M,
                       struct cge_par scalar p, real colvector xfix, real colvector free)
{
    y = _cge_F(M, p, xfix, free, z)
}

// Solve from `start` with parameters p and fixed values in xfix.
// Returns the full solution vector; conv, iter, err and method describe the outcome.
real colvector _cge_solve_point(struct cge_model scalar M, struct cge_par scalar p, real colvector xfix,
                                real colvector start, real scalar tol, real scalar maxit,
                                real scalar trace, real scalar conv, real scalar iter,
                                real scalar err, string scalar method)
{
    real colvector free, z, z2, x
    transmorphic S
    real scalar rc, iter2

    free = select((1::rows(M.x0)), M.exists :* (1 :- M.fixed))
    z = start[free] :/ M.xscale[free]
    method = "newton"
    conv = _cge_newton(M, p, xfix, free, z, tol, maxit, trace, iter, err)
    if (!conv) {
        // Fallback: Powell's hybrid method, then Newton to polish the result
        method = "broydenpowell"
        S = solvenl_init()
        solvenl_init_evaluator(S, &_cge_solvenl_eval())
        solvenl_init_type(S, "zero")
        solvenl_init_technique(S, "broydenpowell")
        solvenl_init_narguments(S, 4)
        solvenl_init_argument(S, 1, M)
        solvenl_init_argument(S, 2, p)
        solvenl_init_argument(S, 3, xfix)
        solvenl_init_argument(S, 4, free)
        solvenl_init_iter_log(S, (trace ? "on" : "off"))
        solvenl_init_conv_maxiter(S, 1000)
        solvenl_init_startingvals(S, start[free] :/ M.xscale[free])
        rc = _solvenl_solve(S)
        if (rc == 0) {
            z2 = solvenl_result_values(S)
            conv = _cge_newton(M, p, xfix, free, z2, tol, maxit, trace, iter2, err)
            if (conv) z = z2
            iter = iter + iter2
        }
    }
    x = xfix
    x[free] = z :* M.xscale[free]
    return(x)
}

void _cge_solve(string scalar name, real scalar tol, real scalar maxit, real scalar trace)
{
    struct cge_model scalar M
    real colvector x
    real scalar conv, iter, err, k, walras
    string scalar method

    M = _cge_load()
    _cge_need(M, "calibrated")
    if (name == "") name = "sim" + strofreal(rows(M.simname) + 1)

    x = _cge_solve_point(M, M.p, M.xcur, M.x0, tol, maxit, trace, conv, iter, err, method)
    walras = x[M.voff[_cge_vidx(M, "WALRAS")] + 1]

    k = _cge_find(M.simname, name)
    if (k == 0) {
        M.simname = M.simname \ name
        M.simclosure = M.simclosure \ _cge_closure_text(M)
        M.simmethod = M.simmethod \ method
        M.simx = M.simx, x
        M.simp = M.simp, M.p
        M.simconv = M.simconv \ conv
        M.simiter = M.simiter \ iter
        M.simres = M.simres \ err
    }
    else {
        M.simclosure[k] = _cge_closure_text(M)
        M.simmethod[k] = method
        M.simx[., k] = x
        M.simp[k] = M.p
        M.simconv[k] = conv
        M.simiter[k] = iter
        M.simres[k] = err
    }
    _cge_store(M)

    if (conv) printf("{txt}Simulation {res}%s{txt} solved in {res}%f{txt} iteration(s) ({res}%s{txt})\n", name, iter, method)
    else printf("{err}Simulation %s did not converge (largest scaled residual %9.3e)\n", name, err)
    printf("{txt}Largest scaled residual {res}%9.3e{txt}; WALRAS = {res}%9.3e\n", err, walras)
    st_numscalar("r(converged)", conv)
    st_numscalar("r(iterations)", iter)
    st_numscalar("r(max_residual)", err)
    st_numscalar("r(walras)", walras)
    st_global("r(name)", name)
    st_global("r(method)", method)
    st_global("r(closure)", _cge_closure_text(M))
}

// =====================================================================
// Results
// =====================================================================

real scalar _cge_sim_index(struct cge_model scalar M, string scalar sim)
{
    real scalar k
    if (rows(M.simname) == 0) _cge_fail("no simulation has been solved; use cge_solve", 459)
    if (sim == "") return(rows(M.simname))
    k = _cge_find(M.simname, sim)
    if (k == 0) _cge_fail("simulation " + sim + " not found", 111)
    return(k)
}

real colvector _cge_ev(struct cge_model scalar M, struct cge_par scalar p, real colvector x)
{
    real matrix PQ0, PQ1
    real colvector EH0, EH1
    PQ0 = _cge_v(M, M.x0, _cge_vidx(M, "PQ"))
    PQ1 = _cge_v(M, x, _cge_vidx(M, "PQ"))
    EH0 = _cge_v(M, M.x0, _cge_vidx(M, "EH"))
    EH1 = _cge_v(M, x, _cge_vidx(M, "EH"))
    return(EH1 :* exp(colsum(p.beta :* ln(PQ0 :/ PQ1)))' - EH0)
}

// Expenditure-side GDP minus income-side GDP; zero at any solution
real scalar _cge_gdpgap(struct cge_model scalar M, struct cge_par scalar p, real colvector x)
{
    real matrix PQ, QH, QG, QINV, QE, QM, EXR, PVA, QVA, QQ, PA, QA
    real scalar expend, income
    PQ = _cge_v(M, x, 8);    QH = _cge_v(M, x, 23);   QG = _cge_v(M, x, 24)
    QINV = _cge_v(M, x, 25); QE = _cge_v(M, x, 20);   QM = _cge_v(M, x, 21)
    EXR = _cge_v(M, x, 10);  PVA = _cge_v(M, x, 2);   QVA = _cge_v(M, x, 14)
    QQ = _cge_v(M, x, 22);   PA = _cge_v(M, x, 1);    QA = _cge_v(M, x, 13)
    expend = PQ' * (rowsum(QH) + QG + QINV) + EXR * (p.pwe' * QE) - EXR * (p.pwm' * QM)
    income = PVA' * QVA + sum(p.tq :* PQ :* QQ) + EXR * sum(p.tm :* p.pwm :* QM) +
             EXR * sum(p.te :* p.pwe :* QE) + sum(p.ta :* PA :* QA)
    return(expend - income)
}

void _cge_results_data(string scalar sim)
{
    struct cge_model scalar M
    string colvector v, e1, e2, l1, l2
    real colvector base, value, pos, keep
    real scalar k, s, N

    M = _cge_load()
    _cge_need(M, "calibrated")
    s = _cge_sim_index(M, sim)
    v = J(0, 1, "")
    e1 = v
    e2 = v
    base = J(0, 1, .)
    value = base
    for (k = 1; k <= rows(M.vname); k++) {
        _cge_vlabels(M, k, l1, l2)
        pos = _cge_vpos(M, k)
        keep = M.exists[pos]
        v = v \ select(J(rows(pos), 1, M.vname[k]), keep)
        e1 = e1 \ select(l1, keep)
        e2 = e2 \ select(l2, keep)
        base = base \ select(M.x0[pos], keep)
        value = value \ select(M.simx[pos, s], keep)
    }
    N = rows(v)
    st_addobs(N)
    (void) st_addvar("str8", "variable")
    (void) st_addvar("str32", "element1")
    (void) st_addvar("str32", "element2")
    (void) st_addvar("double", "base")
    (void) st_addvar("double", "value")
    st_sstore(., "variable", v)
    st_sstore(., "element1", e1)
    st_sstore(., "element2", e2)
    st_store(., "base", base)
    st_store(., "value", value)
}

void _cge_results_show(string scalar sim)
{
    struct cge_model scalar M
    struct cge_par scalar p
    real colvector x, ev, eh0
    real matrix b, s
    real scalar k, si

    M = _cge_load()
    _cge_need(M, "calibrated")
    si = _cge_sim_index(M, sim)
    x = M.simx[., si]
    p = M.simp[si]

    printf("\n{txt}Simulation {res}%s{txt} (closure: %s)\n", M.simname[si], M.simclosure[si])
    printf("{txt}{hline 52}\n")
    printf("{txt}%-34s %8s %8s\n", "", "base", "% change")
    printf("{txt}{hline 52}\n")
    _cge_row(M, x, "Real value added (base prices)", colsum(_cge_v(M, M.x0, 2) :* _cge_v(M, M.x0, 14)),
             colsum(_cge_v(M, M.x0, 2) :* _cge_v(M, x, 14)))
    _cge_row(M, x, "Exchange rate", _cge_v(M, M.x0, 10), _cge_v(M, x, 10))
    _cge_row(M, x, "Consumer price index", _cge_v(M, M.x0, 11), _cge_v(M, x, 11))
    _cge_row(M, x, "Investment volume (IADJ)", _cge_v(M, M.x0, 39), _cge_v(M, x, 39))
    _cge_row(M, x, "Imports (world prices)", p.pwm' * _cge_v(M, M.x0, 21), p.pwm' * _cge_v(M, x, 21))
    _cge_row(M, x, "Exports (world prices)", p.pwe' * _cge_v(M, M.x0, 20), p.pwe' * _cge_v(M, x, 20))
    _cge_row(M, x, "Government savings", _cge_v(M, M.x0, 33), _cge_v(M, x, 33))
    b = _cge_v(M, M.x0, 9)
    s = _cge_v(M, x, 9)
    for (k = 1; k <= M.nF; k++) _cge_row(M, x, "Price of " + M.F[k], b[k], s[k])
    b = _cge_v(M, M.x0, 13)
    s = _cge_v(M, x, 13)
    for (k = 1; k <= M.n; k++) _cge_row(M, x, "Output of " + M.A[k], b[k], s[k])
    printf("{txt}{hline 52}\n")
    ev = _cge_ev(M, p, x)
    eh0 = _cge_v(M, M.x0, 30)
    for (k = 1; k <= M.nH; k++) {
        printf("{txt}Equivalent variation, %-12s {res}%9.4g{txt} (%5.2f%% of consumption)\n",
               M.H[k], ev[k], 100 * ev[k] / eh0[k])
    }
    printf("{txt}WALRAS {res}%9.3e{txt}; GDP identity gap {res}%9.3e\n",
           x[M.voff[42] + 1], _cge_gdpgap(M, p, x))
    st_matrix("r(ev)", ev')
    st_global("r(sim)", M.simname[si])
}

void _cge_row(struct cge_model scalar M, real colvector x, string scalar label, real scalar b, real scalar s)
{
    printf("{txt}%-34s {res}%8.4g %8.3f\n", label, b, (b != 0 ? 100 * (s / b - 1) : .))
}

// =====================================================================
// Checks (model_spec.md, Section 8)
// =====================================================================

void _cge_check(string scalar sim, real scalar homog, real scalar perturb, real scalar seed)
{
    struct cge_model scalar M
    struct cge_par scalar p
    real colvector x, xfix, start, free, target, rel
    real scalar fails, v, conv, iter, err, si, scale, tol
    string scalar method

    M = _cge_load()
    _cge_need(M, "calibrated")
    fails = 0
    scale = max((1, max(abs(M.S))))

    v = max(abs(rowsum(M.S) - colsum(M.S)'))
    fails = fails + _cge_report("SAM balance (largest imbalance)", v, 1e-8 * scale)
    v = _cge_maxres(M, M.p0, M.x0)
    fails = fails + _cge_report("benchmark replication (largest scaled residual)", v, 1e-9)
    v = abs(sum(M.exists :* (1 :- M.fixed)) - M.neq)
    fails = fails + _cge_report("closure is square (free variables minus equations)", v, 0.5)

    if (rows(M.simname)) {
        si = _cge_sim_index(M, sim)
        x = M.simx[., si]
        p = M.simp[si]
        printf("{txt}Simulation {res}%s{txt}:\n", M.simname[si])
        fails = fails + _cge_report("  solution (largest scaled residual)", M.simres[si], 1e-8)
        fails = fails + _cge_report("  Walras's law (WALRAS)", abs(x[M.voff[42] + 1]), 1e-8 * scale)
        fails = fails + _cge_report("  GDP identity (expenditure minus income)", abs(_cge_gdpgap(M, p, x)), 1e-8 * scale)
    }

    if (homog) {
        // Double every fixed nominal value: nominal variables should double and real ones stay put
        xfix = M.x0 :* (1 :+ M.fixed :* M.nominal)
        x = _cge_solve_point(M, M.p0, xfix, M.x0, 1e-12, 100, 0, conv, iter, err, method)
        target = M.x0 :* (1 :+ M.nominal)
        rel = select(abs(x - target) :/ rowmax((J(rows(x), 1, 1), abs(target))), M.exists)
        v = (conv ? max(rel) : .)
        fails = fails + _cge_report("homogeneity (largest relative deviation)", v, 1e-8)
    }

    if (perturb > 0) {
        rseed(seed)
        start = M.x0 :* (1 :+ perturb * (2 * runiform(rows(M.x0), 1) :- 1))
        x = _cge_solve_point(M, M.p0, M.x0, start, 1e-12, 100, 0, conv, iter, err, method)
        rel = select(abs(x - M.x0) :/ rowmax((J(rows(x), 1, 1), abs(M.x0))), M.exists)
        v = (conv ? max(rel) : .)
        fails = fails + _cge_report("perturbed start returns the base (largest deviation)", v, 1e-7)
    }

    st_numscalar("r(failures)", fails)
    if (fails) printf("{err}%f check(s) failed\n", fails)
    else printf("{txt}All checks passed\n")
}

real scalar _cge_report(string scalar label, real scalar value, real scalar tol)
{
    real scalar ok
    ok = (value < . & value <= tol)
    printf("{txt}  %s %-52s {res}%9.3e\n", (ok ? "[ok]  " : "{err}[fail]{txt}"), label, value)
    return(!ok)
}

end
