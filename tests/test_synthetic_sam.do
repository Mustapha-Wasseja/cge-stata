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
