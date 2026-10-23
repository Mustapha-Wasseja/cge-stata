*! cge_optimize.ado  v0.9.4  2026-10-23
*! cge-stata: choose instruments to maximise or minimise a report measure or an
*! expression, within constraints, or to reach targets, solving the model at
*! every trial (docs/model_spec.md, Section 18)
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_optimize, rclass
    version 13.0
    syntax , INSTruments(string) [MAXimize(string) MINimize(string) TARGets(string) ///
        CONStraints(string) LOWer(string) UPper(string) NAME(name) TOLerance(real 1e-12) ///
        ITERate(integer 100) TRACE]

    _cge_load
    if "`name'" == "" local name optimum
    mata: _cge_optimize(st_local("instruments"), st_local("maximize"), st_local("minimize"), ///
        st_local("targets"), st_local("lower"), st_local("upper"), "`name'", `tolerance', `iterate', ///
        ("`trace'" != ""), st_local("constraints"))
    return add
end
