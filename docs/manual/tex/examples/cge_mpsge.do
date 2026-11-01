* Examples of [CGE] cge_mpsge. The data are SYNTHETIC.
*>> mps_tax
cge_model new
cge_parameter tx = 0.25
cge_mpsge model:taxlab
cge_mpsge sectors: X Y W
cge_mpsge commodities: PX PY PL PK PW
cge_mpsge consumers: CONS
cge_mpsge prod:X s:0.5  o:PX q:100  i:PL q:40 p:1.25 a:CONS t:tx  i:PK q:50
cge_mpsge prod:Y s:1.5  o:PY q:100  i:PL q:60  i:PK q:40
cge_mpsge prod:W s:1    o:PW q:200  i:PX q:100  i:PY q:100
cge_mpsge demand:CONS   d:PW q:200  e:PL q:100  e:PK q:90
cge_mpsge end, numeraire(PL)
*<<

*>> mps_list
cge_mpsge, list generated
*<<

*>> mps_solve
cge_shock tx, value(0)
cge_solve, name(notax)
quietly cge_results, sim(notax) clear nodisplay
format base value %10.6f
list variable base value if inlist(variable, "X", "Y", "W", "PX", "PY", "PK") | inlist(variable, "CONS", "X_i2", "X_tx2"), noobs clean
*<<

*>> mps_sets
cge_model new
cge_set s = agr man ser
cge_set g = s
cge_set f = lab cap
cge_set h = rich poor
cge_parameter id0(g,s), values(agr.agr:10 agr.man:20 agr.ser:5 man.agr:15 man.man:30 man.ser:20 ser.agr:5 ser.man:15 ser.ser:25)
cge_parameter fd0(f,s), values(lab.agr:30 lab.man:25 lab.ser:40 cap.agr:20 cap.man:30 cap.ser:35)
cge_parameter tf0(f,s), values(lab.man:0.2)
cge_parameter tf(f,s), values(lab.man:0.2)
cge_parameter y0(s), values(agr:80 man:156.25 ser:125)
cge_parameter ty0(s), values(man:0.2)
cge_parameter ty(s), values(man:0.2)
cge_parameter esub(s), values(agr:0.5 man:1 ser:1.5)
cge_parameter sh(h), values(rich:1.5 poor:0.8)
cge_parameter g0(g), values(agr:5 man:11.25 ser:20)
cge_parameter c0(g,h), values(agr.rich:15 agr.poor:25 man.rich:50 man.poor:30 ser.rich:40 ser.poor:20)
cge_parameter e0(f,h), values(lab.rich:45 lab.poor:50 cap.rich:60 cap.poor:25)
cge_mpsge sectors: Y(s)
cge_mpsge commodities: P(s) PF(f)
cge_mpsge consumers: HH(h) GOV
cge_mpsge prod:Y(s) s:0 va:esub(s)
cge_mpsge    o:P(s)  q:y0(s) p:(1-ty0(s)) a:GOV t:ty(s)
cge_mpsge    i:P(g)$(id0(g,s)) q:id0(g,s)
cge_mpsge    i:PF(f) q:fd0(f,s) p:(1+tf0(f,s)) va: a:GOV t:tf(f,s)
cge_mpsge demand:HH(h) s:sh(h)  d:P(g) q:c0(g,h)  e:PF(f) q:e0(f,h)
cge_mpsge demand:GOV  d:P(g) q:g0(g)
cge_mpsge end, numeraire(PF(lab))
*<<

*>> mps_labtax
cge_shock tf, elements(lab.man) value(0.5)
cge_solve, name(labtax)
quietly cge_results, sim(labtax) clear nodisplay
format base value %10.6f
list variable element1 base value if inlist(variable, "Y", "P", "PF", "HH", "GOV", "HH_u"), noobs sepby(variable)
*<<
