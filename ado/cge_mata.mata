*! cge_mata.mata  v0.1.12  2026-10-15
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
    // top nest: efficiency, value-added share and its complement, exponent, elasticity
    real colvector aa, dla, dlac, rha, sa
    real matrix    ica, dva, theta, icm
    real colvector at, dt, dtc, rt, aq, dq, dqc, rq, sq, st
    real matrix    shif, beta, gamma
    real colvector tins0, mps0, shir, hc, trdg, trdr, trfr, qg, qinv, cwts, dwts, qer
    real matrix    shii
    real scalar    trgr, trrg, trgg
}

struct cge_model {
    // SAM as read (labels0, S0) and after rewriting layouts (labels, S)
    string colvector labels0, labels
    real matrix      S0, S
    real rowvector   rewritten
    real scalar      mapped, calibrated
    real colvector   iA, iC, iF, iH
    real scalar      igov, isav, irow, idirtax, isaltax, iimptax, iexptax, iacttax
    string colvector A, C, F, H, I
    real colvector   iE, imargins, iterritorial, iT, istocks
    string colvector E, D
    // n activities, nC commodities (nC >= n from version 0.1.7)
    real scalar      n, nC, nF, nH, nE, nD, nI
    // model structure
    real colvector   ce, cm, cd, cx, ct, cr
    // activities with a Leontief top nest, and with a Cobb-Douglas one
    real colvector   lt, cda
    real matrix      fa
    // parameters: base (p0) and current, including shocks (p)
    struct cge_par scalar p0, p
    // variable layout; all variables are stacked in one vector x
    string colvector vname, vset
    real colvector   voff, vrows, vcols
    real colvector   x0, xcur, xscale, exists, fixed, nominal, positive
    // sparsity pattern of the Jacobian for the rows found by grouped differences,
    // as (equation, variable) pairs, and the rows with exact derivatives
    real colvector   jr, jc, drow
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

// Columns of the Jacobian for one solve (free variables), grouped so that the
// columns of a group share no equation: CSC storage of the pattern (rows of
// column j are crow[cstart[j]..cstart[j+1]-1]) and the members of each group
// (gcol[gstart[g]..gstart[g+1]-1])
struct cge_jpat {
    real colvector cstart, crow, gstart, gcol
    real scalar    ncolour
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

// Fails if any element of mask is set, naming the accounts concerned
void _cge_fail_if(real colvector mask, string colvector names, string scalar msg, real scalar rc)
{
    string colvector bad
    if (!max(mask)) return
    bad = select(names, mask)
    errprintf("%s: %s%s\n", msg, invtokens(bad[|1 \ min((rows(bad), 10))|]'),
              (rows(bad) > 10 ? sprintf(" and %f more", rows(bad) - 10) : ""))
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
    if (s == "A") return(M.n)
    if (s == "C") return(M.nC)
    if (s == "F") return(M.nF)
    if (s == "H") return(M.nH)
    if (s == "D") return(M.nD)
    if (s == "I") return(M.nI)
    _cge_fail("cge internal error: unknown set " + s, 3498)
}

void _cge_layout(struct cge_model scalar M)
{
    real scalar k, r, c, off
    M.vname = ("PA","PVA","PINTA","PX","PD","PE","PM","PQ","W","EXR","CPI","DPI",
               "QA","QVA","QINTA","QF","QINT","QX","QD","QE","QM","QQ","QH","QG","QINV","QFS",
               "YF","YIF","YI","EH","YG","EG","GSAV","FSAV","TINS","MPS","TINSADJ","MPSADJ",
               "IADJ","GADJ","WFDIST","WALRAS","QT","QER")'
    M.vset  = ("A","A","A","C","C","C","C","C","F","","","",
               "A","A","A","FA","CA","C","C","C","C","C","CH","C","C","F",
               "F","IF","D","H","","","","","D","D","","",
               "","","FA","","C","C")'
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
         (substr(set, 1, 1) == "F" ? M.F : (substr(set, 1, 1) == "H" ? M.H :
         (substr(set, 1, 1) == "D" ? M.D : M.I)))))
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
    real scalar nmiss, maxdiff, k

    labels = st_sdata(., labelvar)
    names = tokens(accounts)'
    if (rows(names) == 0) _cge_fail("no numeric account variables found", 459)
    S = st_data(., accounts)
    if (rows(S) != cols(S)) {
        errprintf("SAM is not square: %f rows and %f account columns\n", rows(S), cols(S))
        exit(459)
    }
    // A label that is not a valid Stata name (for example s-i) cannot be a
    // variable name; when the data were read, the variable was renamed (si).
    // The variable names are then used as labels, and the change is reported.
    if (labels != names) {
        for (k = 1; k <= rows(labels); k++) {
            if (labels[k] == names[k]) continue
            if (st_isname(labels[k])) {
                _cge_fail("row " + strofreal(k) + " of " + labelvar + " is labelled " + labels[k] +
                          " but account variable " + strofreal(k) + " is " + names[k] +
                          "; row labels must match the account variable names, in the same order", 459)
            }
            printf("{txt}Account label {res}%s{txt} is not a valid Stata name; using {res}%s{txt}\n",
                   labels[k], names[k])
        }
        labels = names
        st_sstore(., labelvar, labels)
    }
    nmiss = missing(S)
    if (nmiss) S = editmissing(S, 0)
    maxdiff = max(abs(rowsum(S) - colsum(S)'))

    M.labels0 = labels
    M.S0 = S
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
              string scalar ents,
              string scalar gov, string scalar sav, string scalar row, string scalar dirtax,
              string scalar saltax, string scalar imptax, string scalar exptax, string scalar acttax,
              string scalar margins, string scalar territorial, string scalar margacc,
              string scalar stocks, string scalar reportfile, real scalar replace)
{
    struct cge_model scalar M
    real colvector role, iA, iC, imarg, iterr, istk, mapped, restc
    real rowvector hcons, rest, share
    real scalar ct, at, timp, texp, negsales, negtotal
    real matrix allowed, negok, transfers, S, issues
    string rowvector rolename, taxname
    real scalar i, j, k, tol, nacc, rr, rc, x
    string colvector taxacc, labels
    real colvector taxidx, direct, payers

    M = _cge_load()
    M.labels = M.labels0
    M.S = M.S0
    S = M.S
    nacc = rows(M.labels)
    rolename = ("activity", "commodity", "factor", "household", "government",
                "savings-investment", "rest of world", "direct tax", "sales tax",
                "import tax", "export tax", "activity tax", "enterprise", "margin account",
                "unmapped")

    M.iA = _cge_lookup(M, acts, "activity")
    M.iC = _cge_lookup(M, coms, "commodity")
    M.iF = _cge_lookup(M, facs, "factor")
    M.iH = _cge_lookup(M, hhs, "household")
    M.iE = _cge_lookup(M, ents, "enterprise")
    M.iT = _cge_lookup(M, margacc, "margin account")
    M.igov = _cge_lookup(M, gov, "government")
    M.isav = _cge_lookup(M, sav, "savings-investment")
    M.irow = _cge_lookup(M, row, "rest of world")
    taxacc = (dirtax \ saltax \ imptax \ exptax \ acttax)
    taxidx = J(5, 1, 0)
    for (k = 1; k <= 5; k++) {
        if (taxacc[k] != "") taxidx[k] = _cge_lookup(M, taxacc[k], rolename[7 + k])
    }

    if (rows(M.iC) < rows(M.iA)) {
        _cge_fail("each activity needs a paired commodity: list the commodities paired with the " +
                  "activities first, in the same order, then any commodities without a paired activity", 198)
    }

    // Layouts rewritten before the checks (model_spec.md, Section 7.0):
    // exports recorded as sales by activities, and taxes paid directly to the
    // government account, which are routed through internal tax accounts.
    direct = (taxidx :== M.igov)
    if (sum(direct[(2, 3, 4)]) > 1) {
        _cge_fail("only one of saltax(), imptax() and exptax() may name the government account", 198)
    }
    labels = M.labels0
    M.rewritten = J(1, 10, 0)
    for (k = 1; k <= rows(M.iA); k++) {
        x = S[M.iA[k], M.irow]
        if (x != 0) {
            S[M.iC[k], M.irow] = S[M.iC[k], M.irow] + x
            S[M.iA[k], M.iC[k]] = S[M.iA[k], M.iC[k]] + x
            S[M.iA[k], M.irow] = 0
            M.rewritten[1] = M.rewritten[1] + x
        }
    }
    // Margins netted out of margin activities as a negative use of their own product
    imarg = _cge_lookup(M, margins, "margin activity")
    for (k = 1; k <= rows(imarg); k++) {
        j = 0
        for (i = 1; i <= rows(M.iA); i++) if (M.iA[i] == imarg[k]) j = i
        if (j == 0) _cge_fail("margins(): " + M.labels0[imarg[k]] + " is not one of the mapped activities", 198)
        x = S[M.iC[j], M.iA[j]]
        if (x >= 0) {
            _cge_fail("margins(): activity " + M.labels0[M.iA[j]] + " has no negative use of its own product " +
                      M.labels0[M.iC[j]], 459)
        }
        S[M.iA[j], M.iC[j]] = S[M.iA[j], M.iC[j]] - x
        S[M.iC[j], M.iA[j]] = 0
        M.rewritten[7] = M.rewritten[7] - x
    }
    M.imargins = imarg

    // Territorial correction: commodity, then optionally its activity
    iterr = _cge_lookup(M, territorial, "territorial correction")
    if (rows(iterr) > 2) _cge_fail("territorial() takes the correction commodity and, optionally, its activity", 198)
    if (rows(iterr)) {
        mapped = M.iA \ M.iC \ M.iF \ M.iH \ M.iE \ M.iT \ M.igov \ M.isav \ M.irow \ select(taxidx, taxidx :> 0)
        for (k = 1; k <= rows(iterr); k++) {
            if (anyof(mapped, iterr[k])) _cge_fail("territorial(): " + M.labels0[iterr[k]] + " is also mapped to a role", 198)
        }
        tol = 1e-9 * max((1, max(abs(S))))
        ct = iterr[1]
        if (rows(iterr) == 2) {
            at = iterr[2]
            x = S[at, M.irow]
            S[ct, M.irow] = S[ct, M.irow] + x
            S[at, ct] = S[at, ct] + x
            S[at, M.irow] = 0
            if (max(abs(S[at, .])) > tol | max(abs(S[., at])) > tol) {
                _cge_fail("territorial(): " + M.labels0[at] + " still has flows after its exports are moved", 459)
            }
        }
        timp = S[M.irow, ct]
        texp = S[ct, M.irow]
        hcons = S[ct, M.iH']
        rest = S[ct, .]
        rest[M.iH'] = J(1, rows(M.iH), 0)
        rest[M.irow] = 0
        restc = S[., ct]
        restc[M.irow] = 0
        if (max(abs(rest)) > tol | max(abs(restc)) > tol) {
            _cge_fail("territorial(): " + M.labels0[ct] + " may have only household consumption, imports and exports", 459)
        }
        if (abs(sum(hcons)) <= tol) _cge_fail("territorial(): households have no consumption of " + M.labels0[ct], 459)
        share = hcons :/ sum(hcons)
        S[M.irow, M.iH'] = S[M.irow, M.iH'] + share :* timp
        S[M.iH, M.irow] = S[M.iH, M.irow] + share' :* texp
        S[ct, M.iH'] = J(1, rows(M.iH), 0)
        S[ct, M.irow] = 0
        S[M.irow, ct] = 0
        M.rewritten[8] = timp
        M.rewritten[9] = texp
    }
    M.iterritorial = iterr

    // Stock-change accounts, merged into savings-investment (from version 0.1.7)
    istk = _cge_lookup(M, stocks, "stock-change account")
    if (rows(istk)) {
        mapped = M.iA \ M.iC \ M.iF \ M.iH \ M.iE \ M.iT \ M.igov \ M.isav \ M.irow \
                 select(taxidx, taxidx :> 0) \ iterr
        tol = 1e-9 * max((1, max(abs(S))))
        for (k = 1; k <= rows(istk); k++) {
            i = istk[k]
            if (anyof(mapped, i)) _cge_fail("stocks(): " + M.labels0[i] + " is also mapped to a role", 198)
            rest = S[i, .]
            rest[M.isav] = 0
            if (max(abs(rest)) > tol) {
                _cge_fail("stocks(): " + M.labels0[i] + " may receive payments only from " +
                          M.labels0[M.isav], 459)
            }
            M.rewritten[10] = M.rewritten[10] + S[i, M.isav]
            S[., M.isav] = S[., M.isav] + S[., i]
            S[., i] = J(rows(S), 1, 0)
            S[i, .] = J(1, cols(S), 0)
        }
    }
    M.istocks = istk
    taxname = ("dirtax", "saltax", "imptax", "exptax", "acttax")
    for (k = 1; k <= 5; k++) {
        if (!direct[k]) continue
        payers = (k == 1 ? (M.iH \ M.iE) : (k == 5 ? M.iA : M.iC))
        if (_cge_find(labels, "_" + taxname[k])) {
            _cge_fail("the SAM already has an account named _" + taxname[k], 198)
        }
        nacc = rows(labels)
        S = (S, J(nacc, 1, 0)) \ J(1, nacc + 1, 0)
        labels = labels \ ("_" + taxname[k])
        S[nacc + 1, payers'] = S[M.igov, payers']
        S[M.igov, payers'] = J(1, rows(payers), 0)
        S[M.igov, nacc + 1] = sum(S[nacc + 1, .])
        taxidx[k] = nacc + 1
        M.rewritten[1 + k] = sum(S[nacc + 1, .])
    }
    M.labels = labels
    M.S = S
    nacc = rows(labels)
    M.idirtax = taxidx[1]
    M.isaltax = taxidx[2]
    M.iimptax = taxidx[3]
    M.iexptax = taxidx[4]
    M.iacttax = taxidx[5]
    _cge_map_rewrites(M)

    // Role of every account; an account may have only one role
    role = J(nacc, 1, 0)
    _cge_assign(M, role, M.iA, 1, rolename)
    _cge_assign(M, role, M.iC, 2, rolename)
    _cge_assign(M, role, M.iF, 3, rolename)
    _cge_assign(M, role, M.iH, 4, rolename)
    _cge_assign(M, role, M.iE, 13, rolename)
    _cge_assign(M, role, M.iT, 14, rolename)
    _cge_assign(M, role, M.igov, 5, rolename)
    _cge_assign(M, role, M.isav, 6, rolename)
    _cge_assign(M, role, M.irow, 7, rolename)
    for (k = 1; k <= 5; k++) if (taxidx[k] > 0) _cge_assign(M, role, taxidx[k], 7 + k, rolename)

    // Accounts without a role get code 15 ("unmapped"); every problem found
    // is collected as (problem code, row, column, value) and reported at the end:
    // 1 unmapped account with flows, 2 unsupported flow, 3 activity paid by a
    // commodity it is not paired with, 4 negative flow, 5 unbalanced account.
    role = role + 15 :* (role :== 0)
    issues = J(0, 4, .)
    tol = 1e-8 * max((1, max(abs(S))))
    for (i = 1; i <= nacc; i++) {
        if (role[i] == 15 & (max(abs(S[i, .])) > tol | max(abs(S[., i])) > tol)) {
            issues = issues \ (1, i, i, sum(S[i, .]))
        }
        if (abs(sum(S[i, .]) - sum(S[., i])) > tol) {
            issues = issues \ (5, i, i, sum(S[i, .]) - sum(S[., i]))
        }
    }

    // Supported flows (row role, column role); role 13 is an enterprise and
    // role 14 a margin account
    allowed = J(15, 15, 0)
    allowed[1, 2] = 1
    allowed[2, 1] = 1; allowed[3, 1] = 1; allowed[12, 1] = 1
    allowed[7, 2] = 1; allowed[10, 2] = 1; allowed[9, 2] = 1; allowed[11, 2] = 1
    allowed[2, 4] = 1; allowed[2, 5] = 1; allowed[2, 6] = 1; allowed[2, 7] = 1
    allowed[4, 3] = 1; allowed[13, 3] = 1; allowed[5, 3] = 1; allowed[7, 3] = 1
    allowed[8, 4] = 1; allowed[6, 4] = 1; allowed[8, 13] = 1; allowed[6, 13] = 1
    allowed[5, 8] = 1; allowed[5, 9] = 1; allowed[5, 10] = 1; allowed[5, 11] = 1; allowed[5, 12] = 1
    allowed[6, 5] = 1; allowed[6, 7] = 1
    allowed[14, 2] = 1; allowed[2, 14] = 1
    // Transfers: among households and enterprises, from them to the rest of
    // the world, from government (to them, itself and abroad) and from the
    // rest of the world (to them, government and factors)
    transfers = J(15, 15, 0)
    transfers[(4, 13), (4, 13)] = J(2, 2, 1)
    transfers[7, (4, 13)] = J(1, 2, 1)
    transfers[(4, 13, 5, 7), 5] = J(4, 1, 1)
    transfers[(4, 13, 5, 3), 7] = J(4, 1, 1)
    allowed = allowed :| transfers
    // Cells that may be negative
    negok = transfers
    negok[(6, 8, 9, 10, 11, 12), .] = J(6, 15, 1)
    negok[5, (8, 9, 10, 11, 12)] = J(1, 5, 1)
    negok[2, 6] = 1         // investment demand: a fall in inventories
    negok[1, 2] = 1         // sales of commodities by activities: negative yields

    for (i = 1; i <= nacc; i++) {
        for (j = 1; j <= nacc; j++) {
            if (abs(S[i, j]) <= tol) continue
            rr = role[i]
            rc = role[j]
            if (!allowed[rr, rc]) {
                issues = issues \ (2, i, j, S[i, j])
                continue
            }
            if (S[i, j] < 0 & !negok[rr, rc]) issues = issues \ (4, i, j, S[i, j])
        }
    }
    // Note on negative sales of commodities by activities (negative yields)
    negsales = 0
    negtotal = 0
    for (i = 1; i <= rows(M.iA); i++) {
        for (j = 1; j <= rows(M.iC); j++) {
            if (S[M.iA[i], M.iC[j]] < -tol) {
                negsales = negsales + 1
                negtotal = negtotal + S[M.iA[i], M.iC[j]]
                printf("{txt}Note: negative sale of %s by %s ({res}%g{txt}), kept as a negative yield\n",
                       M.labels[M.iC[j]], M.labels[M.iA[i]], S[M.iA[i], M.iC[j]])
            }
        }
    }
    st_numscalar("r(N_negative_sales)", negsales)
    if (reportfile != "") _cge_map_save(M, issues, role, rolename, reportfile, replace)
    if (rows(issues)) {
        _cge_map_report(M, issues, role, rolename)
        exit(459)
    }

    M.A = M.labels[M.iA]
    M.C = M.labels[M.iC]
    M.F = M.labels[M.iF]
    M.H = M.labels[M.iH]
    M.E = (rows(M.iE) ? M.labels[M.iE] : J(0, 1, ""))
    M.D = M.H \ M.E
    M.I = M.D \ M.labels[M.igov] \ M.labels[M.irow]
    M.n = rows(M.iA)
    M.nC = rows(M.iC)
    M.nF = rows(M.iF)
    M.nH = rows(M.iH)
    M.nE = rows(M.iE)
    M.nD = M.nH + M.nE
    M.nI = M.nD + 2
    M.mapped = 1
    M.calibrated = 0
    _cge_store(M)
    printf("{txt}Accounts mapped: {res}%f{txt} activities, {res}%f{txt} commodities, {res}%f{txt} factors, {res}%f{txt} households, {res}%f{txt} enterprises, {res}%f{txt} margin accounts\n",
           M.n, M.nC, M.nF, M.nH, M.nE, rows(M.iT))
}

// Amounts moved when rewriting national-accounts layouts
void _cge_map_rewrites(struct cge_model scalar M)
{
    string rowvector what, account
    real scalar k
    what = ("Exports recorded as sales by activities, moved to the paired commodities",
            "Direct taxes paid to government, routed through account _dirtax",
            "Sales taxes paid to government, routed through account _saltax",
            "Import taxes paid to government, routed through account _imptax",
            "Export taxes paid to government, routed through account _exptax",
            "Activity taxes paid to government, routed through account _acttax")
    account = ("", "_dirtax", "_saltax", "_imptax", "_exptax", "_acttax")
    if (M.rewritten[1] != 0) printf("{txt}%s: {res}%g\n", what[1], M.rewritten[1])
    if (rows(M.imargins)) {
        printf("{txt}Margins netted out of %s, moved to their output: {res}%g\n",
               invtokens(M.labels0[M.imargins]'), M.rewritten[7])
    }
    for (k = 2; k <= 6; k++) {
        if (_cge_find(M.labels, account[k])) printf("{txt}%s: {res}%g\n", what[k], M.rewritten[k])
    }
    if (rows(M.istocks)) {
        printf("{txt}Stock-change account(s) %s merged into savings-investment: {res}%g\n",
               invtokens(M.labels0[M.istocks]'), M.rewritten[10])
    }
    if (rows(M.iterritorial)) {
        printf("{txt}Territorial correction %s: purchases abroad by residents, now household payments abroad: {res}%g\n",
               M.labels0[M.iterritorial[1]], M.rewritten[8])
        printf("{txt}Territorial correction %s: purchases by non-residents, now transfers from abroad to households: {res}%g\n",
               M.labels0[M.iterritorial[1]], M.rewritten[9])
    }
    st_numscalar("r(exports_moved)", M.rewritten[1])
    st_numscalar("r(territorial_imports)", M.rewritten[8])
    st_numscalar("r(territorial_exports)", M.rewritten[9])
    st_numscalar("r(margins_moved)", M.rewritten[7])
    st_numscalar("r(stocks_merged)", M.rewritten[10])
    st_numscalar("r(taxes_rerouted)", sum(M.rewritten[(2, 3, 4, 5, 6)]))
}

// Summary of mapping problems, grouped by problem and by the roles of the
// paying and receiving accounts, largest first
void _cge_map_report(struct cge_model scalar M, real matrix issues, real colvector role,
                     string rowvector rolename)
{
    string rowvector problem
    real colvector key, ukey, ord, sel
    real matrix grp
    real scalar g, k, total, cat, rr, rc, i

    problem = ("account has flows but no role", "flow not represented", "secondary production",
               "negative flow", "account not balanced")
    total = sum(abs(M.S))
    key = issues[., 1] :* 10000 + role[issues[., 2]] :* 100 + role[issues[., 3]]
    ukey = uniqrows(key)
    grp = J(rows(ukey), 4, .)
    for (g = 1; g <= rows(ukey); g++) {
        sel = select((1::rows(issues)), key :== ukey[g])
        grp[g, .] = (ukey[g], rows(sel), sum(issues[sel, 4]), sum(abs(issues[sel, 4])))
    }
    ord = order(-grp[., 4], 1)
    grp = grp[ord, .]

    printf("{err}The SAM contains flows that version 0.1 of the model does not represent.\n")
    printf("{txt}%f problem(s) in %f group(s); values are SAM units, shares are of the sum of absolute cells.\n",
           rows(issues), rows(grp))
    printf("{txt}For an account with no role the value is its total; its flows are also listed by role.\n")
    printf("{txt}{hline 104}\n")
    printf("{txt}%-30s %-20s %-20s %6s %16s %7s\n", "Problem", "Paid by (column)", "Received by (row)", "Cells", "Value", "Share")
    printf("{txt}{hline 104}\n")
    for (g = 1; g <= rows(grp); g++) {
        cat = floor(grp[g, 1] / 10000)
        rr = floor(mod(grp[g, 1], 10000) / 100)
        rc = mod(grp[g, 1], 100)
        printf("{txt}%-30s %-20s %-20s {res}%6.0f %16.0fc %6.2f%%\n", problem[cat],
               (cat == 1 | cat == 5 ? "" : rolename[rc]), rolename[rr], grp[g, 2], grp[g, 3],
               100 * grp[g, 4] / total)
    }
    printf("{txt}{hline 104}\n")
    // Accounts named in account-level problems
    for (k = 1; k <= rows(issues); k++) {
        if (issues[k, 1] == 1) printf("{txt}  no role: {res}%s\n", M.labels[issues[k, 2]])
    }
    for (k = 1; k <= rows(issues); k++) {
        if (issues[k, 1] == 5) {
            i = issues[k, 2]
            printf("{txt}  not balanced: {res}%s{txt} (row minus column total {res}%g{txt})\n", M.labels[i], issues[k, 4])
        }
    }
    printf("{txt}Use the report() option to save every cell to a file.\n")
}

// Every problem cell, written as a CSV file
void _cge_map_save(struct cge_model scalar M, real matrix issues, real colvector role,
                   string rowvector rolename, string scalar fn, real scalar replace)
{
    string rowvector problem
    real scalar fh, k, i, j
    problem = ("account has flows but no role", "flow not represented", "secondary production",
               "negative flow", "account not balanced")
    if (fileexists(fn)) {
        if (!replace) _cge_fail("file " + fn + " already exists; specify replace", 602)
        unlink(fn)
    }
    fh = fopen(fn, "w")
    fput(fh, "problem,paid_by,paid_by_role,received_by,received_by_role,value")
    for (k = 1; k <= rows(issues); k++) {
        i = issues[k, 2]
        j = issues[k, 3]
        if (issues[k, 1] == 1 | issues[k, 1] == 5) {
            fput(fh, problem[issues[k, 1]] + ",," + "," + M.labels[i] + "," + rolename[role[i]] + "," +
                 strofreal(issues[k, 4], "%21.0g"))
        }
        else {
            fput(fh, problem[issues[k, 1]] + "," + M.labels[j] + "," + rolename[role[j]] + "," +
                 M.labels[i] + "," + rolename[role[i]] + "," + strofreal(issues[k, 4], "%21.0g"))
        }
    }
    fclose(fh)
    printf("{txt}Mapping report saved to {res}%s{txt} (%f row(s))\n", fn, rows(issues))
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
    real matrix YF, YIF, YI, EH, YG, EG, GSAV, FSAV, TINS, MPS, TINSADJ, MPSADJ
    real matrix IADJ, GADJ, WFDIST, WALRAS, QT, QER
    real matrix qf, rho, cessum, q3, wage, pvaqva, lhs, rhs
    real colvector oneA, oneC, oneF, oneH, oneD, DY, rs
    real scalar k, nH, nD

    PA = _cge_v(M, x, 1);     PVA = _cge_v(M, x, 2);    PINTA = _cge_v(M, x, 3)
    PX = _cge_v(M, x, 4);     PD = _cge_v(M, x, 5);     PE = _cge_v(M, x, 6)
    PM = _cge_v(M, x, 7);     PQ = _cge_v(M, x, 8);     W = _cge_v(M, x, 9)
    EXR = _cge_v(M, x, 10);   CPI = _cge_v(M, x, 11);   DPI = _cge_v(M, x, 12)
    QA = _cge_v(M, x, 13);    QVA = _cge_v(M, x, 14);   QINTA = _cge_v(M, x, 15)
    QF = _cge_v(M, x, 16);    QINT = _cge_v(M, x, 17);  QX = _cge_v(M, x, 18)
    QD = _cge_v(M, x, 19);    QE = _cge_v(M, x, 20);    QM = _cge_v(M, x, 21)
    QQ = _cge_v(M, x, 22);    QH = _cge_v(M, x, 23);    QG = _cge_v(M, x, 24)
    QINV = _cge_v(M, x, 25);  QFS = _cge_v(M, x, 26);   YF = _cge_v(M, x, 27)
    YIF = _cge_v(M, x, 28);   YI = _cge_v(M, x, 29);    EH = _cge_v(M, x, 30)
    YG = _cge_v(M, x, 31);    EG = _cge_v(M, x, 32);    GSAV = _cge_v(M, x, 33)
    FSAV = _cge_v(M, x, 34);  TINS = _cge_v(M, x, 35);  MPS = _cge_v(M, x, 36)
    TINSADJ = _cge_v(M, x, 37); MPSADJ = _cge_v(M, x, 38); IADJ = _cge_v(M, x, 39)
    GADJ = _cge_v(M, x, 40);  WFDIST = _cge_v(M, x, 41); WALRAS = _cge_v(M, x, 42)
    QT = _cge_v(M, x, 43);    QER = _cge_v(M, x, 44)

    L = J(0, 1, .)
    R = J(0, 1, .)
    K = J(0, 1, .)
    if (record) {
        M.ename = J(0, 1, "")
        M.elen = J(0, 1, .)
    }
    oneA = J(M.n, 1, 1)
    oneC = J(M.nC, 1, 1)
    oneF = J(M.nF, 1, 1)
    oneH = J(M.nH, 1, 1)
    oneD = J(M.nD, 1, 1)
    nH = M.nH
    nD = M.nD

    // 5.1 Price block
    _cge_put(M, L, R, K, record, "P1", PM, p.pwm :* (1 :+ p.tm) :* EXR, M.cm)
    _cge_put(M, L, R, K, record, "P2", PE, p.pwe :* (1 :- p.te) :* EXR, M.ce)
    // p.icm' * PQ: cost of margin services per unit of composite supply
    _cge_put(M, L, R, K, record, "P3", PQ :* (1 :- p.tq) :* QQ,
             M.cx :* PD :* QD + M.cm :* PM :* QM + (p.icm' * PQ) :* QQ, oneC)
    _cge_put(M, L, R, K, record, "P4", PX :* QX, PD :* QD + M.ce :* PE :* QE, M.cx)
    _cge_put(M, L, R, K, record, "P5", PA, p.theta * PX, oneA)
    _cge_put(M, L, R, K, record, "P6", PINTA, p.ica' * PQ, oneA)
    _cge_put(M, L, R, K, record, "P7", PA :* (1 :- p.ta) :* QA, PVA :* QVA + PINTA :* QINTA, oneA)
    _cge_put(M, L, R, K, record, "P8", CPI, p.cwts' * PQ, 1)
    _cge_put(M, L, R, K, record, "P9", DPI, p.dwts' * PD, 1)

    // 5.2 Production block
    _cge_put(M, L, R, K, record, "Q1", QVA, p.iva :* QA, M.lt)
    _cge_put(M, L, R, K, record, "Q2", QINTA, p.inta :* QA, M.lt)
    // CES or Cobb-Douglas top nest. Mata gives 0 * missing = missing, so the CES
    // branch uses an exponent of 1 where rho is 0 (Leontief and Cobb-Douglas rows)
    rs = p.rha + (p.rha :== 0)
    _cge_put(M, L, R, K, record, "Q1C", QA,
             M.cda :* (p.aa :* (QVA :^ p.dla) :* (QINTA :^ p.dlac)) +
             (1 :- M.cda) :* (p.aa :* (p.dla :* (QVA :^ (-rs)) + p.dlac :* (QINTA :^ (-rs))) :^ (-1 :/ rs)),
             1 :- M.lt)
    _cge_put(M, L, R, K, record, "Q2C",
             M.cda :* (PVA :* QVA :* p.dlac) + (1 :- M.cda) :* QVA,
             M.cda :* (PINTA :* QINTA :* p.dla) +
             (1 :- M.cda) :* (QINTA :* (((PINTA :/ PVA) :* p.dla :/ p.dlac) :^ (1 :/ (1 :+ p.rha)))),
             1 :- M.lt)
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
    // Intermediate inputs and household purchases exist only where the SAM has a flow
    _cge_put(M, L, R, K, record, "Q5", QINT, p.ica :* QINTA', p.ica :!= 0)
    _cge_put(M, L, R, K, record, "Q6", QX, p.theta' * QA, M.cx)

    // 5.3 Trade block
    _cge_put(M, L, R, K, record, "T1", QX,
             p.at :* (p.dt :* (QE :^ p.rt) + p.dtc :* (QD :^ p.rt)) :^ (1 :/ p.rt), M.ce)
    _cge_put(M, L, R, K, record, "T2", QE,
             QD :* (((PE :/ PD) :* p.dtc :/ p.dt) :^ (1 :/ (p.rt :- 1))), M.ce)
    _cge_put(M, L, R, K, record, "T3", QX, QD, M.cx :* (1 :- M.ce))
    _cge_put(M, L, R, K, record, "T4", QQ,
             p.aq :* (p.dq :* (QM :^ (-p.rq)) + p.dqc :* (QD :^ (-p.rq))) :^ (-1 :/ p.rq), M.cm :* M.cx)
    _cge_put(M, L, R, K, record, "T5", QM,
             QD :* (((PD :/ PM) :* p.dq :/ p.dqc) :^ (1 :/ (1 :+ p.rq))), M.cm :* M.cx)
    _cge_put(M, L, R, K, record, "T6", QQ, p.aq :* QD, M.cx :* (1 :- M.cm))
    _cge_put(M, L, R, K, record, "T7", QQ, p.aq :* QM, M.cm :* (1 :- M.cx))
    _cge_put(M, L, R, K, record, "T8", QT, p.icm * QQ, M.ct)
    _cge_put(M, L, R, K, record, "T9", QER, p.qer :* ((PQ :/ (EXR :* p.pwe)) :^ (-p.st)), M.cr)

    // 5.4 Institution block. DY is income after direct taxes and savings.
    DY = (1 :- MPS) :* (1 :- TINS) :* YI
    _cge_put(M, L, R, K, record, "I1", YF, rowsum(wage :* QF) + p.trfr :* EXR, oneF)
    _cge_put(M, L, R, K, record, "I2", YIF, p.shif :* YF', J(M.nI, M.nF, 1))
    _cge_put(M, L, R, K, record, "I3", YI,
             rowsum(YIF[|1, 1 \ nD, M.nF|]) + p.shii * DY + p.trdg :* CPI + p.trdr :* EXR, oneD)
    _cge_put(M, L, R, K, record, "I4", EH, p.hc :* DY[|1 \ nH|], oneH)
    _cge_put(M, L, R, K, record, "I5", PQ :* QH, PQ :* p.gamma + p.beta :* (EH' - PQ' * p.gamma),
             p.beta :!= 0)
    _cge_put(M, L, R, K, record, "I6", QINV, p.qinv :* IADJ, oneC)
    _cge_put(M, L, R, K, record, "I7", QG, p.qg :* GADJ, oneC)
    _cge_put(M, L, R, K, record, "I8", YG,
             TINS' * YI + sum(p.tq :* PQ :* QQ) + sum(p.tm :* p.pwm :* QM) * EXR
             + sum(p.te :* p.pwe :* QE) * EXR + sum(p.ta :* PA :* QA)
             + sum(YIF[nD + 1, .]) + p.trgr * EXR + p.trgg * CPI, 1)
    _cge_put(M, L, R, K, record, "I9", EG,
             PQ' * QG + (sum(p.trdg) + p.trgg) * CPI + p.trrg * EXR, 1)
    _cge_put(M, L, R, K, record, "I10", TINS, p.tins0 :* TINSADJ, oneD)
    _cge_put(M, L, R, K, record, "I11", MPS, p.mps0 :* MPSADJ, oneD)

    // 5.5 System constraints (S6 is imposed through the closure)
    _cge_put(M, L, R, K, record, "S1", rowsum(M.fa :* QF), QFS, oneF)
    _cge_put(M, L, R, K, record, "S2", QQ,
             rowsum(QINT) + rowsum(QH) + QG + QINV + M.ct :* QT + M.cr :* QER, oneC)
    _cge_put(M, L, R, K, record, "S3",
             sum(p.pwm :* QM) + (sum(YIF[nD + 2, .]) + p.shir' * DY) / EXR + p.trrg,
             sum(p.pwe :* QE) + sum(M.cr :* PQ :* QER) / EXR + sum(p.trdr) + sum(p.trfr) + p.trgr + FSAV, 1)
    _cge_put(M, L, R, K, record, "S4", YG, EG + GSAV, 1)
    _cge_put(M, L, R, K, record, "S5", (MPS :* (1 :- TINS))' * YI + GSAV + EXR * FSAV,
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

void _cge_calibrate(string scalar s_va, string scalar s_q, string scalar s_t, string scalar fqname,
                    string scalar s_ie, string scalar s_fr, string scalar s_a)
{
    struct cge_model scalar M
    struct cge_par scalar p
    real matrix S, VA, QINT0, QF0, QFq, WFD0, dva, YIF0, QH0, w, TR, MAKE0, MG, SV
    real colvector sva, sq, st, QM0, cm, tariffs, tm, exports, ce, etax, te, QE0, pwe
    real colvector cx, ct, MGc, QT0, exported, cr, QER0
    real rowvector spend
    real colvector QA0, ta, QX0, QD0, PM0, stax, QQ0, tq, demand, QINTA0, W0, QVA0
    real colvector cd, rva, ad, rt, dt, dtc, at, rq, dq, dqc, aq, YF0, YI0, tins0, mps0, EH0
    real colvector iD, dtax, dsav, DY0, TROW, cons, gross, safe
    real colvector m, d, num, x0, L, R, K, mag
    real scalar n, nC, nF, nH, tol, k, r, ratio, total, maxres

    M = _cge_load()
    _cge_need(M, "mapped")
    S = M.S
    n = M.n
    nC = M.nC
    nF = M.nF
    nH = M.nH
    tol = 1e-9 * max((1, max(abs(S))))

    sva = _cge_elast(s_va, n, "sigmava")
    sq = _cge_elast(s_q, nC, "sigmaq")
    st = _cge_elast(s_t, nC, "sigmat")

    // 7.2 Taxes and trade
    QM0 = _cge_sub(S, M.irow, M.iC)'
    cm = QM0 :> tol
    tariffs = _cge_sub(S, M.iimptax, M.iC)'
    _cge_fail_if((1 :- cm) :* (abs(tariffs) :> tol), M.labels[M.iC], "import tariff recorded on a commodity without imports", 459)
    tm = cm :* tariffs :/ (cm :* QM0 + (1 :- cm))
    exports = _cge_sub(S, M.iC, M.irow)
    exported = exports :> tol
    etax = _cge_sub(S, M.iexptax, M.iC)'
    _cge_fail_if((1 :- exported) :* (abs(etax) :> tol), M.labels[M.iC], "export tax recorded on a commodity without exports", 459)

    QA0 = colsum(S[., M.iA])'
    _cge_fail_if(QA0 :<= tol, M.labels[M.iA], "every activity needs positive output", 459)
    ta = _cge_sub(S, M.iacttax, M.iA)' :/ QA0
    MAKE0 = _cge_sub(S, M.iA, M.iC)                 // MAKE0[a, c]: output of c by a
    if (max(abs(rowsum(MAKE0) - QA0)) > tol) _cge_fail("activity output does not equal its sales to commodities", 459)
    p.theta = MAKE0 :/ QA0
    QX0 = colsum(MAKE0)'
    cx = QX0 :> tol
    _cge_fail_if((1 :- cx) :* (1 :- cm), M.labels[M.iC], "a commodity has neither domestic output nor imports", 459)
    // Exports at least as large as domestic output are drawn from composite
    // supply (CR, T9); other exports come from domestic output (CE, T1-T2)
    cr = exported :* ((QX0 - (exports - etax)) :<= tol)
    _cge_fail_if(cr :* (abs(etax) :> tol), M.labels[M.iC],
                 "export tax recorded on a commodity whose exports are at least its domestic output", 459)
    ce = exported :* (1 :- cr)
    te = ce :* etax :/ (ce :* exports + (1 :- ce))
    QE0 = ce :* (exports - etax)
    QER0 = cr :* exports
    pwe = 1 :/ (1 :- te)
    QD0 = cx :* (QX0 - QE0)
    _cge_fail_if(cx :* (QD0 :<= tol), M.labels[M.iC], "a commodity with domestic output needs positive domestic sales", 459)
    PM0 = cm :* (1 :+ tm)
    stax = _cge_sub(S, M.isaltax, M.iC)'
    // Margins: MG[t, c] paid by commodity c to margin account t, SV[c, t]
    // margin services c bought by t
    if (rows(M.iT)) {
        MG = _cge_sub(S, M.iT, M.iC)
        SV = _cge_sub(S, M.iC, M.iT)
        MGc = colsum(MG)'
        QT0 = rowsum(SV)
        spend = colsum(SV)
    }
    else {
        MG = J(0, nC, 0)
        SV = J(nC, 0, 0)
        MGc = J(nC, 1, 0)
        QT0 = J(nC, 1, 0)
        spend = J(1, 0, 0)
    }
    QQ0 = QD0 + PM0 :* QM0 + stax + MGc
    tq = stax :/ QQ0
    ct = QT0 :> tol
    if (rows(M.iT)) p.icm = ((SV :/ (spend :* (spend :> tol) + (spend :<= tol))) * MG) :/ QQ0'
    else p.icm = J(nC, nC, 0)
    demand = rowsum(_cge_sub(S, M.iC, M.iA)) + rowsum(_cge_sub(S, M.iC, M.iH)) +
             _cge_sub(S, M.iC, M.igov) + _cge_sub(S, M.iC, M.isav) + QT0 + QER0
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
    _cge_fail_if(QVA0 :<= tol, M.labels[M.iA], "every activity needs positive value added", 459)
    p.iva = QVA0 :/ QA0
    p.inta = QINTA0 :/ QA0
    _cge_topnest(M, p, s_a, QA0, QVA0, QINTA0, colsum(p.ica)')

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
    // 1 - delta is stored (dtc, dqc) rather than computed by subtraction, which
    // loses most significant digits when a share is close to one
    dt = J(nC, 1, 0.5)
    dtc = J(nC, 1, 0.5)
    at = J(nC, 1, 1)
    for (k = 1; k <= nC; k++) {
        if (!ce[k]) continue
        r = rt[k]
        ratio = (QE0[k] / QD0[k])^(r - 1)
        dt[k] = 1 / (1 + ratio)
        dtc[k] = ratio / (1 + ratio)
        at[k] = QX0[k] / (dt[k] * QE0[k]^r + dtc[k] * QD0[k]^r)^(1 / r)
    }
    if (max(cm :* cx :* (abs(sq :- 1) :< 1e-12))) _cge_fail("version 0.1 needs sigmaq different from 1 for imported commodities", 198)
    rq = 1 :/ sq :- 1
    dq = J(nC, 1, 0.5)
    dqc = J(nC, 1, 0.5)
    // non-imported commodities (T6) and commodities imported only (T7)
    aq = cx :* (QQ0 :/ (QD0 + (1 :- cx))) + (1 :- cx) :* (QQ0 :/ (QM0 + (1 :- cm)))
    for (k = 1; k <= nC; k++) {
        if (!cm[k] | !cx[k]) continue
        r = rq[k]
        ratio = PM0[k] * (QM0[k] / QD0[k])^(1 + r)
        dq[k] = ratio / (1 + ratio)
        dqc[k] = 1 / (1 + ratio)
        aq[k] = QQ0[k] / (dq[k] * QM0[k]^(-r) + dqc[k] * QD0[k]^(-r))^(-1 / r)
    }

    // 7.5 Institutions (D = households, then enterprises)
    iD = M.iH \ M.iE
    YF0 = rowsum(S[M.iF, .])
    YIF0 = _cge_sub(S, iD \ M.igov \ M.irow, M.iF)
    if (max(abs(colsum(YIF0)' - YF0)) > tol) _cge_fail("factor income paid out does not equal factor income received", 459)
    p.shif = YIF0 :/ YF0'
    p.trfr = _cge_sub(S, M.iF, M.irow)
    YI0 = rowsum(S[iD, .])
    dtax = _cge_sub(S, M.idirtax, iD)'
    dsav = _cge_sub(S, M.isav, iD)'
    tins0 = dtax :/ YI0
    mps0 = dsav :/ ((1 :- tins0) :* YI0)
    DY0 = YI0 - dtax - dsav
    TR = _cge_sub(S, iD, iD)
    TROW = _cge_sub(S, M.irow, iD)'
    QH0 = _cge_sub(S, M.iC, M.iH)
    EH0 = colsum(QH0)'
    cons = EH0 \ J(M.nE, 1, 0)
    gross = colsum(abs(TR))' + abs(TROW) + abs(cons)
    if (max((abs(DY0) :<= tol) :* (gross :> tol))) {
        _cge_fail("an institution makes transfers or consumes but has no income after direct taxes and savings", 459)
    }
    if (max(abs(colsum(TR)' + TROW + cons - DY0)) > tol) _cge_fail("institution payments do not equal income", 459)
    safe = DY0 :* (abs(DY0) :> tol) + (abs(DY0) :<= tol)
    p.shii = TR :/ safe'
    p.shir = TROW :/ safe
    p.hc = EH0 :/ safe[|1 \ nH|]
    if (sum(EH0) <= tol) _cge_fail("households have no consumption", 459)
    p.beta = QH0 :/ (EH0' :* (EH0' :> 0) + (EH0' :<= 0))
    // Household demand: Cobb-Douglas (gamma = 0), or LES given income
    // elasticities and Frisch parameters (model_spec.md, 7.5)
    p.gamma = J(rows(QH0), cols(QH0), 0)
    if (s_ie != "" | s_fr != "") _cge_les(p, QH0, EH0, s_ie, s_fr, M.nC, nH)
    p.trdg = _cge_sub(S, iD, M.igov)
    p.trdr = _cge_sub(S, iD, M.irow)
    p.trgr = S[M.igov, M.irow]
    p.trrg = S[M.irow, M.igov]
    p.trgg = S[M.igov, M.igov]
    p.qg = _cge_sub(S, M.iC, M.igov)
    p.qinv = _cge_sub(S, M.iC, M.isav)
    p.cwts = rowsum(QH0) :/ sum(QH0)
    p.dwts = QD0 :/ sum(QD0)

    p.pwm = J(nC, 1, 1)
    p.qer = QER0
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
    p.dtc = dtc
    p.rt = rt
    p.aq = aq
    p.dq = dq
    p.dqc = dqc
    p.rq = rq
    p.sq = sq
    p.st = st
    p.tins0 = tins0
    p.mps0 = mps0
    M.ce = ce
    M.cm = cm
    M.cd = cd
    M.cx = cx
    M.ct = ct
    M.cr = cr
    M.p0 = p
    M.p = p

    // Base values of all variables
    _cge_layout(M)
    k = rows(M.voff)
    total = M.voff[k] + M.vrows[k] * M.vcols[k]
    x0 = J(total, 1, 0)
    _cge_setv(M, x0, "PA", J(n, 1, 1))
    _cge_setv(M, x0, "PVA", J(n, 1, 1))
    _cge_setv(M, x0, "PINTA", colsum(p.ica)')
    _cge_setv(M, x0, "PX", J(nC, 1, 1))
    _cge_setv(M, x0, "PD", J(nC, 1, 1))
    _cge_setv(M, x0, "PE", ce)
    _cge_setv(M, x0, "PM", PM0)
    _cge_setv(M, x0, "PQ", J(nC, 1, 1))
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
    _cge_setv(M, x0, "YI", YI0)
    _cge_setv(M, x0, "EH", EH0)
    _cge_setv(M, x0, "YG", sum(S[M.igov, .]))
    _cge_setv(M, x0, "EG", sum(p.qg) + sum(p.trdg) + p.trgg + p.trrg)
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
    _cge_setv(M, x0, "QT", QT0)
    _cge_setv(M, x0, "QER", QER0)
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
    _cge_setv(M, M.exists, "PX", cx)
    _cge_setv(M, M.exists, "PD", cx)
    _cge_setv(M, M.exists, "QX", cx)
    _cge_setv(M, M.exists, "QD", cx)
    _cge_setv(M, M.exists, "QT", ct)
    _cge_setv(M, M.exists, "QER", cr)
    _cge_setv(M, M.exists, "QINT", QINT0 :!= 0)
    _cge_setv(M, M.exists, "QH", QH0 :!= 0)

    M.nominal = J(total, 1, 0)
    for (k = 1; k <= rows(M.vname); k++) {
        if (anyof(("PA","PVA","PINTA","PX","PD","PE","PM","PQ","W","EXR","CPI","DPI",
                   "YF","YIF","YI","EH","YG","EG","GSAV","WALRAS"), M.vname[k])) {
            M.nominal[_cge_vpos(M, k)] = J(M.vrows[k] * M.vcols[k], 1, 1)
        }
    }
    M.positive = J(0, 1, .)
    for (k = 1; k <= rows(M.vname); k++) {
        if (anyof(("PA","PVA","PINTA","PX","PD","PE","PM","PQ","W","EXR","CPI","DPI",
                   "QA","QVA","QINTA","QF","QX","QD","QE","QM","QQ","QT","QER"), M.vname[k])) {
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

    _cge_pattern(M, p)
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
    if (sum(cr)) {
        printf("{txt}Exports drawn from composite supply (equation T9): {res}%s\n",
               invtokens(select(M.C, cr)'))
    }
    st_numscalar("r(N_equations)", M.neq)
    st_numscalar("r(max_residual)", maxres)
}

// Top nest of production (model_spec.md, 5.2 and 7.3): Leontief (sigmaa 0, the
// default), Cobb-Douglas (1) or CES between value added and intermediates.
// Base prices: PVA = 1 and PINTA = sum of the intermediate shares.
void _cge_topnest(struct cge_model scalar M, struct cge_par scalar p, string scalar s_a, real colvector QA0,
                  real colvector QVA0, real colvector QINTA0, real colvector PINTA0)
{
    real colvector sa, lt, cda, rho, qi, pi, ratio, value
    real scalar n
    n = rows(QA0)
    sa = (s_a == "" ? J(n, 1, 0) : strtoreal(tokens(s_a))')
    if (rows(sa) == 1) sa = J(n, 1, sa)
    if (rows(sa) != n) {
        errprintf("sigmaa() needs 1 or %f values\n", n)
        exit(198)
    }
    if (hasmissing(sa) | min(sa) < 0) _cge_fail("sigmaa() values must be zero (Leontief) or positive", 198)
    lt = (sa :== 0) :| (QINTA0 :<= 0)
    if (max((sa :> 0) :* (QINTA0 :<= 0))) {
        printf("{txt}Note: activities without intermediate inputs keep a Leontief top nest: {res}%s\n",
               invtokens(select(M.A, (sa :> 0) :* (QINTA0 :<= 0))'))
    }
    cda = (1 :- lt) :* (abs(sa :- 1) :< 1e-12)
    rho = (1 :- lt) :* (1 :- cda) :* (1 :/ (sa + (sa :== 0)) :- 1)
    qi = lt :+ (1 :- lt) :* QINTA0
    pi = lt :+ (1 :- lt) :* PINTA0
    ratio = (1 :/ pi) :* ((QVA0 :/ qi) :^ (1 :+ rho))
    p.dla = ratio :/ (1 :+ ratio)
    p.dlac = 1 :/ (1 :+ ratio)
    value = QVA0 + pi :* qi
    p.dla = cda :* (QVA0 :/ value) + (1 :- cda) :* p.dla
    p.dlac = cda :* (pi :* qi :/ value) + (1 :- cda) :* p.dlac
    p.aa = J(n, 1, 1)
    p.aa = lt :+ cda :* (QA0 :/ ((QVA0 :^ p.dla) :* (qi :^ p.dlac))) +
           (1 :- lt) :* (1 :- cda) :* (QA0 :/ ((p.dla :* (QVA0 :^ (-rho)) + p.dlac :* (qi :^ (-rho))) :^
           (-1 :/ (rho + (rho :== 0)))))
    p.rha = rho
    p.sa = sa
    M.lt = lt
    M.cda = cda
}

void _cge_les(struct cge_par scalar p, real matrix QH0, real colvector EH0, string scalar s_ie,
              string scalar s_fr, real scalar nC, real scalar nH)
{
    real colvector ie, fr
    real rowvector total
    real matrix b
    if (s_fr == "") _cge_fail("incelas() needs frisch(): LES demand needs Frisch parameters", 198)
    ie = (s_ie == "" ? J(nC, 1, 1) : _cge_elast(s_ie, nC, "incelas"))
    fr = strtoreal(tokens(s_fr))'
    if (rows(fr) == 1) fr = J(nH, 1, fr)
    if (rows(fr) != nH) {
        errprintf("frisch() needs 1 or %f values\n", nH)
        exit(198)
    }
    if (hasmissing(fr) | max(fr) >= -1) {
        _cge_fail("frisch() values must be below -1, so that subsistence spending is positive", 198)
    }
    if (min(QH0) < 0) _cge_fail("LES demand needs non-negative household consumption", 459)
    b = ie :* p.beta
    total = colsum(b)
    p.beta = b :/ (total + (total :<= 0))
    p.gamma = QH0 + p.beta :* (EH0' :/ fr')
    printf("{txt}Household demand: linear expenditure system\n")
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
    if (name == "tm")   return(p.tm)
    if (name == "te")   return(p.te)
    if (name == "tq")   return(p.tq)
    if (name == "ta")   return(p.ta)
    if (name == "pwm")  return(p.pwm)
    if (name == "pwe")  return(p.pwe)
    if (name == "ad")   return(p.ad)
    if (name == "qg")   return(p.qg)
    if (name == "qinv") return(p.qinv)
    if (name == "trdg") return(p.trdg)
    if (name == "trdr") return(p.trdr)
    if (name == "trfr") return(p.trfr)
    if (name == "trgr") return(p.trgr)
    if (name == "trrg") return(p.trrg)
    _cge_fail("cge internal error: unknown parameter " + name, 3498)
}

void _cge_par_set(struct cge_par scalar p, string scalar name, real colvector v)
{
    if (name == "tm")        p.tm = v
    else if (name == "te")   p.te = v
    else if (name == "tq")   p.tq = v
    else if (name == "ta")   p.ta = v
    else if (name == "pwm")  p.pwm = v
    else if (name == "pwe")  p.pwe = v
    else if (name == "ad")   p.ad = v
    else if (name == "qg")   p.qg = v
    else if (name == "qinv") p.qinv = v
    else if (name == "trdg") p.trdg = v
    else if (name == "trdr") p.trdr = v
    else if (name == "trfr") p.trfr = v
    else if (name == "trgr") p.trgr = v
    else if (name == "trrg") p.trrg = v
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

    if (anyof(("tm", "te", "tq", "pwm", "pwe", "qg", "qinv"), target)) {
        idx = _cge_elements(M.C, elems, "commodities")
    }
    else if (anyof(("ta", "ad"), target)) {
        idx = _cge_elements(M.A, elems, "activities")
    }
    else if (anyof(("trdg", "trdr"), target)) {
        idx = _cge_elements(M.D, elems, "households and enterprises")
    }
    else if (target == "trfr") {
        idx = _cge_elements(M.F, elems, "factors")
    }
    else if (anyof(("trgr", "trrg"), target)) {
        if (elems != "" & elems != "all") _cge_fail(target + " has no elements", 198)
        idx = 1
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
        _cge_fail(target + " is not a shockable parameter (tm te tq ta pwm pwe ad qg qinv trdg trdr trfr trgr trrg) or model variable", 198)
    }
    set = M.vset[k]
    if (set == "") {
        if (elems != "" & elems != "all") _cge_fail(target + " has no elements", 198)
        pos = _cge_vpos(M, k)
    }
    else if (strlen(set) == 1) {
        idx = _cge_elements((set == "A" ? M.A : (set == "C" ? M.C : (set == "F" ? M.F :
              (set == "D" ? M.D : M.H)))), elems, "elements")
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

// Jacobian (Section 4 of docs/design.md). Rows of equations that involve
// many variables -- the price indexes, factor incomes and supplies, government
// revenue and spending, the balance of payments and the savings-investment
// balance -- have exact derivatives (_cge_dense). The other rows are found by
// central differences over groups of columns that share no such row; their
// sparsity pattern follows from the equations (_cge_pattern).
string rowvector _cge_denseblocks()
{
    return(("P8", "P9", "I1", "I8", "I9", "S1", "S3", "S5"))
}

real colvector _cge_vcols(struct cge_model scalar M, string scalar name)
{
    real scalar k
    k = _cge_vidx(M, name)
    return(M.voff[k] :+ (1::M.vrows[k] * M.vcols[k]))
}

// Row and column indices (row-major) of the non-zero entries of X
void _cge_nz(real matrix X, real colvector i, real colvector j)
{
    real colvector k
    k = select((1::rows(X) * cols(X)), colshape(X, 1) :!= 0)
    if (rows(k) == 0) {
        i = J(0, 1, .)
        j = J(0, 1, .)
        return
    }
    i = floor((k :- 1) :/ cols(X)) :+ 1
    j = mod(k :- 1, cols(X)) :+ 1
}

// Pattern entries: element e of equation block blk depends on element j of variable var
void _cge_sp(struct cge_model scalar M, real colvector rowid, real colvector boff, real colvector pr,
             real colvector pc, string scalar blk, real colvector e, string scalar var, real colvector j)
{
    real scalar k
    if (rows(e) == 0) return
    k = _cge_find(M.ename, blk)
    pr = pr \ rowid[boff[k] :+ e]
    pc = pc \ (M.voff[_cge_vidx(M, var)] :+ (rows(j) == 1 ? J(rows(e), 1, j) : j))
}

// Each element of block blk depends on the same element of every variable in vars
void _cge_sp_same(struct cge_model scalar M, real colvector rowid, real colvector boff, real colvector pr,
                  real colvector pc, string scalar blk, string rowvector vars)
{
    real colvector e
    real scalar v
    e = (1::M.elen[_cge_find(M.ename, blk)])
    for (v = 1; v <= cols(vars); v++) _cge_sp(M, rowid, boff, pr, pc, blk, e, vars[v], e)
}

void _cge_pattern(struct cge_model scalar M, struct cge_par scalar p)
{
    real colvector rowid, boff, pr, pc, cA, cC, cD, e, i, j, keep
    real matrix P
    real scalar nA, nC, nF, nH, nD, nI, f, g, k
    string rowvector dense

    rowid = runningsum(M.emask) :* M.emask
    boff = runningsum(M.elen) - M.elen
    nA = M.n
    nC = M.nC
    nF = M.nF
    nH = M.nH
    nD = M.nD
    nI = M.nI
    cA = (1::nA)
    cC = (1::nC)
    cD = (1::nD)
    pr = J(0, 1, .)
    pc = J(0, 1, .)

    // 5.1 Price block
    _cge_sp_same(M, rowid, boff, pr, pc, "P1", "PM")
    _cge_sp(M, rowid, boff, pr, pc, "P1", cC, "EXR", 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "P2", "PE")
    _cge_sp(M, rowid, boff, pr, pc, "P2", cC, "EXR", 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "P3", ("PQ", "QQ", "PD", "QD", "PM", "QM"))
    _cge_nz(p.icm, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "P3", j, "PQ", i)
    _cge_sp_same(M, rowid, boff, pr, pc, "P4", ("PX", "QX", "PD", "QD", "PE", "QE"))
    _cge_sp_same(M, rowid, boff, pr, pc, "P5", "PA")
    _cge_nz(p.theta, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "P5", i, "PX", j)
    _cge_sp_same(M, rowid, boff, pr, pc, "P6", "PINTA")
    _cge_nz(p.ica, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "P6", j, "PQ", i)
    _cge_sp_same(M, rowid, boff, pr, pc, "P7", ("PA", "QA", "PVA", "QVA", "PINTA", "QINTA"))

    // 5.2 Production block
    _cge_sp_same(M, rowid, boff, pr, pc, "Q1", ("QVA", "QA"))
    _cge_sp_same(M, rowid, boff, pr, pc, "Q2", ("QINTA", "QA"))
    _cge_sp_same(M, rowid, boff, pr, pc, "Q1C", ("QA", "QVA", "QINTA"))
    _cge_sp_same(M, rowid, boff, pr, pc, "Q2C", ("QVA", "QINTA", "PVA", "PINTA"))
    _cge_sp_same(M, rowid, boff, pr, pc, "Q3", "QVA")
    _cge_nz(M.fa, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "Q3", j, "QF", (i :- 1) :* nA :+ j)
    _cge_sp_same(M, rowid, boff, pr, pc, "Q4", ("WFDIST", "QF"))
    for (f = 1; f <= nF; f++) {
        e = (f - 1) * nA :+ cA
        _cge_sp(M, rowid, boff, pr, pc, "Q4", e, "W", f)
        _cge_sp(M, rowid, boff, pr, pc, "Q4", e, "PVA", cA)
        _cge_sp(M, rowid, boff, pr, pc, "Q4", e, "QVA", cA)
        for (g = 1; g <= nF; g++) _cge_sp(M, rowid, boff, pr, pc, "Q4", e, "QF", (g - 1) * nA :+ cA)
    }
    e = (1::nC * nA)
    _cge_sp(M, rowid, boff, pr, pc, "Q5", e, "QINT", e)
    _cge_sp(M, rowid, boff, pr, pc, "Q5", e, "QINTA", mod(e :- 1, nA) :+ 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "Q6", "QX")
    _cge_nz(p.theta, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "Q6", j, "QA", i)

    // 5.3 Trade block
    _cge_sp_same(M, rowid, boff, pr, pc, "T1", ("QX", "QE", "QD"))
    _cge_sp_same(M, rowid, boff, pr, pc, "T2", ("QE", "QD", "PE", "PD"))
    _cge_sp_same(M, rowid, boff, pr, pc, "T3", ("QX", "QD"))
    _cge_sp_same(M, rowid, boff, pr, pc, "T4", ("QQ", "QM", "QD"))
    _cge_sp_same(M, rowid, boff, pr, pc, "T5", ("QM", "QD", "PD", "PM"))
    _cge_sp_same(M, rowid, boff, pr, pc, "T6", ("QQ", "QD"))
    _cge_sp_same(M, rowid, boff, pr, pc, "T7", ("QQ", "QM"))
    _cge_sp_same(M, rowid, boff, pr, pc, "T8", "QT")
    _cge_nz(p.icm, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "T8", i, "QQ", j)
    _cge_sp_same(M, rowid, boff, pr, pc, "T9", ("QER", "PQ"))
    _cge_sp(M, rowid, boff, pr, pc, "T9", cC, "EXR", 1)

    // 5.4 Institution block
    e = (1::nI * nF)
    _cge_sp(M, rowid, boff, pr, pc, "I2", e, "YIF", e)
    _cge_sp(M, rowid, boff, pr, pc, "I2", e, "YF", mod(e :- 1, nF) :+ 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "I3", "YI")
    for (f = 1; f <= nF; f++) _cge_sp(M, rowid, boff, pr, pc, "I3", cD, "YIF", (cD :- 1) :* nF :+ f)
    for (k = 1; k <= nD; k++) {
        _cge_sp(M, rowid, boff, pr, pc, "I3", cD, "YI", k)
        _cge_sp(M, rowid, boff, pr, pc, "I3", cD, "MPS", k)
        _cge_sp(M, rowid, boff, pr, pc, "I3", cD, "TINS", k)
    }
    _cge_sp(M, rowid, boff, pr, pc, "I3", cD, "CPI", 1)
    _cge_sp(M, rowid, boff, pr, pc, "I3", cD, "EXR", 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "I4", "EH")
    _cge_sp(M, rowid, boff, pr, pc, "I4", (1::nH), "MPS", (1::nH))
    _cge_sp(M, rowid, boff, pr, pc, "I4", (1::nH), "TINS", (1::nH))
    _cge_sp(M, rowid, boff, pr, pc, "I4", (1::nH), "YI", (1::nH))
    e = (1::nC * nH)
    _cge_sp(M, rowid, boff, pr, pc, "I5", e, "QH", e)
    _cge_sp(M, rowid, boff, pr, pc, "I5", e, "PQ", floor((e :- 1) :/ nH) :+ 1)
    _cge_sp(M, rowid, boff, pr, pc, "I5", e, "EH", mod(e :- 1, nH) :+ 1)
    // LES: every purchase of household h depends on the prices of its subsistence quantities
    for (k = 1; k <= nH; k++) {
        i = select(cC, p.gamma[., k] :!= 0)
        for (g = 1; g <= rows(i); g++) _cge_sp(M, rowid, boff, pr, pc, "I5", (cC :- 1) :* nH :+ k, "PQ", i[g])
    }
    _cge_sp_same(M, rowid, boff, pr, pc, "I6", "QINV")
    _cge_sp(M, rowid, boff, pr, pc, "I6", cC, "IADJ", 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "I7", "QG")
    _cge_sp(M, rowid, boff, pr, pc, "I7", cC, "GADJ", 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "I10", "TINS")
    _cge_sp(M, rowid, boff, pr, pc, "I10", cD, "TINSADJ", 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "I11", "MPS")
    _cge_sp(M, rowid, boff, pr, pc, "I11", cD, "MPSADJ", 1)

    // 5.5 System constraints
    _cge_sp_same(M, rowid, boff, pr, pc, "S2", ("QQ", "QG", "QINV", "QT", "QER"))
    for (k = 1; k <= nA; k++) _cge_sp(M, rowid, boff, pr, pc, "S2", cC, "QINT", (cC :- 1) :* nA :+ k)
    for (k = 1; k <= nH; k++) _cge_sp(M, rowid, boff, pr, pc, "S2", cC, "QH", (cC :- 1) :* nH :+ k)
    _cge_sp(M, rowid, boff, pr, pc, "S4", 1, "YG", 1)
    _cge_sp(M, rowid, boff, pr, pc, "S4", 1, "EG", 1)
    _cge_sp(M, rowid, boff, pr, pc, "S4", 1, "GSAV", 1)

    // Keep existing equations and variables
    keep = (pr :> 0) :& M.exists[pc]
    P = uniqrows((select(pr, keep), select(pc, keep)))
    M.jr = P[., 1]
    M.jc = P[., 2]

    // Rows with exact derivatives, in the order of _cge_dense
    dense = _cge_denseblocks()
    M.drow = J(0, 1, .)
    for (k = 1; k <= cols(dense); k++) {
        g = _cge_find(M.ename, dense[k])
        M.drow = M.drow \ rowid[boff[g] :+ (1::M.elen[g])]
    }
    if (min(M.drow) <= 0) _cge_fail("cge internal error: an equation with exact derivatives is masked", 3498)
}

// Exact derivatives of the rows of _cge_denseblocks() with respect to every
// stacked variable (unscaled): rows P8, P9, I1 (one per factor), I8, I9, S1 (one
// per factor), S3, S5
real matrix _cge_dense(struct cge_model scalar M, struct cge_par scalar p, real colvector x)
{
    real matrix G, WFD, QF, YIF
    real colvector PQ, QQ, QM, QE, PA, QA, QG, QINV, QER, YI, TINS, MPS, W, cQF, cWFD, cYIF
    real scalar EXR, FSAV, nA, nF, nD, f, r, A, B

    nA = M.n
    nF = M.nF
    nD = M.nD
    G = J(6 + 2 * nF, rows(x), 0)
    PQ = _cge_v(M, x, 8);    QQ = _cge_v(M, x, 22);   QM = _cge_v(M, x, 21)
    QE = _cge_v(M, x, 20);   PA = _cge_v(M, x, 1);    QA = _cge_v(M, x, 13)
    QG = _cge_v(M, x, 24);   QINV = _cge_v(M, x, 25); QER = _cge_v(M, x, 44)
    YI = _cge_v(M, x, 29);   TINS = _cge_v(M, x, 35); MPS = _cge_v(M, x, 36)
    W = _cge_v(M, x, 9);     WFD = _cge_v(M, x, 41);  QF = _cge_v(M, x, 16)
    YIF = _cge_v(M, x, 28)
    EXR = _cge_v(M, x, 10);  FSAV = _cge_v(M, x, 34)
    cQF = _cge_vcols(M, "QF")
    cWFD = _cge_vcols(M, "WFDIST")
    cYIF = _cge_vcols(M, "YIF")

    // P8, P9: price indexes
    G[1, _cge_vcols(M, "CPI")] = 1
    G[1, _cge_vcols(M, "PQ")'] = -p.cwts'
    G[2, _cge_vcols(M, "DPI")] = 1
    G[2, _cge_vcols(M, "PD")'] = -p.dwts'
    // I1: factor incomes
    for (f = 1; f <= nF; f++) {
        r = 2 + f
        G[r, _cge_vcols(M, "YF")[f]] = 1
        G[r, _cge_vcols(M, "W")[f]] = -(WFD[f, .] * QF[f, .]')
        G[r, cWFD[|(f - 1) * nA + 1 \ f * nA|]'] = -W[f] :* QF[f, .]
        G[r, cQF[|(f - 1) * nA + 1 \ f * nA|]'] = -W[f] :* WFD[f, .]
        G[r, _cge_vcols(M, "EXR")] = -p.trfr[f]
    }
    // I8: government revenue
    r = 3 + nF
    G[r, _cge_vcols(M, "YG")] = 1
    G[r, _cge_vcols(M, "TINS")'] = -YI'
    G[r, _cge_vcols(M, "YI")'] = -TINS'
    G[r, _cge_vcols(M, "PQ")'] = -(p.tq :* QQ)'
    G[r, _cge_vcols(M, "QQ")'] = -(p.tq :* PQ)'
    G[r, _cge_vcols(M, "QM")'] = -EXR :* (p.tm :* p.pwm)'
    G[r, _cge_vcols(M, "QE")'] = -EXR :* (p.te :* p.pwe)'
    G[r, _cge_vcols(M, "EXR")] = -(sum(p.tm :* p.pwm :* QM) + sum(p.te :* p.pwe :* QE) + p.trgr)
    G[r, _cge_vcols(M, "PA")'] = -(p.ta :* QA)'
    G[r, _cge_vcols(M, "QA")'] = -(p.ta :* PA)'
    G[r, cYIF[|nD * nF + 1 \ (nD + 1) * nF|]'] = J(1, nF, -1)
    G[r, _cge_vcols(M, "CPI")] = -p.trgg
    // I9: government spending
    r = 4 + nF
    G[r, _cge_vcols(M, "EG")] = 1
    G[r, _cge_vcols(M, "PQ")'] = -QG'
    G[r, _cge_vcols(M, "QG")'] = -PQ'
    G[r, _cge_vcols(M, "CPI")] = -(sum(p.trdg) + p.trgg)
    G[r, _cge_vcols(M, "EXR")] = -p.trrg
    // S1: factor markets
    for (f = 1; f <= nF; f++) {
        r = 4 + nF + f
        G[r, cQF[|(f - 1) * nA + 1 \ f * nA|]'] = M.fa[f, .]
        G[r, _cge_vcols(M, "QFS")[f]] = -1
    }
    // S3: balance of payments
    r = 5 + 2 * nF
    A = sum(YIF[nD + 2, .]) + p.shir' * ((1 :- MPS) :* (1 :- TINS) :* YI)
    B = sum(M.cr :* PQ :* QER)
    G[r, _cge_vcols(M, "QM")'] = p.pwm'
    G[r, cYIF[|(nD + 1) * nF + 1 \ (nD + 2) * nF|]'] = J(1, nF, 1 / EXR)
    G[r, _cge_vcols(M, "MPS")'] = -(p.shir :* (1 :- TINS) :* YI)' :/ EXR
    G[r, _cge_vcols(M, "TINS")'] = -(p.shir :* (1 :- MPS) :* YI)' :/ EXR
    G[r, _cge_vcols(M, "YI")'] = (p.shir :* (1 :- MPS) :* (1 :- TINS))' :/ EXR
    G[r, _cge_vcols(M, "EXR")] = (B - A) / EXR^2
    G[r, _cge_vcols(M, "QE")'] = -p.pwe'
    G[r, _cge_vcols(M, "PQ")'] = -(M.cr :* QER)' :/ EXR
    G[r, _cge_vcols(M, "QER")'] = -(M.cr :* PQ)' :/ EXR
    G[r, _cge_vcols(M, "FSAV")] = -1
    // S5: savings-investment balance
    r = 6 + 2 * nF
    G[r, _cge_vcols(M, "MPS")'] = ((1 :- TINS) :* YI)'
    G[r, _cge_vcols(M, "TINS")'] = -(MPS :* YI)'
    G[r, _cge_vcols(M, "YI")'] = (MPS :* (1 :- TINS))'
    G[r, _cge_vcols(M, "GSAV")] = 1
    G[r, _cge_vcols(M, "EXR")] = FSAV
    G[r, _cge_vcols(M, "FSAV")] = EXR
    G[r, _cge_vcols(M, "PQ")'] = -QINV'
    G[r, _cge_vcols(M, "QINV")'] = -PQ'
    G[r, _cge_vcols(M, "WALRAS")] = -1
    return(G)
}

// Groups of free variables for the Jacobian: a greedy colouring, most
// connected columns first, in which the columns of a group share no equation
// (Curtis, Powell and Reid, 1974)
struct cge_jpat scalar _cge_jpat_make(struct cge_model scalar M, real colvector free)
{
    struct cge_jpat scalar G
    real colvector map, keep, r0, c0, o, cs, rs, rcol, ccnt, rcnt, gcnt, rstart, colour, forbid
    real scalar n, nnz, k, s, j, a, b, i, col, nc

    n = rows(free)
    map = J(rows(M.x0), 1, 0)
    map[free] = (1::n)
    keep = map[M.jc] :> 0
    r0 = select(M.jr, keep)
    c0 = map[select(M.jc, keep)]
    nnz = rows(r0)
    o = order((c0, r0), (1, 2))
    G.crow = r0[o]
    cs = c0[o]
    o = order((r0, c0), (1, 2))
    rcol = c0[o]
    rs = r0[o]
    ccnt = J(n, 1, 0)
    rcnt = J(M.neq, 1, 0)
    for (k = 1; k <= nnz; k++) {
        ccnt[cs[k]] = ccnt[cs[k]] + 1
        rcnt[rs[k]] = rcnt[rs[k]] + 1
    }
    G.cstart = 1 \ (runningsum(ccnt) :+ 1)
    rstart = 1 \ (runningsum(rcnt) :+ 1)

    colour = J(n, 1, 0)
    forbid = J(n, 1, 0)
    nc = 0
    o = order(-ccnt, 1)
    for (s = 1; s <= n; s++) {
        j = o[s]
        for (a = G.cstart[j]; a < G.cstart[j + 1]; a++) {
            i = G.crow[a]
            for (b = rstart[i]; b < rstart[i + 1]; b++) {
                k = rcol[b]
                if (colour[k]) forbid[colour[k]] = j
            }
        }
        col = 1
        while (forbid[col] == j) col++
        colour[j] = col
        if (col > nc) nc = col
    }
    G.gcol = order((colour, (1::n)), (1, 2))
    gcnt = J(nc, 1, 0)
    for (j = 1; j <= n; j++) gcnt[colour[j]] = gcnt[colour[j]] + 1
    G.gstart = 1 \ (runningsum(gcnt) :+ 1)
    G.ncolour = nc
    return(G)
}

// Central-difference Jacobian by groups of columns: one pair of residual
// evaluations per group gives the derivatives of all its columns
real matrix _cge_jacobian(struct cge_model scalar M, struct cge_par scalar p, real colvector xfix,
                          real colvector free, real colvector z, struct cge_jpat scalar G)
{
    real matrix Jac
    real colvector h, zp, zm, d, cols, rr, x, esc
    real matrix D
    real scalar g, k, j

    Jac = J(M.neq, rows(z), 0)
    h = 1e-6 :* rowmax((J(rows(z), 1, 1), abs(z)))
    for (g = 1; g <= G.ncolour; g++) {
        cols = G.gcol[|G.gstart[g] \ G.gstart[g + 1] - 1|]
        zp = z
        zm = z
        zp[cols] = z[cols] + h[cols]
        zm[cols] = z[cols] - h[cols]
        d = _cge_F(M, p, xfix, free, zp) - _cge_F(M, p, xfix, free, zm)
        if (hasmissing(d)) return(J(M.neq, rows(z), .))
        for (k = 1; k <= rows(cols); k++) {
            j = cols[k]
            if (G.cstart[j + 1] == G.cstart[j]) continue
            rr = G.crow[|G.cstart[j] \ G.cstart[j + 1] - 1|]
            Jac[rr, j] = d[rr] :/ (2 * h[j])
        }
    }
    x = xfix
    x[free] = z :* M.xscale[free]
    esc = select(M.escale, M.emask)
    D = _cge_dense(M, p, x)
    Jac[M.drow, .] = (D[., free] :* M.xscale[free]') :/ esc[M.drow]
    return(Jac)
}

// Column-by-column central-difference Jacobian, kept to check the grouped one
real matrix _cge_jacobian_full(struct cge_model scalar M, struct cge_par scalar p, real colvector xfix,
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

// Test hook: the grouped and column-by-column Jacobians at the current point,
// with the current shocks and closure
void _cge_jaccheck()
{
    struct cge_model scalar M
    struct cge_jpat scalar G
    real colvector free, z
    real matrix A, B

    M = _cge_load()
    _cge_need(M, "calibrated")
    free = select((1::rows(M.x0)), M.exists :* (1 :- M.fixed))
    z = M.xcur[free] :/ M.xscale[free]
    G = _cge_jpat_make(M, free)
    A = _cge_jacobian(M, M.p, M.xcur, free, z, G)
    B = _cge_jacobian_full(M, M.p, M.xcur, free, z)
    st_numscalar("r(maxdiff)", max(abs(A - B)))
    st_numscalar("r(groups)", G.ncolour)
    st_numscalar("r(columns)", rows(z))
    printf("{txt}Jacobian: {res}%f{txt} columns in {res}%f{txt} groups; largest difference from column-by-column {res}%9.3e\n",
           rows(z), G.ncolour, max(abs(A - B)))
}

// Newton-Raphson with a backtracking line search; returns 1 on convergence.
real scalar _cge_newton(struct cge_model scalar M, struct cge_par scalar p, real colvector xfix,
                        real colvector free, real colvector z, real scalar tol, real scalar maxit,
                        real scalar trace, real scalar iter, real scalar err)
{
    struct cge_jpat scalar G
    real colvector f, fn, dz, zn
    real matrix Jac
    real scalar norm0, step, it

    f = _cge_F(M, p, xfix, free, z)
    iter = 0
    err = .
    if (hasmissing(f)) return(0)
    G = _cge_jpat_make(M, free)
    for (it = 0; it <= maxit; it++) {
        err = max(abs(f))
        iter = it
        if (trace) printf("{txt}Iteration %f: largest scaled residual = {res}%9.3e\n", it, err)
        if (err < tol) return(1)
        if (it == maxit) return(0)
        Jac = _cge_jacobian(M, p, xfix, free, z, G)
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

// Evaluator for solvenl(), which takes at most three extra arguments in Stata 13:
// xf holds the fixed values (column 1) and marks the free variables (column 2)
void _cge_solvenl_eval(real colvector z, real colvector y, struct cge_model scalar M,
                       struct cge_par scalar p, real matrix xf)
{
    y = _cge_F(M, p, xf[., 1], select((1::rows(xf)), xf[., 2]), z)
}

// Solve from `start` with parameters p and fixed values in xfix.
// Returns the full solution vector; conv, iter, err and method describe the outcome.
real colvector _cge_solve_point(struct cge_model scalar M, struct cge_par scalar p, real colvector xfix,
                                real colvector start, real scalar tol, real scalar maxit,
                                real scalar trace, real scalar conv, real scalar iter,
                                real scalar err, string scalar method)
{
    real colvector free, z, z2, x, isfree
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
        isfree = J(rows(xfix), 1, 0)
        isfree[free] = J(rows(free), 1, 1)
        solvenl_init_narguments(S, 3)
        solvenl_init_argument(S, 1, M)
        solvenl_init_argument(S, 2, p)
        solvenl_init_argument(S, 3, (xfix, isfree))
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
    return((PQ0' * p.gamma)' + (EH1 - (PQ1' * p.gamma)') :* exp(colsum(p.beta :* ln(PQ0 :/ PQ1)))' - EH0)
}

// Expenditure-side GDP minus income-side GDP; zero at any solution
real scalar _cge_gdpgap(struct cge_model scalar M, struct cge_par scalar p, real colvector x)
{
    real matrix PQ, QH, QG, QINV, QE, QM, EXR, PVA, QVA, QQ, PA, QA, QER
    real scalar expend, income
    PQ = _cge_v(M, x, 8);    QH = _cge_v(M, x, 23);   QG = _cge_v(M, x, 24)
    QINV = _cge_v(M, x, 25); QE = _cge_v(M, x, 20);   QM = _cge_v(M, x, 21)
    EXR = _cge_v(M, x, 10);  PVA = _cge_v(M, x, 2);   QVA = _cge_v(M, x, 14)
    QQ = _cge_v(M, x, 22);   PA = _cge_v(M, x, 1);    QA = _cge_v(M, x, 13)
    QER = _cge_v(M, x, 44)
    expend = PQ' * (rowsum(QH) + QG + QINV + QER) + EXR * (p.pwe' * QE) - EXR * (p.pwm' * QM)
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
    _cge_row(M, x, "Exports (world prices)", p.pwe' * (_cge_v(M, M.x0, 20) + _cge_v(M, M.x0, 44)),
             p.pwe' * (_cge_v(M, x, 20) + _cge_v(M, x, 44)))
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
    // Change relative to the absolute base, so that a fall is negative even
    // when the base is negative (for example government savings)
    printf("{txt}%-34s {res}%8.4g %8.3f\n", label, b, (b != 0 ? 100 * (s - b) / abs(b) : .))
}

// =====================================================================
// Checks (model_spec.md, Section 8)
// =====================================================================

void _cge_check(string scalar sim, real scalar homog, real scalar perturb, real scalar seed)
{
    struct cge_model scalar M
    struct cge_par scalar p
    real colvector x, xfix, start, free, target, rel, unit
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

    // Deviations are relative to each value, with a floor of one; a variable whose
    // base value is zero (WALRAS) is measured against the largest SAM entry, as in
    // the Walras's-law check, so that the checks do not depend on the SAM's units
    unit = (M.x0 :!= 0) + (M.x0 :== 0) :* scale

    if (homog) {
        // Double every fixed nominal value: nominal variables should double and real ones stay put
        xfix = M.x0 :* (1 :+ M.fixed :* M.nominal)
        x = _cge_solve_point(M, M.p0, xfix, M.x0, 1e-12, 100, 0, conv, iter, err, method)
        target = M.x0 :* (1 :+ M.nominal)
        rel = select(abs(x - target) :/ rowmax((unit, abs(target))), M.exists)
        v = (conv ? max(rel) : .)
        fails = fails + _cge_report("homogeneity (largest relative deviation)", v, 1e-8)
    }

    if (perturb > 0) {
        rseed(seed)
        start = M.x0 :* (1 :+ perturb * (2 * runiform(rows(M.x0), 1) :- 1))
        x = _cge_solve_point(M, M.p0, M.x0, start, 1e-12, 100, 0, conv, iter, err, method)
        rel = select(abs(x - M.x0) :/ rowmax((unit, abs(M.x0))), M.exists)
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
