* mp_tax.gms -- SYNTHETIC: two goods, two factors and a tax on labour in
* sector X, written in MPSGE (version 0.44.0 of cge-stata; tests/test_mpsge.do
* reads the model between $ontext and $offtext with cge_mpsge using).
* tools/gams/run_mpsge_check.py solves it with GAMS/MPSGE and writes the
* levels to tests/expected/mpsge_gams.csv. Labour is the numeraire.
Scalar tx 'tax on labour in X' /0.25/;

$ontext
$model:mp_tax
$sectors:
  X  Y  W
$commodities:
  PX  PY  PL  PK  PW
$consumers:
  CONS
$prod:X  s:0.5
  o:PX  q:100
  i:PL  q:40  p:1.25  a:CONS  t:tx
  i:PK  q:50
$prod:Y  s:1.5
  o:PY  q:100
  i:PL  q:60
  i:PK  q:40
$prod:W  s:1
  o:PW  q:200
  i:PX  q:100
  i:PY  q:100
$demand:CONS
  d:PW  q:200
  e:PL  q:100
  e:PK  q:90
$offtext
$sysinclude mpsgeset mp_tax

PL.fx = 1;
mp_tax.iterlim = 0;
$include mp_tax.gen
solve mp_tax using mcp;
mp_tax.iterlim = 10000;
$onecho > path.opt
convergence_tolerance 1e-13
$offecho
mp_tax.optfile = 1;

file res /mp_tax.csv/;
res.pw = 200;
$macro WR(sc) put res; put 'mp_tax,' sc ',X,,' X.l:0:15 /; put 'mp_tax,' sc ',Y,,' Y.l:0:15 /; put 'mp_tax,' sc ',W,,' W.l:0:15 /; put 'mp_tax,' sc ',PX,,' PX.l:0:15 /; put 'mp_tax,' sc ',PY,,' PY.l:0:15 /; put 'mp_tax,' sc ',PK,,' PK.l:0:15 /; put 'mp_tax,' sc ',PW,,' PW.l:0:15 /; put 'mp_tax,' sc ',CONS,,' CONS.l:0:15 /;

tx = 0;
$include mp_tax.gen
solve mp_tax using mcp;
WR('notax')
tx = 0.5;
$include mp_tax.gen
solve mp_tax using mcp;
WR('hitax')
