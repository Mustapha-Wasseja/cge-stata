* Examples of [CGE] cge_synthetic. The SAMs are SYNTHETIC.
*>> synth_load
cge_synthetic, clear
list account act_agr act_man act_ser com_agr com_man com_ser, noobs sep(0)
*<<

*>> synth_health
cge_synthetic, clear health
list account act_hlt com_hlt shi if act_hlt != 0 | com_hlt != 0 | shi != 0, noobs sep(0)
*<<

*>> synth_unbal
cge_synthetic, clear unbalanced
display r(maxdiff)
*<<
