* Examples of [CGE] cge_balance. The SAMs are SYNTHETIC.
*>> bal_ras
cge_synthetic, clear unbalanced
cge_sam, labels(account)
cge_balance
*<<

*>> bal_ce
cge_sam, labels(account)
cge_balance, method(ce) totals(act_agr:97 hhd:290) fixed(row:* hhd:lab)
*<<

*>> bal_return
return list
*<<

*>> bal_fixed
cge_sam, labels(account)
capture noisily cge_balance, fixed(hhd)
di as err "r(" _rc ");"
*<<
