*! cge_mpsge.ado  v0.46.0  2026-11-01
*! cge-stata: a model written as MPSGE writes one, with sectors,
*! commodities, consumers and blocks of production and demand, as user
*! variables and equations of a standalone model (model_spec.md, Section 54)
*!
*! Authors: Mustapha Wasseja Mohammed, Nadia S. Ouedraogo and Mahamat Podda Abouna
*! Requires: Stata 13+

program define cge_mpsge, rclass
    version 13.0
    _cge_load
    gettoken sub rest : 0, parse(" ,")
    if `"`sub'"' == "," | `"`sub'"' == "" {
        syntax [, LIST DROP GENerated]
        if "`list'" != "" & "`drop'" != "" {
            display as error "give list or drop, not both"
            exit 198
        }
        if "`drop'" != "" {
            mata: _cge_mp_drop()
            display as text "The model being read is dropped"
            exit
        }
        mata: _cge_mp_list(`= "`generated'" != ""')
        return add
        exit
    }
    if `"`sub'"' == "end" {
        local 0 `"`rest'"'
        syntax [, NUMeraire(string) STart(string)]
        capture noisily quietly mata: _cge_mp_end(st_local("numeraire"), st_local("start"))
        if _rc {
            local rc = _rc
            mata: _cge_mp_abort()
            display as error "the model was not added; its statements are kept: drop them with cge_mpsge, drop"
            exit `rc'
        }
        mata: _cge_mp_report()
        return add
        exit
    }
    if `"`sub'"' == "using" {
        local 0 `"`0'"'
        syntax using/ [, NUMeraire(string) STart(string)]
        mata: _cge_mp_file(st_local("using"))
        capture noisily quietly mata: _cge_mp_end(st_local("numeraire"), st_local("start"))
        if _rc {
            local rc = _rc
            mata: _cge_mp_abort()
            mata: _cge_mp_drop()
            display as error "the model in `using' was not added"
            exit `rc'
        }
        mata: _cge_mp_report()
        return add
        exit
    }
    mata: _cge_mp_line(st_local("0"))
end
