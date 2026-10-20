*! cge_calibrate.ado  v0.3.2  2026-10-20
*! cge-stata: calibrate the model to the mapped SAM
*! Computes base values and parameters and checks benchmark replication
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_calibrate, rclass
    version 13.0
    syntax , sigmava(numlist >0) sigmaq(numlist >0) sigmat(numlist >0) ///
        [FQuantities(name) INCelas(numlist >0) FRISch(numlist) SIGMAA(numlist >=0) ///
        healthcom(namelist) healthfac(namelist) healthelas(numlist >=0)          ///
        VATCredit(string) DEBT(string) INTerest(string) DEBTHolders(string)     ///
        FOReignborrowing(string) EXPORTOnly(namelist) EXPORTDemand(string)]

    if "`fquantities'" != "" confirm matrix `fquantities'

    _cge_load
    mata: _cge_calibrate("`sigmava'", "`sigmaq'", "`sigmat'", "`fquantities'", ///
        "`incelas'", "`frisch'", "`sigmaa'", "`healthcom'", "`healthfac'", "`healthelas'", ///
        strtrim(st_local("vatcredit")), strtrim(st_local("debt")), strtrim(st_local("interest")), ///
        strtrim(st_local("debtholders")), strtrim(st_local("foreignborrowing")), "`exportonly'", ///
        strtrim(st_local("exportdemand")))
    return add
end
