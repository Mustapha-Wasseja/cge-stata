* test_synthetic_sam.do -- the bundled synthetic SAM loads, is square and balances
* Expected values match reference/tests/test_synthetic_sam.py.

version 13.0

cge_synthetic, clear
assert r(N_accounts) == 15
assert r(maxdiff) < 1e-9
assert abs(r(total) - 1743) < 1e-9

assert _N == 15
assert account[1] == "act_agr"
assert account[15] == "row"

* Spot checks: cell (row r, column c) is a payment from c to r
assert act_agr[4] == 10     // intermediate com_agr used by act_agr
assert lab[9] == 135        // labour income to households
assert hhd[11] == 25        // household direct tax
assert row[14] == 15        // foreign savings
assert com_man[13] == 6     // import tariff on com_man

* National-accounts layout of the same economy
cge_synthetic, clear national
assert r(N_accounts) == 13
assert r(maxdiff) < 1e-9
assert abs(r(total) - 1613) < 1e-9
assert row[1] == 20         // exports recorded as sales by act_agr
assert hhd[10] == 25        // direct tax paid by households to gov
assert com_agr[10] == 8     // sales tax on com_agr paid to gov

* Institutions layout: enterprise (ent) and non-profit institution (npi)
cge_synthetic, clear institutions
assert r(N_accounts) == 17
assert r(maxdiff) < 1e-9
assert abs(r(total) - 1866) < 1e-9
assert ent[9] == 60         // dividends from ent to hhd
assert npi[16] == -1        // negative savings of npi
assert row[7] == 6          // labour income from abroad
