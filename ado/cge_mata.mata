*! cge_mata.mata  v0.3.3  2026-10-20
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
    // health insurance fund: contribution rates, purchases, savings rate and
    // transfers from government and the rest of the world
    real colvector tshi, qshi
    real scalar    sshi, trshi, trshir
    // factor efficiency: exogenous efficiency, elasticity with respect to
    // health services and base volume of health services
    real colvector af, etah
    real scalar    hs0
    // VAT (from version 0.3.1): rates by commodity and credit shares by activity
    real colvector tv, kappa
    // public debt (from version 0.3.1): flag, stocks at the start of the period
    // (domestic in local currency, foreign in foreign currency), interest
    // rates, holders of domestic debt and the foreign share of new borrowing
    real scalar    debt, ddebt, fdebt, rd, rf, phi
    real colvector hold
    // margins by market (from version 0.3.2): services per unit of domestic
    // sales, imports and exports; export demand elasticities (0 = none) and
    // base exports; home consumption shares and subsistence quantities
    real matrix    icd, ici, ice
    real colvector etae, qe0
    real matrix    betah, gammah
    // labour-market regimes (from version 0.3.3): factors with a labour force
    // (flag), labour force, base unemployment rate, wage-curve elasticity,
    // reference real wage, real minimum wage, factors with a floor (flag) and
    // the smoothing parameter of the minimum-wage condition
    real colvector inlf, qlf, u0, epsw, wref, wmin, hasmin
    real scalar    mu
}

struct cge_model {
    // SAM as read (labels0, S0) and after rewriting layouts (labels, S)
    string colvector labels0, labels
    real matrix      S0, S
    real rowvector   rewritten
    real scalar      mapped, calibrated
    real colvector   iA, iC, iF, iH
    real scalar      igov, isav, irow, idirtax, isaltax, iimptax, iexptax, iacttax
    // health insurance fund (0 when none is mapped)
    real scalar      ishi
    // VAT account (0 when none is mapped; from version 0.3.1)
    real scalar      ivattax
    // from version 0.3.2: market of each margin account in iT (0 composite
    // supply, 1 domestic sales, 2 imports, 3 exports); export-only commodities,
    // commodities with finite export demand, with domestic sales and with
    // composite supply
    real colvector   tmkt, cxe, ced, cdo, cq
    string colvector A, C, F, H, I
    real colvector   iE, imargins, iterritorial, iT, istocks
    string colvector E, D
    // n activities, nC commodities (nC >= n from version 0.1.7)
    real scalar      n, nC, nF, nH, nE, nD, nI
    // model structure
    real colvector   ce, cm, cd, cx, ct, cr, cshi
    // health services whose consumption raises factor efficiency
    real colvector   chs
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
    real colvector   jr, jc, drow, drow2
    // reduced system (from version 0.2.0): explicit definitions that are left
    // out (dact, one flag per candidate), the variables they define (derived),
    // the remaining equations (rmask) and their pattern (rjr, rjc, rdrow)
    real colvector   dact, derived, rmask, rjr, rjc, rdrow, rdrow2
    // equation blocks
    string colvector ename
    real colvector   elen, escale, emask
    real scalar      neq
    // closure
    string scalar    c_ext, c_gov, c_si, c_num
    // options of the last calibration (from version 0.2.1)
    string rowvector calargs
    string colvector c_fac
    // stored simulations
    string colvector simname, simclosure, simmethod
    real matrix      simx
    struct cge_par rowvector simp
    real colvector   simconv, simiter, simres
    // dynamic runs (from version 0.2.0): run name, period and uniform efficiency
    // factor of each stored simulation ("" and missing for static ones)
    string colvector simrun
    real colvector   simper, simlam
}

// Columns of the Jacobian for one solve (free variables), grouped so that the
// columns of a group share no equation: CSC storage of the pattern (rows of
// column j are crow[cstart[j]..cstart[j+1]-1]) and the members of each group
// (gcol[gstart[g]..gstart[g+1]-1])
struct cge_jpat {
    real colvector cstart, crow, gstart, gcol
    real scalar    ncolour
}

// Package version; it must equal the version in cge.ado
string scalar _cge_version()
{
    return("0.3.3")
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
               "IADJ","GADJ","WFDIST","WALRAS","QT","QER","YSHI","SHIADJ","QSHI","EFF","HS",
               "TQADJ","TMADJ","TVADJ","PWE","QHA","LSW","LSM")'
    M.vset  = ("A","A","A","C","C","C","C","C","F","","","",
               "A","A","A","FA","CA","C","C","C","C","C","CH","C","C","F",
               "F","IF","D","H","","","","","D","D","","",
               "","","FA","","C","C","","","C","F","",
               "","","","C","AH","F","F")'
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
    string colvector labels, names
    real matrix S
    real scalar nmiss, k

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
    _cge_sam_start(labels, S, nmiss, "SAM read")
}

// =====================================================================
// SAM tools (docs/sam_tools.md, from version 0.3.0)
// =====================================================================

// Starts a new model from a SAM: earlier mappings, calibrations and
// simulations are discarded
void _cge_sam_start(string colvector labels, real matrix S, real scalar nmiss, string scalar what)
{
    struct cge_model scalar M
    real scalar maxdiff
    maxdiff = max(abs(rowsum(S) - colsum(S)'))
    M.labels0 = labels
    M.S0 = S
    M.labels = labels
    M.S = S
    M.mapped = 0
    M.calibrated = 0
    _cge_store(M)
    printf("{txt}%s: {res}%f{txt} accounts, total {res}%g\n", what, rows(S), sum(S))
    if (nmiss) printf("{txt}Blank cells treated as zero: {res}%f\n", nmiss)
    printf("{txt}Largest row-column imbalance: {res}%9.3e\n", maxdiff)
    st_numscalar("r(N_accounts)", rows(S))
    st_numscalar("r(total)", sum(S))
    st_numscalar("r(maxdiff)", maxdiff)
    st_numscalar("r(N_blank)", nmiss)
}

// Position of each label, for fast lookups
transmorphic _cge_index(string colvector labels)
{
    transmorphic A
    real scalar k
    A = asarray_create()
    for (k = 1; k <= rows(labels); k++) asarray(A, labels[k], k)
    return(A)
}

real scalar _cge_pos(transmorphic A, string scalar label, string scalar what)
{
    if (!asarray_contains(A, label)) _cge_fail("account " + label + " (" + what + ") is not in the SAM", 111)
    return(asarray(A, label))
}

// A label as a Stata name (Section 1): characters other than letters,
// digits and the underscore removed, then any leading digits, and the result
// cut to 32 characters; "" if that is not a valid name
string scalar _cge_name(string scalar s)
{
    string scalar out, ch
    real scalar k
    if (st_isname(s)) return(s)
    out = ""
    for (k = 1; k <= strlen(s); k++) {
        ch = substr(s, k, 1)
        if ((ch >= "a" & ch <= "z") | (ch >= "A" & ch <= "Z") | (ch >= "0" & ch <= "9") | ch == "_") out = out + ch
    }
    while (strlen(out) > 0) {
        ch = substr(out, 1, 1)
        if (ch < "0" | ch > "9") break
        out = substr(out, 2, .)
    }
    out = substr(out, 1, 32)
    return(st_isname(out) ? out : "")
}

// Labels converted to names; each change is displayed, and a label that
// cannot be converted, or two labels that give the same name, are errors
string colvector _cge_names(string colvector raw)
{
    string colvector out
    transmorphic A
    real scalar k, nchanged
    out = raw
    A = asarray_create()
    nchanged = 0
    for (k = 1; k <= rows(raw); k++) {
        if (raw[k] == "") _cge_fail("account " + strofreal(k) + " has a blank label", 459)
        out[k] = _cge_name(raw[k])
        if (out[k] == "") _cge_fail("account label " + raw[k] + " cannot be converted to a Stata name; rename it", 459)
        if (out[k] != raw[k]) {
            nchanged++
            if (nchanged <= 20) {
                printf("{txt}Account label {res}%s{txt} is not a valid Stata name; using {res}%s{txt}\n", raw[k], out[k])
            }
        }
        if (asarray_contains(A, out[k])) {
            _cge_fail("account labels " + asarray(A, out[k]) + " and " + raw[k] + " both give the name " + out[k] +
                      "; rename one of them", 459)
        }
        asarray(A, out[k], raw[k])
    }
    if (nchanged > 20) printf("{txt}... and {res}%f{txt} more labels changed\n", nchanged - 20)
    return(out)
}

// The whole of a text file, without carriage returns
string scalar _cge_readfile(string scalar fn)
{
    real scalar fh
    string colvector chunks
    string scalar chunk
    if (!fileexists(fn)) _cge_fail("file " + fn + " not found", 601)
    fh = fopen(fn, "r")
    chunks = J(0, 1, "")
    while ((chunk = fread(fh, 4194304)) != J(0, 0, "")) chunks = chunks \ chunk
    fclose(fh)
    if (rows(chunks) == 0) return("")
    return(subinstr(invtokens(chunks', ""), char(13), ""))
}

// Fields of s separated by the character sep; quotes (for example `""""')
// protect separators within a field
string rowvector _cge_split(string scalar s, string scalar sep, string scalar quotes)
{
    transmorphic t
    string rowvector tok, out
    string scalar l2
    real rowvector issep, pos, keep
    // Comma-separated values without quotes or blanks: tokens() is much
    // faster than tokeninit(); empty fields become "."
    if (sep == "," & !strpos(s, `"""') & !strpos(s, " ") & !strpos(s, char(9))) {
        l2 = subinstr(subinstr("," + s + ",", ",,", ",.,"), ",,", ",.,")
        return(tokens(subinstr(substr(l2, 2, strlen(l2) - 2), ",", " ")))
    }
    t = tokeninit("", sep, quotes)
    tokenset(t, s)
    tok = tokengetall(t)
    if (cols(tok) == 0) return("")
    issep = (tok :== sep)
    pos = runningsum(issep) :+ 1
    out = J(1, sum(issep) + 1, "")
    keep = selectindex(!issep)
    if (cols(keep)) out[pos[keep]] = tok[keep]
    return(out)
}

// Fields without surrounding blanks and quotes
string rowvector _cge_unquote(string rowvector f)
{
    string rowvector out
    real rowvector q
    real scalar k, i
    out = strtrim(f)
    q = selectindex((substr(out, 1, 1) :== `"""') :& (substr(out, -1, 1) :== `"""') :& (strlen(out) :>= 2))
    for (k = 1; k <= cols(q); k++) {
        i = q[k]
        out[i] = strtrim(subinstr(substr(out[i], 2, strlen(out[i]) - 2), `""""', `"""'))
    }
    return(out)
}

// Number of account columns in the first line of a CSV file
real scalar _cge_csv_ncols(string scalar fn)
{
    real scalar fh, p
    string scalar s, chunk
    if (!fileexists(fn)) _cge_fail("file " + fn + " not found", 601)
    fh = fopen(fn, "r")
    s = ""
    while ((chunk = fread(fh, 65536)) != J(0, 0, "")) {
        s = s + chunk
        p = strpos(s, char(10))
        if (p) {
            s = substr(s, 1, p - 1)
            break
        }
    }
    fclose(fh)
    return(cols(_cge_split(subinstr(s, char(13), ""), ",", `""""')) - 1)
}

// Reads a wide CSV SAM directly (Section 1, form 2)
void _cge_sam_csv(string scalar fn)
{
    string colvector lines, rlab
    string rowvector head, f
    real matrix S
    real rowvector v, blank, bad
    real scalar n, k, nmiss

    lines = _cge_split(_cge_readfile(fn), char(10), "")'
    lines = select(lines, strtrim(lines) :!= "")
    if (rows(lines) < 2) _cge_fail(fn + " has no SAM rows", 459)
    head = _cge_unquote(_cge_split(lines[1], ",", `""""'))
    n = cols(head) - 1
    if (n < 1) _cge_fail(fn + " has no account columns", 459)
    if (rows(lines) - 1 != n) {
        errprintf("SAM is not square: %f rows and %f account columns\n", rows(lines) - 1, n)
        exit(459)
    }
    S = J(n, n, 0)
    rlab = J(n, 1, "")
    nmiss = 0
    for (k = 1; k <= n; k++) {
        f = _cge_unquote(_cge_split(lines[k + 1], ",", `""""'))
        if (cols(f) != n + 1) {
            _cge_fail("line " + strofreal(k + 1) + " of " + fn + " has " + strofreal(cols(f)) +
                      " fields; the first line has " + strofreal(n + 1), 459)
        }
        rlab[k] = f[1]
        f = f[|2 \ n + 1|]
        blank = (f :== "") :| (f :== ".")
        v = strtoreal(f)
        bad = selectindex(!blank :& (v :>= .))
        if (cols(bad)) {
            _cge_fail("row " + rlab[k] + ", column " + head[bad[1] + 1] + ": " + f[bad[1]] +
                      " is not a number", 459)
        }
        nmiss = nmiss + sum(blank)
        S[k, .] = editmissing(v, 0)
    }
    for (k = 1; k <= n; k++) {
        if (rlab[k] != head[k + 1]) {
            _cge_fail("row " + strofreal(k) + " is labelled " + rlab[k] + " but column " + strofreal(k) +
                      " is labelled " + head[k + 1] + "; row and column labels must agree, in the same order", 459)
        }
    }
    _cge_sam_start(_cge_names(rlab), S, nmiss, "SAM read")
}

// Reads a SAM from long data in memory (Section 1, form 3)
void _cge_sam_long(string scalar rvar, string scalar cvar, string scalar vvar)
{
    string colvector r, c, raw
    real colvector v, ri, ci, key, ord
    real matrix S
    transmorphic A
    real scalar i, n, nmiss, k
    string scalar x

    r = strtrim(st_sdata(., rvar))
    c = strtrim(st_sdata(., cvar))
    v = st_data(., vvar)
    if (rows(r) == 0) _cge_fail("no observations", 2000)
    A = asarray_create()
    raw = J(2 * rows(r), 1, "")
    ri = J(rows(r), 1, .)
    ci = J(rows(r), 1, .)
    // Accounts in the order of their first appearance as row accounts, then
    // any accounts that appear only as column accounts
    n = 0
    for (i = 1; i <= rows(r); i++) {
        if (r[i] == "" | c[i] == "") _cge_fail("observation " + strofreal(i) + " has a blank account label", 459)
        x = r[i]
        if (!asarray_contains(A, x)) {
            n++
            asarray(A, x, n)
            raw[n] = x
        }
        ri[i] = asarray(A, x)
    }
    for (i = 1; i <= rows(r); i++) {
        x = c[i]
        if (!asarray_contains(A, x)) {
            n++
            asarray(A, x, n)
            raw[n] = x
        }
        ci[i] = asarray(A, x)
    }
    raw = raw[|1 \ n|]
    key = (ri :- 1) :* n :+ ci
    ord = order(key, 1)
    for (k = 2; k <= rows(ord); k++) {
        if (key[ord[k]] == key[ord[k - 1]]) {
            _cge_fail("cell " + raw[ri[ord[k]]] + ", " + raw[ci[ord[k]]] + " is given twice", 459)
        }
    }
    nmiss = sum(v :>= .)
    v = editmissing(v, 0)
    S = J(n, n, 0)
    for (i = 1; i <= rows(v); i++) S[ri[i], ci[i]] = v[i]
    _cge_sam_start(_cge_names(raw), S, nmiss, "SAM read")
}

// Numbers as text that reads back as the same double (Section 2)
string rowvector _cge_numstr(real rowvector x)
{
    string rowvector s, sn
    real rowvector bad, nz
    real scalar k
    s = J(1, cols(x), "0")
    nz = selectindex(x :!= 0)
    if (cols(nz) == 0) return(s)
    sn = strtrim(strofreal(x[nz], "%21.0g"))
    bad = selectindex(strtoreal(sn) :!= x[nz])
    for (k = 1; k <= cols(bad); k++) sn[bad[k]] = strtrim(strofreal(x[nz[bad[k]]], "%24.17g"))
    s[nz] = sn
    return(s)
}

// The SAM as read, aggregated or balanced, or after the layout rewrites
void _cge_sam_pick(real scalar mapped, string colvector labels, real matrix S)
{
    struct cge_model scalar M
    M = _cge_load()
    if (mapped) {
        _cge_need(M, "mapped")
        labels = M.labels
        S = M.S
    }
    else {
        labels = M.labels0
        S = M.S0
    }
}

// Writes the SAM to a CSV file (Section 2)
void _cge_sam_write(string scalar fn, real scalar islong, real scalar mapped, real scalar replace)
{
    string colvector labels, lines
    real matrix S
    real rowvector nz
    real scalar fh, k, j, ncell

    _cge_sam_pick(mapped, labels, S)
    if (fileexists(fn)) {
        if (!replace) _cge_fail("file " + fn + " already exists; specify replace", 602)
        unlink(fn)
    }
    fh = fopen(fn, "w")
    ncell = 0
    if (islong) {
        fput(fh, "row,column,value")
        for (k = 1; k <= rows(S); k++) {
            nz = selectindex(S[k, .] :!= 0)
            if (cols(nz) == 0) continue
            lines = (labels[k] :+ "," :+ labels[nz]' :+ "," :+ _cge_numstr(S[k, nz]))'
            for (j = 1; j <= rows(lines); j++) fput(fh, lines[j])
            ncell = ncell + cols(nz)
        }
    }
    else {
        fput(fh, "account," + invtokens(labels', ","))
        for (k = 1; k <= rows(S); k++) fput(fh, labels[k] + "," + invtokens(_cge_numstr(S[k, .]), ","))
    }
    fclose(fh)
    if (islong) printf("{txt}SAM saved to {res}%s{txt}: {res}%f{txt} non-zero cells\n", fn, ncell)
    else printf("{txt}SAM saved to {res}%s{txt}: {res}%f{txt} accounts\n", fn, rows(S))
}

// Puts the SAM in the (empty) data in memory (Section 2)
void _cge_sam_todata(real scalar islong, real scalar mapped)
{
    string colvector labels, rl, cl
    real matrix S
    real colvector vl
    real rowvector nz
    real scalar k, n, w, m

    _cge_sam_pick(mapped, labels, S)
    n = rows(S)
    w = max((1, max(strlen(labels))))
    if (islong) {
        m = sum(S :!= 0)
        rl = J(m, 1, "")
        cl = J(m, 1, "")
        vl = J(m, 1, .)
        m = 0
        for (k = 1; k <= n; k++) {
            nz = selectindex(S[k, .] :!= 0)
            if (cols(nz) == 0) continue
            rl[|m + 1 \ m + cols(nz)|] = J(cols(nz), 1, labels[k])
            cl[|m + 1 \ m + cols(nz)|] = labels[nz]
            vl[|m + 1 \ m + cols(nz)|] = S[k, nz]'
            m = m + cols(nz)
        }
        st_addobs(m)
        (void) st_addvar("str" + strofreal(w), "row")
        (void) st_addvar("str" + strofreal(w), "column")
        (void) st_addvar("double", "value")
        if (m) {
            st_sstore(., "row", rl)
            st_sstore(., "column", cl)
            st_store(., "value", vl)
        }
        return
    }
    if (n + 1 > st_numscalar("c(maxvar)")) {
        _cge_fail("the SAM has " + strofreal(n) + " accounts, more than fit as variables (c(maxvar) is " +
                  strofreal(st_numscalar("c(maxvar)")) + "); save it as .csv or use the option long", 900)
    }
    st_addobs(n)
    (void) st_addvar("str" + strofreal(w), "account")
    st_sstore(., "account", labels)
    st_store(., st_addvar(J(1, n, "double"), labels'), S)
}

// ---------------------------------------------------------------------
// Mapping template (Section 3)
// ---------------------------------------------------------------------

string rowvector _cge_role_options()
{
    return(("activities", "commodities", "factors", "households", "enterprises", "government",
            "savinv", "row", "dirtax", "saltax", "imptax", "exptax", "acttax", "margins",
            "territorial", "marginaccounts", "stocks", "insurance", "vattax", "domesticmargins",
            "importmargins", "exportmargins"))
}

// A role entry in standard form: the cge_map options it names, in the order
// of _cge_role_options()
string scalar _cge_role_norm(string scalar cell, string scalar account)
{
    string rowvector opts, sing, tok
    real rowvector has
    real scalar k, m
    opts = _cge_role_options()
    sing = ("activity", "commodity", "factor", "household", "enterprise", "", "", "", "", "", "",
            "", "", "margin", "", "marginaccount", "stock", "", "vat", "domesticmargin", "importmargin",
            "exportmargin")
    tok = tokens(strlower(subinstr(cell, ",", " ")))
    has = J(1, cols(opts), 0)
    for (k = 1; k <= cols(tok); k++) {
        for (m = 1; m <= cols(opts); m++) if (tok[k] == opts[m] | tok[k] == sing[m]) break
        if (m > cols(opts)) {
            _cge_fail("role " + tok[k] + " of account " + account + " is not a cge_map option (see the " +
                      "template's roles sheet or help cge_template)", 198)
        }
        has[m] = 1
    }
    if (!max(has)) return("")
    return(invtokens(select(opts, has)))
}

void _cge_tmpl_add(string colvector role, real colvector idx, string scalar name)
{
    real scalar k
    for (k = 1; k <= rows(idx); k++) {
        if (idx[k] >= 1 & idx[k] <= rows(role)) role[idx[k]] = strtrim(role[idx[k]] + " " + name)
    }
}

// Puts the template of the SAM in memory in the (empty) data (Section 3);
// role and pair come from the mapping, if there is one
void _cge_template_data()
{
    struct cge_model scalar M
    string colvector role, pair, labels
    string rowvector taxname
    real colvector taxidx
    real scalar n0, k

    M = _cge_load()
    labels = M.labels0
    n0 = rows(labels)
    role = J(n0, 1, "")
    pair = J(n0, 1, "")
    if (M.mapped) {
        _cge_tmpl_add(role, M.iA, "activities")
        _cge_tmpl_add(role, M.iC, "commodities")
        _cge_tmpl_add(role, M.iF, "factors")
        _cge_tmpl_add(role, M.iH, "households")
        _cge_tmpl_add(role, M.iE, "enterprises")
        _cge_tmpl_add(role, M.igov, "government")
        _cge_tmpl_add(role, M.isav, "savinv")
        _cge_tmpl_add(role, M.irow, "row")
        // A tax paid directly to government was routed through an internal
        // account after the accounts of the SAM
        taxname = ("dirtax", "saltax", "imptax", "exptax", "acttax", "vattax")
        taxidx = (M.idirtax \ M.isaltax \ M.iimptax \ M.iexptax \ M.iacttax \
                  ((M.ivattax > 0 & M.ivattax < .) ? M.ivattax : 0))
        for (k = 1; k <= 6; k++) {
            // VAT moved out of the sales tax by vatshare() has no role in the template
            if (k == 6 & taxidx[k] > n0) {
                if (M.labels[taxidx[k]] == "_vatshare") continue
            }
            if (taxidx[k] > n0) _cge_tmpl_add(role, M.igov, taxname[k])
            else if (taxidx[k] > 0) _cge_tmpl_add(role, taxidx[k], taxname[k])
        }
        _cge_tmpl_add(role, M.imargins, "margins")
        _cge_tmpl_add(role, M.iterritorial, "territorial")
        if (rows(M.tmkt) != rows(M.iT)) M.tmkt = J(rows(M.iT), 1, 0)
        _cge_tmpl_add(role, select(M.iT, M.tmkt :== 0), "marginaccounts")
        _cge_tmpl_add(role, select(M.iT, M.tmkt :== 1), "domesticmargins")
        _cge_tmpl_add(role, select(M.iT, M.tmkt :== 2), "importmargins")
        _cge_tmpl_add(role, select(M.iT, M.tmkt :== 3), "exportmargins")
        _cge_tmpl_add(role, M.istocks, "stocks")
        if (M.ishi) _cge_tmpl_add(role, M.ishi, "insurance")
        for (k = 1; k <= rows(M.iA); k++) pair[M.iA[k]] = M.labels[M.iC[k]]
    }
    st_addobs(n0)
    (void) st_addvar("str" + strofreal(max((1, max(strlen(labels))))), "account")
    (void) st_addvar("str" + strofreal(max((1, max(strlen(role))))), "role")
    (void) st_addvar("str" + strofreal(max((1, max(strlen(pair))))), "pair")
    (void) st_addvar("str1", "group")
    (void) st_addvar(("double", "double", "double"), ("row_total", "column_total", "difference"))
    st_sstore(., "account", labels)
    st_sstore(., "role", role)
    st_sstore(., "pair", pair)
    st_store(., ("row_total", "column_total", "difference"),
             (rowsum(M.S0), colsum(M.S0)', rowsum(M.S0) - colsum(M.S0)'))
    printf("{txt}Template of {res}%f{txt} accounts%s\n", n0, (M.mapped ? ", with roles from the current mapping" : ""))
}

// Stores the template in memory (account, role, pair, group) for cge_map
// and cge_aggregate; an empty variable name gives a blank column
void _cge_tmpl_store(string scalar accvar, string scalar rolevar, string scalar pairvar, string scalar groupvar)
{
    string matrix T
    pointer() scalar q
    T = strtrim(st_sdata(., accvar))
    T = T, (rolevar != "" ? strtrim(st_sdata(., rolevar)) : J(rows(T), 1, ""))
    T = T, (pairvar != "" ? strtrim(st_sdata(., pairvar)) : J(rows(T), 1, ""))
    T = T, (groupvar != "" ? strtrim(st_sdata(., groupvar)) : J(rows(T), 1, ""))
    T = select(T, T[., 1] :!= "")
    if (rows(T) == 0) _cge_fail("the template has no accounts", 459)
    if ((q = findexternal("cge__template")) == NULL) q = crexternal("cge__template")
    *q = T
}

string matrix _cge_tmpl_get()
{
    pointer() scalar q
    q = findexternal("cge__template")
    if (q == NULL) _cge_fail("no template has been read", 459)
    return(*q)
}

// Members of each account of the SAM in memory: the template rows of the
// account itself, if the SAM has the template's accounts, or of the
// accounts in its group, if the SAM has the template's groups
pointer(real colvector) colvector _cge_tmpl_members(string colvector L, string matrix T, real scalar grouped)
{
    pointer(real colvector) colvector mem
    transmorphic A, G
    string colvector eff
    real scalar k, ok
    A = asarray_create()
    for (k = 1; k <= rows(T); k++) {
        if (asarray_contains(A, T[k, 1])) _cge_fail("account " + T[k, 1] + " appears twice in the template", 459)
        asarray(A, T[k, 1], k)
    }
    eff = T[., 1]
    for (k = 1; k <= rows(T); k++) if (T[k, 4] != "") eff[k] = T[k, 4]
    G = asarray_create()
    for (k = 1; k <= rows(T); k++) {
        if (asarray_contains(G, eff[k])) asarray(G, eff[k], (asarray(G, eff[k]) \ k))
        else asarray(G, eff[k], k)
    }
    // The SAM has the template's accounts, or its groups
    grouped = 0
    ok = (rows(L) == rows(T))
    for (k = 1; ok & k <= rows(L); k++) ok = asarray_contains(A, L[k])
    if (!ok) {
        grouped = 1
        ok = (rows(L) == asarray_elements(G))
        for (k = 1; ok & k <= rows(L); k++) ok = asarray_contains(G, L[k])
        if (!ok) _cge_fail("the accounts of the SAM in memory are neither the template's accounts nor its groups", 459)
    }
    mem = J(rows(L), 1, NULL)
    for (k = 1; k <= rows(L); k++) {
        if (grouped) mem[k] = &(asarray(G, L[k]))
        else mem[k] = &(asarray(A, L[k]))
    }
    return(mem)
}

// Maps the SAM from the template in memory (Section 3)
void _cge_map_template(string scalar reportfile, real scalar replace, | string scalar vatshare)
{
    struct cge_model scalar M
    string matrix T
    string colvector L, role, pairc, eff, lists
    string rowvector opts, single, tt, hl
    string scalar r1, p, cmd
    real colvector hh
    pointer(real colvector) colvector mem
    real colvector m, acts, coms, pairs, used, cands
    real rowvector vals
    transmorphic AL, AT
    real scalar n, k, j, grouped, a, mx, o

    M = _cge_load()
    T = _cge_tmpl_get()
    L = M.labels0
    n = rows(L)
    mem = _cge_tmpl_members(L, T, grouped)
    AL = _cge_index(L)
    AT = _cge_index(T[., 1])
    eff = T[., 1]
    for (k = 1; k <= rows(T); k++) if (T[k, 4] != "") eff[k] = T[k, 4]

    // Roles, which must agree within a group, and pairs
    role = J(n, 1, "")
    pairc = J(n, 1, "")
    for (k = 1; k <= n; k++) {
        m = *mem[k]
        role[k] = _cge_role_norm(T[m[1], 2], T[m[1], 1])
        for (j = 2; j <= rows(m); j++) {
            r1 = _cge_role_norm(T[m[j], 2], T[m[j], 1])
            if (r1 != role[k]) {
                _cge_fail("accounts " + T[m[1], 1] + " and " + T[m[j], 1] + " of group " + L[k] +
                          " have different roles", 459)
            }
        }
        for (j = 1; j <= rows(m); j++) {
            p = T[m[j], 3]
            if (p == "") continue
            // The pair as an account of the SAM in memory: itself, or its group
            if (!asarray_contains(AL, p)) {
                if (grouped & asarray_contains(AT, p)) p = eff[asarray(AT, p)]
                if (!asarray_contains(AL, p)) _cge_fail("pair " + T[m[j], 3] + " of account " + T[m[j], 1] + " is not in the SAM", 111)
            }
            if (pairc[k] != "" & pairc[k] != p) {
                _cge_fail("the members of group " + L[k] + " are paired with different commodities (" +
                          pairc[k] + ", " + p + ")", 459)
            }
            pairc[k] = p
        }
    }

    // Accounts of each option, in the order of the SAM
    opts = _cge_role_options()
    lists = J(cols(opts), 1, "")
    for (o = 1; o <= cols(opts); o++) {
        for (k = 1; k <= n; k++) {
            if (anyof(tokens(role[k]), opts[o])) lists[o] = strtrim(lists[o] + " " + L[k])
        }
    }
    single = ("government", "savinv", "row", "dirtax", "saltax", "imptax", "exptax", "acttax", "insurance",
              "vattax")
    for (o = 1; o <= cols(opts); o++) {
        if (!anyof(single, opts[o])) continue
        if (cols(tokens(lists[o])) > 1) _cge_fail("role " + opts[o] + " is given to more than one account: " + lists[o], 198)
        if (o <= 8 & o >= 6 & lists[o] == "") _cge_fail("no account has the role " + opts[o], 198)
    }
    for (o = 1; o <= 4; o++) if (lists[o] == "") _cge_fail("no account has the role " + opts[o], 198)
    // territorial(): the correction commodity, which households consume, first
    tt = tokens(lists[15])
    if (cols(tt) == 2) {
        hh = J(0, 1, .)
        hl = tokens(lists[4])
        for (k = 1; k <= cols(hl); k++) hh = hh \ asarray(AL, hl[k])
        if (sum(abs(M.S0[asarray(AL, tt[1]), hh'])) == 0 & sum(abs(M.S0[asarray(AL, tt[2]), hh'])) != 0) {
            lists[15] = tt[2] + " " + tt[1]
        }
    }

    // Pairs: the pair column, or the commodity whose column pays the activity most
    acts = J(0, 1, .)
    coms = J(0, 1, .)
    for (k = 1; k <= n; k++) {
        if (anyof(tokens(role[k]), "activities")) acts = acts \ k
        if (anyof(tokens(role[k]), "commodities")) coms = coms \ k
    }
    if (rows(coms) < rows(acts)) _cge_fail("there are fewer commodities than activities; each activity needs a paired commodity", 198)
    pairs = J(rows(acts), 1, 0)
    for (j = 1; j <= rows(acts); j++) {
        a = acts[j]
        if (pairc[a] != "") {
            pairs[j] = asarray(AL, pairc[a])
            if (!anyof(coms, pairs[j])) _cge_fail("activity " + L[a] + " is paired with " + pairc[a] + ", which is not a commodity", 198)
        }
        else {
            vals = M.S0[a, coms']
            mx = max(vals)
            if (mx <= 0) _cge_fail("activity " + L[a] + " sells to no commodity; give its pair in the template", 459)
            cands = selectindex(vals' :== mx)
            if (rows(cands) > 1) _cge_fail("activity " + L[a] + " sells equal amounts to several commodities; give its pair in the template", 459)
            pairs[j] = coms[cands[1]]
        }
    }
    for (j = 1; j <= rows(acts); j++) {
        for (k = j + 1; k <= rows(acts); k++) {
            if (pairs[j] == pairs[k]) _cge_fail("commodity " + L[pairs[j]] + " is paired with both " + L[acts[j]] + " and " + L[acts[k]], 459)
        }
    }
    used = J(n, 1, 0)
    used[pairs] = J(rows(pairs), 1, 1)
    lists[2] = invtokens(L[pairs]')
    for (k = 1; k <= rows(coms); k++) if (!used[coms[k]]) lists[2] = lists[2] + " " + L[coms[k]]

    // The equivalent command
    cmd = "cge_map,"
    for (o = 1; o <= cols(opts); o++) if (lists[o] != "") cmd = cmd + " " + opts[o] + "(" + lists[o] + ")"
    if (vatshare != "") cmd = cmd + " vatshare(" + vatshare + ")"
    if (strlen(cmd) <= 2000) printf("{txt}Mapping from the template:\n{res}%s\n", cmd)
    else printf("{txt}Mapping from the template ({res}%f{txt} accounts)\n", n)
    _cge_map(lists[1], lists[2], lists[3], lists[4], lists[5], lists[6], lists[7], lists[8], lists[9],
             lists[10], lists[11], lists[12], lists[13], lists[14], lists[15], lists[16], lists[17],
             lists[18], reportfile, replace, lists[19], vatshare, lists[20], lists[21], lists[22])
    st_global("r(command)", cmd)
}

// ---------------------------------------------------------------------
// Aggregation (Section 4)
// ---------------------------------------------------------------------

// group[k] is the group of account k of the SAM in memory ("" keeps it)
void _cge_aggregate(string colvector group, real scalar netdiag)
{
    struct cge_model scalar M
    string colvector L, g, newl
    real colvector gi, size
    real matrix S, R, X
    transmorphic A
    real scalar n, m, k, ndiag, sdiag

    M = _cge_load()
    L = M.labels0
    S = M.S0
    n = rows(L)
    g = group
    for (k = 1; k <= n; k++) if (g[k] == "") g[k] = L[k]
    A = asarray_create()
    newl = J(n, 1, "")
    gi = J(n, 1, 0)
    m = 0
    for (k = 1; k <= n; k++) {
        if (!asarray_contains(A, g[k])) {
            if (!st_isname(g[k])) _cge_fail("group " + g[k] + " is not a valid Stata name", 198)
            m++
            asarray(A, g[k], m)
            newl[m] = g[k]
        }
        gi[k] = asarray(A, g[k])
    }
    newl = newl[|1 \ m|]
    // X = G S G', summing rows then columns in the order of the accounts
    R = J(m, n, 0)
    for (k = 1; k <= n; k++) R[gi[k], .] = R[gi[k], .] + S[k, .]
    X = J(m, m, 0)
    for (k = 1; k <= n; k++) X[., gi[k]] = X[., gi[k]] + R[., k]
    ndiag = sum(diagonal(X) :!= 0)
    sdiag = sum(diagonal(X))
    if (netdiag) _diag(X, J(m, 1, 0))
    size = J(m, 1, 0)
    for (k = 1; k <= n; k++) size[gi[k]] = size[gi[k]] + 1
    printf("{txt}Accounts merged: {res}%f{txt} accounts into {res}%f{txt} groups; {res}%f{txt} accounts left as they are\n",
           sum((size :> 1) :* size), sum(size :> 1), sum(size :== 1))
    if (ndiag) {
        printf("{txt}Diagonal cells (flows within an account): {res}%f{txt}, total {res}%g{txt}%s\n", ndiag, sdiag,
               (netdiag ? ", removed" : ", kept"))
    }
    _cge_sam_start(newl, X, 0, "Aggregated SAM")
    st_numscalar("r(N_diagonal)", ndiag)
    st_numscalar("r(diagonal)", sdiag)
}

// groups(new: old old ..., new: old ...)
void _cge_aggregate_spec(string scalar spec, real scalar netdiag)
{
    struct cge_model scalar M
    string colvector L, group
    string rowvector parts, mem
    string scalar name
    transmorphic AL
    real scalar k, j, p, i

    M = _cge_load()
    L = M.labels0
    AL = _cge_index(L)
    group = J(rows(L), 1, "")
    parts = _cge_split(spec, ",", "")
    for (k = 1; k <= cols(parts); k++) {
        p = strpos(parts[k], ":")
        if (strtrim(parts[k]) == "") continue
        if (!p) _cge_fail("groups(): " + strtrim(parts[k]) + " needs the form new: old old ...", 198)
        name = strtrim(substr(parts[k], 1, p - 1))
        mem = tokens(substr(parts[k], p + 1, .))
        if (name == "" | cols(mem) == 0) _cge_fail("groups(): " + strtrim(parts[k]) + " needs the form new: old old ...", 198)
        for (j = 1; j <= cols(mem); j++) {
            i = _cge_pos(AL, mem[j], "groups()")
            if (group[i] != "") _cge_fail("groups(): account " + mem[j] + " is in two groups", 198)
            group[i] = name
        }
    }
    // A group may take the label of one of its members, but not of another account
    for (k = 1; k <= rows(L); k++) {
        if (group[k] != "" & group[k] != L[k] & asarray_contains(AL, group[k])) {
            i = asarray(AL, group[k])
            if (group[i] != group[k]) _cge_fail("groups(): group " + group[k] + " has the label of an account that is not one of its members", 198)
        }
    }
    _cge_aggregate(group, netdiag)
}

// The template's group column; members of a group must have the same role
void _cge_aggregate_template(real scalar netdiag)
{
    struct cge_model scalar M
    string matrix T
    string colvector L, group
    pointer(real colvector) colvector mem
    transmorphic AT, G
    real colvector m
    real scalar k, j, grouped
    string scalar g, r1, r2

    M = _cge_load()
    T = _cge_tmpl_get()
    L = M.labels0
    mem = _cge_tmpl_members(L, T, grouped)
    if (grouped) _cge_fail("the SAM in memory has already been aggregated with this template", 459)
    AT = _cge_index(T[., 1])
    group = J(rows(L), 1, "")
    for (k = 1; k <= rows(L); k++) group[k] = T[asarray(AT, L[k]), 4]
    // Roles within each group
    G = asarray_create()
    for (k = 1; k <= rows(L); k++) {
        g = (group[k] == "" ? L[k] : group[k])
        if (asarray_contains(G, g)) {
            j = asarray(G, g)
            r1 = _cge_role_norm(T[asarray(AT, L[j]), 2], L[j])
            r2 = _cge_role_norm(T[asarray(AT, L[k]), 2], L[k])
            if (r1 != r2) _cge_fail("accounts " + L[j] + " and " + L[k] + " of group " + g + " have different roles", 459)
        }
        else asarray(G, g, k)
    }
    _cge_aggregate(group, netdiag)
}

// ---------------------------------------------------------------------
// Balancing (Section 5)
// ---------------------------------------------------------------------

// Cells kept at their values: row:col, row:*, *:col or an account
real matrix _cge_fixedmask(string colvector L, string scalar spec)
{
    real matrix mask
    string rowvector tok
    string scalar r, c
    transmorphic AL
    real scalar n, k, p, i, j

    n = rows(L)
    AL = _cge_index(L)
    mask = J(n, n, 0)
    tok = tokens(spec)
    for (k = 1; k <= cols(tok); k++) {
        p = strpos(tok[k], ":")
        if (!p) {
            i = _cge_pos(AL, tok[k], "fixed()")
            mask[i, .] = J(1, n, 1)
            mask[., i] = J(n, 1, 1)
            continue
        }
        r = substr(tok[k], 1, p - 1)
        c = substr(tok[k], p + 1, .)
        if (r == "*" & c == "*") _cge_fail("fixed(): *:* would fix every cell", 198)
        if (r == "*") mask[., _cge_pos(AL, c, "fixed()")] = J(n, 1, 1)
        else if (c == "*") mask[_cge_pos(AL, r, "fixed()"), .] = J(1, n, 1)
        else {
            i = _cge_pos(AL, r, "fixed()")
            j = _cge_pos(AL, c, "fixed()")
            mask[i, j] = 1
        }
    }
    return(mask)
}

// totals(account:value ...)
void _cge_totals(string colvector L, string scalar spec, real colvector K, real colvector t)
{
    string rowvector tok
    transmorphic AL
    real scalar k, p, i
    AL = _cge_index(L)
    tok = tokens(spec)
    K = J(0, 1, .)
    t = J(0, 1, .)
    for (k = 1; k <= cols(tok); k++) {
        p = strpos(tok[k], ":")
        if (!p) _cge_fail("totals(): " + tok[k] + " needs the form account:value", 198)
        i = _cge_pos(AL, substr(tok[k], 1, p - 1), "totals()")
        if (anyof(K, i)) _cge_fail("totals(): " + L[i] + " is given twice", 198)
        K = K \ i
        t = t \ strtoreal(substr(tok[k], p + 1, .))
        if (t[rows(t)] >= .) _cge_fail("totals(): " + tok[k] + " has no valid value", 198)
    }
}

// Positive root x of p x^2 - u x - n = 0, in the stable form for each sign of u
real colvector _cge_ras_factor(real colvector u, real colvector p, real colvector nn, real colvector active,
                               string scalar what, string colvector L)
{
    real colvector x, d, i1, i2, bad
    x = J(rows(u), 1, 1)
    d = sqrt(u:^2 :+ 4 :* p :* nn)
    i1 = selectindex(active :& (u :>= 0))
    i2 = selectindex(active :& (u :< 0))
    if (rows(i1)) x[i1] = (u[i1] :+ d[i1]) :/ (2 :* p[i1])
    if (rows(i2)) x[i2] = 2 :* nn[i2] :/ (d[i2] :- u[i2])
    bad = selectindex(active :& ((x :>= .) :| (x :<= 0)))
    if (rows(bad)) _cge_fail("the " + what + " target of " + L[bad[1]] + " cannot be met with the signs of its cells", 459)
    return(x)
}

// Generalised RAS (Section 5.1)
real matrix _cge_ras(string colvector L, real matrix S0, real matrix fixed, string scalar rule,
                     real colvector K, real colvector tK, real scalar tol, real scalar maxit,
                     real scalar it, real colvector t)
{
    real matrix free, P, N, F, Pt, Nt
    real colvector given, rowfree, colfree, frow, fcol, u, v, r, s, rt, ct, hist, implied
    real scalar n, scale, k, err

    n = rows(L)
    scale = max((1, max(abs(S0))))
    free = (S0 :!= 0) :& !fixed
    P = S0 :* (free :& (S0 :> 0))
    N = -S0 :* (free :& (S0 :< 0))
    F = S0 :* !free
    if (rule == "average") t = 0.5 :* (rowsum(S0) + colsum(S0)')
    else if (rule == "rows") t = rowsum(S0)
    else t = colsum(S0)'
    given = J(n, 1, 0)
    if (rows(K)) {
        t[K] = tK
        given[K] = J(rows(K), 1, 1)
    }
    rowfree = (rowsum(free) :> 0)
    colfree = (colsum(free)' :> 0)
    frow = rowsum(F)
    fcol = colsum(F)'
    // An account whose row (or column) cannot change has that total as its target
    for (k = 1; k <= n; k++) {
        implied = J(0, 1, .)
        if (!rowfree[k]) implied = implied \ frow[k]
        if (!colfree[k]) implied = implied \ fcol[k]
        if (rows(implied) == 0) continue
        if (rows(implied) == 2) {
            if (abs(implied[1] - implied[2]) > tol * scale) {
                _cge_fail(L[k] + ": its row and column cannot change and their totals differ", 459)
            }
        }
        if (given[k] & abs(t[k] - implied[1]) > tol * scale) {
            _cge_fail(L[k] + ": the given total differs from the total of cells that cannot change", 459)
        }
        t[k] = implied[1]
    }
    u = t - frow
    v = t - fcol
    Pt = P'
    Nt = N'
    r = J(n, 1, 1)
    s = J(n, 1, 1)
    hist = J(maxit, 1, .)
    for (it = 1; it <= maxit; it++) {
        r = _cge_ras_factor(u, P * s, N * (1 :/ s), rowfree, "row", L)
        s = _cge_ras_factor(v, Pt * r, Nt * (1 :/ r), colfree, "column", L)
        // Row and column totals without forming the matrix
        rt = r :* (P * s) - (N * (1 :/ s)) :/ r + frow
        ct = s :* (Pt * r) - (Nt * (1 :/ r)) :/ s + fcol
        err = max((max(abs(rt - t)), max(abs(ct - t))))
        if (err <= tol * scale) break
        // A gap that no longer falls: the targets cannot be met
        hist[it] = err
        if (it > 100) {
            if (err >= (1 - 1e-6) * hist[it - 100]) {
                _cge_fail(sprintf("RAS stopped after %f iterations with a gap of %g that no longer falls: the " +
                                  "targets cannot be met with the zeros and fixed cells of the SAM", it, err), 430)
            }
        }
    }
    if (it > maxit) _cge_fail(sprintf("RAS did not converge in %f iterations", maxit), 430)
    return((r :* P :* s') - N :/ (r * s') + F)
}

// Accounts connected by off-diagonal cells that may change: a set number
// for each account, numbered from the account with the lowest position
real colvector _cge_components(real matrix free)
{
    real matrix link
    real colvector comp, stack, nb
    real scalar n, start, k, nc
    n = rows(free)
    link = (free :| free')
    _diag(link, J(n, 1, 0))
    comp = J(n, 1, 0)
    nc = 0
    for (start = 1; start <= n; start++) {
        if (comp[start]) continue
        nc++
        comp[start] = nc
        stack = start
        while (rows(stack)) {
            k = stack[rows(stack)]
            stack = (rows(stack) > 1 ? stack[|1 \ rows(stack) - 1|] : J(0, 1, .))
            nb = selectindex(link[., k] :& (comp :== 0))
            if (rows(nb)) {
                comp[nb] = J(rows(nb), 1, nc)
                stack = stack \ nb
            }
        }
    }
    return(comp)
}

// Cells of the cross-entropy solution for multipliers theta (Section 5.2)
void _cge_ce_cells(real colvector theta, real colvector imu, real colvector iK, real matrix P, real matrix N,
                   real matrix Xp, real matrix Xn, real colvector mu, real colvector rho)
{
    real matrix A
    real scalar n, nmu
    n = rows(P)
    nmu = rows(imu)
    mu = J(n, 1, 0)
    if (nmu) mu[imu] = theta[|1 \ nmu|]
    rho = J(n, 1, 0)
    if (rows(iK)) rho[iK] = theta[|nmu + 1 \ rows(theta)|]
    // a_ij = mu_i - mu_j + rho_i (a column and a row vector are not c-conformable)
    A = (mu + rho) * J(1, n, 1) - J(n, 1, 1) * mu'
    Xp = P :* exp(A :* (P :> 0))
    Xn = N :* exp(-A :* (N :> 0))
}

real scalar _cge_ce_phi(real colvector theta, real colvector imu, real colvector iK, real matrix P, real matrix N,
                        real colvector c, real colvector frow, real colvector t)
{
    real matrix Xp, Xn
    real colvector mu, rho
    _cge_ce_cells(theta, imu, iK, P, N, Xp, Xn, mu, rho)
    // sum() ignores missing values, so an overflow is checked first
    if (hasmissing(Xp) | hasmissing(Xn)) return(.)
    return(sum(Xp) + sum(Xn) + mu' * c + (rows(iK) ? rho[iK]' * (frow[iK] - t[iK]) : 0))
}

// Cross entropy (Section 5.2)
real matrix _cge_ce(string colvector L, real matrix S0, real matrix fixed, real colvector K, real colvector tK,
                    real scalar tol, real scalar maxit, real scalar it)
{
    real matrix free, P, N, F, Xp, Xn, X, W, Hmm, Hrm, H
    real colvector c, frow, fcol, rowfree, colfree, known, t, rhofree, comp, mufree, iK, imu, members
    real colvector theta, mu, rho, g, h, grad, step, rs, cs, trial, rx
    real scalar n, scale, k, kk, implied, nmu, nK, err, f0, f1, slope, alpha, ls

    n = rows(L)
    scale = max((1, max(abs(S0))))
    free = (S0 :!= 0) :& !fixed
    P = S0 :* (free :& (S0 :> 0))
    N = -S0 :* (free :& (S0 :< 0))
    F = S0 :* !free
    frow = rowsum(F)
    fcol = colsum(F)'
    c = frow - fcol
    rowfree = (rowsum(free) :> 0)
    colfree = (colsum(free)' :> 0)
    known = J(n, 1, 0)
    t = J(n, 1, 0)
    if (rows(K)) {
        known[K] = J(rows(K), 1, 1)
        t[K] = tK
    }
    // A known total whose row or column cannot change is implied by the fixed
    // cells; it must agree with them and needs no multiplier
    rhofree = known
    for (kk = 1; kk <= rows(K); kk++) {
        k = K[kk]
        implied = (rowfree[k] ? . : frow[k])
        if (!colfree[k]) implied = fcol[k]
        if (implied < .) {
            if (abs(t[k] - implied) > tol * scale) {
                _cge_fail(L[k] + ": the given total differs from the total of cells that cannot change", 459)
            }
            rhofree[k] = 0
        }
    }
    // One balance multiplier in each connected set of accounts is fixed at
    // zero; the fixed cells of each set must balance among themselves
    comp = _cge_components(free)
    mufree = J(n, 1, 1)
    for (k = 1; k <= max(comp); k++) {
        members = selectindex(comp :== k)
        if (abs(sum(c[members])) > tol * scale) {
            _cge_fail("the cells that cannot change do not balance for accounts " +
                      invtokens(L[members]'), 459)
        }
        mufree[members[1]] = 0
    }
    iK = selectindex(rhofree)
    imu = selectindex(mufree)
    nmu = rows(imu)
    nK = rows(iK)

    theta = J(nmu + nK, 1, 0)
    _cge_ce_cells(theta, imu, iK, P, N, Xp, Xn, mu, rho)
    for (it = 0; it <= maxit; it++) {
        X = Xp - Xn + F
        rx = rowsum(X)
        g = rx - colsum(X)'
        h = (nK ? rx[iK] - t[iK] : J(0, 1, .))
        err = max(abs(g))
        if (nK) err = max((err, max(abs(h))))
        if (err <= tol * scale) break
        if (it == maxit) _cge_fail(sprintf("cross entropy did not converge in %f iterations", maxit), 430)
        W = Xp + Xn
        rs = rowsum(W)
        cs = colsum(W)'
        Hmm = diag(rs + cs) - W - W'
        if (nK) {
            Hrm = -W[iK, .]
            for (kk = 1; kk <= nK; kk++) Hrm[kk, iK[kk]] = Hrm[kk, iK[kk]] + rs[iK[kk]]
            H = (Hmm[imu, imu], Hrm[., imu]' \ Hrm[., imu], diag(rs[iK]))
            grad = g[imu] \ h
        }
        else {
            H = Hmm[imu, imu]
            grad = g[imu]
        }
        step = -cholsolve(H, grad)
        if (hasmissing(step)) step = -lusolve(H, grad)
        if (hasmissing(step)) _cge_fail("cross entropy: the Newton system is singular; the pattern of cells may not allow a unique balanced SAM", 430)
        f0 = _cge_ce_phi(theta, imu, iK, P, N, c, frow, t)
        slope = grad' * step
        // Close to the solution the predicted decrease is below the rounding
        // of the dual, and the full Newton step is taken
        if (-slope <= 1e-12 * max((1, abs(f0)))) trial = theta + step
        else {
            alpha = 1
            for (ls = 1; ls <= 60; ls++) {
                trial = theta + alpha :* step
                f1 = _cge_ce_phi(trial, imu, iK, P, N, c, frow, t)
                if (f1 < . & f1 <= f0 + 1e-4 * alpha * slope) break
                alpha = alpha / 2
            }
            if (ls > 60) _cge_fail("cross entropy: the line search failed; no balanced SAM with this pattern may exist", 430)
        }
        theta = trial
        _cge_ce_cells(theta, imu, iK, P, N, Xp, Xn, mu, rho)
    }
    return(X)
}

void _cge_balance(string scalar method, string scalar rule, string scalar totals, string scalar fixspec,
                  real scalar tol, real scalar maxit, real scalar show)
{
    struct cge_model scalar M
    string colvector L
    real matrix S0, X, fixed
    real colvector K, tK, t, d, top, i, j
    real scalar it, n, before, after, total0, nchanged, maxrel, k, nshow, scale

    M = _cge_load()
    L = M.labels0
    S0 = M.S0
    n = rows(L)
    fixed = _cge_fixedmask(L, fixspec)
    _cge_totals(L, totals, K, tK)
    before = max(abs(rowsum(S0) - colsum(S0)'))
    total0 = sum(S0)
    if (method == "ras") X = _cge_ras(L, S0, fixed, rule, K, tK, tol, maxit, it, t)
    else X = _cge_ce(L, S0, fixed, K, tK, tol, maxit, it)
    after = max(abs(rowsum(X) - colsum(X)'))
    nchanged = sum(X :!= S0)
    d = vec(abs(X - S0))
    scale = max((1, max(abs(S0))))
    maxrel = max(vec(abs(X - S0) :/ (abs(S0) + (S0 :== 0))))
    printf("{txt}%s: converged in {res}%f{txt} iterations\n", (method == "ras" ? "RAS" : "Cross entropy"), it)
    printf("{txt}Largest row-column imbalance: {res}%9.3e{txt} before, {res}%9.3e{txt} after\n", before, after)
    printf("{txt}SAM total: {res}%g{txt} before, {res}%g{txt} after\n", total0, sum(X))
    printf("{txt}Cells changed: {res}%f{txt} of {res}%f{txt} non-zero; largest relative change {res}%9.3e\n",
           nchanged, sum(S0 :!= 0), maxrel)
    if (show & nchanged) {
        nshow = min((10, nchanged))
        top = order(d, -1)
        top = top[|1 \ nshow|]
        j = ceil(top :/ n)
        i = top - (j :- 1) :* n
        printf("\n{txt}Largest changes\n")
        printf("{txt}{space 2}%-20s %-20s %14s %14s %10s\n", "row", "column", "before", "after", "change %")
        for (k = 1; k <= nshow; k++) {
            printf("{txt}{space 2}%-20s %-20s {res}%14.6g %14.6g %10.3f\n", abbrev(L[i[k]], 20), abbrev(L[j[k]], 20),
                   S0[i[k], j[k]], X[i[k], j[k]], 100 * (X[i[k], j[k]] / S0[i[k], j[k]] - 1))
        }
        printf("\n")
    }
    _cge_sam_start(L, X, 0, "Balanced SAM")
    st_numscalar("r(iterations)", it)
    st_numscalar("r(maxdiff_before)", before)
    st_numscalar("r(total_before)", total0)
    st_numscalar("r(N_changed)", nchanged)
    st_numscalar("r(maxrelchange)", maxrel)
    st_global("r(method)", method)
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
              string scalar stocks, string scalar insurance, string scalar reportfile,
              real scalar replace, | string scalar vattax, string scalar vatshare, string scalar domm,
              string scalar impm, string scalar expm)
{
    struct cge_model scalar M
    real colvector role, iA, iC, imarg, iterr, istk, ishi, mapped, restc
    real rowvector hcons, rest, share
    real scalar ct, at, timp, texp, negsales, negtotal
    real matrix allowed, negok, transfers, S, issues
    string rowvector rolename, taxname
    real scalar i, j, k, tol, nacc, rr, rc, x
    string colvector taxacc, labels
    real colvector taxidx, direct, payers, taxrole, rwidx, vshare

    M = _cge_load()
    M.labels = M.labels0
    M.S = M.S0
    S = M.S
    nacc = rows(M.labels)
    rolename = ("activity", "commodity", "factor", "household", "government",
                "savings-investment", "rest of world", "direct tax", "sales tax",
                "import tax", "export tax", "activity tax", "enterprise", "margin account",
                "insurance fund", "VAT account", "unmapped")
    // Role codes of the tax accounts, and the entries of M.rewritten for taxes
    // paid directly to the government (VAT from version 0.3.1)
    taxrole = (8 \ 9 \ 10 \ 11 \ 12 \ 16)
    rwidx = (2 \ 3 \ 4 \ 5 \ 6 \ 11)

    M.iA = _cge_lookup(M, acts, "activity")
    M.iC = _cge_lookup(M, coms, "commodity")
    M.iF = _cge_lookup(M, facs, "factor")
    M.iH = _cge_lookup(M, hhs, "household")
    M.iE = _cge_lookup(M, ents, "enterprise")
    // Margin accounts: per unit of composite supply, then (from version 0.3.2)
    // per unit of domestic sales, imports and exports, with their market in tmkt
    M.iT = _cge_lookup(M, margacc, "margin account")
    M.tmkt = J(rows(M.iT), 1, 0)
    k = rows(M.iT)
    M.iT = M.iT \ _cge_lookup(M, domm, "domestic margin account")
    M.tmkt = M.tmkt \ J(rows(M.iT) - k, 1, 1)
    k = rows(M.iT)
    M.iT = M.iT \ _cge_lookup(M, impm, "import margin account")
    M.tmkt = M.tmkt \ J(rows(M.iT) - k, 1, 2)
    k = rows(M.iT)
    M.iT = M.iT \ _cge_lookup(M, expm, "export margin account")
    M.tmkt = M.tmkt \ J(rows(M.iT) - k, 1, 3)
    M.igov = _cge_lookup(M, gov, "government")
    M.isav = _cge_lookup(M, sav, "savings-investment")
    M.irow = _cge_lookup(M, row, "rest of world")
    ishi = _cge_lookup(M, insurance, "health insurance fund")
    if (rows(ishi) > 1) _cge_fail("insurance() takes one account", 198)
    M.ishi = (rows(ishi) ? ishi[1] : 0)
    taxacc = (dirtax \ saltax \ imptax \ exptax \ acttax \ vattax)
    taxidx = J(6, 1, 0)
    for (k = 1; k <= 6; k++) {
        if (taxacc[k] != "") taxidx[k] = _cge_lookup(M, taxacc[k], rolename[taxrole[k]])
    }
    if (vattax != "" & vatshare != "") _cge_fail("give either vattax() or vatshare(), not both", 198)

    if (rows(M.iC) < rows(M.iA)) {
        _cge_fail("each activity needs a paired commodity: list the commodities paired with the " +
                  "activities first, in the same order, then any commodities without a paired activity", 198)
    }

    // Layouts rewritten before the checks (model_spec.md, Section 7.0):
    // exports recorded as sales by activities, and taxes paid directly to the
    // government account, which are routed through internal tax accounts.
    direct = (taxidx :== M.igov)
    if (sum(direct[(2, 3, 4, 6)]) > 1) {
        _cge_fail("only one of saltax(), imptax(), exptax() and vattax() may name the government account", 198)
    }
    labels = M.labels0
    M.rewritten = J(1, 12, 0)
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
        mapped = M.iA \ M.iC \ M.iF \ M.iH \ M.iE \ M.iT \ M.igov \ M.isav \ M.irow \ ishi \
                 select(taxidx, taxidx :> 0)
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
        mapped = M.iA \ M.iC \ M.iF \ M.iH \ M.iE \ M.iT \ M.igov \ M.isav \ M.irow \ ishi \
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
    taxname = ("dirtax", "saltax", "imptax", "exptax", "acttax", "vattax")
    for (k = 1; k <= 6; k++) {
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
        M.rewritten[rwidx[k]] = sum(S[nacc + 1, .])
    }
    // VAT recorded within the sales tax (model_spec.md, 12.2): the given share
    // of each commodity's sales tax is moved to an internal account _vatshare
    if (vatshare != "") {
        if (taxidx[2] == 0) _cge_fail("vatshare() needs a sales tax account: give saltax()", 198)
        if (_cge_find(labels, "_vatshare")) _cge_fail("the SAM already has an account named _vatshare", 198)
        vshare = _cge_shares(vatshare, labels[M.iC], 0, "vatshare")
        nacc = rows(labels)
        S = (S, J(nacc, 1, 0)) \ J(1, nacc + 1, 0)
        labels = labels \ "_vatshare"
        S[nacc + 1, M.iC'] = vshare' :* S[taxidx[2], M.iC']
        S[taxidx[2], M.iC'] = S[taxidx[2], M.iC'] - S[nacc + 1, M.iC']
        x = sum(S[nacc + 1, .])
        S[M.igov, nacc + 1] = x
        S[M.igov, taxidx[2]] = S[M.igov, taxidx[2]] - x
        taxidx[6] = nacc + 1
        M.rewritten[12] = x
    }
    M.labels = labels
    M.S = S
    nacc = rows(labels)
    M.idirtax = taxidx[1]
    M.isaltax = taxidx[2]
    M.iimptax = taxidx[3]
    M.iexptax = taxidx[4]
    M.iacttax = taxidx[5]
    M.ivattax = taxidx[6]
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
    _cge_assign(M, role, ishi, 15, rolename)
    for (k = 1; k <= 6; k++) if (taxidx[k] > 0) _cge_assign(M, role, taxidx[k], taxrole[k], rolename)

    // Accounts without a role get code 17 ("unmapped"); every problem found
    // is collected as (problem code, row, column, value) and reported at the end:
    // 1 unmapped account with flows, 2 unsupported flow, 3 activity paid by a
    // commodity it is not paired with, 4 negative flow, 5 unbalanced account.
    role = role + 17 :* (role :== 0)
    issues = J(0, 4, .)
    tol = 1e-8 * max((1, max(abs(S))))
    for (i = 1; i <= nacc; i++) {
        if (role[i] == 17 & (max(abs(S[i, .])) > tol | max(abs(S[., i])) > tol)) {
            issues = issues \ (1, i, i, sum(S[i, .]))
        }
        if (abs(sum(S[i, .]) - sum(S[., i])) > tol) {
            issues = issues \ (5, i, i, sum(S[i, .]) - sum(S[., i]))
        }
    }

    // Supported flows (row role, column role); role 13 is an enterprise,
    // role 14 a margin account, role 15 a health insurance fund and role 16 a
    // VAT account
    allowed = J(17, 17, 0)
    allowed[1, 2] = 1
    allowed[2, 1] = 1; allowed[3, 1] = 1; allowed[12, 1] = 1
    allowed[7, 2] = 1; allowed[10, 2] = 1; allowed[9, 2] = 1; allowed[11, 2] = 1
    allowed[2, 4] = 1; allowed[2, 5] = 1; allowed[2, 6] = 1; allowed[2, 7] = 1
    allowed[4, 3] = 1; allowed[13, 3] = 1; allowed[5, 3] = 1; allowed[7, 3] = 1
    allowed[8, 4] = 1; allowed[6, 4] = 1; allowed[8, 13] = 1; allowed[6, 13] = 1
    allowed[5, 8] = 1; allowed[5, 9] = 1; allowed[5, 10] = 1; allowed[5, 11] = 1; allowed[5, 12] = 1
    allowed[6, 5] = 1; allowed[6, 7] = 1
    allowed[14, 2] = 1; allowed[2, 14] = 1
    allowed[15, 3] = 1; allowed[15, 5] = 1; allowed[15, 7] = 1; allowed[2, 15] = 1; allowed[6, 15] = 1
    allowed[16, 2] = 1; allowed[5, 16] = 1
    // home consumption: households pay activities (from version 0.3.2)
    allowed[1, 4] = 1
    // Transfers: among households and enterprises, from them to the rest of
    // the world, from government (to them, itself and abroad) and from the
    // rest of the world (to them, government and factors)
    transfers = J(17, 17, 0)
    transfers[(4, 13), (4, 13)] = J(2, 2, 1)
    transfers[7, (4, 13)] = J(1, 2, 1)
    transfers[(4, 13, 5, 7), 5] = J(4, 1, 1)
    transfers[(4, 13, 5, 3), 7] = J(4, 1, 1)
    allowed = allowed :| transfers
    // Cells that may be negative
    negok = transfers
    negok[(6, 8, 9, 10, 11, 12, 16), .] = J(7, 17, 1)
    negok[5, (8, 9, 10, 11, 12, 16)] = J(1, 6, 1)
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
    if (M.ishi) M.I = M.I \ M.labels[M.ishi]
    M.n = rows(M.iA)
    M.nC = rows(M.iC)
    M.nF = rows(M.iF)
    M.nH = rows(M.iH)
    M.nE = rows(M.iE)
    M.nD = M.nH + M.nE
    M.nI = M.nD + 2 + (M.ishi > 0)
    M.mapped = 1
    M.calibrated = 0
    _cge_store(M)
    printf("{txt}Accounts mapped: {res}%f{txt} activities, {res}%f{txt} commodities, {res}%f{txt} factors, {res}%f{txt} households, {res}%f{txt} enterprises, {res}%f{txt} margin accounts\n",
           M.n, M.nC, M.nF, M.nH, M.nE, rows(M.iT))
    if (M.ishi) printf("{txt}Health insurance fund: {res}%s\n", M.labels[M.ishi])
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
    if (cols(M.rewritten) >= 12) {
        if (_cge_find(M.labels, "_vattax")) {
            printf("{txt}VAT paid to government, routed through account _vattax: {res}%g\n", M.rewritten[11])
        }
        if (_cge_find(M.labels, "_vatshare")) {
            printf("{txt}VAT within the sales tax, moved to account _vatshare: {res}%g\n", M.rewritten[12])
        }
        st_numscalar("r(vat_moved)", M.rewritten[12])
    }
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
    real matrix IADJ, GADJ, WFDIST, WALRAS, QT, QER, YSHI, SHIADJ, QSHI, EFF, HS
    real matrix TQADJ, TMADJ, TVADJ, PWE, QHA, LSW, LSM
    real matrix qf, rho, cessum, q3, wage, pvaqva, lhs, rhs, yif, z, vint
    real colvector oneA, oneC, oneF, oneH, oneD, DY, rs, tq, tm, tv, PH, pwe, PDD, unemp, rwage, ub
    real rowvector SN
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
    QT = _cge_v(M, x, 43);    QER = _cge_v(M, x, 44);   YSHI = _cge_v(M, x, 45)
    SHIADJ = _cge_v(M, x, 46); QSHI = _cge_v(M, x, 47);  EFF = _cge_v(M, x, 48)
    HS = _cge_v(M, x, 49)
    TQADJ = _cge_v(M, x, 50); TMADJ = _cge_v(M, x, 51); TVADJ = _cge_v(M, x, 52)
    PWE = _cge_v(M, x, 53);   QHA = _cge_v(M, x, 54)
    LSW = _cge_v(M, x, 55);   LSM = _cge_v(M, x, 56)

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

    // Rates after scaling (from version 0.3.1); PH is the price paid by final
    // users, including VAT, and vint the VAT activities cannot recover
    tq = p.tq :* TQADJ
    tm = p.tm :* TMADJ
    tv = p.tv :* TVADJ
    PH = PQ :* (1 :+ tv)
    vint = tv * (1 :- p.kappa)'
    // World export prices: a variable where export demand is finite; the price
    // domestic buyers pay for domestic output, with domestic margins (13.2, 13.4)
    pwe = M.ced :* PWE + (1 :- M.ced) :* p.pwe
    PDD = PD + p.icd' * PQ

    // 5.1 Price block
    _cge_put(M, L, R, K, record, "P1", PM, p.pwm :* (1 :+ tm) :* EXR + p.ici' * PQ, M.cm)
    _cge_put(M, L, R, K, record, "P2", PE, pwe :* (1 :- p.te) :* EXR - p.ice' * PQ, M.ce)
    // p.icm' * PQ: cost of margin services per unit of composite supply
    _cge_put(M, L, R, K, record, "P3", PQ :* (1 :- tq) :* QQ,
             M.cdo :* PDD :* QD + M.cm :* PM :* QM + (p.icm' * PQ) :* QQ, M.cq)
    _cge_put(M, L, R, K, record, "P4", PX :* QX, M.cdo :* PD :* QD + M.ce :* PE :* QE, M.cx)
    _cge_put(M, L, R, K, record, "P5", PA, p.theta * PX, oneA)
    _cge_put(M, L, R, K, record, "P6", PINTA, (p.ica :* (1 :+ vint))' * PQ, oneA)
    _cge_put(M, L, R, K, record, "P7", PA :* (1 :- p.ta) :* QA, PVA :* QVA + PINTA :* QINTA, oneA)
    _cge_put(M, L, R, K, record, "P8", CPI, p.cwts' * PH, 1)
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
    // Factors in efficiency units (from version 0.1.14)
    z = p.af :* EFF
    qf = M.fa :* (z :* QF) + (1 :- M.fa)
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
    rhs = (pvaqva :/ cessum) :* p.dva :* (qf :^ (-rho :- 1)) :* z
    for (k = 1; k <= M.n; k++) {
        if (M.cd[k]) {
            lhs[., k] = wage[., k] :* QF[., k]
            rhs[., k] = p.dva[., k] :* pvaqva[k]
        }
    }
    _cge_put(M, L, R, K, record, "Q4", lhs, rhs, M.fa)
    // Health services and factor efficiency (from version 0.1.14)
    _cge_put(M, L, R, K, record, "H1", HS, sum(M.chs :* (rowsum(QH) + QG + QSHI)), any(p.etah))
    _cge_put(M, L, R, K, record, "H2", EFF, (HS / p.hs0) :^ p.etah, p.etah :!= 0)
    // Intermediate inputs and household purchases exist only where the SAM has a flow
    _cge_put(M, L, R, K, record, "Q5", QINT, p.ica :* QINTA', p.ica :!= 0)
    // Marketed output: home consumption does not reach the market (13.1)
    _cge_put(M, L, R, K, record, "Q6", QX, p.theta' * (QA - rowsum(QHA)), M.cx)

    // 5.3 Trade block
    _cge_put(M, L, R, K, record, "T1", QX,
             p.at :* (p.dt :* (QE :^ p.rt) + p.dtc :* (QD :^ p.rt)) :^ (1 :/ p.rt), M.ce :* (1 :- M.cxe))
    _cge_put(M, L, R, K, record, "T2", QE,
             QD :* (((PE :/ PD) :* p.dtc :/ p.dt) :^ (1 :/ (p.rt :- 1))), M.ce :* (1 :- M.cxe))
    _cge_put(M, L, R, K, record, "T3", QX, QD, M.cx :* (1 :- M.ce))
    _cge_put(M, L, R, K, record, "T3E", QX, QE, M.cxe)
    _cge_put(M, L, R, K, record, "T4", QQ,
             p.aq :* (p.dq :* (QM :^ (-p.rq)) + p.dqc :* (QD :^ (-p.rq))) :^ (-1 :/ p.rq), M.cm :* M.cdo)
    _cge_put(M, L, R, K, record, "T5", QM,
             QD :* (((PDD :/ PM) :* p.dq :/ p.dqc) :^ (1 :/ (1 :+ p.rq))), M.cm :* M.cdo)
    _cge_put(M, L, R, K, record, "T6", QQ, p.aq :* QD, M.cdo :* (1 :- M.cm))
    _cge_put(M, L, R, K, record, "T7", QQ, p.aq :* QM, M.cm :* (1 :- M.cdo))
    _cge_put(M, L, R, K, record, "T8", QT, p.icm * QQ + p.icd * QD + p.ici * QM + p.ice * QE, M.ct)
    _cge_put(M, L, R, K, record, "T9", QER, p.qer :* ((PQ :/ (EXR :* p.pwe)) :^ (-p.st)), M.cr)
    _cge_put(M, L, R, K, record, "T10", QE, p.qe0 :* ((PWE :/ p.pwe) :^ (-p.etae)), M.ced)

    // 5.4 Institution block. DY is income after direct taxes and savings.
    DY = (1 :- MPS) :* (1 :- TINS) :* YI
    _cge_put(M, L, R, K, record, "I1", YF, rowsum(wage :* QF) + p.trfr :* EXR, oneF)
    // Health insurance contributions are taken before factor income is distributed
    yif = p.shif :* ((1 :- p.tshi) :* YF)'
    if (M.ishi) yif[M.nI, .] = (p.tshi :* YF)'
    _cge_put(M, L, R, K, record, "I2", YIF, yif, J(M.nI, M.nF, 1))
    _cge_put(M, L, R, K, record, "I3", YI,
             rowsum(YIF[|1, 1 \ nD, M.nF|]) + p.shii * DY + p.trdg :* CPI + p.trdr :* EXR
             + p.hold :* (p.rd * p.ddebt), oneD)
    _cge_put(M, L, R, K, record, "I4", EH, p.hc :* DY[|1 \ nH|], oneH)
    // Supernumerary spending, counting home goods at PA (13.1)
    SN = EH' - PH' * p.gamma - PA' * p.gammah
    _cge_put(M, L, R, K, record, "I5", PH :* QH, PH :* p.gamma + p.beta :* SN, p.beta :!= 0)
    _cge_put(M, L, R, K, record, "I5H", PA :* QHA, PA :* p.gammah + p.betah :* SN, p.betah :!= 0)
    _cge_put(M, L, R, K, record, "I6", QINV, p.qinv :* IADJ, oneC)
    _cge_put(M, L, R, K, record, "I7", QG, p.qg :* GADJ, oneC)
    _cge_put(M, L, R, K, record, "I8", YG,
             TINS' * YI + sum(tq :* PQ :* QQ) + sum(tm :* p.pwm :* QM) * EXR
             + sum(p.te :* pwe :* QE) * EXR + sum(p.ta :* PA :* QA)
             + sum(tv :* PQ :* (rowsum(QH) + QG + QINV + QSHI + rowsum(QINT :* (1 :- p.kappa)')))
             + sum(YIF[nD + 1, .]) + p.trgr * EXR + p.trgg * CPI, 1)
    _cge_put(M, L, R, K, record, "I9", EG,
             PH' * QG + (sum(p.trdg) + p.trgg + p.trshi) * CPI + p.trrg * EXR
             + p.rd * p.ddebt + p.rf * p.fdebt * EXR, 1)
    _cge_put(M, L, R, K, record, "I10", TINS, p.tins0 :* TINSADJ, oneD)
    _cge_put(M, L, R, K, record, "I11", MPS, p.mps0 :* MPSADJ, oneD)
    // Health insurance fund (from version 0.1.13); the last institution
    _cge_put(M, L, R, K, record, "I12", YSHI,
             (M.ishi ? sum(YIF[M.nI, .]) : 0) + p.trshi * CPI + p.trshir * EXR, (M.ishi > 0))
    _cge_put(M, L, R, K, record, "I13", QSHI, p.qshi :* SHIADJ, M.cshi)
    _cge_put(M, L, R, K, record, "I14", PH' * QSHI, (1 - p.sshi) * YSHI, (M.ishi > 0))

    // Labour-market regimes (Section 14): the wage curve (L1) and the smoothed
    // minimum-wage condition (L2), inert unless the closure fixes their slack
    unemp = 1 :- QFS :/ p.qlf
    rwage = W :/ CPI
    _cge_put(M, L, R, K, record, "L1", rwage, p.wref :* ((unemp :/ p.u0) :^ (-p.epsw)) + LSW, p.inlf)
    ub = rwage :/ p.wmin :- 1
    _cge_put(M, L, R, K, record, "L2", unemp + ub - sqrt(unemp :^ 2 + ub :^ 2 :+ 2 * p.mu), LSM, p.inlf)

    // 5.5 System constraints (S6 is imposed through the closure)
    _cge_put(M, L, R, K, record, "S1", rowsum(M.fa :* QF), QFS, oneF)
    _cge_put(M, L, R, K, record, "S2", QQ,
             rowsum(QINT) + rowsum(QH) + QG + QINV + M.ct :* QT + M.cr :* QER + QSHI, M.cq)
    _cge_put(M, L, R, K, record, "S3",
             sum(p.pwm :* QM) + (sum(YIF[nD + 2, .]) + p.shir' * DY) / EXR + p.trrg + p.rf * p.fdebt,
             sum(pwe :* QE) + sum(M.cr :* PQ :* QER) / EXR + sum(p.trdr) + sum(p.trfr) + p.trgr
             + p.trshir + FSAV, 1)
    _cge_put(M, L, R, K, record, "S4", YG, EG + GSAV, 1)
    _cge_put(M, L, R, K, record, "S5", (MPS :* (1 :- TINS))' * YI + GSAV + p.sshi * YSHI + EXR * FSAV,
             PH' * QINV + WALRAS, 1)
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
                    string scalar s_ie, string scalar s_fr, string scalar s_a, string scalar s_hc,
                    string scalar s_hf, string scalar s_he, | string scalar s_vc, string scalar s_debt,
                    string scalar s_int, string scalar s_hold, string scalar s_borrow,
                    string scalar s_xo, string scalar s_ed, string scalar s_un, string scalar s_wc,
                    string scalar s_mw, string scalar s_mu)
{
    struct cge_model scalar M
    struct cge_par scalar p
    real matrix S, VA, QINT0, QF0, QFq, WFD0, dva, YIF0, QH0, w, TR, MAKE0, MG, SV
    real colvector sva, sq, st, QM0, cm, tariffs, tm, exports, ce, etax, te, QE0, pwe
    real colvector cx, ct, MGc, QT0, exported, cr, QER0, QSHI0, iI
    real rowvector spend
    real colvector QA0, ta, QX0, QD0, PM0, stax, QQ0, tq, demand, QINTA0, W0, QVA0
    real colvector cd, rva, ad, rt, dt, dtc, at, rq, dq, dqc, aq, YF0, YI0, tins0, mps0, EH0
    real colvector iD, dtax, dsav, DY0, TROW, cons, gross, safe
    real colvector m, d, num, x0, L, R, K, mag
    real matrix VINT, VH
    real colvector kappa, vg, vinv, vshi, vat, tv, PINTA0
    real matrix HOME0, share
    real colvector QAM0, cxe, ced, cdo, cq, eqo, netx, EMc, DMc, IMc, MGq, PDD0, etae, sel, cand
    real scalar nT
    real scalar n, nC, nF, nH, tol, k, r, ratio, total, maxres, YSHI0

    M = _cge_load()
    _cge_need(M, "mapped")
    // The options of this calibration, so that cge_sensitivity can repeat it
    // with other elasticities
    M.calargs = (s_va, s_q, s_t, fqname, s_ie, s_fr, s_a, s_hc, s_hf, s_he, s_vc, s_debt, s_int,
                 s_hold, s_borrow, s_xo, s_ed, s_un, s_wc, s_mw, s_mu)
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
    HOME0 = _cge_sub(S, M.iA, M.iH)                 // HOME0[a, h]: home consumption (13.1)
    if (max(abs(rowsum(MAKE0) + rowsum(HOME0) - QA0)) > tol) {
        _cge_fail("activity output does not equal its sales to commodities and home consumption", 459)
    }
    _cge_fail_if(rowsum(HOME0 :< -tol), M.labels[M.iA], "negative home consumption of the output of", 459)
    QAM0 = QA0 - rowsum(HOME0)
    _cge_fail_if(QAM0 :<= tol, M.labels[M.iA], "an activity needs some marketed output; all the output is consumed at home by", 459)
    p.theta = MAKE0 :/ QAM0
    QX0 = colsum(MAKE0)'
    cx = QX0 :> tol
    _cge_fail_if((1 :- cx) :* (1 :- cm), M.labels[M.iC], "a commodity has neither domestic output nor imports", 459)
    // Margins: MG[t, c] paid by commodity c to margin account t, SV[c, t]
    // margin services c bought by t; by market from version 0.3.2 (13.4)
    nT = rows(M.iT)
    if (nT) {
        MG = _cge_sub(S, M.iT, M.iC)
        SV = _cge_sub(S, M.iC, M.iT)
        QT0 = rowsum(SV)
        spend = colsum(SV)
        share = SV :/ (spend :* (spend :> tol) + (spend :<= tol))
    }
    else {
        MG = J(0, nC, 0)
        SV = J(nC, 0, 0)
        QT0 = J(nC, 1, 0)
        spend = J(1, 0, 0)
        share = J(nC, 0, 0)
    }
    if (rows(M.tmkt) != nT) M.tmkt = J(nT, 1, 0)
    MGq = (nT ? colsum(MG :* (M.tmkt :== 0))' : J(nC, 1, 0))
    DMc = (nT ? colsum(MG :* (M.tmkt :== 1))' : J(nC, 1, 0))
    IMc = (nT ? colsum(MG :* (M.tmkt :== 2))' : J(nC, 1, 0))
    EMc = (nT ? colsum(MG :* (M.tmkt :== 3))' : J(nC, 1, 0))
    // Export-only commodities (13.3), chosen with exportonly()
    cxe = J(nC, 1, 0)
    if (s_xo != "") {
        sel = _cge_elements(M.C, s_xo, "commodities")
        cxe[sel] = J(rows(sel), 1, 1)
    }
    netx = exports - etax - EMc
    eqo = exported :* cx :* (abs(QX0 - netx) :<= tol)
    _cge_fail_if(cxe :* (1 :- eqo), M.labels[M.iC],
                 "exportonly(): exports, net of export taxes and margins, must equal domestic output for", 459)
    // Exports at least as large as domestic output are drawn from composite
    // supply (CR, T9); other exports come from domestic output (CE, T1-T2)
    cr = exported :* ((QX0 - (exports - etax)) :<= tol) :* (1 :- cxe)
    _cge_fail_if(cr :* (abs(etax) :> tol), M.labels[M.iC],
                 "export tax recorded on a commodity whose exports are at least its domestic output (give it in exportonly() if all its output is exported)", 459)
    _cge_fail_if(cr :* (abs(EMc) :> tol), M.labels[M.iC],
                 "export margins recorded on a commodity whose exports are drawn from composite supply", 459)
    ce = exported :* (1 :- cr)
    te = ce :* etax :/ (ce :* exports + (1 :- ce))
    QE0 = ce :* netx
    QER0 = cr :* exports
    pwe = ce :* (exports :/ (QE0 + (1 :- ce))) + (1 :- ce) :* (1 :/ (1 :- te))
    cdo = cx :* (1 :- cxe)
    QD0 = cdo :* (QX0 - QE0)
    _cge_fail_if(cdo :* (QD0 :<= tol), M.labels[M.iC],
                 "a commodity with domestic output needs positive domestic sales (unless all its output is exported: see exportonly())", 459)
    _cge_fail_if((abs(DMc) :> tol) :* (QD0 :<= tol), M.labels[M.iC], "margins on domestic sales recorded on a commodity without domestic sales", 459)
    _cge_fail_if((abs(IMc) :> tol) :* (QM0 :<= tol), M.labels[M.iC], "margins on imports recorded on a commodity without imports", 459)
    _cge_fail_if((abs(EMc) :> tol) :* (QE0 :<= tol), M.labels[M.iC], "margins on exports recorded on a commodity without exports", 459)
    if (nT) {
        p.icd = (share * (MG :* (M.tmkt :== 1))) :/ (QD0' + (QD0' :<= tol))
        p.ici = (share * (MG :* (M.tmkt :== 2))) :/ (QM0' + (QM0' :<= tol))
        p.ice = (share * (MG :* (M.tmkt :== 3))) :/ (QE0' + (QE0' :<= tol))
    }
    else {
        p.icd = J(nC, nC, 0)
        p.ici = J(nC, nC, 0)
        p.ice = J(nC, nC, 0)
    }
    PM0 = cm :* (1 :+ tm :+ colsum(p.ici)')
    PDD0 = 1 :+ colsum(p.icd)'
    stax = _cge_sub(S, M.isaltax, M.iC)'
    QQ0 = PDD0 :* QD0 + PM0 :* QM0 + stax + MGq
    cq = cdo :| cm
    tq = cq :* stax :/ (cq :* QQ0 + (1 :- cq))
    ct = QT0 :> tol
    if (nT) p.icm = (share * (MG :* (M.tmkt :== 0))) :/ (cq' :* QQ0' + (1 :- cq'))
    else p.icm = J(nC, nC, 0)
    // Export demand (13.2): finite elasticities for the commodities given
    etae = J(nC, 1, 0)
    if (s_ed != "") {
        if (!strpos(s_ed, ":") & cols(tokens(s_ed)) == 1) etae = ce :* strtoreal(s_ed)
        else {
            sel = J(0, 1, .)
            etae = _cge_values(s_ed, M.C, 0, "exportdemand")
        }
        _cge_fail_if((etae :!= 0) :* (1 :- ce), M.labels[M.iC], "exportdemand(): no exports from domestic output for", 459)
        if (hasmissing(etae) | min(etae) < 0) _cge_fail("exportdemand() elasticities must be positive", 198)
    }
    ced = (etae :> 0)
    // Commodities whose exports equal domestic output, which could be export-only
    cand = eqo :* (1 :- cxe)
    if (any(cand)) {
        printf("{txt}Note: exports equal domestic output for {res}%s{txt}; give exportonly() to export their output directly\n",
               invtokens(select(M.labels[M.iC], cand)'))
    }
    // VAT (model_spec.md, 12.2): rates from the VAT account, then the quantity
    // of each use at PQ = 1
    kappa = _cge_shares(s_vc, M.A, 1, "vatcredit")
    if (s_vc != "" & !(M.ivattax > 0 & M.ivattax < .)) _cge_fail("vatcredit() needs a VAT account: map one with cge_map, vattax() or vatshare()", 198)
    VINT = _cge_sub(S, M.iC, M.iA)
    VH = _cge_sub(S, M.iC, M.iH)
    vg = _cge_sub(S, M.iC, M.igov)
    vinv = _cge_sub(S, M.iC, M.isav)
    vshi = (M.ishi ? _cge_sub(S, M.iC, M.ishi) : J(nC, 1, 0))
    vat = ((M.ivattax > 0 & M.ivattax < .) ? _cge_sub(S, M.ivattax, M.iC)' : J(nC, 1, 0))
    tv = J(nC, 1, 0)
    for (k = 1; k <= nC; k++) {
        if (abs(vat[k]) <= tol) continue
        tv[k] = _cge_vat_rate(vat[k], (VINT[k, .], VH[k, .], vg[k], vinv[k], vshi[k])',
                              ((1 :- kappa)', J(1, nH + 3, 1))', M.labels[M.iC[k]])
    }
    QINT0 = VINT :/ (1 :+ tv * (1 :- kappa)')
    QH0 = VH :/ (1 :+ tv)
    QSHI0 = vshi :/ (1 :+ tv)
    p.qg = vg :/ (1 :+ tv)
    p.qinv = vinv :/ (1 :+ tv)
    demand = rowsum(QINT0) + rowsum(QH0) + p.qg + p.qinv + QT0 + QER0 + QSHI0
    if (max(abs(QQ0 - demand)) > tol) _cge_fail("composite supply does not equal domestic demand for some commodity", 459)

    // 7.3 Production
    QINTA0 = colsum(QINT0)'
    p.ica = QINT0 :/ (QINTA0' + (QINTA0' :<= 0))
    PINTA0 = colsum(p.ica :* (1 :+ tv * (1 :- kappa)'))'
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
    _cge_topnest(M, p, s_a, QA0, QVA0, QINTA0, PINTA0)

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
        if (!ce[k] | cxe[k]) continue
        r = rt[k]
        ratio = (QE0[k] / QD0[k])^(r - 1)
        dt[k] = 1 / (1 + ratio)
        dtc[k] = ratio / (1 + ratio)
        at[k] = QX0[k] / (dt[k] * QE0[k]^r + dtc[k] * QD0[k]^r)^(1 / r)
    }
    if (max(cm :* cdo :* (abs(sq :- 1) :< 1e-12))) _cge_fail("version 0.1 needs sigmaq different from 1 for imported commodities", 198)
    rq = 1 :/ sq :- 1
    dq = J(nC, 1, 0.5)
    dqc = J(nC, 1, 0.5)
    // non-imported commodities (T6) and commodities imported only (T7)
    aq = cdo :* (QQ0 :/ (QD0 + (1 :- cdo))) + (1 :- cdo) :* (cm :* (QQ0 :/ (QM0 + (1 :- cm))) + (1 :- cm))
    for (k = 1; k <= nC; k++) {
        if (!cm[k] | !cdo[k]) continue
        r = rq[k]
        ratio = (PM0[k] / PDD0[k]) * (QM0[k] / QD0[k])^(1 + r)
        dq[k] = ratio / (1 + ratio)
        dqc[k] = 1 / (1 + ratio)
        aq[k] = QQ0[k] / (dq[k] * QM0[k]^(-r) + dqc[k] * QD0[k]^(-r))^(-1 / r)
    }

    // 7.5 Institutions (D = households, then enterprises)
    iD = M.iH \ M.iE
    YF0 = rowsum(S[M.iF, .])
    iI = iD \ M.igov \ M.irow
    if (M.ishi) iI = iI \ M.ishi
    YIF0 = _cge_sub(S, iI, M.iF)
    if (max(abs(colsum(YIF0)' - YF0)) > tol) _cge_fail("factor income paid out does not equal factor income received", 459)
    // Health insurance contributions as a rate on factor income
    if (M.ishi) {
        p.tshi = YIF0[M.nI, .]' :/ (YF0 + (YF0 :== 0))
        if (max(p.tshi) >= 1) _cge_fail("health insurance contributions take all the income of a factor", 459)
    }
    else p.tshi = J(nF, 1, 0)
    p.shif = YIF0 :/ ((1 :- p.tshi) :* YF0)'
    if (M.ishi) p.shif[M.nI, .] = J(1, nF, 0)
    p.trfr = _cge_sub(S, M.iF, M.irow)
    YI0 = rowsum(S[iD, .])
    dtax = _cge_sub(S, M.idirtax, iD)'
    dsav = _cge_sub(S, M.isav, iD)'
    tins0 = dtax :/ YI0
    mps0 = dsav :/ ((1 :- tins0) :* YI0)
    DY0 = YI0 - dtax - dsav
    TR = _cge_sub(S, iD, iD)
    TROW = _cge_sub(S, M.irow, iD)'
    EH0 = colsum(VH)' + colsum(HOME0)'
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
    p.beta = VH :/ (EH0' :* (EH0' :> 0) + (EH0' :<= 0))
    p.betah = HOME0 :/ (EH0' :* (EH0' :> 0) + (EH0' :<= 0))
    p.gammah = J(rows(HOME0), cols(HOME0), 0)
    // Household demand: Cobb-Douglas (gamma = 0), or LES given income
    // elasticities and Frisch parameters (model_spec.md, 7.5)
    p.gamma = J(rows(QH0), cols(QH0), 0)
    if (s_ie != "" | s_fr != "") _cge_les(p, QH0, EH0, s_ie, s_fr, M.nC, nH, 1 :+ tv, HOME0)
    p.trdg = _cge_sub(S, iD, M.igov)
    p.trdr = _cge_sub(S, iD, M.irow)
    p.trgr = S[M.igov, M.irow]
    p.trrg = S[M.irow, M.igov]
    p.trgg = S[M.igov, M.igov]
    // Health insurance fund: purchases, savings rate and transfers received
    p.qshi = QSHI0
    YSHI0 = (M.ishi ? sum(S[M.ishi, .]) : 0)
    if (M.ishi & YSHI0 <= tol) _cge_fail("the health insurance fund has no revenue", 459)
    p.sshi = (M.ishi ? S[M.isav, M.ishi] / YSHI0 : 0)
    p.trshi = (M.ishi ? S[M.ishi, M.igov] : 0)
    p.trshir = (M.ishi ? S[M.ishi, M.irow] : 0)
    M.cshi = (QSHI0 :!= 0)
    _cge_health(M, p, QH0, QSHI0, s_hc, s_hf, s_he)
    p.cwts = rowsum(VH) :/ sum(VH) :/ (1 :+ tv)
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
    p.tv = tv
    p.kappa = kappa
    p.etae = etae
    p.qe0 = QE0
    M.cxe = cxe
    M.ced = ced
    M.cdo = cdo
    M.cq = cq
    // Public debt (model_spec.md, 12.3): interest separated from government transfers
    _cge_debt(M, p, s_debt, s_int, s_hold, s_borrow, tol)
    // Labour force, wage curve and minimum wage (model_spec.md, Section 14)
    _cge_labour(M, p, s_un, s_wc, s_mw, s_mu, W0, p.cwts' * (1 :+ tv), rowsum(QF0))
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
    _cge_setv(M, x0, "PINTA", PINTA0)
    _cge_setv(M, x0, "PX", J(nC, 1, 1))
    _cge_setv(M, x0, "PD", J(nC, 1, 1))
    _cge_setv(M, x0, "PE", ce)
    _cge_setv(M, x0, "PM", PM0)
    _cge_setv(M, x0, "PQ", J(nC, 1, 1))
    _cge_setv(M, x0, "W", W0)
    _cge_setv(M, x0, "EXR", 1)
    _cge_setv(M, x0, "CPI", p.cwts' * (1 :+ tv))
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
    _cge_setv(M, x0, "EG", sum(vg) + sum(_cge_sub(S, iD, M.igov)) + p.trgg + S[M.irow, M.igov] + p.trshi)
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
    _cge_setv(M, x0, "YSHI", YSHI0)
    _cge_setv(M, x0, "SHIADJ", 1)
    _cge_setv(M, x0, "QSHI", QSHI0)
    _cge_setv(M, x0, "EFF", J(nF, 1, 1))
    _cge_setv(M, x0, "HS", p.hs0)
    _cge_setv(M, x0, "TQADJ", 1)
    _cge_setv(M, x0, "TMADJ", 1)
    _cge_setv(M, x0, "TVADJ", 1)
    _cge_setv(M, x0, "PWE", pwe)
    _cge_setv(M, x0, "QHA", HOME0)
    _cge_setv(M, x0, "LSW", J(nF, 1, 0))
    _cge_setv(M, x0, "LSM", _cge_lsm0(p, rowsum(QF0)))
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
    _cge_setv(M, M.exists, "PD", cdo)
    _cge_setv(M, M.exists, "QX", cx)
    _cge_setv(M, M.exists, "QD", cdo)
    _cge_setv(M, M.exists, "PQ", cq)
    _cge_setv(M, M.exists, "QQ", cq)
    _cge_setv(M, M.exists, "PWE", ced)
    _cge_setv(M, M.exists, "QHA", HOME0 :!= 0)
    _cge_setv(M, M.exists, "QT", ct)
    _cge_setv(M, M.exists, "QER", cr)
    _cge_setv(M, M.exists, "QINT", QINT0 :!= 0)
    _cge_setv(M, M.exists, "QH", QH0 :!= 0)
    _cge_setv(M, M.exists, "YSHI", (M.ishi > 0))
    _cge_setv(M, M.exists, "SHIADJ", (M.ishi > 0))
    _cge_setv(M, M.exists, "QSHI", M.cshi)
    _cge_setv(M, M.exists, "EFF", p.etah :!= 0)
    _cge_setv(M, M.exists, "HS", any(p.etah))
    _cge_setv(M, M.exists, "LSW", p.inlf)
    _cge_setv(M, M.exists, "LSM", p.inlf)

    M.nominal = J(total, 1, 0)
    for (k = 1; k <= rows(M.vname); k++) {
        if (anyof(("PA","PVA","PINTA","PX","PD","PE","PM","PQ","W","EXR","CPI","DPI",
                   "YF","YIF","YI","EH","YG","EG","GSAV","WALRAS","YSHI"), M.vname[k])) {
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
    M.simrun = J(0, 1, "")
    M.simper = J(0, 1, .)
    M.simlam = J(0, 1, .)
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

// Factor efficiency (model_spec.md, 5.2 and 7.3): af = 1 and, given health
// commodities and elasticities, EFF_f = (HS / HS0)^eta_f. Elasticities are one
// value for every factor in healthfac() (all factors by default) or one each.
void _cge_health(struct cge_model scalar M, struct cge_par scalar p, real matrix QH0, real colvector QSHI0,
                 string scalar s_hc, string scalar s_hf, string scalar s_he)
{
    real colvector idx, f, eta
    real rowvector v
    real scalar hs0
    M.chs = J(M.nC, 1, 0)
    if (s_hc != "") {
        idx = _cge_elements(M.C, s_hc, "commodities")
        M.chs[idx] = J(rows(idx), 1, 1)
    }
    eta = J(M.nF, 1, 0)
    if (s_he != "") {
        if (s_hc == "") _cge_fail("healthelas() needs healthcom(): name the health services", 198)
        if (s_hf == "") f = (1::M.nF)
        else f = _cge_elements(M.F, s_hf, "factors")
        v = strtoreal(tokens(s_he))
        if (cols(v) == 1) v = J(1, rows(f), v)
        if (cols(v) != rows(f)) {
            errprintf("healthelas() needs 1 or %f values\n", rows(f))
            exit(198)
        }
        if (hasmissing(v) | min(v) < 0) _cge_fail("healthelas() values must be zero or positive", 198)
        eta[f] = v'
    }
    else if (s_hf != "") _cge_fail("healthfac() needs healthelas()", 198)
    hs0 = sum(M.chs :* (rowsum(QH0) + p.qg + QSHI0))
    if (any(eta) & hs0 <= 0) {
        _cge_fail("health services have no consumption by households, the government or the health insurance fund", 459)
    }
    p.af = J(M.nF, 1, 1)
    p.etah = eta
    p.hs0 = (any(eta) ? hs0 : 1)
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

// Shares by element of a set, as "label:share ..." or one number for all,
// between 0 and 1; dflt for elements not listed
real colvector _cge_shares(string scalar spec, string colvector set, real scalar dflt, string scalar name)
{
    real colvector out
    string rowvector tok
    real scalar k, pos, i, v
    out = J(rows(set), 1, dflt)
    tok = tokens(spec)
    if (cols(tok) == 1 & !strpos(spec, ":")) out = J(rows(set), 1, strtoreal(tok[1]))
    else {
        for (k = 1; k <= cols(tok); k++) {
            pos = strpos(tok[k], ":")
            if (!pos) _cge_fail(name + "() entries take the form label:share, or give one share for all", 198)
            i = _cge_find(set, substr(tok[k], 1, pos - 1))
            if (!i) _cge_fail(name + "(): " + substr(tok[k], 1, pos - 1) + " is not one of the model's accounts of that kind", 111)
            v = strtoreal(substr(tok[k], pos + 1, .))
            out[i] = v
        }
    }
    if (hasmissing(out) | min(out) < 0 | max(out) > 1) _cge_fail(name + "() shares must lie between 0 and 1", 198)
    return(out)
}

// Values by element of a set, as "label:value ..."; dflt for elements not listed
real colvector _cge_values(string scalar spec, string colvector set, real scalar dflt, string scalar name)
{
    real colvector out
    string rowvector tok
    real scalar k, pos, i
    out = J(rows(set), 1, dflt)
    tok = tokens(spec)
    for (k = 1; k <= cols(tok); k++) {
        pos = strpos(tok[k], ":")
        if (!pos) _cge_fail(name + "() entries take the form label:value, or give one value for all", 198)
        i = _cge_find(set, substr(tok[k], 1, pos - 1))
        if (!i) _cge_fail(name + "(): " + substr(tok[k], 1, pos - 1) + " is not one of the model's accounts of that kind", 111)
        out[i] = strtoreal(substr(tok[k], pos + 1, .))
    }
    return(out)
}

// VAT rate tv such that v' (tv liab / (1 + tv liab)) = vat (model_spec.md,
// 12.2), by Newton's method from the first-order value
real scalar _cge_vat_rate(real scalar vat, real colvector v, real colvector liab, string scalar label)
{
    real scalar base, tv, f, df, step, k
    base = v' * liab
    if (base == 0) _cge_fail("VAT is recorded on " + label + " but no use of it bears VAT", 459)
    tv = vat / base
    for (k = 1; k <= 100; k++) {
        f = v' * (tv :* liab :/ (1 :+ tv :* liab)) - vat
        df = v' * (liab :/ (1 :+ tv :* liab):^2)
        step = f / df
        tv = tv - step
        if (abs(step) <= 1e-15 * max((1, abs(tv)))) break
    }
    if (k > 100) _cge_fail("the VAT rate of " + label + " could not be calibrated", 430)
    if (min(1 :+ tv :* liab) <= 0) _cge_fail("the VAT rate of " + label + " is below -100 per cent", 459)
    return(tv)
}

// "domestic:# foreign:#" as (domestic, foreign)
real rowvector _cge_domfor(string scalar spec, string scalar name)
{
    real rowvector out
    string rowvector tok
    string scalar key
    real scalar k, pos
    out = (0, 0)
    tok = tokens(spec)
    for (k = 1; k <= cols(tok); k++) {
        pos = strpos(tok[k], ":")
        if (!pos) _cge_fail(name + "() entries take the form domestic:# and foreign:#", 198)
        key = strlower(substr(tok[k], 1, pos - 1))
        if (key == "domestic") out[1] = strtoreal(substr(tok[k], pos + 1, .))
        else if (key == "foreign") out[2] = strtoreal(substr(tok[k], pos + 1, .))
        else _cge_fail(name + "(): " + key + " is not domestic or foreign", 198)
    }
    if (hasmissing(out)) _cge_fail(name + "() needs numbers", 198)
    return(out)
}

// Public debt and interest (model_spec.md, 12.3): the base transfers from
// government are split into interest on the stated debt and other transfers
void _cge_debt(struct cge_model scalar M, struct cge_par scalar p, string scalar s_debt, string scalar s_int,
               string scalar s_hold, string scalar s_borrow, real scalar tol)
{
    real rowvector dbt, rate
    real colvector pos, hold, trdg, bad
    real scalar dd, df, rd, rf, trrg, phi

    p.debt = 0
    p.ddebt = 0
    p.fdebt = 0
    p.rd = 0
    p.rf = 0
    p.phi = 0
    p.hold = J(M.nD, 1, 0)
    if (s_debt == "" & s_int == "" & s_hold == "" & s_borrow == "") return
    dbt = _cge_domfor(s_debt, "debt")
    rate = _cge_domfor(s_int, "interest")
    dd = dbt[1]
    df = dbt[2]
    rd = rate[1]
    rf = rate[2]
    if (min(dbt) < 0 | min(rate) <= -1) _cge_fail("debt must be non-negative and interest rates above -1", 198)
    if (s_hold == "") {
        pos = p.trdg :* (p.trdg :> 0)
        if (rd * dd != 0 & sum(pos) <= 0) _cge_fail("the government makes no transfers to domestic institutions; give the debt holders with debtholders()", 459)
        hold = (sum(pos) > 0 ? pos :/ sum(pos) : J(M.nD, 1, 0))
    }
    else {
        hold = _cge_shares(s_hold, M.D, 0, "debtholders")
        if (abs(sum(hold) - 1) > 1e-12) _cge_fail("debtholders() shares must sum to one", 198)
    }
    trdg = p.trdg - hold :* (rd * dd)
    trrg = p.trrg - rf * df
    bad = trdg :< -tol
    _cge_fail_if(bad, M.D, "government transfers are smaller than the interest on the stated debt for", 459)
    if (trrg < -tol) _cge_fail("government transfers to the rest of the world are smaller than the interest on the stated foreign debt", 459)
    if (s_borrow == "") phi = (dd + df > 0 ? df / (dd + df) : 0)
    else {
        phi = strtoreal(s_borrow)
        if (phi >= . | phi < 0 | phi > 1) _cge_fail("foreignborrowing() must lie between 0 and 1", 198)
    }
    p.trdg = trdg
    p.trrg = trrg
    p.debt = 1
    p.ddebt = dd
    p.fdebt = df
    p.rd = rd
    p.rf = rf
    p.hold = hold
    p.phi = phi
    printf("{txt}Public debt: {res}%g{txt} at home at {res}%g{txt}, {res}%g{txt} abroad at {res}%g{txt}; interest of {res}%g{txt} separated from government transfers\n",
           dd, rd, df, rf, rd * dd + rf * df)
}

// Values given as "label:value ..." for some elements of a set, and which
// elements are given
real colvector _cge_given(string scalar spec, string colvector set, string scalar name, real colvector given)
{
    real colvector out
    out = _cge_values(spec, set, ., name)
    given = (out :< .)
    if (sum(given) != cols(tokens(spec))) _cge_fail(name + "() needs one number for each factor given", 198)
    return(out)
}

// Labour force, wage curve and minimum wage (model_spec.md, Section 14): the
// labour force from the base unemployment rate; with unemployment in the base
// the floor binds at the base real wage, and with full employment it is a share
// of the base real wage
void _cge_labour(struct cge_model scalar M, struct cge_par scalar p, string scalar s_un, string scalar s_wc,
                 string scalar s_mw, string scalar s_mu, real colvector W0, real scalar CPI0,
                 real colvector QFS0)
{
    real colvector un, wc, mw, gun, gwc, gmw, inlf, wref
    real scalar nF, k, u, r, mu
    string scalar f

    nF = M.nF
    mu = (strtrim(s_mu) == "" ? 1e-10 : strtoreal(s_mu))
    if (mu >= . | mu <= 0) _cge_fail("smoothing() must be positive", 198)
    un = _cge_given(s_un, M.F, "unemployment", gun)
    wc = _cge_given(s_wc, M.F, "wagecurve", gwc)
    mw = _cge_given(s_mw, M.F, "minwage", gmw)
    for (k = 1; k <= nF; k++) {
        if (gwc[k] & !(gun[k] & un[k] > 0)) _cge_fail("wagecurve(): " + M.F[k] + " needs unemployment in the base: give it in unemployment()", 198)
    }
    inlf = gun :| gmw
    wref = W0 :/ CPI0
    p.inlf = inlf
    p.qlf = QFS0
    p.u0 = J(nF, 1, 1)
    p.epsw = J(nF, 1, 0)
    p.wref = wref
    p.wmin = wref
    p.hasmin = J(nF, 1, 0)
    p.mu = mu
    for (k = 1; k <= nF; k++) {
        if (!inlf[k]) continue
        f = M.F[k]
        u = (gun[k] ? un[k] : 0)
        if (!(u >= 0 & u < 1)) _cge_fail("unemployment(): the rate of " + f + " must be at least 0 and below 1", 198)
        if (gmw[k]) {
            r = mw[k]
            p.hasmin[k] = 1
            if (u > 0) {
                if (abs(r - 1) > 1e-12) _cge_fail("minwage(): with unemployment of " + f + " in the base, the floor is the base wage (" + f + ":1)", 198)
                p.wmin[k] = wref[k] / (1 + mu / u)
            }
            else {
                if (!(r > 0 & r < 1)) _cge_fail("minwage(): with full employment of " + f + " in the base, the floor must be below the base wage", 198)
                p.wmin[k] = r * wref[k]
                u = mu / (1 / r - 1)
            }
        }
        else if (u > 0) {
            // by default the floor is the base wage
            p.hasmin[k] = 1
            p.wmin[k] = wref[k] / (1 + mu / u)
        }
        if (gwc[k]) {
            if (!(wc[k] > 0)) _cge_fail("wagecurve(): the elasticity of " + f + " must be positive", 198)
            p.epsw[k] = wc[k]
        }
        if (!(u > 0)) _cge_fail(f + ": a labour force needs unemployment in the base or a minimum wage", 198)
        p.u0[k] = u
        p.qlf[k] = QFS0[k] / (1 - u)
    }
    for (k = 1; k <= nF; k++) {
        if (!inlf[k]) continue
        printf("{txt}Labour force of {res}%s{txt}: {res}%g{txt}; base unemployment rate {res}%g{txt}", M.F[k], p.qlf[k], p.u0[k])
        if (p.epsw[k] > 0) printf("{txt}; wage-curve elasticity {res}%g", p.epsw[k])
        printf("{txt}; real minimum wage {res}%g{txt} (base real wage %g)\n", p.wmin[k], p.wref[k])
    }
}

// Base value of the slack of the minimum-wage condition (L2)
real colvector _cge_lsm0(struct cge_par scalar p, real colvector QFS0)
{
    real colvector a, b
    a = 1 :- QFS0 :/ p.qlf
    b = p.wref :/ p.wmin :- 1
    return(p.inlf :* (a + b - sqrt(a :^ 2 + b :^ 2 :+ 2 * p.mu)))
}

void _cge_les(struct cge_par scalar p, real matrix QH0, real colvector EH0, string scalar s_ie,
              string scalar s_fr, real scalar nC, real scalar nH, real colvector ph0, real matrix QHA0)
{
    real colvector ie, fr
    real rowvector total
    real matrix b, bh
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
    // Home consumption of activity a takes the income elasticity of its paired
    // commodity, the a-th commodity (13.1)
    bh = ie[|1 \ rows(p.betah)|] :* p.betah
    total = colsum(b) + colsum(bh)
    p.beta = b :/ (total + (total :<= 0))
    p.betah = bh :/ (total + (total :<= 0))
    // Subsistence quantities at the prices final users pay (PH, with VAT)
    // (in Mata :/ binds more tightly than :*)
    p.gamma = QH0 + (p.beta :* (EH0' :/ fr')) :/ ph0
    p.gammah = QHA0 + p.betah :* (EH0' :/ fr')
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
    string rowvector tok, inst, adj
    string scalar instrument
    real colvector rates

    fixed = J(rows(M.x0), 1, 0)
    _cge_fix(M, fixed, "GADJ", 0)
    if (ext == "flexexr") _cge_fix(M, fixed, "FSAV", 0)
    else if (ext == "fixexr") _cge_fix(M, fixed, "EXR", 0)
    else _cge_fail("external() must be flexexr or fixexr", 198)
    // Government (model_spec.md, 12.1): with fixed savings, direct, sales,
    // import or VAT rates adjust; the other tax scaling factors are fixed
    inst = ("direct", "sales", "import", "vat")
    adj = ("TINSADJ", "TQADJ", "TMADJ", "TVADJ")
    tok = tokens(subinstr(gov, ":", " "))
    if (cols(tok) == 0) tok = "flexgsav"
    instrument = ""
    if (tok[1] == "flexgsav" & cols(tok) == 1) instrument = ""
    else if (tok[1] == "fixgsav" & cols(tok) <= 2) {
        instrument = (cols(tok) == 2 ? tok[2] : "direct")
        if (!anyof(inst, instrument)) _cge_fail("government(fixgsav " + instrument + "): the adjusting tax is direct, sales, import or vat", 198)
    }
    else _cge_fail("government() must be flexgsav, or fixgsav with direct, sales, import or vat", 198)
    for (k = 1; k <= 4; k++) if (inst[k] != instrument) _cge_fix(M, fixed, adj[k], 0)
    if (instrument != "") {
        _cge_fix(M, fixed, "GSAV", 0)
        rates = (instrument == "direct" ? M.p0.tins0 : (instrument == "sales" ? M.p0.tq :
                 (instrument == "import" ? M.p0.tm : M.p0.tv)))
        if (!any(rates)) _cge_fail("government(fixgsav " + instrument + "): that tax raises no revenue in the base", 459)
    }
    gov = (instrument == "" ? "flexgsav" : (instrument == "direct" ? "fixgsav" : "fixgsav:" + instrument))
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
        else if (fac[k] == "wagecurve" | fac[k] == "minwage") {
            // Labour-market regimes (model_spec.md, Section 14)
            if (!M.p0.inlf[k]) _cge_fail(M.F[k] + ": " + fac[k] + " needs a labour force: calibrate with unemployment() or minwage()", 459)
            if (fac[k] == "wagecurve" & !(M.p0.epsw[k] > 0)) _cge_fail(M.F[k] + ": the wage curve needs an elasticity: calibrate with wagecurve()", 459)
            if (fac[k] == "minwage" & !M.p0.hasmin[k]) _cge_fail(M.F[k] + ": give a minimum wage", 459)
            _cge_fix(M, fixed, "WFDIST", k)
            _cge_fix(M, fixed, (fac[k] == "wagecurve" ? "LSW" : "LSM"), k)
        }
        else _cge_fail("factor closure must be mobile, specific, unemployed, wagecurve or minwage", 198)
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
            if (pos == 0) _cge_fail("factors() entries take the form factor:mode, with mode mobile, specific, unemployed, wagecurve or minwage", 198)
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
    if (name == "tshi") return(p.tshi)
    if (name == "qshi") return(p.qshi)
    if (name == "trshi") return(p.trshi)
    if (name == "trshir") return(p.trshir)
    if (name == "af") return(p.af)
    if (name == "tv") return(p.tv)
    if (name == "kappa") return(p.kappa)
    if (name == "rd") return(p.rd)
    if (name == "rf") return(p.rf)
    if (name == "ddebt") return(p.ddebt)
    if (name == "fdebt") return(p.fdebt)
    if (name == "qlf") return(p.qlf)
    if (name == "wmin") return(p.wmin)
    if (name == "wref") return(p.wref)
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
    else if (name == "tshi") p.tshi = v
    else if (name == "qshi") p.qshi = v
    else if (name == "trshi") p.trshi = v
    else if (name == "trshir") p.trshir = v
    else if (name == "af") p.af = v
    else if (name == "tv") p.tv = v
    else if (name == "kappa") p.kappa = v
    else if (name == "rd") p.rd = v
    else if (name == "rf") p.rf = v
    else if (name == "ddebt") p.ddebt = v
    else if (name == "fdebt") p.fdebt = v
    else if (name == "qlf") p.qlf = v
    else if (name == "wmin") p.wmin = v
    else if (name == "wref") p.wref = v
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

    if (anyof(("tshi", "qshi", "trshi", "trshir"), target) & !M.ishi) {
        _cge_fail(target + " needs a health insurance fund: name it with cge_map, insurance()", 459)
    }
    // VAT and public debt (from version 0.3.1)
    if (anyof(("tv", "kappa"), target) & !(M.ivattax > 0 & M.ivattax < .)) {
        _cge_fail(target + " needs a VAT account: map one with cge_map, vattax() or vatshare() (vatshare(0) creates an empty one)", 459)
    }
    if (anyof(("rd", "rf", "ddebt", "fdebt"), target) & M.p0.debt != 1) {
        _cge_fail(target + " needs public debt: calibrate with debt() and interest()", 459)
    }
    // Labour-market regimes (from version 0.3.3)
    if (anyof(("qlf", "wmin", "wref"), target)) {
        idx = _cge_elements(M.F, elems, "factors")
        if (!all(M.p0.inlf[idx])) _cge_fail(target + " needs a labour force: calibrate with unemployment() or minwage()", 459)
        if (target != "qlf" & mode == "set" & value <= 0) _cge_fail(target + " must be positive", 198)
    }
    else if (anyof(("tm", "te", "tq", "pwm", "pwe", "qg", "qinv", "qshi", "tv"), target)) {
        idx = _cge_elements(M.C, elems, "commodities")
    }
    else if (anyof(("ta", "ad", "kappa"), target)) {
        idx = _cge_elements(M.A, elems, "activities")
    }
    else if (anyof(("trdg", "trdr"), target)) {
        idx = _cge_elements(M.D, elems, "households and enterprises")
    }
    else if (anyof(("trfr", "tshi", "af"), target)) {
        idx = _cge_elements(M.F, elems, "factors")
    }
    else if (anyof(("trgr", "trrg", "trshi", "trshir", "rd", "rf", "ddebt", "fdebt"), target)) {
        if (elems != "" & elems != "all") _cge_fail(target + " has no elements", 198)
        idx = 1
    }
    else idx = J(0, 1, .)

    if (rows(idx)) {
        v = _cge_par_get(M.p, target)
        v[idx] = (mode == "scale" ? v[idx] :* value : J(rows(idx), 1, value))
        if (target == "kappa" & (min(v) < 0 | max(v) > 1)) _cge_fail("VAT credit shares (kappa) must lie between 0 and 1", 198)
        _cge_par_set(M.p, target, v)
        _cge_store(M)
        printf("{txt}Parameter {res}%s{txt} changed for %f element(s)\n", target, rows(idx))
        return
    }

    k = _cge_vidx(M, target)
    if (k == 0) {
        _cge_fail(target + " is not a shockable parameter (tm te tq ta tv kappa pwm pwe ad af qg qinv trdg trdr trfr trgr trrg tshi qshi trshi trshir rd rf ddebt fdebt qlf wmin wref) or model variable", 198)
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

// The system the solver works on (from version 0.2.0): the free variables,
// the equations (a mask over all equation elements) and the sparsity pattern.
// The full system has every existing equation; the reduced system (the
// default) leaves out explicit definitions -- intermediate and household
// demand, import and export prices, the price of intermediates, output by
// commodity, margin demand, the fund's purchases and factor efficiency --
// whose variables are computed from the others (_cge_derive).
struct cge_sys {
    real colvector free, mask, jr, jc, drow, drow2
    real scalar    neq, reduced
}

struct cge_sys scalar _cge_sys_make(struct cge_model scalar M, real scalar reduced)
{
    struct cge_sys scalar S
    S.reduced = reduced
    if (reduced) {
        S.free = select((1::rows(M.x0)), M.exists :* (1 :- M.fixed) :* (1 :- M.derived))
        S.mask = M.rmask
        S.jr = M.rjr
        S.jc = M.rjc
        S.drow = M.rdrow
        S.drow2 = M.rdrow2
    }
    else {
        S.free = select((1::rows(M.x0)), M.exists :* (1 :- M.fixed))
        S.mask = M.emask
        S.jr = M.jr
        S.jc = M.jc
        S.drow = M.drow
        S.drow2 = M.drow2
    }
    S.neq = sum(S.mask)
    return(S)
}

// Explicit definitions that the reduced system leaves out, as (block, variable),
// in the order of M.dact. None of these variables appears in a row with exact
// derivatives (_cge_dense), and none depends on another of them.
string matrix _cge_dcandidates()
{
    return(("P1", "PM") \ ("P2", "PE") \ ("P6", "PINTA") \ ("Q5", "QINT") \ ("Q6", "QX") \
           ("I5", "QH") \ ("T8", "QT") \ ("I13", "QSHI") \ ("H2", "EFF"))
}

// Compute the variables of the active explicit definitions from the others;
// the formulas are those of _cge_eq
void _cge_derive(struct cge_model scalar M, struct cge_par scalar p, real colvector x)
{
    real colvector PQ, EH, PH
    real scalar EXR, TVADJ
    EXR = _cge_v(M, x, 10)
    PQ = _cge_v(M, x, 8)
    TVADJ = _cge_v(M, x, 52)
    PH = PQ :* (1 :+ p.tv :* TVADJ)
    if (M.dact[1]) _cge_setv(M, x, "PM", M.cm :* (p.pwm :* (1 :+ p.tm :* _cge_v(M, x, 51)) :* EXR + p.ici' * PQ))
    if (M.dact[2]) {
        _cge_setv(M, x, "PE", M.ce :* ((M.ced :* _cge_v(M, x, 53) + (1 :- M.ced) :* p.pwe) :* (1 :- p.te) :* EXR
                                       - p.ice' * PQ))
    }
    if (M.dact[3]) _cge_setv(M, x, "PINTA", (p.ica :* (1 :+ (p.tv :* TVADJ) * (1 :- p.kappa)'))' * PQ)
    if (M.dact[4]) _cge_setv(M, x, "QINT", p.ica :* _cge_v(M, x, 15)')
    if (M.dact[5]) _cge_setv(M, x, "QX", M.cx :* (p.theta' * (_cge_v(M, x, 13) - rowsum(_cge_v(M, x, 54)))))
    if (M.dact[6]) {
        EH = _cge_v(M, x, 30)
        _cge_setv(M, x, "QH", (p.beta :!= 0) :*
                  (PH :* p.gamma + p.beta :* (EH' :- PH' * p.gamma :- _cge_v(M, x, 1)' * p.gammah)) :/ PH)
    }
    if (M.dact[7]) {
        _cge_setv(M, x, "QT", M.ct :* (p.icm * _cge_v(M, x, 22) + p.icd * _cge_v(M, x, 19) +
                                       p.ici * _cge_v(M, x, 21) + p.ice * _cge_v(M, x, 20)))
    }
    if (M.dact[8]) _cge_setv(M, x, "QSHI", p.qshi :* _cge_v(M, x, 46))
    if (M.dact[9]) _cge_setv(M, x, "EFF", (_cge_v(M, x, 49) / p.hs0) :^ p.etah)
}

// The reduced system, set up after the full pattern (_cge_pattern): a
// definition is left out when its equation elements are exactly the existing
// elements of its variable. The pattern of the reduced system replaces each
// left-out variable by the variables of its definition.
void _cge_reduce_setup(struct cge_model scalar M, real colvector rowid, real colvector boff)
{
    string matrix cand
    real colvector pos, erow, ex, isder, rowdef, sel, depk, depj, keep, r, j, dj, plain, o, dstart
    real colvector rnew, newr, newc, dpos, drow, cnt, xr, xc
    real scalar k, g, v, a, b, nd

    cand = _cge_dcandidates()
    M.dact = J(rows(cand), 1, 0)
    M.derived = J(rows(M.x0), 1, 0)
    dpos = J(0, 1, .)
    drow = J(0, 1, .)
    for (k = 1; k <= rows(cand); k++) {
        // With VAT, government revenue (I8, exact derivatives) depends on QINT,
        // QH and QSHI, so they and PINTA are kept in the system
        if (M.ivattax > 0 & M.ivattax < . & anyof((3, 4, 6, 8), k)) continue
        g = _cge_find(M.ename, cand[k, 1])
        v = _cge_vidx(M, cand[k, 2])
        if (g == 0 | v == 0) continue
        if (M.elen[g] != M.vrows[v] * M.vcols[v]) continue
        pos = _cge_vpos(M, v)
        erow = rowid[boff[g] :+ (1::M.elen[g])]
        ex = M.exists[pos]
        if (any((erow :> 0) :!= ex)) continue
        M.dact[k] = 1
        sel = select((1::rows(pos)), ex)
        dpos = dpos \ pos[sel]
        drow = drow \ erow[sel]
    }
    M.derived[dpos] = J(rows(dpos), 1, 1)
    nd = rows(dpos)

    // Index of each left-out variable, and of each definition row
    isder = J(rows(M.x0), 1, 0)
    isder[dpos] = (1::nd)
    rowdef = J(M.neq, 1, 0)
    rowdef[drow] = (1::nd)
    // Dependencies of each left-out variable: the other columns of its definition row
    sel = rowdef[M.jr] :> 0
    depk = rowdef[select(M.jr, sel)]
    depj = select(M.jc, sel)
    keep = (isder[depj] :!= depk)
    depk = select(depk, keep)
    depj = select(depj, keep)
    o = order((depk, depj), (1, 2))
    depk = depk[o]
    depj = depj[o]
    dstart = J(nd + 1, 1, 0)
    for (a = 1; a <= rows(depk); a++) dstart[depk[a] + 1] = dstart[depk[a] + 1] + 1
    dstart = runningsum(dstart) :+ 1

    // Pattern of the remaining rows, with left-out variables substituted
    sel = rowdef[M.jr] :== 0
    r = select(M.jr, sel)
    j = select(M.jc, sel)
    dj = isder[j]
    plain = (dj :== 0)
    newr = select(r, plain)
    newc = select(j, plain)
    sel = select((1::rows(r)), 1 :- plain)
    cnt = (rows(sel) ? dstart[dj[sel] :+ 1] - dstart[dj[sel]] : J(0, 1, .))
    xr = J(sum(cnt), 1, .)
    xc = xr
    b = 0
    for (a = 1; a <= rows(sel); a++) {
        if (cnt[a] == 0) continue
        k = dj[sel[a]]
        xr[|b + 1 \ b + cnt[a]|] = J(cnt[a], 1, r[sel[a]])
        xc[|b + 1 \ b + cnt[a]|] = depj[|dstart[k] \ dstart[k + 1] - 1|]
        b = b + cnt[a]
    }
    newr = newr \ xr
    newc = newc \ xc
    // Rows renumbered without the definition rows
    rnew = runningsum(rowdef :== 0) :* (rowdef :== 0)
    M.rmask = M.emask
    M.rmask[select(select((1::rows(M.emask)), M.emask), rowdef :> 0)] = J(nd, 1, 0)
    sel = (M.exists[newc] :* (1 :- M.derived[newc])) :> 0
    o = uniqrows((rnew[select(newr, sel)], select(newc, sel)))
    M.rjr = o[., 1]
    M.rjc = o[., 2]
    M.rdrow = rnew[M.drow]
    M.rdrow2 = rnew[M.drow2]
    if (min(M.rdrow) <= 0) _cge_fail("cge internal error: a row with exact derivatives is left out", 3498)
}

real colvector _cge_F(struct cge_model scalar M, struct cge_par scalar p, real colvector xfix,
                      struct cge_sys scalar S, real colvector z)
{
    real colvector x, L, R, K
    x = xfix
    x[S.free] = z :* M.xscale[S.free]
    if (S.reduced) _cge_derive(M, p, x)
    if (min(x[M.positive]) <= 0 | hasmissing(x)) return(J(S.neq, 1, .))
    _cge_eq(M, p, x, L, R, K, 0)
    return(select((L - R) :/ M.escale, S.mask))
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
    _cge_sp(M, rowid, boff, pr, pc, "P1", cC, "TMADJ", 1)
    _cge_nz(p.ici, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "P1", j, "PQ", i)
    _cge_sp_same(M, rowid, boff, pr, pc, "P2", ("PE", "PWE"))
    _cge_sp(M, rowid, boff, pr, pc, "P2", cC, "EXR", 1)
    _cge_nz(p.ice, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "P2", j, "PQ", i)
    _cge_sp_same(M, rowid, boff, pr, pc, "P3", ("PQ", "QQ", "PD", "QD", "PM", "QM"))
    _cge_nz(p.icm, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "P3", j, "PQ", i)
    _cge_sp(M, rowid, boff, pr, pc, "P3", cC, "TQADJ", 1)
    _cge_nz(p.icd, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "P3", j, "PQ", i)
    _cge_sp_same(M, rowid, boff, pr, pc, "P4", ("PX", "QX", "PD", "QD", "PE", "QE"))
    _cge_sp_same(M, rowid, boff, pr, pc, "P5", "PA")
    _cge_nz(p.theta, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "P5", i, "PX", j)
    _cge_sp_same(M, rowid, boff, pr, pc, "P6", "PINTA")
    _cge_nz(p.ica, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "P6", j, "PQ", i)
    _cge_sp(M, rowid, boff, pr, pc, "P6", cA, "TVADJ", 1)
    // P7 has exact derivatives (_cge_dense2)

    // 5.2 Production block
    _cge_sp_same(M, rowid, boff, pr, pc, "Q1", ("QVA", "QA"))
    _cge_sp_same(M, rowid, boff, pr, pc, "Q2", ("QINTA", "QA"))
    _cge_sp_same(M, rowid, boff, pr, pc, "Q1C", ("QA", "QVA", "QINTA"))
    _cge_sp_same(M, rowid, boff, pr, pc, "Q2C", ("QVA", "QINTA", "PVA", "PINTA"))
    _cge_sp_same(M, rowid, boff, pr, pc, "Q3", "QVA")
    _cge_nz(M.fa, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "Q3", j, "QF", (i :- 1) :* nA :+ j)
    _cge_nz(M.fa, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "Q3", j, "EFF", i)
    _cge_sp_same(M, rowid, boff, pr, pc, "Q4", ("WFDIST", "QF"))
    for (f = 1; f <= nF; f++) {
        e = (f - 1) * nA :+ cA
        _cge_sp(M, rowid, boff, pr, pc, "Q4", e, "W", f)
        _cge_sp(M, rowid, boff, pr, pc, "Q4", e, "PVA", cA)
        _cge_sp(M, rowid, boff, pr, pc, "Q4", e, "QVA", cA)
        for (g = 1; g <= nF; g++) {
            _cge_sp(M, rowid, boff, pr, pc, "Q4", e, "QF", (g - 1) * nA :+ cA)
            _cge_sp(M, rowid, boff, pr, pc, "Q4", e, "EFF", g)
        }
    }
    _cge_sp(M, rowid, boff, pr, pc, "H1", 1, "HS", 1)
    i = select(cC, M.chs)
    for (k = 1; k <= rows(i); k++) {
        _cge_sp(M, rowid, boff, pr, pc, "H1", J(nH, 1, 1), "QH", (i[k] - 1) * nH :+ (1::nH))
        _cge_sp(M, rowid, boff, pr, pc, "H1", 1, "QG", i[k])
        _cge_sp(M, rowid, boff, pr, pc, "H1", 1, "QSHI", i[k])
    }
    _cge_sp_same(M, rowid, boff, pr, pc, "H2", "EFF")
    _cge_sp(M, rowid, boff, pr, pc, "H2", (1::nF), "HS", 1)
    e = (1::nC * nA)
    _cge_sp(M, rowid, boff, pr, pc, "Q5", e, "QINT", e)
    _cge_sp(M, rowid, boff, pr, pc, "Q5", e, "QINTA", mod(e :- 1, nA) :+ 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "Q6", "QX")
    _cge_nz(p.theta, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "Q6", j, "QA", i)
    for (k = 1; k <= nH; k++) _cge_sp(M, rowid, boff, pr, pc, "Q6", j, "QHA", (i :- 1) :* nH :+ k)

    // 5.3 Trade block
    _cge_sp_same(M, rowid, boff, pr, pc, "T1", ("QX", "QE", "QD"))
    _cge_sp_same(M, rowid, boff, pr, pc, "T2", ("QE", "QD", "PE", "PD"))
    _cge_sp_same(M, rowid, boff, pr, pc, "T3", ("QX", "QD"))
    _cge_sp_same(M, rowid, boff, pr, pc, "T3E", ("QX", "QE"))
    _cge_sp_same(M, rowid, boff, pr, pc, "T4", ("QQ", "QM", "QD"))
    _cge_sp_same(M, rowid, boff, pr, pc, "T5", ("QM", "QD", "PD", "PM"))
    _cge_nz(p.icd, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "T5", j, "PQ", i)
    _cge_sp_same(M, rowid, boff, pr, pc, "T6", ("QQ", "QD"))
    _cge_sp_same(M, rowid, boff, pr, pc, "T7", ("QQ", "QM"))
    _cge_sp_same(M, rowid, boff, pr, pc, "T8", "QT")
    _cge_nz(p.icm, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "T8", i, "QQ", j)
    _cge_nz(p.icd, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "T8", i, "QD", j)
    _cge_nz(p.ici, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "T8", i, "QM", j)
    _cge_nz(p.ice, i, j)
    _cge_sp(M, rowid, boff, pr, pc, "T8", i, "QE", j)
    _cge_sp_same(M, rowid, boff, pr, pc, "T9", ("QER", "PQ"))
    _cge_sp(M, rowid, boff, pr, pc, "T9", cC, "EXR", 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "T10", ("QE", "PWE"))

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
    _cge_sp(M, rowid, boff, pr, pc, "I5", e, "TVADJ", 1)
    // LES: every purchase of household h depends on the prices of its subsistence quantities
    for (k = 1; k <= nH; k++) {
        i = select(cC, p.gamma[., k] :!= 0)
        for (g = 1; g <= rows(i); g++) _cge_sp(M, rowid, boff, pr, pc, "I5", (cC :- 1) :* nH :+ k, "PQ", i[g])
        i = select(cA, p.gammah[., k] :!= 0)
        for (g = 1; g <= rows(i); g++) _cge_sp(M, rowid, boff, pr, pc, "I5", (cC :- 1) :* nH :+ k, "PA", i[g])
    }
    // Home consumption (13.1): own price, spending, and subsistence prices
    e = (1::nA * nH)
    _cge_sp(M, rowid, boff, pr, pc, "I5H", e, "QHA", e)
    _cge_sp(M, rowid, boff, pr, pc, "I5H", e, "PA", floor((e :- 1) :/ nH) :+ 1)
    _cge_sp(M, rowid, boff, pr, pc, "I5H", e, "EH", mod(e :- 1, nH) :+ 1)
    _cge_sp(M, rowid, boff, pr, pc, "I5H", e, "TVADJ", 1)
    for (k = 1; k <= nH; k++) {
        i = select(cC, p.gamma[., k] :!= 0)
        for (g = 1; g <= rows(i); g++) _cge_sp(M, rowid, boff, pr, pc, "I5H", (cA :- 1) :* nH :+ k, "PQ", i[g])
        i = select(cA, p.gammah[., k] :!= 0)
        for (g = 1; g <= rows(i); g++) _cge_sp(M, rowid, boff, pr, pc, "I5H", (cA :- 1) :* nH :+ k, "PA", i[g])
    }
    _cge_sp_same(M, rowid, boff, pr, pc, "I6", "QINV")
    _cge_sp(M, rowid, boff, pr, pc, "I6", cC, "IADJ", 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "I7", "QG")
    _cge_sp(M, rowid, boff, pr, pc, "I7", cC, "GADJ", 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "I10", "TINS")
    _cge_sp(M, rowid, boff, pr, pc, "I10", cD, "TINSADJ", 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "I11", "MPS")
    _cge_sp(M, rowid, boff, pr, pc, "I11", cD, "MPSADJ", 1)
    _cge_sp(M, rowid, boff, pr, pc, "I12", 1, "YSHI", 1)
    _cge_sp(M, rowid, boff, pr, pc, "I12", J(nF, 1, 1), "YIF", (nI - 1) * nF :+ (1::nF))
    _cge_sp(M, rowid, boff, pr, pc, "I12", 1, "CPI", 1)
    _cge_sp(M, rowid, boff, pr, pc, "I12", 1, "EXR", 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "I13", "QSHI")
    _cge_sp(M, rowid, boff, pr, pc, "I13", cC, "SHIADJ", 1)
    _cge_sp(M, rowid, boff, pr, pc, "I14", J(nC, 1, 1), "PQ", cC)
    _cge_sp(M, rowid, boff, pr, pc, "I14", J(nC, 1, 1), "QSHI", cC)
    _cge_sp(M, rowid, boff, pr, pc, "I14", 1, "YSHI", 1)
    _cge_sp(M, rowid, boff, pr, pc, "I14", 1, "TVADJ", 1)

    // Labour-market regimes (Section 14)
    _cge_sp_same(M, rowid, boff, pr, pc, "L1", ("W", "QFS", "LSW"))
    _cge_sp(M, rowid, boff, pr, pc, "L1", (1::nF), "CPI", 1)
    _cge_sp_same(M, rowid, boff, pr, pc, "L2", ("W", "QFS", "LSM"))
    _cge_sp(M, rowid, boff, pr, pc, "L2", (1::nF), "CPI", 1)

    // 5.5 System constraints
    // S2 has exact derivatives (_cge_dense2)
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
    // Rows of S2 and P7, in the order of _cge_dense2
    // (commodities without composite supply have no S2 row)
    M.drow2 = rowid[boff[_cge_find(M.ename, "S2")] :+ select((1::M.nC), M.cq)] \
              rowid[boff[_cge_find(M.ename, "P7")] :+ (1::M.n)]
    if (min(M.drow2) <= 0) _cge_fail("cge internal error: an equation with exact derivatives is masked", 3498)
    _cge_reduce_setup(M, rowid, boff)
}

// Exact derivatives of the rows of _cge_denseblocks() with respect to every
// stacked variable (unscaled): rows P8, P9, I1 (one per factor), I8, I9, S1 (one
// per factor), S3, S5
real matrix _cge_dense(struct cge_model scalar M, struct cge_par scalar p, real colvector x)
{
    real matrix G, WFD, QF, YIF, QH, QINT
    real colvector PQ, QQ, QM, QE, PA, QA, QG, QINV, QER, YI, TINS, MPS, W, cQF, cWFD, cYIF
    real colvector QSHI, tq, tm, tv, PH, vbase, cQH, cQINT, PWE, pwe
    real scalar EXR, FSAV, nA, nF, nD, nH, f, r, A, B, c, TQADJ, TMADJ, TVADJ

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
    QH = _cge_v(M, x, 23);   QINT = _cge_v(M, x, 17); QSHI = _cge_v(M, x, 47)
    TQADJ = _cge_v(M, x, 50); TMADJ = _cge_v(M, x, 51); TVADJ = _cge_v(M, x, 52)
    PWE = _cge_v(M, x, 53)
    pwe = M.ced :* PWE + (1 :- M.ced) :* p.pwe
    nH = M.nH
    tq = p.tq :* TQADJ
    tm = p.tm :* TMADJ
    tv = p.tv :* TVADJ
    PH = PQ :* (1 :+ tv)
    // VAT base by commodity: final demand and the inputs activities cannot recover
    vbase = rowsum(QH) + QG + QINV + QSHI + rowsum(QINT :* (1 :- p.kappa)')
    cQH = _cge_vcols(M, "QH")
    cQINT = _cge_vcols(M, "QINT")
    cQF = _cge_vcols(M, "QF")
    cWFD = _cge_vcols(M, "WFDIST")
    cYIF = _cge_vcols(M, "YIF")

    // P8, P9: price indexes
    G[1, _cge_vcols(M, "CPI")] = 1
    G[1, _cge_vcols(M, "PQ")'] = -(p.cwts :* (1 :+ tv))'
    G[1, _cge_vcols(M, "TVADJ")] = -sum(p.cwts :* PQ :* p.tv)
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
    G[r, _cge_vcols(M, "PQ")'] = -(tq :* QQ + tv :* vbase)'
    G[r, _cge_vcols(M, "QQ")'] = -(tq :* PQ)'
    G[r, _cge_vcols(M, "QM")'] = -EXR :* (tm :* p.pwm)'
    G[r, _cge_vcols(M, "QE")'] = -EXR :* (p.te :* pwe)'
    G[r, _cge_vcols(M, "PWE")'] = -EXR :* (M.ced :* p.te :* QE)'
    G[r, _cge_vcols(M, "EXR")] = -(sum(tm :* p.pwm :* QM) + sum(p.te :* pwe :* QE) + p.trgr)
    G[r, _cge_vcols(M, "TQADJ")] = -sum(p.tq :* PQ :* QQ)
    G[r, _cge_vcols(M, "TMADJ")] = -EXR * sum(p.tm :* p.pwm :* QM)
    G[r, _cge_vcols(M, "TVADJ")] = -sum(p.tv :* PQ :* vbase)
    // VAT on each use
    G[r, _cge_vcols(M, "QG")'] = -(tv :* PQ)'
    G[r, _cge_vcols(M, "QINV")'] = -(tv :* PQ)'
    G[r, _cge_vcols(M, "QSHI")'] = -(tv :* PQ)'
    for (c = 1; c <= M.nC; c++) {
        if (tv[c] == 0) continue
        G[r, cQH[|(c - 1) * nH + 1 \ c * nH|]'] = J(1, nH, -tv[c] * PQ[c])
        G[r, cQINT[|(c - 1) * nA + 1 \ c * nA|]'] = -tv[c] * PQ[c] :* (1 :- p.kappa)'
    }
    G[r, _cge_vcols(M, "PA")'] = -(p.ta :* QA)'
    G[r, _cge_vcols(M, "QA")'] = -(p.ta :* PA)'
    G[r, cYIF[|nD * nF + 1 \ (nD + 1) * nF|]'] = J(1, nF, -1)
    G[r, _cge_vcols(M, "CPI")] = -p.trgg
    // I9: government spending
    r = 4 + nF
    G[r, _cge_vcols(M, "EG")] = 1
    G[r, _cge_vcols(M, "PQ")'] = -((1 :+ tv) :* QG)'
    G[r, _cge_vcols(M, "QG")'] = -PH'
    G[r, _cge_vcols(M, "TVADJ")] = -sum(p.tv :* PQ :* QG)
    G[r, _cge_vcols(M, "CPI")] = -(sum(p.trdg) + p.trgg + p.trshi)
    G[r, _cge_vcols(M, "EXR")] = -(p.trrg + p.rf * p.fdebt)
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
    G[r, _cge_vcols(M, "QE")'] = -pwe'
    G[r, _cge_vcols(M, "PWE")'] = -(M.ced :* QE)'
    G[r, _cge_vcols(M, "PQ")'] = -(M.cr :* QER)' :/ EXR
    G[r, _cge_vcols(M, "QER")'] = -(M.cr :* PQ)' :/ EXR
    G[r, _cge_vcols(M, "FSAV")] = -1
    // S5: savings-investment balance
    r = 6 + 2 * nF
    G[r, _cge_vcols(M, "MPS")'] = ((1 :- TINS) :* YI)'
    G[r, _cge_vcols(M, "TINS")'] = -(MPS :* YI)'
    G[r, _cge_vcols(M, "YI")'] = (MPS :* (1 :- TINS))'
    G[r, _cge_vcols(M, "GSAV")] = 1
    G[r, _cge_vcols(M, "YSHI")] = p.sshi
    G[r, _cge_vcols(M, "EXR")] = FSAV
    G[r, _cge_vcols(M, "FSAV")] = EXR
    G[r, _cge_vcols(M, "PQ")'] = -((1 :+ tv) :* QINV)'
    G[r, _cge_vcols(M, "QINV")'] = -PH'
    G[r, _cge_vcols(M, "TVADJ")] = -sum(p.tv :* PQ :* QINV)
    G[r, _cge_vcols(M, "WALRAS")] = -1
    return(G)
}

// Exact derivatives of the market-clearing rows S2 (one per commodity) and the
// activity-price rows P7 (one per activity), from version 0.2.0, with respect
// to every stacked variable (unscaled). In the reduced system they are total
// derivatives, through the variables computed from explicit definitions
// (_cge_derive): S2 then depends on intermediate input (QINTA) rather than
// QINT, on household spending and prices rather than QH, and P7 on commodity
// prices rather than PINTA. These rows involve many variables, so computing
// them exactly keeps the groups of the central differences few.
real matrix _cge_dense2(struct cge_model scalar M, struct cge_par scalar p, real colvector x,
                        real scalar reduced)
{
    real matrix G
    real colvector PQ, EH, PA, QA, PVA, QVA, PINTA, QINTA, cQQ, cPQ, cEH, cQINTA, cQINT, cQH, cQT
    real colvector cQSHI, cQG, cQINV, cQER, cPA, cQA, cPVA, cQVA, cPINTA, g, gh, cQD, cQM, cQE
    real scalar nC, nA, nH, c, a, h, r, sh, cSHIADJ

    nC = M.nC
    nA = M.n
    nH = M.nH
    G = J(nC + nA, rows(x), 0)
    PQ = _cge_vn(M, x, "PQ");        EH = _cge_vn(M, x, "EH")
    PA = _cge_vn(M, x, "PA");        QA = _cge_vn(M, x, "QA")
    PVA = _cge_vn(M, x, "PVA");      QVA = _cge_vn(M, x, "QVA")
    PINTA = _cge_vn(M, x, "PINTA");  QINTA = _cge_vn(M, x, "QINTA")
    cQQ = _cge_vcols(M, "QQ");       cPQ = _cge_vcols(M, "PQ")
    cEH = _cge_vcols(M, "EH");       cQINTA = _cge_vcols(M, "QINTA")
    cQINT = _cge_vcols(M, "QINT");   cQH = _cge_vcols(M, "QH")
    cQT = _cge_vcols(M, "QT");       cQSHI = _cge_vcols(M, "QSHI")
    cQG = _cge_vcols(M, "QG");       cQINV = _cge_vcols(M, "QINV")
    cQER = _cge_vcols(M, "QER");     cSHIADJ = _cge_vcols(M, "SHIADJ")
    cPA = _cge_vcols(M, "PA");       cQA = _cge_vcols(M, "QA")
    cPVA = _cge_vcols(M, "PVA");     cQVA = _cge_vcols(M, "QVA")
    cPINTA = _cge_vcols(M, "PINTA")
    cQD = _cge_vcols(M, "QD");       cQM = _cge_vcols(M, "QM")
    cQE = _cge_vcols(M, "QE")

    // S2: QQ - (sum_a QINT + sum_h QH + QG + QINV + QT + QER + QSHI)
    for (c = 1; c <= nC; c++) {
        G[c, cQQ[c]] = 1
        G[c, cQG[c]] = -1
        G[c, cQINV[c]] = -1
        G[c, cQER[c]] = -M.cr[c]
        if (reduced & M.dact[4]) G[c, cQINTA'] = -p.ica[c, .]
        else G[c, cQINT[|(c - 1) * nA + 1 \ c * nA|]'] = J(1, nA, -1)
        if (reduced & M.dact[7]) {
            G[c, cQQ'] = G[c, cQQ'] - M.ct[c] :* p.icm[c, .]
            G[c, cQD'] = G[c, cQD'] - M.ct[c] :* p.icd[c, .]
            G[c, cQM'] = G[c, cQM'] - M.ct[c] :* p.ici[c, .]
            G[c, cQE'] = G[c, cQE'] - M.ct[c] :* p.ice[c, .]
        }
        else G[c, cQT[c]] = -M.ct[c]
        if (reduced & M.dact[8]) G[c, cSHIADJ] = -p.qshi[c]
        else G[c, cQSHI[c]] = -1
        if (reduced & M.dact[6]) {
            // QH = gamma + beta (EH - PQ'gamma) / PQ for each household
            for (h = 1; h <= nH; h++) {
                if (p.beta[c, h] == 0) continue
                G[c, cEH[h]] = -p.beta[c, h] / PQ[c]
                g = p.gamma[., h]
                gh = p.gammah[., h]
                if (any(g)) G[c, cPQ'] = G[c, cPQ'] + (p.beta[c, h] / PQ[c]) :* g'
                if (any(gh)) G[c, cPA'] = G[c, cPA'] + (p.beta[c, h] / PQ[c]) :* gh'
                sh = EH[h] - PQ' * g - PA' * gh
                G[c, cPQ[c]] = G[c, cPQ[c]] + p.beta[c, h] * sh / PQ[c]^2
            }
        }
        else G[c, cQH[|(c - 1) * nH + 1 \ c * nH|]'] = J(1, nH, -1)
    }
    // P7: PA (1 - ta) QA - PVA QVA - PINTA QINTA
    for (a = 1; a <= nA; a++) {
        r = nC + a
        G[r, cPA[a]] = (1 - p.ta[a]) * QA[a]
        G[r, cQA[a]] = PA[a] * (1 - p.ta[a])
        G[r, cPVA[a]] = -QVA[a]
        G[r, cQVA[a]] = -PVA[a]
        G[r, cQINTA[a]] = -PINTA[a]
        if (reduced & M.dact[3]) G[r, cPQ'] = -QINTA[a] :* p.ica[., a]'
        else G[r, cPINTA[a]] = -QINTA[a]
    }
    // Commodities without composite supply have no S2 row
    return(G[(select((1::nC), M.cq) \ (nC :+ (1::nA))), .])
}

// Groups of free variables for the Jacobian: a greedy colouring, most
// connected columns first, in which the columns of a group share no equation
// (Curtis, Powell and Reid, 1974)
struct cge_jpat scalar _cge_jpat_make(struct cge_model scalar M, struct cge_sys scalar S)
{
    struct cge_jpat scalar G
    real colvector map, keep, r0, c0, o, cs, rs, rcol, ccnt, rcnt, gcnt, rstart, colour, forbid
    real scalar n, nnz, k, s, j, a, b, i, col, nc

    n = rows(S.free)
    map = J(rows(M.x0), 1, 0)
    map[S.free] = (1::n)
    keep = map[S.jc] :> 0
    r0 = select(S.jr, keep)
    c0 = map[select(S.jc, keep)]
    nnz = rows(r0)
    o = order((c0, r0), (1, 2))
    G.crow = r0[o]
    cs = c0[o]
    o = order((r0, c0), (1, 2))
    rcol = c0[o]
    rs = r0[o]
    ccnt = J(n, 1, 0)
    rcnt = J(S.neq, 1, 0)
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
                          struct cge_sys scalar S, real colvector z, struct cge_jpat scalar G)
{
    real matrix Jac
    real colvector h, zp, zm, d, cols, rr, x, esc
    real matrix D
    real scalar g, k, j

    Jac = J(S.neq, rows(z), 0)
    h = 1e-6 :* rowmax((J(rows(z), 1, 1), abs(z)))
    for (g = 1; g <= G.ncolour; g++) {
        cols = G.gcol[|G.gstart[g] \ G.gstart[g + 1] - 1|]
        zp = z
        zm = z
        zp[cols] = z[cols] + h[cols]
        zm[cols] = z[cols] - h[cols]
        d = _cge_F(M, p, xfix, S, zp) - _cge_F(M, p, xfix, S, zm)
        if (hasmissing(d)) return(J(S.neq, rows(z), .))
        for (k = 1; k <= rows(cols); k++) {
            j = cols[k]
            if (G.cstart[j + 1] == G.cstart[j]) continue
            rr = G.crow[|G.cstart[j] \ G.cstart[j + 1] - 1|]
            Jac[rr, j] = d[rr] :/ (2 * h[j])
        }
    }
    x = xfix
    x[S.free] = z :* M.xscale[S.free]
    if (S.reduced) _cge_derive(M, p, x)
    esc = select(M.escale, S.mask)
    D = _cge_dense(M, p, x)
    Jac[S.drow, .] = (D[., S.free] :* M.xscale[S.free]') :/ esc[S.drow]
    D = _cge_dense2(M, p, x, S.reduced)
    Jac[S.drow2, .] = (D[., S.free] :* M.xscale[S.free]') :/ esc[S.drow2]
    return(Jac)
}

// Column-by-column central-difference Jacobian, kept to check the grouped one
real matrix _cge_jacobian_full(struct cge_model scalar M, struct cge_par scalar p, real colvector xfix,
                               struct cge_sys scalar S, real colvector z)
{
    real matrix Jac
    real colvector zp, zm
    real scalar j, h
    Jac = J(S.neq, rows(z), .)
    for (j = 1; j <= rows(z); j++) {
        h = 1e-6 * max((1, abs(z[j])))
        zp = z
        zm = z
        zp[j] = zp[j] + h
        zm[j] = zm[j] - h
        Jac[., j] = (_cge_F(M, p, xfix, S, zp) - _cge_F(M, p, xfix, S, zm)) / (2 * h)
    }
    return(Jac)
}

// Test hook: the grouped and column-by-column Jacobians at the current point,
// with the current shocks and closure, for the reduced system (the default)
// or the full one
void _cge_jaccheck(| real scalar full)
{
    struct cge_model scalar M
    struct cge_jpat scalar G
    struct cge_sys scalar S
    real colvector z
    real matrix A, B

    if (args() == 0) full = 0
    M = _cge_load()
    _cge_need(M, "calibrated")
    S = _cge_sys_make(M, !full)
    z = M.xcur[S.free] :/ M.xscale[S.free]
    G = _cge_jpat_make(M, S)
    A = _cge_jacobian(M, M.p, M.xcur, S, z, G)
    B = _cge_jacobian_full(M, M.p, M.xcur, S, z)
    st_numscalar("r(maxdiff)", max(abs(A - B)))
    st_numscalar("r(groups)", G.ncolour)
    st_numscalar("r(columns)", rows(z))
    printf("{txt}Jacobian (%s system): {res}%f{txt} columns in {res}%f{txt} groups; largest difference from column-by-column {res}%9.3e\n",
           (full ? "full" : "reduced"), rows(z), G.ncolour, max(abs(A - B)))
}

// Newton-Raphson with a backtracking line search; returns 1 on convergence.
// From version 0.2.0 the LU factors of the Jacobian are reused for further
// steps while each such step at least halves the residual norm; otherwise the
// Jacobian is computed again.
real scalar _cge_newton(struct cge_model scalar M, struct cge_par scalar p, real colvector xfix,
                        struct cge_sys scalar S, real colvector z, real scalar tol, real scalar maxit,
                        real scalar trace, real scalar iter, real scalar err)
{
    struct cge_jpat scalar G
    real colvector f, fn, dz, zn, perm
    real matrix LU, U
    real scalar norm0, step, it, fresh, njac

    f = _cge_F(M, p, xfix, S, z)
    iter = 0
    err = .
    if (hasmissing(f)) return(0)
    G = _cge_jpat_make(M, S)
    fresh = 1
    njac = 0
    for (it = 0; it <= maxit; it++) {
        err = max(abs(f))
        iter = it
        if (trace) printf("{txt}Iteration %f: largest scaled residual = {res}%9.3e{txt} (%f Jacobian(s))\n",
                          it, err, njac)
        if (err < tol) {
            st_numscalar("r(jacobians)", njac)
            return(1)
        }
        if (it == maxit) break
        norm0 = norm(f)
        if (!fresh) {
            // Step with the factors of an earlier Jacobian
            dz = solveupper(U, solvelower(LU, -f[perm]))
            if (!hasmissing(dz)) {
                zn = z + dz
                fn = _cge_F(M, p, xfix, S, zn)
                if (!hasmissing(fn)) {
                    if (norm(fn) <= 0.5 * norm0) {
                        z = zn
                        f = fn
                        continue
                    }
                }
            }
            fresh = 1
        }
        LU = _cge_jacobian(M, p, xfix, S, z, G)
        njac++
        if (hasmissing(LU)) break
        // Mata's _lud() gives A = (L*U)[p, .], so A x = b is solved with b[invorder(p)]
        _lud(LU, U, perm)
        perm = invorder(perm)
        dz = solveupper(U, solvelower(LU, -f[perm]))
        if (hasmissing(dz)) break
        fresh = 0
        step = 1
        while (step >= 1e-8) {
            zn = z + step * dz
            fn = _cge_F(M, p, xfix, S, zn)
            if (!hasmissing(fn)) {
                if (norm(fn) <= (1 - 1e-4 * step) * norm0) break
            }
            step = step / 2
        }
        if (step < 1e-8) break
        // After a damped step the old factors are less likely to help
        if (step < 1) fresh = 1
        z = zn
        f = fn
    }
    st_numscalar("r(jacobians)", njac)
    return(0)
}

// Evaluator for solvenl(), which takes at most three extra arguments in Stata 13:
// xf holds the fixed values (column 1), marks the free variables (column 2)
// and, in column 3, whether the system is the reduced one
void _cge_solvenl_eval(real colvector z, real colvector y, struct cge_model scalar M,
                       struct cge_par scalar p, real matrix xf)
{
    struct cge_sys scalar S
    S.reduced = xf[1, 3]
    S.free = select((1::rows(xf)), xf[., 2])
    S.mask = (S.reduced ? M.rmask : M.emask)
    S.neq = sum(S.mask)
    y = _cge_F(M, p, xf[., 1], S, z)
}

// Solve from `start` with parameters p and fixed values in xfix, using the
// reduced system unless `full` is set. Returns the full solution vector; conv,
// iter, err and method describe the outcome.
real colvector _cge_solve_point(struct cge_model scalar M, struct cge_par scalar p, real colvector xfix,
                                real colvector start, real scalar tol, real scalar maxit,
                                real scalar trace, real scalar conv, real scalar iter,
                                real scalar err, string scalar method, | real scalar full)
{
    struct cge_sys scalar S
    real colvector z, z2, x, isfree
    transmorphic SV
    real scalar rc, iter2

    if (args() < 12) full = 0
    S = _cge_sys_make(M, !full)
    z = start[S.free] :/ M.xscale[S.free]
    method = "newton"
    conv = _cge_newton(M, p, xfix, S, z, tol, maxit, trace, iter, err)
    if (!conv) {
        // Fallback: Powell's hybrid method, then Newton to polish the result
        method = "broydenpowell"
        SV = solvenl_init()
        solvenl_init_evaluator(SV, &_cge_solvenl_eval())
        solvenl_init_type(SV, "zero")
        solvenl_init_technique(SV, "broydenpowell")
        isfree = J(rows(xfix), 1, 0)
        isfree[S.free] = J(rows(S.free), 1, 1)
        solvenl_init_narguments(SV, 3)
        solvenl_init_argument(SV, 1, M)
        solvenl_init_argument(SV, 2, p)
        solvenl_init_argument(SV, 3, (xfix, isfree, J(rows(xfix), 1, S.reduced)))
        solvenl_init_iter_log(SV, (trace ? "on" : "off"))
        solvenl_init_conv_maxiter(SV, 1000)
        // Tighter than the defaults, so that the result needs little polishing
        solvenl_init_conv_iterchng(SV, 1e-13)
        solvenl_init_conv_nearzero(SV, 1e-20)
        solvenl_init_startingvals(SV, start[S.free] :/ M.xscale[S.free])
        rc = _solvenl_solve(SV)
        if (rc == 0) {
            z2 = solvenl_result_values(SV)
            conv = _cge_newton(M, p, xfix, S, z2, tol, maxit, trace, iter2, err)
            if (conv) z = z2
            iter = iter + iter2
        }
    }
    x = xfix
    x[S.free] = z :* M.xscale[S.free]
    if (S.reduced) _cge_derive(M, p, x)
    return(x)
}

// Store a solution as a named simulation (replacing one of the same name);
// returns its index
real scalar _cge_store_sim(struct cge_model scalar M, string scalar name, real colvector x, real scalar conv,
                           real scalar iter, real scalar err, string scalar method)
{
    real scalar k
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
        M.simrun = M.simrun \ ""
        M.simper = M.simper \ .
        M.simlam = M.simlam \ .
        return(rows(M.simname))
    }
    M.simclosure[k] = _cge_closure_text(M)
    M.simmethod[k] = method
    M.simx[., k] = x
    M.simp[k] = M.p
    M.simconv[k] = conv
    M.simiter[k] = iter
    M.simres[k] = err
    M.simrun[k] = ""
    M.simper[k] = .
    M.simlam[k] = .
    return(k)
}

void _cge_solve(string scalar name, real scalar tol, real scalar maxit, real scalar trace, | real scalar full)
{
    struct cge_model scalar M
    real colvector x
    real scalar conv, iter, err, k, walras
    string scalar method

    if (args() < 5) full = 0
    M = _cge_load()
    _cge_need(M, "calibrated")
    if (name == "") name = "sim" + strofreal(rows(M.simname) + 1)

    x = _cge_solve_point(M, M.p, M.xcur, M.x0, tol, maxit, trace, conv, iter, err, method, full)
    walras = x[M.voff[_cge_vidx(M, "WALRAS")] + 1]
    // The largest scaled residual of every equation, the left-out ones included
    err = _cge_maxres(M, M.p, x)

    (void) _cge_store_sim(M, name, x, conv, iter, err, method)
    _cge_store(M)

    if (conv) printf("{txt}Simulation {res}%s{txt} solved in {res}%f{txt} iteration(s) ({res}%s{txt})\n", name, iter, method)
    else printf("{err}Simulation %s did not converge (largest scaled residual %9.3e)\n", name, err)
    printf("{txt}Largest scaled residual {res}%9.3e{txt}; WALRAS = {res}%9.3e\n", err, walras)
    st_numscalar("r(converged)", conv)
    st_numscalar("r(iterations)", iter)
    st_numscalar("r(max_residual)", err)
    st_numscalar("r(walras)", walras)
    st_numscalar("r(N_solved)", (full ? M.neq : sum(M.rmask)))
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

// Price paid by final users, including VAT (model_spec.md, P8; from version
// 0.3.1): PH = PQ (1 + tv TVADJ)
real colvector _cge_ph(struct cge_model scalar M, struct cge_par scalar p, real colvector x)
{
    return(_cge_v(M, x, 8) :* (1 :+ p.tv :* _cge_v(M, x, 52)))
}

// World export prices: PWE where export demand is finite, else pwe (13.2)
real colvector _cge_pwe(struct cge_model scalar M, struct cge_par scalar p, real colvector x)
{
    return(M.ced :* _cge_v(M, x, 53) + (1 :- M.ced) :* p.pwe)
}

// Net VAT revenue (I8)
real scalar _cge_vat(struct cge_model scalar M, struct cge_par scalar p, real colvector x)
{
    real colvector base
    base = rowsum(_cge_v(M, x, 23)) + _cge_v(M, x, 24) + _cge_v(M, x, 25) + _cge_v(M, x, 47) +
           rowsum(_cge_v(M, x, 17) :* (1 :- p.kappa)')
    return(sum(p.tv :* _cge_v(M, x, 52) :* _cge_v(M, x, 8) :* base))
}

real colvector _cge_ev(struct cge_model scalar M, struct cge_par scalar p, real colvector x)
{
    real matrix PQ0, PQ1, B, G
    real colvector EH0, EH1
    // Prices households pay: with VAT for marketed goods, PA for home goods (13.1)
    PQ0 = _cge_ph(M, M.p0, M.x0) \ _cge_v(M, M.x0, 1)
    PQ1 = _cge_ph(M, p, x) \ _cge_v(M, x, 1)
    B = p.beta \ p.betah
    G = p.gamma \ p.gammah
    EH0 = _cge_v(M, M.x0, _cge_vidx(M, "EH"))
    EH1 = _cge_v(M, x, _cge_vidx(M, "EH"))
    return((PQ0' * G)' + (EH1 - (PQ1' * G)') :* exp(colsum(B :* ln(PQ0 :/ PQ1)))' - EH0)
}

// Expenditure-side GDP minus income-side GDP; zero at any solution
real scalar _cge_gdpgap(struct cge_model scalar M, struct cge_par scalar p, real colvector x)
{
    real matrix PQ, QH, QG, QINV, QE, QM, EXR, PVA, QVA, QQ, PA, QA, QER, QSHI
    real scalar expend, income
    PQ = _cge_v(M, x, 8);    QH = _cge_v(M, x, 23);   QG = _cge_v(M, x, 24)
    QINV = _cge_v(M, x, 25); QE = _cge_v(M, x, 20);   QM = _cge_v(M, x, 21)
    EXR = _cge_v(M, x, 10);  PVA = _cge_v(M, x, 2);   QVA = _cge_v(M, x, 14)
    QQ = _cge_v(M, x, 22);   PA = _cge_v(M, x, 1);    QA = _cge_v(M, x, 13)
    QER = _cge_v(M, x, 44);  QSHI = _cge_v(M, x, 47)
    expend = _cge_ph(M, p, x)' * (rowsum(QH) + QG + QINV + QSHI) + PQ' * QER +
             PA' * rowsum(_cge_v(M, x, 54)) + EXR * (_cge_pwe(M, p, x)' * QE) - EXR * (p.pwm' * QM)
    income = PVA' * QVA + sum(p.tq :* _cge_v(M, x, 50) :* PQ :* QQ) +
             EXR * sum(p.tm :* _cge_v(M, x, 51) :* p.pwm :* QM) +
             EXR * sum(p.te :* _cge_pwe(M, p, x) :* QE) + sum(p.ta :* PA :* QA) + _cge_vat(M, p, x)
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
        // select() on a 1 x 1 matrix with a zero mask returns 1 x 0, not 0 x 1
        if (!any(keep)) continue
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
    if (M.ishi) _cge_row(M, x, "Health insurance purchases (SHIADJ)", _cge_v(M, M.x0, 46), _cge_v(M, x, 46))
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


// =====================================================================
// Reporting (model_spec.md, Section 9; from version 0.1.15)
// =====================================================================

real matrix _cge_vn(struct cge_model scalar M, real colvector x, string scalar name)
{
    return(_cge_v(M, x, _cge_vidx(M, name)))
}

// Compensating variation by household: spending after the shock less the
// spending that would give base utility at the new prices (Cobb-Douglas or LES)
real colvector _cge_cv(struct cge_model scalar M, struct cge_par scalar p, real colvector x)
{
    real colvector PQ0, PQ1, EH0, EH1
    real matrix B, G
    PQ0 = _cge_ph(M, M.p0, M.x0) \ _cge_vn(M, M.x0, "PA")
    PQ1 = _cge_ph(M, p, x) \ _cge_vn(M, x, "PA")
    B = p.beta \ p.betah
    G = p.gamma \ p.gammah
    EH0 = _cge_vn(M, M.x0, "EH")
    EH1 = _cge_vn(M, x, "EH")
    return(EH1 - (PQ1' * G)' - (EH0 - (PQ0' * G)') :* exp(colsum(B :* ln(PQ1 :/ PQ0)))')
}

void _cge_radd(string matrix keys, real colvector val, string scalar table, string scalar measure,
               string scalar element, real scalar value)
{
    keys = keys \ (table, measure, element)
    val = val \ value
}

// Report measures at the point x with parameters p, one row per measure.
// Real measures use base prices, and base world prices for trade.
void _cge_measures(struct cge_model scalar M, struct cge_par scalar p, real colvector x,
                   string matrix keys, real colvector val)
{
    struct cge_par scalar p0
    real colvector PQ, PQ0, QG, QINV, QSHI, QER, QE, QM, fin, YI, TINS, MPS, W, YF, QFS, EH
    real colvector QA, PA, QVA, PVA0, QQ, QX, QD, EFF, PH, PH0, home, PA0, pwe
    real matrix QH
    real scalar EXR, EXR0, CPI, DPI, gdpn, gdpr, k, gsav, intd, intf, endd, endf

    p0 = M.p0
    keys = J(0, 3, "")
    val = J(0, 1, .)
    PQ = _cge_vn(M, x, "PQ");        PQ0 = _cge_vn(M, M.x0, "PQ")
    QH = _cge_vn(M, x, "QH");        QG = _cge_vn(M, x, "QG")
    QINV = _cge_vn(M, x, "QINV");    QSHI = _cge_vn(M, x, "QSHI")
    QER = _cge_vn(M, x, "QER");      QE = _cge_vn(M, x, "QE")
    QM = _cge_vn(M, x, "QM");        EXR = _cge_vn(M, x, "EXR")
    EXR0 = _cge_vn(M, M.x0, "EXR");  CPI = _cge_vn(M, x, "CPI")
    DPI = _cge_vn(M, x, "DPI");      YI = _cge_vn(M, x, "YI")
    TINS = _cge_vn(M, x, "TINS");    MPS = _cge_vn(M, x, "MPS")
    W = _cge_vn(M, x, "W");          YF = _cge_vn(M, x, "YF")
    QFS = _cge_vn(M, x, "QFS");      EH = _cge_vn(M, x, "EH")
    QA = _cge_vn(M, x, "QA");        PA = _cge_vn(M, x, "PA")
    QVA = _cge_vn(M, x, "QVA");      PVA0 = _cge_vn(M, M.x0, "PVA")
    QQ = _cge_vn(M, x, "QQ");        QX = _cge_vn(M, x, "QX")
    QD = _cge_vn(M, x, "QD");        EFF = _cge_vn(M, x, "EFF")

    // Final demand at final-user prices, including VAT; exports from composite
    // supply at PQ (from version 0.3.1)
    PH = _cge_ph(M, p, x)
    PH0 = _cge_ph(M, p0, M.x0)
    fin = rowsum(QH) + QG + QINV + QSHI
    // Home consumption at producer prices, and world export prices (from version 0.3.2)
    home = rowsum(_cge_vn(M, x, "QHA"))
    PA0 = _cge_vn(M, M.x0, "PA")
    pwe = _cge_pwe(M, p, x)
    gdpn = PH' * fin + PQ' * QER + PA' * home + EXR * (pwe' * QE) - EXR * (p.pwm' * QM)
    gdpr = PH0' * fin + PQ0' * QER + PA0' * home + EXR0 * (p0.pwe' * QE) - EXR0 * (p0.pwm' * QM)
    _cge_radd(keys, val, "macro", "gdp_nominal", "", gdpn)
    _cge_radd(keys, val, "macro", "gdp_real", "", gdpr)
    _cge_radd(keys, val, "macro", "gdp_deflator", "", gdpn / gdpr)
    _cge_radd(keys, val, "macro", "consumption_real", "", PH0' * rowsum(QH) + PA0' * home)
    if (any(p0.betah)) _cge_radd(keys, val, "macro", "home_consumption_real", "", PA0' * home)
    _cge_radd(keys, val, "macro", "government_real", "", PH0' * QG)
    _cge_radd(keys, val, "macro", "investment_real", "", PH0' * QINV)
    _cge_radd(keys, val, "macro", "insurance_fund_real", "", PH0' * QSHI)
    _cge_radd(keys, val, "macro", "exports_real", "", EXR0 * (p0.pwe' * QE) + PQ0' * QER)
    _cge_radd(keys, val, "macro", "imports_real", "", EXR0 * (p0.pwm' * QM))
    _cge_radd(keys, val, "macro", "value_added_real", "", PVA0' * QVA)
    _cge_radd(keys, val, "macro", "cpi", "", CPI)
    _cge_radd(keys, val, "macro", "dpi", "", DPI)
    _cge_radd(keys, val, "macro", "exchange_rate", "", EXR)
    _cge_radd(keys, val, "macro", "real_exchange_rate", "", EXR / DPI)
    _cge_radd(keys, val, "macro", "private_savings", "", (MPS :* (1 :- TINS))' * YI)
    _cge_radd(keys, val, "macro", "investment_value", "", PH' * QINV)
    _cge_radd(keys, val, "macro", "foreign_savings", "", _cge_vn(M, x, "FSAV"))

    _cge_radd(keys, val, "government", "revenue", "", _cge_vn(M, x, "YG"))
    _cge_radd(keys, val, "government", "spending", "", _cge_vn(M, x, "EG"))
    _cge_radd(keys, val, "government", "savings", "", _cge_vn(M, x, "GSAV"))
    _cge_radd(keys, val, "government", "tax_direct", "", TINS' * YI)
    _cge_radd(keys, val, "government", "tax_sales", "", sum(p.tq :* _cge_vn(M, x, "TQADJ") :* PQ :* QQ))
    _cge_radd(keys, val, "government", "tax_import", "", EXR * sum(p.tm :* _cge_vn(M, x, "TMADJ") :* p.pwm :* QM))
    _cge_radd(keys, val, "government", "tax_export", "", EXR * sum(p.te :* pwe :* QE))
    _cge_radd(keys, val, "government", "tax_activity", "", sum(p.ta :* PA :* QA))
    _cge_radd(keys, val, "government", "tax_vat", "", _cge_vat(M, p, x))

    // Public debt (model_spec.md, 12.3): stocks at the end of the period
    if (p0.debt == 1) {
        gsav = _cge_vn(M, x, "GSAV")
        intd = p.rd * p.ddebt
        intf = p.rf * p.fdebt * EXR
        endd = p.ddebt + (1 - p.phi) * (-gsav)
        endf = p.fdebt + p.phi * (-gsav) / EXR
        _cge_radd(keys, val, "debt", "interest_domestic", "", intd)
        _cge_radd(keys, val, "debt", "interest_foreign", "", intf)
        _cge_radd(keys, val, "debt", "primary_balance", "", gsav + intd + intf)
        _cge_radd(keys, val, "debt", "debt_domestic", "", endd)
        _cge_radd(keys, val, "debt", "debt_foreign", "", endf * EXR)
        _cge_radd(keys, val, "debt", "debt_foreign_fc", "", endf)
        _cge_radd(keys, val, "debt", "debt_total", "", endd + endf * EXR)
        _cge_radd(keys, val, "debt", "debt_gdp", "", 100 * (endd + endf * EXR) / gdpn)
    }

    for (k = 1; k <= M.nD; k++) _cge_radd(keys, val, "institutions", "income", M.D[k], YI[k])
    for (k = 1; k <= M.nH; k++) _cge_radd(keys, val, "institutions", "consumption", M.H[k], EH[k])
    for (k = 1; k <= M.nF; k++) {
        _cge_radd(keys, val, "factors", "wage", M.F[k], W[k])
        _cge_radd(keys, val, "factors", "real_wage", M.F[k], W[k] / CPI)
        _cge_radd(keys, val, "factors", "income", M.F[k], YF[k])
        _cge_radd(keys, val, "factors", "supply", M.F[k], QFS[k])
        if (M.p0.inlf[k]) {
            _cge_radd(keys, val, "factors", "labour_force", M.F[k], p.qlf[k])
            _cge_radd(keys, val, "factors", "unemployment_rate", M.F[k], 100 * (1 - QFS[k] / p.qlf[k]))
        }
    }
    for (k = 1; k <= M.n; k++) {
        _cge_radd(keys, val, "activities", "output", M.A[k], QA[k])
        _cge_radd(keys, val, "activities", "price", M.A[k], PA[k])
        _cge_radd(keys, val, "activities", "value_added", M.A[k], QVA[k])
    }
    for (k = 1; k <= M.nC; k++) {
        _cge_radd(keys, val, "commodities", "supply", M.C[k], QQ[k])
        _cge_radd(keys, val, "commodities", "price", M.C[k], PQ[k])
        _cge_radd(keys, val, "commodities", "output", M.C[k], QX[k])
        _cge_radd(keys, val, "commodities", "domestic_sales", M.C[k], QD[k])
        _cge_radd(keys, val, "commodities", "exports", M.C[k], QE[k] + QER[k])
        _cge_radd(keys, val, "commodities", "imports", M.C[k], QM[k])
        if (M.ced[k]) _cge_radd(keys, val, "commodities", "world_export_price", M.C[k], pwe[k])
    }
    if (any(M.p0.etah)) {
        _cge_radd(keys, val, "health", "health_services", "", _cge_vn(M, x, "HS"))
        for (k = 1; k <= M.nF; k++) {
            if (M.p0.etah[k] != 0) _cge_radd(keys, val, "health", "efficiency", M.F[k], EFF[k])
        }
    }
    if (M.ishi) {
        _cge_radd(keys, val, "health", "fund_revenue", "", _cge_vn(M, x, "YSHI"))
        _cge_radd(keys, val, "health", "fund_volume", "", _cge_vn(M, x, "SHIADJ"))
    }
}

// Simulation indexes from a list of names: the most recent one when empty,
// every one for _all
real colvector _cge_sim_list(struct cge_model scalar M, string scalar sims)
{
    string rowvector tok
    real colvector s
    real scalar k
    if (sims == "") return(_cge_sim_index(M, ""))
    if (sims == "_all" | sims == "all") {
        if (rows(M.simname) == 0) _cge_fail("no simulation has been solved; use cge_solve", 459)
        return((1::rows(M.simname)))
    }
    tok = tokens(sims)
    s = J(cols(tok), 1, 0)
    for (k = 1; k <= cols(tok); k++) s[k] = _cge_sim_index(M, tok[k])
    return(s)
}

// Report rows for simulations s: keys (table, measure, element), base values,
// simulated values (one column per simulation) and percentage changes. For the
// equivalent and compensating variations, the base is zero and the percentage
// is of base household consumption; for rates (the debt ratio and unemployment
// rates; from version 0.3.3) the change is in percentage points.
void _cge_report_rows(struct cge_model scalar M, real colvector s, string matrix keys,
                      real colvector base, real matrix vals, real matrix pct)
{
    string matrix k1
    real colvector v, ev, cv, eh0, rate
    real scalar j, h, nr

    _cge_measures(M, M.p0, M.x0, keys, base)
    nr = rows(base)
    rate = (keys[., 2] :== "debt_gdp") :| (keys[., 2] :== "unemployment_rate")
    eh0 = _cge_vn(M, M.x0, "EH")
    for (h = 1; h <= M.nH; h++) {
        keys = keys \ ("welfare", "equivalent_variation", M.H[h]) \ ("welfare", "compensating_variation", M.H[h])
        base = base \ 0 \ 0
    }
    vals = J(rows(base), rows(s), .)
    pct = vals
    for (j = 1; j <= rows(s); j++) {
        _cge_measures(M, M.simp[s[j]], M.simx[., s[j]], k1, v)
        ev = _cge_ev(M, M.simp[s[j]], M.simx[., s[j]])
        cv = _cge_cv(M, M.simp[s[j]], M.simx[., s[j]])
        for (h = 1; h <= M.nH; h++) v = v \ ev[h] \ cv[h]
        vals[., j] = v
        pct[|1, j \ nr, j|] = 100 :* (v[|1 \ nr|] - base[|1 \ nr|]) :/ abs(base[|1 \ nr|])
        pct[|1, j \ nr, j|] = pct[|1, j \ nr, j|] :/ (base[|1 \ nr|] :!= 0)
        for (h = 1; h <= nr; h++) if (rate[h]) pct[h, j] = v[h] - base[h]
        for (h = 1; h <= M.nH; h++) {
            pct[nr + 2 * h - 1, j] = 100 * ev[h] / eh0[h]
            pct[nr + 2 * h, j] = 100 * cv[h] / eh0[h]
        }
    }
}

// Display the report, and optionally fill the dataset in memory (mode "long":
// one observation per simulation and measure; "wide": one per measure, with
// a value and a percentage change for each simulation)
void _cge_report_run(string scalar sims, string scalar tables, real scalar show, string scalar mode)
{
    struct cge_model scalar M
    string matrix keys
    string rowvector tab, alltab, title
    real colvector s, base, sel
    real matrix vals, pct
    real scalar t, i, j, n, ns, w1

    M = _cge_load()
    _cge_need(M, "calibrated")
    s = _cge_sim_list(M, sims)
    ns = rows(s)
    _cge_report_rows(M, s, keys, base, vals, pct)
    alltab = ("macro", "government", "debt", "institutions", "factors", "activities", "commodities", "health", "welfare")
    title = ("Macroeconomic aggregates", "Government", "Public debt", "Institutions", "Factors", "Activities",
             "Commodities", "Health", "Welfare (per cent of base consumption)")
    tab = (tables == "" ? ("macro", "government", "debt", "institutions", "factors", "health", "welfare") :
          (tables == "all" ? alltab : tokens(tables)))
    for (t = 1; t <= cols(tab); t++) {
        if (!anyof(alltab, tab[t])) _cge_fail("tables(): " + tab[t] + " is not a report table (" +
                                              invtokens(alltab) + ")", 198)
    }
    if (show) {
        for (t = 1; t <= cols(tab); t++) {
            sel = select((1::rows(keys)), keys[., 1] :== tab[t])
            if (rows(sel) == 0) continue
            w1 = max((24, max(strlen(keys[sel, 2] :+ " " :+ keys[sel, 3])))) + 1
            printf("\n{txt}%s\n", title[_cge_find(alltab', tab[t])])
            printf("{txt}%s\n", "{hline " + strofreal(w1 + 13 + 11 * min((ns, 6))) + "}")
            printf("{txt}%-" + strofreal(w1) + "s %12s", "", (tab[t] == "welfare" ? "" : "base"))
            for (j = 1; j <= min((ns, 6)); j++) printf(" %10s", abbrev(M.simname[s[j]], 10))
            printf("\n")
            for (i = 1; i <= rows(sel); i++) {
                n = sel[i]
                printf("{txt}%-" + strofreal(w1) + "s ", keys[n, 2] + (keys[n, 3] == "" ? "" : " " + keys[n, 3]))
                if (tab[t] == "welfare") printf("%12s", "")
                else printf("{res}%12.4g", base[n])
                for (j = 1; j <= min((ns, 6)); j++) printf("{res} %10.3f", pct[n, j])
                printf("\n")
            }
            printf("{txt}%s\n", "{hline " + strofreal(w1 + 13 + 11 * min((ns, 6))) + "}")
        }
        printf("{txt}Percentage changes from the base (rates: percentage points)")
        if (ns > 6) printf("; the first 6 of %f simulations are shown", ns)
        printf("\n")
    }
    if (mode == "long") _cge_report_long(M, s, keys, base, vals, pct)
    if (mode == "wide") _cge_report_wide(M, s, keys, base, vals, pct)
    st_numscalar("r(N_measures)", rows(keys))
    st_numscalar("r(N_sims)", ns)
}

void _cge_report_long(struct cge_model scalar M, real colvector s, string matrix keys, real colvector base,
                      real matrix vals, real matrix pct)
{
    real scalar n, ns, j
    string colvector sim
    n = rows(keys)
    ns = rows(s)
    sim = J(0, 1, "")
    for (j = 1; j <= ns; j++) sim = sim \ J(n, 1, M.simname[s[j]])
    st_addobs(n * ns)
    (void) st_addvar("str32", "sim")
    (void) st_addvar("str16", "table")
    (void) st_addvar("str32", "measure")
    (void) st_addvar("str32", "element")
    (void) st_addvar("double", ("base", "value", "pct"))
    st_sstore(., "sim", sim)
    st_sstore(., "table", J(ns, 1, keys[., 1]))
    st_sstore(., "measure", J(ns, 1, keys[., 2]))
    st_sstore(., "element", J(ns, 1, keys[., 3]))
    st_store(., "base", J(ns, 1, base))
    st_store(., "value", colshape(vals', 1))
    st_store(., "pct", colshape(pct', 1))
    st_varlabel("sim", "Simulation")
    st_varlabel("table", "Report table")
    st_varlabel("measure", "Measure")
    st_varlabel("element", "Set element")
    st_varlabel("base", "Base value")
    st_varlabel("value", "Simulated value")
    st_varlabel("pct", "Per cent change (rates: points; welfare: per cent of base consumption)")
}

void _cge_report_wide(struct cge_model scalar M, real colvector s, string matrix keys, real colvector base,
                      real matrix vals, real matrix pct)
{
    real scalar n, j
    n = rows(keys)
    st_addobs(n)
    (void) st_addvar("str16", "table")
    (void) st_addvar("str32", "measure")
    (void) st_addvar("str32", "element")
    (void) st_addvar("double", "base")
    st_sstore(., "table", keys[., 1])
    st_sstore(., "measure", keys[., 2])
    st_sstore(., "element", keys[., 3])
    st_store(., "base", base)
    st_varlabel("table", "Table")
    st_varlabel("measure", "Measure")
    st_varlabel("element", "Element")
    st_varlabel("base", "Base")
    for (j = 1; j <= rows(s); j++) {
        (void) st_addvar("double", ("v" + strofreal(j), "p" + strofreal(j)))
        st_store(., "v" + strofreal(j), vals[., j])
        st_store(., "p" + strofreal(j), pct[., j])
        st_varlabel("v" + strofreal(j), M.simname[s[j]] + ": value")
        st_varlabel("p" + strofreal(j), M.simname[s[j]] + ": % change (rates: points)")
    }
}

// =====================================================================
// Calibrated parameters as a dataset (from version 0.1.15)
// =====================================================================

void _cge_padd(string matrix keys, real colvector val, string scalar name, real matrix X,
               string colvector r, string colvector c)
{
    real colvector i
    real scalar n
    n = rows(X) * cols(X)
    if (n == 0) return
    i = (1::n)
    // colshape(): subscripting a 1 x 1 vector returns a row
    keys = keys \ (J(n, 1, name), colshape(r[floor((i :- 1) :/ cols(X)) :+ 1], 1),
                   (rows(c) ? colshape(c[mod(i :- 1, cols(X)) :+ 1], 1) : J(n, 1, "")))
    val = val \ colshape(X, 1)
}

void _cge_param_data(string scalar sim, real scalar current)
{
    struct cge_model scalar M
    struct cge_par scalar p
    string matrix keys
    string colvector none
    real colvector val
    M = _cge_load()
    _cge_need(M, "calibrated")
    if (sim != "") p = M.simp[_cge_sim_index(M, sim)]
    else p = (current ? M.p : M.p0)
    keys = J(0, 3, "")
    val = J(0, 1, .)
    none = J(0, 1, "")
    // commodities
    _cge_padd(keys, val, "pwm", p.pwm, M.C, none);   _cge_padd(keys, val, "pwe", p.pwe, M.C, none)
    _cge_padd(keys, val, "tm", p.tm, M.C, none);     _cge_padd(keys, val, "te", p.te, M.C, none)
    _cge_padd(keys, val, "tq", p.tq, M.C, none);     _cge_padd(keys, val, "at", p.at, M.C, none)
    _cge_padd(keys, val, "dt", p.dt, M.C, none);     _cge_padd(keys, val, "dtc", p.dtc, M.C, none)
    _cge_padd(keys, val, "rt", p.rt, M.C, none);     _cge_padd(keys, val, "st", p.st, M.C, none)
    _cge_padd(keys, val, "aq", p.aq, M.C, none);     _cge_padd(keys, val, "dq", p.dq, M.C, none)
    _cge_padd(keys, val, "dqc", p.dqc, M.C, none);   _cge_padd(keys, val, "rq", p.rq, M.C, none)
    _cge_padd(keys, val, "sq", p.sq, M.C, none);     _cge_padd(keys, val, "qg", p.qg, M.C, none)
    _cge_padd(keys, val, "qinv", p.qinv, M.C, none); _cge_padd(keys, val, "qer", p.qer, M.C, none)
    _cge_padd(keys, val, "cwts", p.cwts, M.C, none); _cge_padd(keys, val, "dwts", p.dwts, M.C, none)
    _cge_padd(keys, val, "qshi", p.qshi, M.C, none); _cge_padd(keys, val, "tv", p.tv, M.C, none)
    _cge_padd(keys, val, "etae", p.etae, M.C, none); _cge_padd(keys, val, "qe0", p.qe0, M.C, none)
    // activities
    _cge_padd(keys, val, "ta", p.ta, M.A, none);     _cge_padd(keys, val, "ad", p.ad, M.A, none)
    _cge_padd(keys, val, "iva", p.iva, M.A, none);   _cge_padd(keys, val, "inta", p.inta, M.A, none)
    _cge_padd(keys, val, "rva", p.rva, M.A, none);   _cge_padd(keys, val, "sva", p.sva, M.A, none)
    _cge_padd(keys, val, "aa", p.aa, M.A, none);     _cge_padd(keys, val, "dla", p.dla, M.A, none)
    _cge_padd(keys, val, "dlac", p.dlac, M.A, none); _cge_padd(keys, val, "rha", p.rha, M.A, none)
    _cge_padd(keys, val, "sa", p.sa, M.A, none);     _cge_padd(keys, val, "kappa", p.kappa, M.A, none)
    // matrices
    _cge_padd(keys, val, "ica", p.ica, M.C, M.A);     _cge_padd(keys, val, "dva", p.dva, M.F, M.A)
    _cge_padd(keys, val, "theta", p.theta, M.A, M.C); _cge_padd(keys, val, "icm", p.icm, M.C, M.C)
    _cge_padd(keys, val, "shif", p.shif, M.I, M.F);   _cge_padd(keys, val, "beta", p.beta, M.C, M.H)
    _cge_padd(keys, val, "gamma", p.gamma, M.C, M.H); _cge_padd(keys, val, "shii", p.shii, M.D, M.D)
    _cge_padd(keys, val, "betah", p.betah, M.A, M.H); _cge_padd(keys, val, "gammah", p.gammah, M.A, M.H)
    _cge_padd(keys, val, "icd", p.icd, M.C, M.C);     _cge_padd(keys, val, "ici", p.ici, M.C, M.C)
    _cge_padd(keys, val, "ice", p.ice, M.C, M.C)
    // institutions and factors
    _cge_padd(keys, val, "tins0", p.tins0, M.D, none); _cge_padd(keys, val, "mps0", p.mps0, M.D, none)
    _cge_padd(keys, val, "shir", p.shir, M.D, none);   _cge_padd(keys, val, "trdg", p.trdg, M.D, none)
    _cge_padd(keys, val, "trdr", p.trdr, M.D, none);   _cge_padd(keys, val, "hc", p.hc, M.H, none)
    _cge_padd(keys, val, "trfr", p.trfr, M.F, none);   _cge_padd(keys, val, "tshi", p.tshi, M.F, none)
    _cge_padd(keys, val, "af", p.af, M.F, none);       _cge_padd(keys, val, "etah", p.etah, M.F, none)
    _cge_padd(keys, val, "hold", p.hold, M.D, none)
    _cge_padd(keys, val, "inlf", p.inlf, M.F, none);   _cge_padd(keys, val, "qlf", p.qlf, M.F, none)
    _cge_padd(keys, val, "u0", p.u0, M.F, none);       _cge_padd(keys, val, "epsw", p.epsw, M.F, none)
    _cge_padd(keys, val, "wref", p.wref, M.F, none);   _cge_padd(keys, val, "wmin", p.wmin, M.F, none)
    _cge_padd(keys, val, "hasmin", p.hasmin, M.F, none)
    // scalars
    _cge_padd(keys, val, "trgr", p.trgr, "", none);    _cge_padd(keys, val, "trrg", p.trrg, "", none)
    _cge_padd(keys, val, "trgg", p.trgg, "", none);    _cge_padd(keys, val, "sshi", p.sshi, "", none)
    _cge_padd(keys, val, "trshi", p.trshi, "", none);  _cge_padd(keys, val, "trshir", p.trshir, "", none)
    _cge_padd(keys, val, "hs0", p.hs0, "", none)
    _cge_padd(keys, val, "debt", p.debt, "", none);    _cge_padd(keys, val, "ddebt", p.ddebt, "", none)
    _cge_padd(keys, val, "fdebt", p.fdebt, "", none);  _cge_padd(keys, val, "rd", p.rd, "", none)
    _cge_padd(keys, val, "rf", p.rf, "", none);        _cge_padd(keys, val, "phi", p.phi, "", none)
    _cge_padd(keys, val, "mu", p.mu, "", none)
    st_addobs(rows(val))
    (void) st_addvar("str8", "parameter")
    (void) st_addvar("str32", "element1")
    (void) st_addvar("str32", "element2")
    (void) st_addvar("double", "value")
    st_sstore(., "parameter", keys[., 1])
    st_sstore(., "element1", keys[., 2])
    st_sstore(., "element2", keys[., 3])
    st_store(., "value", val)
    st_varlabel("parameter", "Parameter (docs/model_spec.md, Section 4)")
    st_varlabel("element1", "First set element")
    st_varlabel("element2", "Second set element")
    st_varlabel("value", "Value")
    st_numscalar("r(N)", rows(val))
}

// =====================================================================
// Saving and loading a model (from version 0.1.15)
// =====================================================================

void _cge_io_put(real scalar fh, string scalar name, transmorphic matrix v)
{
    fputmatrix(fh, name)
    fputmatrix(fh, v)
}

void _cge_save(string scalar fn, real scalar replace)
{
    struct cge_model scalar M
    real scalar fh
    M = _cge_load()
    if (fileexists(fn)) {
        if (!replace) _cge_fail("file " + fn + " already exists; use replace", 602)
        unlink(fn)
    }
    fh = fopen(fn, "w")
    fputmatrix(fh, "cge-stata model")
    fputmatrix(fh, _cge_version())
    _cge_model_write(fh, M)
    fputmatrix(fh, "__end__")
    fclose(fh)
    printf("{txt}Model saved to {res}%s{txt} (%s, %f simulation(s))\n", fn,
           (M.calibrated == 1 ? "calibrated" : (M.mapped == 1 ? "mapped" : "SAM only")), rows(M.simname))
}

// The bytes that fputmatrix() writes for the identifier of a model file
string scalar _cge_signature()
{
    string scalar tmp, sig
    real scalar fh
    tmp = st_tempfilename()
    fh = fopen(tmp, "w")
    fputmatrix(fh, "cge-stata model")
    fclose(fh)
    fh = fopen(tmp, "r")
    sig = fread(fh, 4096)
    fclose(fh)
    unlink(tmp)
    return(sig)
}

// Defaults of the parameters added in version 0.3.1, for models saved before it
void _cge_par_fill(struct cge_par scalar p, struct cge_model scalar M)
{
    if (M.calibrated != 1) return
    if (rows(p.tv) == 0) p.tv = J(M.nC, 1, 0)
    if (rows(p.kappa) == 0) p.kappa = J(M.n, 1, 1)
    if (rows(p.hold) == 0) p.hold = J(M.nD, 1, 0)
    if (p.debt >= .) p.debt = 0
    if (p.ddebt >= .) p.ddebt = 0
    if (p.fdebt >= .) p.fdebt = 0
    if (p.rd >= .) p.rd = 0
    if (p.rf >= .) p.rf = 0
    if (p.phi >= .) p.phi = 0
    if (rows(p.icd) == 0) p.icd = J(M.nC, M.nC, 0)
    if (rows(p.ici) == 0) p.ici = J(M.nC, M.nC, 0)
    if (rows(p.ice) == 0) p.ice = J(M.nC, M.nC, 0)
    if (rows(p.etae) == 0) p.etae = J(M.nC, 1, 0)
    if (rows(p.qe0) == 0) p.qe0 = J(M.nC, 1, 0)
    if (rows(p.betah) == 0) p.betah = J(M.n, M.nH, 0)
    if (rows(p.gammah) == 0) p.gammah = J(M.n, M.nH, 0)
    // 0.3.3: no labour force (the values only fill the masked equations)
    if (rows(p.inlf) == 0) {
        p.inlf = J(M.nF, 1, 0)
        p.qlf = J(M.nF, 1, 1)
        p.u0 = J(M.nF, 1, 1)
        p.epsw = J(M.nF, 1, 0)
        p.wref = J(M.nF, 1, 1)
        p.wmin = J(M.nF, 1, 1)
        p.hasmin = J(M.nF, 1, 0)
    }
    if (p.mu >= .) p.mu = 1e-10
}

// Variables added after the saved model's version are appended to the layout:
// TQADJ, TMADJ and TVADJ (0.3.1), fixed at one; PWE and QHA (0.3.2), and LSW
// and LSM (0.3.3), which do not exist in older models. The Jacobian pattern is
// rebuilt.
void _cge_use_upgrade(struct cge_model scalar M)
{
    real scalar nold, k, v, len
    real colvector val, ex, L, R, K, mag
    string colvector oldnames
    oldnames = M.vname
    nold = rows(M.x0)
    _cge_layout(M)
    for (k = rows(oldnames) + 1; k <= rows(M.vname); k++) {
        len = M.vrows[k] * M.vcols[k]
        if (M.vname[k] == "PWE") {
            val = M.p0.pwe
            ex = J(len, 1, 0)
        }
        else if (anyof(("QHA", "LSW", "LSM"), M.vname[k])) {
            val = J(len, 1, 0)
            ex = J(len, 1, 0)
        }
        else {
            val = J(len, 1, 1)
            ex = J(len, 1, 1)
        }
        M.x0 = M.x0 \ val
        M.xcur = M.xcur \ val
        M.xscale = M.xscale \ (abs(val) :* (abs(val) :> 1e-12) + (abs(val) :<= 1e-12))
        M.exists = M.exists \ ex
        M.fixed = M.fixed \ J(len, 1, 1)
        M.nominal = M.nominal \ J(len, 1, 0)
        M.simx = M.simx \ J(1, cols(M.simx), val)
    }
    v = M.voff[rows(M.voff)] + M.vrows[rows(M.vrows)] * M.vcols[rows(M.vcols)]
    if (rows(M.x0) != v) _cge_fail("cge internal error: the saved model's variables do not match", 3498)
    // Equation blocks added since are recorded (masked for the old model), with
    // masks and scales from the base point, as at calibration
    _cge_eq(M, M.p0, M.x0, L, R, K, 1)
    M.emask = K
    mag = rowmax((abs(L), abs(R)))
    M.escale = mag :* (mag :> 1e-9) + (mag :<= 1e-9)
    if (sum(K) != M.neq) _cge_fail("cge internal error: the saved model's equations do not match", 3498)
    _cge_pattern(M, M.p0)
}

void _cge_use(string scalar fn)
{
    struct cge_model scalar M
    struct cge_par scalar q0, q1, qs
    struct cge_par rowvector sp
    transmorphic matrix v, hd
    string scalar name, ver, rest, sig, head
    real scalar fh, unknown, ok, cur, d, k
    if (!fileexists(fn)) _cge_fail("file " + fn + " not found", 601)
    // Check the file's identifier before fgetmatrix(), which stops with an
    // error on another kind of file and would leave it open. Some header bytes
    // that fputmatrix() writes differ between Stata sessions, so only the
    // format's opening bytes and the identifier itself are compared.
    sig = _cge_signature()
    fh = fopen(fn, "r")
    hd = fread(fh, strlen(sig))
    head = (rows(hd) * cols(hd) ? hd : "")
    if (substr(head, 1, 5) != substr(sig, 1, 5) | !strpos(head, "cge-stata model")) {
        fclose(fh)
        _cge_fail(fn + " is not a cge-stata model file", 610)
    }
    fseek(fh, 0, -1)
    v = fgetmatrix(fh)
    ver = fgetmatrix(fh)
    unknown = 0
    // Parameter structures are built in fresh structures and assigned once:
    // in Stata 13, reading an element of a structure vector back, changing it
    // and storing it again can hang Mata. A simulation's parameters are
    // contiguous in the file.
    q0 = cge_par()
    q1 = cge_par()
    qs = cge_par()
    sp = cge_par(1, 0)
    cur = 0
    while (1) {
        name = fgetmatrix(fh)
        if (name == "__end__") break
        v = fgetmatrix(fh)
        if (substr(name, 1, 3) == "p0.") ok = _cge_par_member(q0, substr(name, 4, .), v)
        else if (substr(name, 1, 2) == "p.") ok = _cge_par_member(q1, substr(name, 3, .), v)
        else if (name == "simp.count") {
            sp = cge_par(1, v)
            ok = 1
        }
        else if (substr(name, 1, 5) == "simp.") {
            rest = substr(name, 6, .)
            d = strpos(rest, ".")
            k = strtoreal(substr(rest, 1, d - 1))
            if (k != cur) {
                if (cur) {
                    _cge_par_fill(qs, M)
                    sp[cur] = qs
                }
                qs = cge_par()
                cur = k
            }
            ok = _cge_par_member(qs, substr(rest, d + 1, .), v)
        }
        else ok = _cge_model_member(M, name, v)
        if (!ok) unknown++
    }
    fclose(fh)
    if (cur) {
        _cge_par_fill(qs, M)
        sp[cur] = qs
    }
    _cge_par_fill(q0, M)
    _cge_par_fill(q1, M)
    M.p0 = q0
    M.p = q1
    M.simp = sp
    // Files saved before version 0.3.1 have no VAT account and no tax scaling
    // factors TQADJ, TMADJ and TVADJ: these are added, fixed at one, and the
    // Jacobian pattern is rebuilt
    if (M.ivattax >= .) M.ivattax = 0
    // Files saved before version 0.3.2: no margins by market, export demand,
    // export-only commodities or home consumption
    if (M.calibrated == 1) {
        if (rows(M.tmkt) != rows(M.iT)) M.tmkt = J(rows(M.iT), 1, 0)
        if (rows(M.cxe) == 0) M.cxe = J(M.nC, 1, 0)
        if (rows(M.ced) == 0) M.ced = J(M.nC, 1, 0)
        if (rows(M.cdo) == 0) M.cdo = M.cx
        if (rows(M.cq) == 0) M.cq = (M.cx :| M.cm)
        if (!_cge_vidx(M, "LSM")) _cge_use_upgrade(M)
    }
    // Files saved before version 0.2.0 have no dynamic-run items
    if (rows(M.simrun) != rows(M.simname)) {
        M.simrun = J(rows(M.simname), 1, "")
        M.simper = J(rows(M.simname), 1, .)
        M.simlam = J(rows(M.simname), 1, .)
    }
    _cge_store(M)
    printf("{txt}Model loaded from {res}%s{txt} (saved by cge-stata %s; %s, %f simulation(s))\n", fn, ver,
           (M.calibrated == 1 ? "calibrated" : (M.mapped == 1 ? "mapped" : "SAM only")), rows(M.simname))
    if (unknown) printf("{txt}Note: %f saved item(s) are not used by this version and were ignored\n", unknown)
    st_global("r(saved_by)", ver)
}


// =====================================================================
// Recursive dynamics (model_spec.md, Section 10; from version 0.2.0)
// =====================================================================

// State of a dynamic run while cge_dynamic runs; kept outside the model
struct cge_dyn {
    string scalar         name
    real colvector        periods, prev, capital, delta, rental, fgrowth, tfp, target, lampath
    real scalar           k, sens, gpop, ggov, gfor, mode, tol, maxit
    struct cge_par scalar psave
    real colvector        xsave
}

struct cge_dyn scalar _cge_dyn_load()
{
    pointer() scalar q
    q = findexternal("cge__dyn")
    if (q == NULL) _cge_fail("cge internal error: no dynamic run in progress", 3498)
    return(*q)
}

void _cge_dyn_store(struct cge_dyn scalar D)
{
    pointer() scalar q
    if ((q = findexternal("cge__dyn")) == NULL) q = crexternal("cge__dyn")
    *q = D
}

// One value, or one per element of a set
real colvector _cge_dyn_values(string scalar s, real scalar n, string scalar what)
{
    real colvector v
    v = strtoreal(tokens(s))'
    if (rows(v) == 1) v = J(n, 1, v)
    if (rows(v) != n | hasmissing(v)) _cge_fail(what + " needs 1 or " + strofreal(n) + " values", 198)
    return(v)
}

void _cge_dyn_start(string scalar name, string scalar periods, string scalar capital,
                    string scalar depreciation, string scalar rental, real scalar sens,
                    string scalar growth, string scalar tfp, string scalar gdpgrowth,
                    string scalar baseline, real scalar gpop, real scalar ggov, real scalar gfor,
                    real scalar tol, real scalar maxit)
{
    struct cge_model scalar M
    struct cge_dyn scalar D
    string rowvector tok, pair
    real colvector idx, s
    real scalar j, f, T

    M = _cge_load()
    _cge_need(M, "calibrated")
    D.name = name
    D.periods = strtoreal(tokens(periods))'
    T = rows(D.periods) - 1
    D.k = 1
    D.sens = sens
    D.gpop = gpop
    D.ggov = ggov
    D.gfor = gfor
    D.tol = tol
    D.maxit = maxit
    if (sens < 0) _cge_fail("sensitivity() must be zero or positive", 198)

    // Capital factors, with depreciation and base gross rental rates
    D.capital = J(M.nF, 1, 0)
    D.delta = J(M.nF, 1, 0)
    D.rental = J(M.nF, 1, 0)
    if (capital != "") {
        idx = _cge_elements(M.F, capital, "factors")
        if (depreciation == "" | rental == "") {
            _cge_fail("capital() needs depreciation() and rental(): they set how investment adds to capital", 198)
        }
        D.capital[idx] = J(rows(idx), 1, 1)
        D.delta[idx] = _cge_dyn_values(depreciation, rows(idx), "depreciation()")
        D.rental[idx] = _cge_dyn_values(rental, rows(idx), "rental()")
        for (j = 1; j <= rows(idx); j++) {
            if (anyof(("unemployed", "wagecurve", "minwage"), M.c_fac[idx[j]])) {
                _cge_fail("capital(): " + M.F[idx[j]] + " is " + M.c_fac[idx[j]] + " in the closure; capital must be mobile or specific", 198)
            }
        }
    }
    else if (depreciation != "" | rental != "") _cge_fail("depreciation() and rental() need capital()", 198)

    // Growth of other factors: factor:rate pairs
    D.fgrowth = J(M.nF, 1, 0)
    tok = tokens(growth)
    for (j = 1; j <= cols(tok); j++) {
        pair = tokens(tok[j], ":")
        if (cols(pair) != 3) _cge_fail("growth(): write factor:rate, for example lab:0.02", 198)
        f = _cge_find(M.F, pair[1])
        if (f == 0) _cge_fail("growth(): " + pair[1] + " is not a factor of the model", 111)
        if (D.capital[f]) _cge_fail("growth(): " + pair[1] + " is a capital factor", 198)
        D.fgrowth[f] = strtoreal(pair[3])
        if (missing(D.fgrowth[f])) _cge_fail("growth(): rate for " + pair[1] + " is not a number", 198)
        if (D.fgrowth[f] != 0 & M.c_fac[f] == "unemployed" & !M.p0.inlf[f]) {
            _cge_fail("growth(): " + pair[1] + " is unemployed, so its supply is not fixed", 198)
        }
    }

    // Efficiency: rates (mode 0), growth targets (1) or a baseline's path (2)
    if ((tfp != "") + (gdpgrowth != "") + (baseline != "") > 1) {
        _cge_fail("choose one of tfp(), gdpgrowth() and baseline()", 198)
    }
    D.mode = 0
    D.tfp = (tfp == "" ? J(M.n, 1, 0) : _cge_dyn_values(tfp, M.n, "tfp()"))
    D.target = J(0, 1, .)
    D.lampath = J(0, 1, .)
    if (gdpgrowth != "") {
        D.mode = 1
        D.target = _cge_dyn_values(gdpgrowth, T, "gdpgrowth()")
    }
    if (baseline != "") {
        D.mode = 2
        D.lampath = J(T, 1, .)
        for (j = 1; j <= T; j++) {
            s = select((1::rows(M.simname)), (M.simrun :== baseline) :* (M.simper :== D.periods[j + 1]))
            if (rows(s) != 1) {
                _cge_fail("baseline(): run " + baseline + " has no period " + strofreal(D.periods[j + 1]), 111)
            }
            D.lampath[j] = M.simlam[s[1]]
            if (missing(D.lampath[j])) {
                _cge_fail("baseline(): run " + baseline + " did not solve for efficiency (use gdpgrowth() there)", 198)
            }
        }
    }

    // The run starts from the base; shocks set before it are kept aside
    D.psave = M.p
    D.xsave = M.xcur
    if (M.xcur != M.x0) printf("{txt}Note: the run starts from the base; fixed values set with cge_shock are not used\n")
    M.p = M.p0
    M.xcur = M.x0
    D.prev = M.x0
    _cge_store(M)
    _cge_dyn_store(D)
}

// Updates before the next period (Section 10, steps 1 to 4), from the solution
// of the previous period
void _cge_dyn_advance()
{
    struct cge_model scalar M
    struct cge_dyn scalar D
    real matrix QF, WFD
    real colvector QFS, W, inv0, YF0, q, s, rent, eta, qlf
    real scalar f, inv, newk, avg, yk, def

    M = _cge_load()
    D = _cge_dyn_load()
    QF = _cge_vn(M, D.prev, "QF")
    WFD = _cge_vn(M, D.prev, "WFDIST")
    QFS = _cge_vn(M, D.prev, "QFS")
    W = _cge_vn(M, D.prev, "W")
    inv = _cge_vn(M, M.x0, "PQ")' * _cge_vn(M, D.prev, "QINV")
    YF0 = _cge_vn(M, M.x0, "YF")
    yk = sum(D.capital :* YF0)
    qlf = M.p.qlf
    for (f = 1; f <= M.nF; f++) {
        if (D.capital[f]) {
            // 1. Capital: depreciation plus new capital from real investment
            newk = D.rental[f] * YF0[f] / yk * inv
            if (M.c_fac[f] == "specific") {
                q = M.fa[f, .]' :* QF[f, .]'
                s = q / sum(q)
                rent = W[f] :* WFD[f, .]'
                avg = s' * rent
                eta = M.fa[f, .]' :* s :* (1 :+ D.sens :* (rent :/ avg :- 1))
                eta = eta :* (eta :> 0)
                eta = eta / sum(eta)
                QF[f, .] = ((1 - D.delta[f]) :* q + newk :* eta)'
            }
            else QFS[f] = (1 - D.delta[f]) * QFS[f] + newk
        }
        else {
            // 2. Other factors
            if (M.c_fac[f] == "specific") QF[f, .] = (1 + D.fgrowth[f]) :* QF[f, .]
            else if (M.c_fac[f] == "mobile") QFS[f] = (1 + D.fgrowth[f]) * QFS[f]
            // The labour force grows at the same rate (model_spec.md, 14.4)
            if (M.p0.inlf[f]) qlf[f] = (1 + D.fgrowth[f]) * qlf[f]
        }
    }
    M.p.qlf = qlf
    _cge_setv(M, M.xcur, "QF", QF)
    _cge_setv(M, M.xcur, "QFS", QFS)
    // 3. Population; 4. government and foreign flows
    M.p.gamma = M.p.gamma :* (1 + D.gpop)
    M.p.gammah = M.p.gammah :* (1 + D.gpop)
    M.p.hs0 = M.p.hs0 * (1 + D.gpop)
    M.p.qg = M.p.qg :* (1 + D.ggov)
    M.p.trdg = M.p.trdg :* (1 + D.ggov)
    M.p.trgg = M.p.trgg * (1 + D.ggov)
    M.p.trshi = M.p.trshi * (1 + D.ggov)
    M.p.trdr = M.p.trdr :* (1 + D.gfor)
    M.p.trfr = M.p.trfr :* (1 + D.gfor)
    M.p.trgr = M.p.trgr * (1 + D.gfor)
    M.p.trrg = M.p.trrg * (1 + D.gfor)
    M.p.trshir = M.p.trshir * (1 + D.gfor)
    if (M.c_ext == "flexexr") _cge_setv(M, M.xcur, "FSAV", _cge_vn(M, M.xcur, "FSAV") * (1 + D.gfor))
    // 5. Public debt (model_spec.md, 12.3): last period's deficit is borrowed,
    // the share phi abroad; a surplus repays debt in the same shares
    if (M.p.debt == 1) {
        def = -_cge_vn(M, D.prev, "GSAV")
        M.p.ddebt = M.p.ddebt + (1 - M.p.phi) * def
        M.p.fdebt = M.p.fdebt + M.p.phi * def / _cge_vn(M, D.prev, "EXR")
    }
    _cge_store(M)
}

real scalar _cge_dyn_va(struct cge_model scalar M, real colvector x)
{
    return(_cge_vn(M, M.x0, "PVA")' * _cge_vn(M, x, "QVA"))
}

// Solve one period (step 6 of Section 10 for t >= 1) and store it as the
// simulation <run><period>
void _cge_dyn_solve(real scalar period, real scalar first)
{
    struct cge_model scalar M
    struct cge_dyn scalar D
    real colvector x, x1, ad
    real scalar conv, iter, err, lam, l0, l1, l2, g0, g1, target, it, t, kk
    string scalar method

    M = _cge_load()
    D = _cge_dyn_load()
    lam = .
    if (first) {
        x = _cge_solve_point(M, M.p, M.xcur, M.x0, D.tol, D.maxit, 0, conv, iter, err, method)
    }
    else {
        t = D.k
        ad = M.p.ad
        if (D.mode == 0) {
            M.p.ad = ad :* (1 :+ D.tfp)
            x = _cge_solve_point(M, M.p, M.xcur, D.prev, D.tol, D.maxit, 0, conv, iter, err, method)
        }
        else if (D.mode == 2) {
            lam = D.lampath[t]
            M.p.ad = ad :* lam
            x = _cge_solve_point(M, M.p, M.xcur, D.prev, D.tol, D.maxit, 0, conv, iter, err, method)
        }
        else {
            // Uniform efficiency factor for the growth target (secant iterations)
            target = (1 + D.target[t]) * _cge_dyn_va(M, D.prev)
            l0 = 1
            M.p.ad = ad :* l0
            x = _cge_solve_point(M, M.p, M.xcur, D.prev, D.tol, D.maxit, 0, conv, iter, err, method)
            if (!conv) _cge_fail("period " + strofreal(period) + " did not converge", 430)
            g0 = _cge_dyn_va(M, x) / target - 1
            l1 = 1 + D.target[t]
            M.p.ad = ad :* l1
            x = _cge_solve_point(M, M.p, M.xcur, D.prev, D.tol, D.maxit, 0, conv, iter, err, method)
            if (!conv) _cge_fail("period " + strofreal(period) + " did not converge", 430)
            g1 = _cge_dyn_va(M, x) / target - 1
            for (it = 1; it <= 50; it++) {
                if (abs(g1) < 1e-13) break
                l2 = l1 - g1 * (l1 - l0) / (g1 - g0)
                l0 = l1
                g0 = g1
                l1 = l2
                M.p.ad = ad :* l1
                x = _cge_solve_point(M, M.p, M.xcur, D.prev, D.tol, D.maxit, 0, conv, iter, err, method)
                if (!conv) _cge_fail("period " + strofreal(period) + " did not converge", 430)
                g1 = _cge_dyn_va(M, x) / target - 1
            }
            if (abs(g1) >= 1e-13) _cge_fail("period " + strofreal(period) + ": the growth target was not met", 430)
            lam = l1
        }
        D.k = D.k + 1
    }
    if (!conv) _cge_fail("period " + strofreal(period) + " did not converge", 430)
    err = _cge_maxres(M, M.p, x)
    kk = _cge_store_sim(M, D.name + strofreal(period), x, conv, iter, err, method)
    M.simrun[kk] = D.name
    M.simper[kk] = period
    M.simlam[kk] = lam
    D.prev = x
    _cge_store(M)
    _cge_dyn_store(D)
    printf("{txt}Period {res}%f{txt}: solved in {res}%f{txt} iteration(s)", period, iter)
    if (!missing(lam)) printf("{txt}; efficiency factor {res}%12.10f", lam)
    printf("\n")
}

// Restore the parameters and fixed values the model had before the run
void _cge_dyn_end()
{
    struct cge_model scalar M
    struct cge_dyn scalar D
    pointer() scalar q
    if ((q = findexternal("cge__dyn")) == NULL) return
    D = *q
    M = _cge_load()
    M.p = D.psave
    M.xcur = D.xsave
    _cge_store(M)
    rmexternal("cge__dyn")
}

// Names of the simulations of a dynamic run, in period order
string colvector _cge_run_sims(struct cge_model scalar M, string scalar run)
{
    real colvector s
    s = select((1::rows(M.simname)), M.simrun :== run)
    if (rows(s) == 0) _cge_fail("no dynamic run named " + run, 111)
    s = s[order(M.simper[s], 1)]
    return(M.simname[s])
}

void _cge_run_sims_local(string scalar run, string scalar lname)
{
    st_local(lname, invtokens(_cge_run_sims(_cge_load(), run)'))
}

// The results of a dynamic run as a dataset: one observation per period and
// variable element, with the base, the value and, given a baseline run, the
// baseline's value in the same period and the per cent difference from it
void _cge_dyn_data(string scalar run, string scalar baseline)
{
    struct cge_model scalar M
    string colvector sims, bsims, v, e1, e2, l1, l2
    real colvector per, base, value, bval, pos, keep, s, b
    real scalar j, k, n
    M = _cge_load()
    sims = _cge_run_sims(M, run)
    if (baseline != "") bsims = _cge_run_sims(M, baseline)
    v = J(0, 1, "")
    e1 = v
    e2 = v
    per = J(0, 1, .)
    base = per
    value = per
    bval = per
    for (j = 1; j <= rows(sims); j++) {
        s = _cge_sim_index(M, sims[j])
        b = .
        if (baseline != "") {
            b = select((1::rows(M.simname)), (M.simrun :== baseline) :* (M.simper :== M.simper[s]))
            if (rows(b) != 1) _cge_fail("baseline(): run " + baseline + " has no period " + strofreal(M.simper[s]), 111)
        }
        for (k = 1; k <= rows(M.vname); k++) {
            _cge_vlabels(M, k, l1, l2)
            pos = _cge_vpos(M, k)
            keep = M.exists[pos]
            if (!any(keep)) continue
            n = sum(keep)
            v = v \ J(n, 1, M.vname[k])
            e1 = e1 \ select(l1, keep)
            e2 = e2 \ select(l2, keep)
            per = per \ J(n, 1, M.simper[s])
            base = base \ select(M.x0[pos], keep)
            value = value \ select(M.simx[pos, s], keep)
            if (baseline != "") bval = bval \ select(M.simx[pos, b], keep)
        }
    }
    st_addobs(rows(v))
    (void) st_addvar("double", "period")
    (void) st_addvar("str8", "variable")
    (void) st_addvar("str32", "element1")
    (void) st_addvar("str32", "element2")
    (void) st_addvar("double", ("base", "value"))
    st_store(., "period", per)
    st_sstore(., "variable", v)
    st_sstore(., "element1", e1)
    st_sstore(., "element2", e2)
    st_store(., "base", base)
    st_store(., "value", value)
    st_varlabel("period", "Period")
    st_varlabel("variable", "Model variable")
    st_varlabel("element1", "First set element")
    st_varlabel("element2", "Second set element")
    st_varlabel("base", "Base value (calibrated SAM)")
    st_varlabel("value", "Value in the period")
    if (baseline != "") {
        (void) st_addvar("double", ("baseline", "dev_pct"))
        st_store(., "baseline", bval)
        st_store(., "dev_pct", 100 :* (value - bval) :/ abs(bval) :/ (bval :!= 0))
        st_varlabel("baseline", "Baseline value in the period")
        st_varlabel("dev_pct", "Per cent difference from the baseline")
    }
}

// =====================================================================
// Sensitivity analysis (from version 0.2.1)
// =====================================================================

// State of a sensitivity analysis while cge_sensitivity runs
struct cge_sens {
    string rowvector calargs, vary
    string scalar    ext, gov, si, num
    string colvector fac
    real colvector   cva, cq, ct, ca
    real matrix      dva, dq, dt, da, pct, val
    real colvector   conv
    string matrix    keys
    real colvector   base
}

struct cge_sens scalar _cge_sens_load()
{
    pointer() scalar q
    q = findexternal("cge__sens")
    if (q == NULL) _cge_fail("cge internal error: no sensitivity analysis in progress", 3498)
    return(*q)
}

void _cge_sens_store(struct cge_sens scalar G)
{
    pointer() scalar q
    if ((q = findexternal("cge__sens")) == NULL) q = crexternal("cge__sens")
    *q = G
}

// Multiplicative factors around one: uniform on [1 - s, 1 + s], or symmetric
// triangular on the same interval; one column per draw. With `common`, the
// same factor applies to every element.
real matrix _cge_sens_factors(real scalar n, real scalar draws, real scalar s, string scalar dist,
                              real scalar common)
{
    real scalar m
    real matrix u
    m = (common ? 1 : n)
    if (dist == "triangular") u = runiform(m, draws) + runiform(m, draws) :- 1
    else u = 2 :* runiform(m, draws) :- 1
    u = 1 :+ s :* u
    if (common) return(J(n, 1, 1) * u)
    return(u)
}

void _cge_sens_init(real scalar draws, real scalar seed, real scalar spread, string scalar dist,
                    string scalar vary, real scalar common)
{
    struct cge_model scalar M
    struct cge_sens scalar G
    string rowvector v
    real scalar k

    M = _cge_load()
    _cge_need(M, "calibrated")
    if (cols(M.calargs) < 10) _cge_fail("calibrate the model again: this model does not record its calibration", 459)
    if (spread < 0 | spread >= 1) _cge_fail("spread() must be at least 0 and less than 1", 198)
    if (dist != "uniform" & dist != "triangular") _cge_fail("distribution() must be uniform or triangular", 198)
    v = (vary == "" ? ("va", "q", "t") : tokens(vary))
    for (k = 1; k <= cols(v); k++) {
        if (!anyof(("va", "q", "t", "a"), v[k])) _cge_fail("vary(): " + v[k] + " is not one of va, q, t and a", 198)
    }
    G.vary = v
    G.calargs = M.calargs
    G.ext = M.c_ext
    G.gov = M.c_gov
    G.si = M.c_si
    G.num = M.c_num
    G.fac = M.c_fac
    G.cva = M.p0.sva
    G.cq = M.p0.sq
    G.ct = M.p0.st
    G.ca = M.p0.sa
    rseed(seed)
    // Draws in a fixed order (va, q, t, a), so a seed gives the same draws
    // whatever is varied
    G.dva = _cge_sens_factors(M.n, draws, spread, dist, common)
    G.dq = _cge_sens_factors(M.nC, draws, spread, dist, common)
    G.dt = _cge_sens_factors(M.nC, draws, spread, dist, common)
    G.da = _cge_sens_factors(M.n, draws, spread, dist, common)
    if (!anyof(v, "va")) G.dva = J(M.n, draws, 1)
    if (!anyof(v, "q")) G.dq = J(M.nC, draws, 1)
    if (!anyof(v, "t")) G.dt = J(M.nC, draws, 1)
    if (!anyof(v, "a")) G.da = J(M.n, draws, 1)
    G.conv = J(draws + 1, 1, 0)
    G.keys = J(0, 3, "")
    _cge_sens_store(G)
}

string scalar _cge_numlist(real colvector v)
{
    return(invtokens(strofreal(v', "%21.17g")))
}

// Elasticities of draw d (0: the central values)
void _cge_sens_values(struct cge_sens scalar G, real scalar d, real colvector va, real colvector q,
                      real colvector t, real colvector a)
{
    va = G.cva
    q = G.cq
    t = G.ct
    a = G.ca
    if (d > 0) {
        va = va :* G.dva[., d]
        q = q :* G.dq[., d]
        t = t :* G.dt[., d]
        a = a :* G.da[., d]
    }
}

// Calibrate with the elasticities of draw d, then restore the closure
void _cge_sens_calibrate(real scalar d)
{
    struct cge_model scalar M
    struct cge_sens scalar G
    real colvector va, q, t, a
    string rowvector c

    G = _cge_sens_load()
    _cge_sens_values(G, d, va, q, t, a)
    // Options of the last calibration; models calibrated before version 0.3.1
    // stored ten of them, and before 0.3.3 seventeen
    c = G.calargs
    if (cols(c) < 21) c = c, J(1, 21 - cols(c), "")
    _cge_calibrate(_cge_numlist(va), _cge_numlist(q), _cge_numlist(t), c[4], c[5], c[6],
                   (c[7] == "" & !anyof(G.vary, "a") ? "" : _cge_numlist(a)), c[8], c[9], c[10],
                   c[11], c[12], c[13], c[14], c[15], c[16], c[17], c[18], c[19], c[20], c[21])
    M = _cge_load()
    _cge_closure_apply(M, G.ext, G.gov, G.si, G.num, G.fac)
    _cge_store(M)
}

// Record the report measures of the simulation just solved, for draw d
void _cge_sens_collect(real scalar d, real scalar conv)
{
    struct cge_model scalar M
    struct cge_sens scalar G
    string matrix keys
    real colvector base, s
    real matrix vals, pct

    M = _cge_load()
    G = _cge_sens_load()
    G.conv[d + 1] = conv
    if (conv) {
        s = _cge_sim_index(M, "_sens")
        _cge_report_rows(M, s, keys, base, vals, pct)
        if (rows(G.keys) == 0) {
            G.keys = keys
            G.base = base
            G.pct = J(rows(keys), rows(G.conv), .)
            G.val = G.pct
        }
        G.pct[., d + 1] = pct
        G.val[., d + 1] = vals
    }
    _cge_sens_store(G)
}

// Display the summary and, if asked, fill the dataset in memory
void _cge_sens_finish(string scalar tables, real scalar show, real scalar fill)
{
    struct cge_model scalar M
    struct cge_sens scalar G
    string rowvector tab
    string colvector lab, d1, d2, d3
    real colvector ok, sel, x, q, nd, dv, va, qq, tt, aa
    real matrix P
    real scalar i, n, nk, j, D, w1, k

    M = _cge_load()
    G = _cge_sens_load()
    D = rows(G.conv) - 1
    if (rows(G.keys) == 0 | !G.conv[1]) _cge_fail("the scenario did not converge with the central elasticities", 430)
    ok = select((2::(D + 1)), G.conv[|2 \ D + 1|])
    n = rows(ok)
    P = G.pct[., ok]
    if (show) {
        tab = (tables == "" ? ("macro", "welfare") : (tables == "all" ?
               ("macro", "government", "debt", "institutions", "factors", "activities", "commodities", "health", "welfare") :
               tokens(tables)))
        printf("\n{txt}Sensitivity of the scenario to the elasticities: {res}%f{txt} of {res}%f{txt} draws converged\n", n, D)
        printf("{txt}Per cent changes from the base (welfare: per cent of base consumption)\n")
        for (k = 1; k <= cols(tab); k++) {
            sel = select((1::rows(G.keys)), G.keys[., 1] :== tab[k])
            if (rows(sel) == 0) continue
            w1 = max((24, max(strlen(G.keys[sel, 2] :+ " " :+ G.keys[sel, 3])))) + 1
            printf("\n{txt}%s\n{hline %f}\n", tab[k], w1 + 55)
            printf("{txt}%-" + strofreal(w1) + "s %10s %10s %10s %10s %10s\n", "", "central", "mean", "sd", "p5", "p95")
            for (i = 1; i <= rows(sel); i++) {
                j = sel[i]
                x = select(P[j, .]', P[j, .]' :< .)
                q = (rows(x) ? sort(x, 1) : J(0, 1, .))
                printf("{txt}%-" + strofreal(w1) + "s {res}%10.3f %10.3f %10.3f %10.3f %10.3f\n",
                       G.keys[j, 2] + (G.keys[j, 3] == "" ? "" : " " + G.keys[j, 3]), G.pct[j, 1],
                       (rows(x) ? mean(x) : .), (rows(x) > 1 ? sqrt(variance(x)) : .),
                       (rows(x) ? q[max((1, ceil(0.05 * rows(x))))] : .), (rows(x) ? q[max((1, ceil(0.95 * rows(x))))] : .))
            }
            printf("{txt}{hline %f}\n", w1 + 55)
        }
    }
    st_numscalar("r(N_draws)", D)
    st_numscalar("r(N_converged)", n)
    if (fill) {
        // Report measures for every draw (draw 0: central elasticities), then the
        // elasticities of every draw
        nk = rows(G.keys)
        nd = J(0, 1, .)
        d1 = J(0, 1, "")
        d2 = d1
        d3 = d1
        dv = J(0, 1, .)
        lab = M.A \ M.C \ M.C \ M.A
        for (j = 0; j <= D; j++) {
            if (!G.conv[j + 1]) continue
            nd = nd \ J(nk, 1, j)
        }
        st_addobs(rows(nd))
        (void) st_addvar("double", "draw")
        (void) st_addvar("str16", "table")
        (void) st_addvar("str32", "measure")
        (void) st_addvar("str32", "element")
        (void) st_addvar("double", ("base", "value", "pct"))
        st_store(., "draw", nd)
        st_sstore(., "table", J(rows(nd) / nk, 1, G.keys[., 1]))
        st_sstore(., "measure", J(rows(nd) / nk, 1, G.keys[., 2]))
        st_sstore(., "element", J(rows(nd) / nk, 1, G.keys[., 3]))
        st_store(., "base", J(rows(nd) / nk, 1, G.base))
        sel = select((1::(D + 1)), G.conv)
        st_store(., "value", colshape(G.val[., sel]', 1))
        st_store(., "pct", colshape(G.pct[., sel]', 1))
        for (j = 0; j <= D; j++) {
            _cge_sens_values(G, j, va, qq, tt, aa)
            nd = J(rows(lab), 1, j)
            k = st_nobs()
            st_addobs(rows(lab))
            st_store(((k + 1)::(k + rows(lab))), "draw", nd)
            st_sstore(((k + 1)::(k + rows(lab))), "table", J(rows(lab), 1, "elasticity"))
            st_sstore(((k + 1)::(k + rows(lab))), "measure", J(M.n, 1, "sigmava") \ J(M.nC, 1, "sigmaq") \
                      J(M.nC, 1, "sigmat") \ J(M.n, 1, "sigmaa"))
            st_sstore(((k + 1)::(k + rows(lab))), "element", lab)
            st_store(((k + 1)::(k + rows(lab))), "value", va \ qq \ tt \ aa)
        }
        st_varlabel("draw", "Draw (0: central elasticities)")
        st_varlabel("table", "Report table, or elasticity")
        st_varlabel("measure", "Measure, or elasticity")
        st_varlabel("element", "Set element")
        st_varlabel("base", "Base value")
        st_varlabel("value", "Value in the draw")
        st_varlabel("pct", "Per cent change (rates: points; welfare: per cent of base consumption)")
    }
}

void _cge_sens_end()
{
    if (findexternal("cge__sens") != NULL) rmexternal("cge__sens")
}

// =====================================================================
// Link to household surveys (model_spec.md, Section 11; from version 0.2.2)
// =====================================================================

// Ratio of the new to the base value of income source src for household group h
real scalar _cge_ms_ratio(struct cge_model scalar M, struct cge_par scalar p, real colvector x,
                          real scalar h, string scalar src)
{
    real matrix YIF, YIF0
    real colvector YF, YF0, DY, DY0, MPS, TINS, YI, MPS0, TINS0, YI0
    real scalar f, a, b, cpi, cpi0, exr, exr0

    cpi = _cge_vn(M, x, "CPI")
    cpi0 = _cge_vn(M, M.x0, "CPI")
    if (src == "fixed") return(1)
    if (src == "cpi") return(cpi / cpi0)
    if (src == "gov") {
        a = M.p0.trdg[h] * cpi0
        b = p.trdg[h] * cpi
        return(a == 0 ? cpi / cpi0 : b / a)
    }
    if (src == "row") {
        exr = _cge_vn(M, x, "EXR")
        exr0 = _cge_vn(M, M.x0, "EXR")
        a = M.p0.trdr[h] * exr0
        b = p.trdr[h] * exr
        return(a == 0 ? exr / exr0 : b / a)
    }
    if (src == "dom") {
        MPS = _cge_vn(M, x, "MPS");      TINS = _cge_vn(M, x, "TINS");      YI = _cge_vn(M, x, "YI")
        MPS0 = _cge_vn(M, M.x0, "MPS");  TINS0 = _cge_vn(M, M.x0, "TINS");  YI0 = _cge_vn(M, M.x0, "YI")
        DY = (1 :- MPS) :* (1 :- TINS) :* YI
        DY0 = (1 :- MPS0) :* (1 :- TINS0) :* YI0
        a = M.p0.shii[h, .] * DY0
        b = p.shii[h, .] * DY
        return(a == 0 ? cpi / cpi0 : b / a)
    }
    f = _cge_find(M.F, src)
    YIF = _cge_vn(M, x, "YIF")
    YIF0 = _cge_vn(M, M.x0, "YIF")
    if (YIF0[h, f] == 0) {
        YF = _cge_vn(M, x, "YF")
        YF0 = _cge_vn(M, M.x0, "YF")
        return(YF[f] / YF0[f])
    }
    return(YIF[h, f] / YIF0[h, f])
}

// Weighted Fosters-Greer-Thorbecke index of order a for poverty line z
real scalar _cge_fgt(real colvector r, real colvector w, real scalar z, real scalar a)
{
    real colvector poor, gap
    poor = (r :< z)
    gap = poor :* (z :- r) :/ z
    return(sum(w :* poor :* (a == 0 ? J(rows(r), 1, 1) : gap :^ a)) / sum(w))
}

// Weighted Gini coefficient
real scalar _cge_gini(real colvector r, real colvector w)
{
    real colvector o, rs, ws, cw, L, cw1, L1
    if (rows(r) < 2) return(.)
    o = order(r, 1)
    rs = r[o]
    ws = w[o]
    cw = runningsum(ws) / sum(ws)
    L = runningsum(rs :* ws) / sum(rs :* ws)
    cw1 = 0 \ cw[|1 \ rows(cw) - 1|]
    L1 = 0 \ L[|1 \ rows(L) - 1|]
    return(1 - sum((cw - cw1) :* (L + L1)))
}

// "var:target" pairs
void _cge_ms_pairs(string scalar spec, string scalar what, string rowvector vars, string rowvector targets)
{
    string rowvector tok, pair
    real scalar k
    tok = tokens(spec)
    vars = J(1, cols(tok), "")
    targets = vars
    for (k = 1; k <= cols(tok); k++) {
        pair = tokens(tok[k], ":")
        if (cols(pair) != 3) _cge_fail(what + "(): write variable:" + (what == "income" ? "source" : "commodity") +
                                       ", for example " + (what == "income" ? "wages:lab" : "food:com_agr"), 198)
        vars[k] = pair[1]
        targets[k] = pair[3]
    }
}

void _cge_microsim(string scalar sim, string scalar touse, string scalar gvar, string scalar cvar,
                   string scalar wvar, string scalar svar, string scalar income, string scalar budget,
                   real scalar zline, string scalar gen, real scalar show)
{
    struct cge_model scalar M
    struct cge_par scalar p
    string colvector g, ug, rlab
    string rowvector ivars, isrc, bvars, bcom
    real colvector x, C0, w, nsz, hi, EH, EH0, MPS, TINS, MPS0, TINS0, kappa, grp, ratio, C1, PQ, PQ0
    real colvector pr, Pg, P, R, r0, r1, pw, Y0, Y1, tot, ci, sel, present
    real matrix Y, rho, QH0, wg, B, T
    real scalar s, n, k, h, j, nH, row, hasline

    M = _cge_load()
    _cge_need(M, "calibrated")
    s = _cge_sim_index(M, sim)
    x = M.simx[., s]
    p = M.simp[s]
    nH = M.nH
    g = st_sdata(., gvar, touse)
    C0 = st_data(., cvar, touse)
    n = rows(C0)
    if (n == 0) _cge_fail("no observations", 2000)
    w = (wvar == "" ? J(n, 1, 1) : st_data(., wvar, touse))
    nsz = (svar == "" ? J(n, 1, 1) : st_data(., svar, touse))
    if (min(w) < 0 | min(nsz) <= 0) _cge_fail("weights must be non-negative and household sizes positive", 459)

    // Household groups
    hi = J(n, 1, 0)
    ug = uniqrows(g)
    for (k = 1; k <= rows(ug); k++) {
        h = _cge_find(M.H, ug[k])
        if (h == 0) _cge_fail("group(): " + ug[k] + " is not a household of the model (" + invtokens(M.H') + ")", 111)
        hi = hi + h :* (g :== ug[k])
    }

    // Nominal consumption
    EH = _cge_vn(M, x, "EH")
    EH0 = _cge_vn(M, M.x0, "EH")
    MPS = _cge_vn(M, x, "MPS");      TINS = _cge_vn(M, x, "TINS")
    MPS0 = _cge_vn(M, M.x0, "MPS");  TINS0 = _cge_vn(M, M.x0, "TINS")
    kappa = ((1 :- MPS[|1 \ nH|]) :* (1 :- TINS[|1 \ nH|])) :/ ((1 :- MPS0[|1 \ nH|]) :* (1 :- TINS0[|1 \ nH|]))
    grp = EH :/ EH0
    if (income == "") ratio = grp[hi, 1]
    else {
        _cge_ms_pairs(income, "income", ivars, isrc)
        for (k = 1; k <= cols(isrc); k++) {
            if (!anyof(("gov", "row", "dom", "cpi", "fixed"), isrc[k]) & !_cge_find(M.F, isrc[k])) {
                _cge_fail("income(): " + isrc[k] + " is not a factor of the model or one of gov, row, dom, cpi and fixed", 198)
            }
        }
        Y = st_data(., ivars, touse)
        rho = J(nH, cols(isrc), .)
        for (h = 1; h <= nH; h++) {
            for (k = 1; k <= cols(isrc); k++) rho[h, k] = _cge_ms_ratio(M, p, x, h, isrc[k])
        }
        Y0 = rowsum(Y)
        Y1 = rowsum(Y :* rho[hi, .])
        ratio = (Y0 :!= 0) :* (Y1 :/ (Y0 + (Y0 :== 0))) :* kappa[hi, 1] + (Y0 :== 0) :* grp[hi, 1]
    }
    // (indexes like grp[hi, 1] keep a column when there is one household group)
    C1 = C0 :* ratio

    // Prices households pay (including VAT): the household's budget shares, or its group's
    // (home consumption, from version 0.3.2, at the activity price)
    PQ = _cge_ph(M, p, x) \ _cge_vn(M, x, "PA")
    PQ0 = _cge_ph(M, M.p0, M.x0) \ _cge_vn(M, M.x0, "PA")
    pr = PQ :/ PQ0
    QH0 = _cge_vn(M, M.x0, "QH") \ _cge_vn(M, M.x0, "QHA")
    wg = (PQ0 :* QH0) :/ (EH0' + (EH0' :== 0))
    Pg = wg' * pr
    if (budget == "") P = Pg[hi, 1]
    else {
        _cge_ms_pairs(budget, "budget", bvars, bcom)
        ci = J(cols(bcom), 1, 0)
        for (k = 1; k <= cols(bcom); k++) {
            ci[k] = _cge_find(M.C, bcom[k])
            // an activity: home consumption of its output, at its price
            if (ci[k] == 0 & _cge_find(M.A, bcom[k])) ci[k] = M.nC + _cge_find(M.A, bcom[k])
            if (ci[k] == 0) _cge_fail("budget(): " + bcom[k] + " is not a commodity or activity of the model", 111)
        }
        B = st_data(., bvars, touse)
        if (min(B) < 0) _cge_fail("budget(): spending on an item cannot be negative", 459)
        tot = rowsum(B)
        P = (tot :> 0) :* ((B * pr[ci]) :/ (tot + (tot :== 0))) + (tot :<= 0) :* Pg[hi, 1]
    }
    R = C1 :/ P
    r0 = C0 :/ nsz
    r1 = R :/ nsz
    pw = w :* nsz

    // Results: all households, then each group present
    hasline = (zline > 0 & zline < .)
    present = uniqrows(hi)
    rlab = "all" \ M.H[present]
    T = J(rows(rlab), 11, .)
    for (row = 1; row <= rows(rlab); row++) {
        if (row == 1) sel = (1::n)
        else sel = select((1::n), hi :== present[row - 1])
        T[row, 1] = sum(pw[sel] :* r0[sel]) / sum(pw[sel])
        T[row, 2] = sum(pw[sel] :* r1[sel]) / sum(pw[sel])
        T[row, 3] = 100 * (T[row, 2] / T[row, 1] - 1)
        if (hasline) {
            for (j = 0; j <= 2; j++) {
                T[row, 4 + 2 * j] = _cge_fgt(r0[sel], pw[sel], zline, j)
                T[row, 5 + 2 * j] = _cge_fgt(r1[sel], pw[sel], zline, j)
            }
        }
        T[row, 10] = _cge_gini(r0[sel], pw[sel])
        T[row, 11] = _cge_gini(r1[sel], pw[sel])
    }

    if (show) {
        printf("\n{txt}Household survey results of simulation {res}%s{txt}: {res}%f{txt} households\n", sim, n)
        printf("{txt}Real consumption per person (base prices); poverty and inequality over persons\n")
        printf("{txt}{hline 98}\n")
        printf("{txt}%-14s %11s %11s %8s %18s %18s %18s\n", "", "base", "simulated", "% chg",
               (hasline ? "headcount (%)" : ""), (hasline ? "poverty gap (%)" : ""), "Gini (%)")
        printf("{txt}{hline 98}\n")
        for (row = 1; row <= rows(rlab); row++) {
            printf("{txt}%-14s {res}%11.4g %11.4g %8.3f", abbrev(rlab[row], 14), T[row, 1], T[row, 2], T[row, 3])
            if (hasline) printf("{res}  %7.2f -> %7.2f  %7.2f -> %7.2f", 100 * T[row, 4], 100 * T[row, 5],
                                100 * T[row, 6], 100 * T[row, 7])
            else printf("%38s", "")
            printf("{res}  %7.2f -> %7.2f\n", 100 * T[row, 10], 100 * T[row, 11])
        }
        printf("{txt}{hline 98}\n")
        if (hasline) printf("{txt}Poverty line {res}%g{txt} per person; severity (FGT2) is in r(table)\n", zline)
    }

    if (gen != "") {
        (void) st_addvar("double", (gen + "_nom", gen + "_price", gen + "_real", gen + "_pc"))
        st_store(., gen + "_nom", touse, C1)
        st_store(., gen + "_price", touse, P)
        st_store(., gen + "_real", touse, R)
        st_store(., gen + "_pc", touse, r1)
        st_varlabel(gen + "_nom", "Nominal consumption, simulation " + sim)
        st_varlabel(gen + "_price", "Household price index, simulation " + sim)
        st_varlabel(gen + "_real", "Real consumption (base prices), simulation " + sim)
        st_varlabel(gen + "_pc", "Real consumption per person, simulation " + sim)
    }
    st_matrix("r(table)", T)
    st_matrixrowstripe("r(table)", (J(rows(rlab), 1, ""), rlab))
    st_matrixcolstripe("r(table)", (J(11, 1, ""), ("mean_base" \ "mean_sim" \ "mean_pct" \ "fgt0_base" \
                       "fgt0_sim" \ "fgt1_base" \ "fgt1_sim" \ "fgt2_base" \ "fgt2_sim" \ "gini_base" \ "gini_sim")))
    st_numscalar("r(N)", n)
    st_numscalar("r(fgt0_base)", T[1, 4])
    st_numscalar("r(fgt0_sim)", T[1, 5])
    st_numscalar("r(gini_base)", T[1, 10])
    st_numscalar("r(gini_sim)", T[1, 11])
}

// BEGIN GENERATED: model input-output (tools/gen_mata_io.py; do not edit by hand)

void _cge_par_write(real scalar fh, struct cge_par scalar p, string scalar prefix)
{
    _cge_io_put(fh, prefix + "pwm", p.pwm)
    _cge_io_put(fh, prefix + "pwe", p.pwe)
    _cge_io_put(fh, prefix + "tm", p.tm)
    _cge_io_put(fh, prefix + "te", p.te)
    _cge_io_put(fh, prefix + "tq", p.tq)
    _cge_io_put(fh, prefix + "ta", p.ta)
    _cge_io_put(fh, prefix + "iva", p.iva)
    _cge_io_put(fh, prefix + "inta", p.inta)
    _cge_io_put(fh, prefix + "ad", p.ad)
    _cge_io_put(fh, prefix + "rva", p.rva)
    _cge_io_put(fh, prefix + "sva", p.sva)
    _cge_io_put(fh, prefix + "aa", p.aa)
    _cge_io_put(fh, prefix + "dla", p.dla)
    _cge_io_put(fh, prefix + "dlac", p.dlac)
    _cge_io_put(fh, prefix + "rha", p.rha)
    _cge_io_put(fh, prefix + "sa", p.sa)
    _cge_io_put(fh, prefix + "ica", p.ica)
    _cge_io_put(fh, prefix + "dva", p.dva)
    _cge_io_put(fh, prefix + "theta", p.theta)
    _cge_io_put(fh, prefix + "icm", p.icm)
    _cge_io_put(fh, prefix + "at", p.at)
    _cge_io_put(fh, prefix + "dt", p.dt)
    _cge_io_put(fh, prefix + "dtc", p.dtc)
    _cge_io_put(fh, prefix + "rt", p.rt)
    _cge_io_put(fh, prefix + "aq", p.aq)
    _cge_io_put(fh, prefix + "dq", p.dq)
    _cge_io_put(fh, prefix + "dqc", p.dqc)
    _cge_io_put(fh, prefix + "rq", p.rq)
    _cge_io_put(fh, prefix + "sq", p.sq)
    _cge_io_put(fh, prefix + "st", p.st)
    _cge_io_put(fh, prefix + "shif", p.shif)
    _cge_io_put(fh, prefix + "beta", p.beta)
    _cge_io_put(fh, prefix + "gamma", p.gamma)
    _cge_io_put(fh, prefix + "tins0", p.tins0)
    _cge_io_put(fh, prefix + "mps0", p.mps0)
    _cge_io_put(fh, prefix + "shir", p.shir)
    _cge_io_put(fh, prefix + "hc", p.hc)
    _cge_io_put(fh, prefix + "trdg", p.trdg)
    _cge_io_put(fh, prefix + "trdr", p.trdr)
    _cge_io_put(fh, prefix + "trfr", p.trfr)
    _cge_io_put(fh, prefix + "qg", p.qg)
    _cge_io_put(fh, prefix + "qinv", p.qinv)
    _cge_io_put(fh, prefix + "cwts", p.cwts)
    _cge_io_put(fh, prefix + "dwts", p.dwts)
    _cge_io_put(fh, prefix + "qer", p.qer)
    _cge_io_put(fh, prefix + "shii", p.shii)
    _cge_io_put(fh, prefix + "trgr", p.trgr)
    _cge_io_put(fh, prefix + "trrg", p.trrg)
    _cge_io_put(fh, prefix + "trgg", p.trgg)
    _cge_io_put(fh, prefix + "tshi", p.tshi)
    _cge_io_put(fh, prefix + "qshi", p.qshi)
    _cge_io_put(fh, prefix + "sshi", p.sshi)
    _cge_io_put(fh, prefix + "trshi", p.trshi)
    _cge_io_put(fh, prefix + "trshir", p.trshir)
    _cge_io_put(fh, prefix + "af", p.af)
    _cge_io_put(fh, prefix + "etah", p.etah)
    _cge_io_put(fh, prefix + "hs0", p.hs0)
    _cge_io_put(fh, prefix + "tv", p.tv)
    _cge_io_put(fh, prefix + "kappa", p.kappa)
    _cge_io_put(fh, prefix + "debt", p.debt)
    _cge_io_put(fh, prefix + "ddebt", p.ddebt)
    _cge_io_put(fh, prefix + "fdebt", p.fdebt)
    _cge_io_put(fh, prefix + "rd", p.rd)
    _cge_io_put(fh, prefix + "rf", p.rf)
    _cge_io_put(fh, prefix + "phi", p.phi)
    _cge_io_put(fh, prefix + "hold", p.hold)
    _cge_io_put(fh, prefix + "icd", p.icd)
    _cge_io_put(fh, prefix + "ici", p.ici)
    _cge_io_put(fh, prefix + "ice", p.ice)
    _cge_io_put(fh, prefix + "etae", p.etae)
    _cge_io_put(fh, prefix + "qe0", p.qe0)
    _cge_io_put(fh, prefix + "betah", p.betah)
    _cge_io_put(fh, prefix + "gammah", p.gammah)
    _cge_io_put(fh, prefix + "inlf", p.inlf)
    _cge_io_put(fh, prefix + "qlf", p.qlf)
    _cge_io_put(fh, prefix + "u0", p.u0)
    _cge_io_put(fh, prefix + "epsw", p.epsw)
    _cge_io_put(fh, prefix + "wref", p.wref)
    _cge_io_put(fh, prefix + "wmin", p.wmin)
    _cge_io_put(fh, prefix + "hasmin", p.hasmin)
    _cge_io_put(fh, prefix + "mu", p.mu)
}

real scalar _cge_par_member(struct cge_par scalar p, string scalar name, transmorphic matrix v)
{
    if (name == "pwm") p.pwm = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "pwe") p.pwe = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "tm") p.tm = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "te") p.te = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "tq") p.tq = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "ta") p.ta = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "iva") p.iva = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "inta") p.inta = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "ad") p.ad = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "rva") p.rva = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "sva") p.sva = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "aa") p.aa = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "dla") p.dla = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "dlac") p.dlac = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "rha") p.rha = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "sa") p.sa = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "ica") p.ica = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "dva") p.dva = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "theta") p.theta = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "icm") p.icm = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "at") p.at = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "dt") p.dt = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "dtc") p.dtc = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "rt") p.rt = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "aq") p.aq = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "dq") p.dq = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "dqc") p.dqc = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "rq") p.rq = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "sq") p.sq = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "st") p.st = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "shif") p.shif = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "beta") p.beta = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "gamma") p.gamma = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "tins0") p.tins0 = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "mps0") p.mps0 = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "shir") p.shir = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "hc") p.hc = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "trdg") p.trdg = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "trdr") p.trdr = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "trfr") p.trfr = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "qg") p.qg = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "qinv") p.qinv = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "cwts") p.cwts = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "dwts") p.dwts = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "qer") p.qer = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "shii") p.shii = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "trgr") p.trgr = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "trrg") p.trrg = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "trgg") p.trgg = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "tshi") p.tshi = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "qshi") p.qshi = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "sshi") p.sshi = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "trshi") p.trshi = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "trshir") p.trshir = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "af") p.af = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "etah") p.etah = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "hs0") p.hs0 = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "tv") p.tv = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "kappa") p.kappa = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "debt") p.debt = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "ddebt") p.ddebt = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "fdebt") p.fdebt = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "rd") p.rd = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "rf") p.rf = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "phi") p.phi = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "hold") p.hold = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "icd") p.icd = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "ici") p.ici = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "ice") p.ice = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "etae") p.etae = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "qe0") p.qe0 = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "betah") p.betah = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "gammah") p.gammah = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "inlf") p.inlf = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "qlf") p.qlf = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "u0") p.u0 = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "epsw") p.epsw = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "wref") p.wref = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "wmin") p.wmin = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "hasmin") p.hasmin = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "mu") p.mu = (rows(v) * cols(v) == 0 ? . : v)
    else return(0)
    return(1)
}

void _cge_model_write(real scalar fh, struct cge_model scalar M)
{
    real scalar k
    _cge_io_put(fh, "labels0", M.labels0)
    _cge_io_put(fh, "labels", M.labels)
    _cge_io_put(fh, "S0", M.S0)
    _cge_io_put(fh, "S", M.S)
    _cge_io_put(fh, "rewritten", M.rewritten)
    _cge_io_put(fh, "mapped", M.mapped)
    _cge_io_put(fh, "calibrated", M.calibrated)
    _cge_io_put(fh, "iA", M.iA)
    _cge_io_put(fh, "iC", M.iC)
    _cge_io_put(fh, "iF", M.iF)
    _cge_io_put(fh, "iH", M.iH)
    _cge_io_put(fh, "igov", M.igov)
    _cge_io_put(fh, "isav", M.isav)
    _cge_io_put(fh, "irow", M.irow)
    _cge_io_put(fh, "idirtax", M.idirtax)
    _cge_io_put(fh, "isaltax", M.isaltax)
    _cge_io_put(fh, "iimptax", M.iimptax)
    _cge_io_put(fh, "iexptax", M.iexptax)
    _cge_io_put(fh, "iacttax", M.iacttax)
    _cge_io_put(fh, "ishi", M.ishi)
    _cge_io_put(fh, "ivattax", M.ivattax)
    _cge_io_put(fh, "tmkt", M.tmkt)
    _cge_io_put(fh, "cxe", M.cxe)
    _cge_io_put(fh, "ced", M.ced)
    _cge_io_put(fh, "cdo", M.cdo)
    _cge_io_put(fh, "cq", M.cq)
    _cge_io_put(fh, "A", M.A)
    _cge_io_put(fh, "C", M.C)
    _cge_io_put(fh, "F", M.F)
    _cge_io_put(fh, "H", M.H)
    _cge_io_put(fh, "I", M.I)
    _cge_io_put(fh, "iE", M.iE)
    _cge_io_put(fh, "imargins", M.imargins)
    _cge_io_put(fh, "iterritorial", M.iterritorial)
    _cge_io_put(fh, "iT", M.iT)
    _cge_io_put(fh, "istocks", M.istocks)
    _cge_io_put(fh, "E", M.E)
    _cge_io_put(fh, "D", M.D)
    _cge_io_put(fh, "n", M.n)
    _cge_io_put(fh, "nC", M.nC)
    _cge_io_put(fh, "nF", M.nF)
    _cge_io_put(fh, "nH", M.nH)
    _cge_io_put(fh, "nE", M.nE)
    _cge_io_put(fh, "nD", M.nD)
    _cge_io_put(fh, "nI", M.nI)
    _cge_io_put(fh, "ce", M.ce)
    _cge_io_put(fh, "cm", M.cm)
    _cge_io_put(fh, "cd", M.cd)
    _cge_io_put(fh, "cx", M.cx)
    _cge_io_put(fh, "ct", M.ct)
    _cge_io_put(fh, "cr", M.cr)
    _cge_io_put(fh, "cshi", M.cshi)
    _cge_io_put(fh, "chs", M.chs)
    _cge_io_put(fh, "lt", M.lt)
    _cge_io_put(fh, "cda", M.cda)
    _cge_io_put(fh, "fa", M.fa)
    _cge_par_write(fh, M.p0, "p0.")
    _cge_par_write(fh, M.p, "p.")
    _cge_io_put(fh, "vname", M.vname)
    _cge_io_put(fh, "vset", M.vset)
    _cge_io_put(fh, "voff", M.voff)
    _cge_io_put(fh, "vrows", M.vrows)
    _cge_io_put(fh, "vcols", M.vcols)
    _cge_io_put(fh, "x0", M.x0)
    _cge_io_put(fh, "xcur", M.xcur)
    _cge_io_put(fh, "xscale", M.xscale)
    _cge_io_put(fh, "exists", M.exists)
    _cge_io_put(fh, "fixed", M.fixed)
    _cge_io_put(fh, "nominal", M.nominal)
    _cge_io_put(fh, "positive", M.positive)
    _cge_io_put(fh, "jr", M.jr)
    _cge_io_put(fh, "jc", M.jc)
    _cge_io_put(fh, "drow", M.drow)
    _cge_io_put(fh, "drow2", M.drow2)
    _cge_io_put(fh, "dact", M.dact)
    _cge_io_put(fh, "derived", M.derived)
    _cge_io_put(fh, "rmask", M.rmask)
    _cge_io_put(fh, "rjr", M.rjr)
    _cge_io_put(fh, "rjc", M.rjc)
    _cge_io_put(fh, "rdrow", M.rdrow)
    _cge_io_put(fh, "rdrow2", M.rdrow2)
    _cge_io_put(fh, "ename", M.ename)
    _cge_io_put(fh, "elen", M.elen)
    _cge_io_put(fh, "escale", M.escale)
    _cge_io_put(fh, "emask", M.emask)
    _cge_io_put(fh, "neq", M.neq)
    _cge_io_put(fh, "c_ext", M.c_ext)
    _cge_io_put(fh, "c_gov", M.c_gov)
    _cge_io_put(fh, "c_si", M.c_si)
    _cge_io_put(fh, "c_num", M.c_num)
    _cge_io_put(fh, "calargs", M.calargs)
    _cge_io_put(fh, "c_fac", M.c_fac)
    _cge_io_put(fh, "simname", M.simname)
    _cge_io_put(fh, "simclosure", M.simclosure)
    _cge_io_put(fh, "simmethod", M.simmethod)
    _cge_io_put(fh, "simx", M.simx)
    _cge_io_put(fh, "simp.count", cols(M.simp))
    for (k = 1; k <= cols(M.simp); k++) _cge_par_write(fh, M.simp[k], "simp." + strofreal(k) + ".")
    _cge_io_put(fh, "simconv", M.simconv)
    _cge_io_put(fh, "simiter", M.simiter)
    _cge_io_put(fh, "simres", M.simres)
    _cge_io_put(fh, "simrun", M.simrun)
    _cge_io_put(fh, "simper", M.simper)
    _cge_io_put(fh, "simlam", M.simlam)
}

real scalar _cge_model_member(struct cge_model scalar M, string scalar name, transmorphic matrix v)
{
    if (name == "labels0") M.labels0 = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "labels") M.labels = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "S0") M.S0 = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "S") M.S = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "rewritten") M.rewritten = (rows(v) * cols(v) == 0 ? J(1, 0, .) : v)
    else if (name == "mapped") M.mapped = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "calibrated") M.calibrated = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "iA") M.iA = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "iC") M.iC = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "iF") M.iF = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "iH") M.iH = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "igov") M.igov = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "isav") M.isav = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "irow") M.irow = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "idirtax") M.idirtax = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "isaltax") M.isaltax = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "iimptax") M.iimptax = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "iexptax") M.iexptax = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "iacttax") M.iacttax = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "ishi") M.ishi = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "ivattax") M.ivattax = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "tmkt") M.tmkt = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "cxe") M.cxe = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "ced") M.ced = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "cdo") M.cdo = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "cq") M.cq = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "A") M.A = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "C") M.C = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "F") M.F = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "H") M.H = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "I") M.I = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "iE") M.iE = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "imargins") M.imargins = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "iterritorial") M.iterritorial = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "iT") M.iT = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "istocks") M.istocks = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "E") M.E = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "D") M.D = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "n") M.n = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "nC") M.nC = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "nF") M.nF = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "nH") M.nH = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "nE") M.nE = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "nD") M.nD = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "nI") M.nI = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "ce") M.ce = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "cm") M.cm = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "cd") M.cd = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "cx") M.cx = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "ct") M.ct = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "cr") M.cr = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "cshi") M.cshi = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "chs") M.chs = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "lt") M.lt = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "cda") M.cda = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "fa") M.fa = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "vname") M.vname = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "vset") M.vset = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "voff") M.voff = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "vrows") M.vrows = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "vcols") M.vcols = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "x0") M.x0 = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "xcur") M.xcur = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "xscale") M.xscale = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "exists") M.exists = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "fixed") M.fixed = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "nominal") M.nominal = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "positive") M.positive = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "jr") M.jr = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "jc") M.jc = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "drow") M.drow = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "drow2") M.drow2 = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "dact") M.dact = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "derived") M.derived = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "rmask") M.rmask = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "rjr") M.rjr = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "rjc") M.rjc = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "rdrow") M.rdrow = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "rdrow2") M.rdrow2 = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "ename") M.ename = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "elen") M.elen = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "escale") M.escale = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "emask") M.emask = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "neq") M.neq = (rows(v) * cols(v) == 0 ? . : v)
    else if (name == "c_ext") M.c_ext = (rows(v) * cols(v) == 0 ? "" : v)
    else if (name == "c_gov") M.c_gov = (rows(v) * cols(v) == 0 ? "" : v)
    else if (name == "c_si") M.c_si = (rows(v) * cols(v) == 0 ? "" : v)
    else if (name == "c_num") M.c_num = (rows(v) * cols(v) == 0 ? "" : v)
    else if (name == "calargs") M.calargs = (rows(v) * cols(v) == 0 ? J(1, 0, "") : v)
    else if (name == "c_fac") M.c_fac = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "simname") M.simname = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "simclosure") M.simclosure = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "simmethod") M.simmethod = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "simx") M.simx = (rows(v) * cols(v) == 0 ? J(0, 0, .) : v)
    else if (name == "simconv") M.simconv = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "simiter") M.simiter = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "simres") M.simres = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "simrun") M.simrun = (rows(v) * cols(v) == 0 ? J(0, 1, "") : v)
    else if (name == "simper") M.simper = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else if (name == "simlam") M.simlam = (rows(v) * cols(v) == 0 ? J(0, 1, .) : v)
    else return(0)
    return(1)
}

// END GENERATED: model input-output

end
