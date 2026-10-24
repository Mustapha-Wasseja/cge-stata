* test_gdx.do -- GDX files, cge_gdx (version 0.10.0). The GAMS program that
* writes a GDX file, the scripts, and the reading of what gdxdump writes, from
* files in its format; tools/gams/run_gdx_check.py runs GAMS and gdxdump and
* checks the round trip

version 13.0
quietly do helpers_reference.do

local stdmap activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)          ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)

tempfile tf
local dir "`tf'_gdx"

quietly cge_synthetic, clear
_cge_load
mata: _cge_mkdirs(st_local("dir"))
quietly cge_sam, labels(account)
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
quietly cge_solve, name(gs) tolerance(1e-12)

* ---------------------------------------------------------------------
* 1. The GAMS program that writes the GDX file
* ---------------------------------------------------------------------
cge_gdx write using "`dir'/m.gdx", sims(gs) norun gams(C:/GAMS/54/gams.exe)
assert r(N_sims) == 1 & r(N_levels) > 100 & r(N_parameters) > 50
mata:
g = cat(st_local("dir") + "/m_write.gms")
s = cat(st_local("dir") + "/m_write.cmd")
st_numscalar("okw", (sum(g :== "set AC 'accounts' /") == 1) +
             (sum(g :== "    'act_agr'.'com_agr' 100,") == 1) +
             (sum(g :== "    'tm'.'com_man'.'-' 0.10000000000000001,") == 1) +
             (sum(strpos(g, "    'gs'.'QA'.'act_man'.'-' ") :== 1) == 1) +
             (sum(g :== "execute_unload 'm.gdx', AC, A, C, F, H, E, SAM, CAL, sim, LEVEL;") == 1) +
             (sum(s :== `""C:/GAMS/54/gams.exe" m_write.gms lo=2 lf=m_write.log"') == 1))
end
assert scalar(okw) == 6
* the levels written are those of the simulation, to the last digit
quietly cge_results, sim(gs) clear nodisplay
quietly summarize value if variable == "QA" & element1 == "act_man"
mata: st_numscalar("okl", sum(g :== "    'gs'.'QA'.'act_man'.'-' " + _cge_gnum17(st_numscalar("r(mean)")) + ","))
assert scalar(okl) == 1
capture noisily cge_gdx write using "`dir'/m.gdx", sims(nosuch) norun
assert _rc == 111
capture noisily cge_gdx write using "`dir'/m.csv", norun
assert _rc == 198

* ---------------------------------------------------------------------
* 2. Reading what gdxdump writes: hexadecimal floats read exactly, special
*    values, variables with all their fields, sets with text, scalars
* ---------------------------------------------------------------------
cge_gdx read using "`dir'/h.gdx", symbol(P) norun clear gams(C:/GAMS/54/gams.exe)
mata:
st_numscalar("oks", sum(cat(st_local("dir") + "/h_read_P.cmd") :==
    `""C:/GAMS/54/gdxdump.exe" "h.gdx" symb=P format=csv dFormat=hexponential CSVAllFields CSVSetText output="h_P.csv""'))
end
assert scalar(oks) == 1
mata:
fh = _cge_gopen(st_local("dir") + "/h_P.csv")
fput(fh, `""AC","ACP","Val""')
fput(fh, `""a1","b1",0x1.5555555555555p-2"')
fput(fh, `""a1","b2",-0x1.8p+3"')
fput(fh, `""a2","b1",0x1.921fb54442d18p+1"')
fput(fh, `""a2","b2",0x1p-1022"')
fput(fh, `""a3","b1",Eps"')
fput(fh, `""a3","b2",+Inf"')
fput(fh, `""a3","b3",NA"')
fput(fh, `""a4","b4",17.25"')
fclose(fh)
end
cge_gdx read using "`dir'/h.gdx", symbol(P) norun clear
assert r(N) == 8 & r(dim) == 2 & "`r(kind)'" == "parameter" & "`r(indexes)'" == "ac acp"
assert value[1] == 1/3
assert value[2] == -12
assert value[3] == _pi
* 2^-1022, written in Stata's own exact hexadecimal form
assert value[4] == 1.0X-3fe
assert value[5] == 0 & missing(value[6]) & missing(value[7]) & value[8] == 17.25
assert ac[1] == "a1" & acp[3] == "b1"
mata:
fh = _cge_gopen(st_local("dir") + "/h_X.csv")
fput(fh, `""Dim1","Val","Marginal","Lower","Upper","Scale""')
fput(fh, `""act_agr",0x1.5555555555555p-1,0x1p-1,-Inf,0x1.cp+2,0x1p+0"')
fclose(fh)
fh = _cge_gopen(st_local("dir") + "/h_S.csv")
fput(fh, `""Dim1","Text""')
fput(fh, `""act_agr","agriculture, livestock""')
fput(fh, `""com_agr","')
fclose(fh)
fh = _cge_gopen(st_local("dir") + "/h_T.csv")
fput(fh, `""Val""')
fput(fh, `"0x1.4p+1"')
fclose(fh)
end
cge_gdx read using "`dir'/h.gdx", symbol(X) norun clear
assert "`r(kind)'" == "variable" & r(dim) == 1
assert level == 2/3 & marginal == 0.5 & missing(lower) & upper == 7 & scale == 1 & dim1 == "act_agr"
cge_gdx read using "`dir'/h.gdx", symbol(S) norun clear
assert "`r(kind)'" == "set" & _N == 2 & text[1] == "agriculture, livestock" & text[2] == ""
cge_gdx read using "`dir'/h.gdx", symbol(T) norun clear
assert r(dim) == 0 & _N == 1 & value == 2.5
* the list of symbols
mata:
fh = _cge_gopen(st_local("dir") + "/h_symbols.txt")
fput(fh, "  Symbol Dim Type Records  Explanatory text")
fput(fh, "1 AC       1  Set       3  accounts")
fput(fh, "2 SAM      2  Par       3  social accounting matrix")
fput(fh, "3 trgr     0  Par       1  transfers")
fclose(fh)
end
cge_gdx list using "`dir'/h.gdx", norun clear
assert r(N_symbols) == 3 & "`r(symbols)'" == "AC SAM trgr"
assert symbol[2] == "SAM" & dim[2] == 2 & type[2] == "Par" & records[2] == 3 & text[2] == "social accounting matrix"
* a symbol not read yet: the script is written, and nothing is read
capture erase "`dir'/h_Q.csv"
cge_gdx read using "`dir'/h.gdx", symbol(Q) norun clear
assert "`r(kind)'" == ""
capture confirm file "`dir'/h_read_Q.cmd"
assert _rc == 0
capture noisily cge_gdx read using "`dir'/h.gdx", symbol(P) norun
assert _rc == 4
capture noisily cge_gdx read using "`dir'/h.gdx", norun clear
assert _rc == 198
capture noisily cge_gdx copy using "`dir'/h.gdx"
assert _rc == 198

* ---------------------------------------------------------------------
* 3. A SAM from a GDX file: cge_sam reads the symbol with two indexes
* ---------------------------------------------------------------------
quietly cge_synthetic, clear
quietly cge_sam, labels(account)
capture mata: mata drop _tg_keep() _tg_csv() _tg_same()
mata:
// the SAM in memory, kept
void _tg_keep()
{
    struct cge_model scalar M
    pointer() scalar q
    M = _cge_load()
    if ((q = findexternal("tg_S")) == NULL) q = crexternal("tg_S")
    *q = M.S
    if ((q = findexternal("tg_L")) == NULL) q = crexternal("tg_L")
    *q = M.labels
}
// the SAM kept, in the format of gdxdump
void _tg_csv(string scalar fn)
{
    real matrix S
    string colvector L
    real scalar fh, i, j
    S = *findexternal("tg_S")
    L = *findexternal("tg_L")
    fh = _cge_gopen(fn)
    fput(fh, `""AC","ACP","Val""')
    for (i = 1; i <= rows(S); i++) {
        for (j = 1; j <= cols(S); j++) {
            if (S[i, j] != 0) fput(fh, `"""' + L[i] + `"",""' + L[j] + `"","' + strtrim(sprintf("%21.17g", S[i, j])))
        }
    }
    fclose(fh)
}
// 1 if the SAM in memory is the one kept, cell by cell, by label
real scalar _tg_same()
{
    struct cge_model scalar M
    real matrix S0
    string colvector L0
    real scalar i, j, a, b
    M = _cge_load()
    S0 = *findexternal("tg_S")
    L0 = *findexternal("tg_L")
    if (rows(M.labels) != rows(L0)) return(0)
    for (i = 1; i <= rows(L0); i++) {
        a = _cge_find(M.labels, L0[i])
        if (!a) return(0)
        for (j = 1; j <= rows(L0); j++) {
            b = _cge_find(M.labels, L0[j])
            if (!b) return(0)
            if (M.S[a, b] != S0[i, j]) return(0)
        }
    }
    return(1)
}
end
mata: _tg_keep()
mata: _tg_csv(st_local("dir") + "/s_SAM.csv")
cge_sam using "`dir'/s.gdx", symbol(SAM) norun clear
mata: st_numscalar("oksam", _tg_same())
assert scalar(oksam) == 1
* the SAM then calibrates as the one read from the data in memory
quietly cge_map, `stdmap'
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
assert r(max_residual) < 1e-10
mata: mata drop _tg_keep() _tg_csv() _tg_same()
mata: rmexternal("tg_S")
mata: rmexternal("tg_L")
