* Examples of [CGE] cge_gdx. The SAM is SYNTHETIC.
* The manual runs this file twice, and the scripts it writes in between:
* Stata for Windows cannot start GAMS in batch mode. The commands that read
* come last, since the first run has nothing to read.
*>> gdx_setup
cge_synthetic, clear
cge_sam, labels(account)
quietly cge_map, activities(act_agr act_man act_ser) commodities(com_agr com_man com_ser) ///
    factors(lab cap) households(hhd) government(gov) savinv(sav) row(row)                 ///
    dirtax(tax_dir) saltax(tax_sal) imptax(tax_imp)
quietly cge_calibrate, sigmava(0.8) sigmaq(2) sigmat(2)
cge_shock tm, value(0)
cge_solve, name(notariff)
*<<

*>> gdx_write
cge_gdx write using model.gdx, sims(notariff) replace norun gams(C:/GAMS/54/gams.exe)
mata: g = cat("model_write.gms"); for (i = 1; i <= 14; i++) printf("%s\n", g[i])
*<<

*>> gdx_list
cge_gdx list using model.gdx, norun gams(C:/GAMS/54/gams.exe)
*<<

*>> gdx_sam
cge_sam using model.gdx, symbol(SAM) clear norun gams(C:/GAMS/54/gams.exe)
*<<

*>> gdx_read
cge_gdx read using model.gdx, symbol(LEVEL) clear norun gams(C:/GAMS/54/gams.exe)
return list
list sim dim2 dim3 value if dim2 == "QA", noobs sepby(sim)
*<<
