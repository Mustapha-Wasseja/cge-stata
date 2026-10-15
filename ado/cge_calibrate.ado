*! cge_calibrate.ado  v0.1.12  2026-10-15
*! cge-stata: calibrate the model to the mapped SAM
*! Computes base values and parameters and checks benchmark replication
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge_calibrate, rclass
    version 13.0
    syntax , sigmava(numlist >0) sigmaq(numlist >0) sigmat(numlist >0) ///
        [FQuantities(name) INCelas(numlist >0) FRISch(numlist) SIGMAA(numlist >=0)]

    if "`fquantities'" != "" confirm matrix `fquantities'

    _cge_load
    mata: _cge_calibrate("`sigmava'", "`sigmaq'", "`sigmat'", "`fquantities'", ///
        "`incelas'", "`frisch'", "`sigmaa'")
    return add
end
