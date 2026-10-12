*! cge.ado  v0.0.1  2026-10-12
*! cge-stata: computable general equilibrium modelling in Stata
*! Displays the package version and the available commands
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge, rclass
    version 13.0
    syntax

    local version "0.0.1"

    display as text _n "cge-stata " as result "`version'" ///
        as text " (development release)"
    display as text "Computable general equilibrium modelling in Stata"
    display as text _n "Available commands"
    display as text "  {help cge_synthetic}   load the synthetic SAM used in tests and examples"
    display as text _n "Planned for version 0.1"
    display as text "  cge_sam, cge_map, cge_calibrate, cge_closure, cge_shock,"
    display as text "  cge_solve, cge_results, cge_check"

    return local version "`version'"
end
