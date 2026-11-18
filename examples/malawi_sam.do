* malawi_sam.do -- worked example: a real SAM, from the file as published to
* the results of policy simulations (from version 0.51.0)
*
* The SAM is the 2019 Social Accounting Matrix for Malawi of the International
* Food Policy Research Institute (IFPRI), shipped with cge-stata as
* cge_malawi_sam.csv and unchanged:
*
*   International Food Policy Research Institute (IFPRI). 2023. 2019 Social
*   Accounting Matrix for Malawi. Washington, DC: IFPRI [dataset].
*   https://doi.org/10.7910/DVN/C9WA0I. Harvard Dataverse. Version 1.
*
*   Kankwamba, Henry; Pauw, Karl; Randriamamonjy, Josee; Thurlow, James. 2023.
*   2019 Social Accounting Matrix for Malawi: A Nexus Project SAM. Data Paper.
*   Washington, DC: IFPRI. https://doi.org/10.2499/p15738coll2.136898.
*
* Licensed under Creative Commons Attribution 4.0 (CC BY 4.0). This data was
* provided by the International Food Policy Research Institute (IFPRI). IFPRI
* bears no responsibility for the analyses or interpretations of the data
* presented here.
*
* The choices of steps 4 and 5 are those of this example, made on the model's
* copy of the SAM, not on the file. The elasticities are round values for
* illustration, not estimates for Malawi, and the simulations show the
* commands: their results are not findings about Malawi.

version 13.0
clear all
set more off

* ---------------------------------------------------------------------
* 1. Read the SAM as published (billions of Malawian kwacha). Its first
*    column describes the accounts and its second holds their codes, which
*    cge_sam takes as the labels; its last row and column are totals, which
*    are checked against the sums of the cells and left out. Labels that are
*    not Stata names (flab-n, hhd-r1, s-i) lose the hyphen. With no file of
*    that name in the working directory, the copy shipped with cge-stata is
*    read, and r(filename) gives its path
* ---------------------------------------------------------------------
cge_sam using cge_malawi_sam.csv, clear
display "`r(filename)'"

* ---------------------------------------------------------------------
* 2. The accounts: 42 activities (a...), each paired with the commodity of
*    the same name (c...), a transaction-cost account (trc), labour of three
*    levels of education, agricultural land and capital, enterprises, ten
*    households by area and expenditure quintile, government, direct, import
*    and sales taxes, savings-investment and the rest of the world
* ---------------------------------------------------------------------
quietly levelsof Code if substr(Code, 1, 1) == "a", local(acts) clean
quietly levelsof Code if substr(Code, 1, 1) == "c", local(coms) clean
local hhds hhdr1 hhdr2 hhdr3 hhdr4 hhdr5 hhdu1 hhdu2 hhdu3 hhdu4 hhdu5

* ---------------------------------------------------------------------
* 3. A first mapping, with every account in the role the SAM gives it.
*    cge_map lists the flows the model does not represent, and stops
* ---------------------------------------------------------------------
capture noisily cge_map, activities(`acts') commodities(`coms') factors(flabn flabp flabs flnd fcap) ///
    households(`hhds') enterprises(ent) government(gov) savinv(si) row(row) ///
    dirtax(dtax) saltax(stax) imptax(mtax) marginaccounts(trc)
assert _rc == 459

* ---------------------------------------------------------------------
* 4. Two choices for those flows
*    - Households and enterprises pay the government 37 (fees and other
*      transfers) besides their direct taxes. The direct-tax account is
*      merged into the government, its payment to the government netted out,
*      and dirtax(gov) then routes all these payments through one internal
*      direct-tax account: they are counted as direct taxes.
*    - The enterprise account buys commodities (962). The model's enterprises
*      do not consume, so the account is mapped as an institution that does,
*      in the households option.
* ---------------------------------------------------------------------
cge_aggregate, groups(gov: gov dtax) netdiagonal

* ---------------------------------------------------------------------
* 5. The SAM balances to the rounding of its cells (5e-6); calibration needs
*    1e-9 of the largest cell. RAS removes the difference, changing no cell
*    by more than 4e-6 of its value
* ---------------------------------------------------------------------
cge_balance

* ---------------------------------------------------------------------
* 6. Map, calibrate and check
* ---------------------------------------------------------------------
cge_map, activities(`acts') commodities(`coms') factors(flabn flabp flabs flnd fcap) ///
    households(`hhds' ent) government(gov) savinv(si) row(row) ///
    dirtax(gov) saltax(stax) imptax(mtax) marginaccounts(trc)
cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_check

* ---------------------------------------------------------------------
* 7. Simulations: all import tariffs removed; maize productivity 10 percent
*    higher
* ---------------------------------------------------------------------
cge_shock tm, value(0)
cge_solve, name(notariff)
cge_shock, reset
cge_shock ad, elements(amaiz) scale(1.1)
cge_solve, name(maize)
cge_shock, reset

* ---------------------------------------------------------------------
* 8. Results
* ---------------------------------------------------------------------
cge_report, sims(notariff maize) tables(macro welfare)
