*! cge.ado  v0.1.3  2026-10-14
*! cge-stata: computable general equilibrium modelling in Stata
*! Displays the package version and the available commands
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge, rclass
    version 13.0
    syntax

    local version "0.1.3"

    display as text _n "cge-stata " as result "`version'"
    display as text "Computable general equilibrium modelling in Stata"
    display as text _n "Workflow"
    display as text "  {help cge_sam}         read a social accounting matrix"
    display as text "  {help cge_map}         assign SAM accounts to model roles"
    display as text "  {help cge_calibrate}   calibrate the model"
    display as text "  {help cge_closure}     choose the closure"
    display as text "  {help cge_shock}       change parameters or fixed variables"
    display as text "  {help cge_solve}       solve and store a simulation"
    display as text "  {help cge_results}     report or save results"
    display as text "  {help cge_check}       run validation checks"
    display as text _n "Data"
    display as text "  {help cge_synthetic}   load the synthetic SAM used in tests and examples"

    return local version "`version'"
end
