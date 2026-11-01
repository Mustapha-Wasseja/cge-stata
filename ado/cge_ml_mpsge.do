*! cge_ml_mpsge.do -- cge-stata model library (version 0.44.0)
*! title: Two goods and a tax on labour, written in the form of MPSGE
*! kind: system
*! reference: Rutherford (1999), MPSGE; GAMS/MPSGE gives the same equilibrium
*! expect: without the tax, X = 1.0612061, Y = 0.9475111, PX = 0.8787782 (labour the numeraire)
* Sectors X and Y make two goods from labour and capital, with elasticities
* of substitution of 0.5 and 1.5, and W combines the goods into welfare for
* the consumer, who owns the factors and receives a tax of 25 per cent on
* the labour of X. The tax is removed.
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
cge_shock tx, value(0)
cge_solve, name(notax)
cge_results, sim(notax)
