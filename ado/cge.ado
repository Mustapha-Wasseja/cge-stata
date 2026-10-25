*! cge.ado  v0.22.0  2026-10-25
*! cge-stata: computable general equilibrium modelling in Stata
*! Displays the package version and the available commands
*!
*! Author: Mustapha Wasseja
*! Requires: Stata 13+

program define cge, rclass
    version 13.0
    syntax

    local version "0.22.0"

    display as text _n "cge-stata " as result "`version'"
    display as text "Computable general equilibrium modelling in Stata"
    display as text _n "Preparing a SAM"
    display as text "  {help cge_sam}         read a social accounting matrix, of any size, wide or long"
    display as text "  {help cge_template}    write a template for roles and aggregation (Excel or CSV)"
    display as text "  {help cge_aggregate}   merge accounts into groups"
    display as text "  {help cge_balance}     balance the SAM by RAS or cross entropy"
    display as text "  {help cge_samexport}   write the SAM to a file or to memory"
    display as text "  {help cge_multiplier}  SAM multipliers and their decomposition"
    display as text "  {help cge_spa}         structural paths of a SAM multiplier"
    display as text _n "Workflow"
    display as text "  {help cge_map}         assign SAM accounts to model roles"
    display as text "  {help cge_calibrate}   calibrate the model"
    display as text "  {help cge_elasticities} published elasticities, with sources, as calibration options"
    display as text "  {help cge_closure}     choose the closure"
    display as text "  {help cge_shock}       change parameters or fixed variables"
    display as text "  {help cge_constraint}  limits that may bind: quotas, capacity, borrowing and deficit ceilings"
    display as text "  {help cge_bound}       attributes of variables: bounds, scales, starting levels and fixed values"
    display as text "  {help cge_variable}    user variables, defined by an expression or by user equations"
    display as text "  {help cge_equation}    user equations: new relations among the model's variables"
    display as text "  {help cge_set}         user sets of elements, for indexes and sums"
    display as text "  {help cge_parameter}   user parameters: values, assignments and data"
    display as text "  {help cge_macro}       macros of the language of user variables and equations"
    display as text "  {help cge_nest}        declare a nested CES or CET block, as MPSGE's production blocks"
    display as text "  {help cge_model}       a standalone model, written whole in the user language; model statistics"
    display as text "  {help cge_modlib}      a library of ready-to-run models in the user language"
    display as text "  {help cge_solve}       solve and store a simulation"
    display as text "  {help cge_options}     settings of the solver: LU, limits, Jacobian"
    display as text "  {help cge_optimize}    choose instruments to maximise an outcome or reach targets"
    display as text "  {help cge_loop}        solve the model for a list or grid of scenarios"
    display as text "  {help cge_nash}        Nash equilibria of players who choose instruments, and leaders"
    display as text "  {help cge_dynamic}     solve a dynamic run, recursive or with perfect foresight"
    display as text "  {help cge_region}      link single-country models through bilateral trade"
    display as text "  {help cge_results}     display or save all results of a simulation"
    display as text "  {help cge_report}      standard report tables, to screen, Stata or Excel"
    display as text "  {help cge_dynresults}  results of a dynamic run, against a baseline"
    display as text "  {help cge_sensitivity} sensitivity of a scenario to the elasticities"
    display as text "  {help cge_microsim}    pass simulations to household survey data: poverty, inequality and incidence"
    display as text "  {help cge_check}       run validation checks"
    display as text "  {help cge_listing}     equation listing and infeasibility report"
    display as text "  {help cge_gdx}         GAMS data exchange (GDX) files: write, read and list"
    display as text "  {help cge_parameters}  calibrated parameters as a dataset"
    display as text "  {help cge_save}        save the model and its simulations to a file"
    display as text "  {help cge_use}         load a saved model"
    display as text "  {help cge_gams}        write the model as a GAMS program; solve it with PATH, CONOPT or IPOPT"
    display as text _n "Data"
    display as text "  {help cge_synthetic}   load the synthetic SAM used in tests and examples"

    _cge_load
    mata: st_local("libversion", _cge_version())
    if "`libversion'" != "`version'" {
        display as error "the Mata library is version `libversion'; restart Stata to load version `version'"
        exit 498
    }
    return local version "`version'"
end
