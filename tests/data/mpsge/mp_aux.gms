* mp_aux.gms -- SYNTHETIC: an equal-yield tax and a floor on the real wage,
* written in MPSGE with auxiliary variables, constraints, an endogenous tax
* (n:), a rationed endowment (r:) and report variables (version 0.45.0 of
* cge-stata; tests/test_mpsge.do reads the model between $ontext and
* $offtext with cge_mpsge using). The government's tax on the output of X,
* TAU, keeps its real revenue at grev; unemployment, U, keeps the real wage
* at least 1. tools/gams/run_mpsge_check.py solves it with GAMS/MPSGE and
* writes the levels to tests/expected/mpsge_gams.csv. Labour is the
* numeraire.
Scalar kend 'endowment of capital' /90/, grev 'real revenue of the government' /10/;

$ontext
$model:mp_aux
$sectors:
  X  Y  W
$commodities:
  PX  PY  PL  PK  PW
$consumers:
  CONS  GOVT
$auxiliary:
  TAU  U
$prod:X  s:0.5
  o:PX  q:100  p:0.9  a:GOVT  n:TAU
  i:PL  q:40
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
  d:PW  q:190
  e:PL  q:100
  e:PL  q:(-100)  r:U
  e:PK  q:kend
$demand:GOVT
  d:PW  q:10
$constraint:TAU
  GOVT =e= grev * PW;
$constraint:U
  PL =g= PW;
$report:
  v:XO   o:PX  prod:X
  v:XL   i:PL  prod:X
  v:CW   d:PW  demand:CONS
  v:WC   w:CONS
$offtext
$sysinclude mpsgeset mp_aux

TAU.l = 0.1;
U.l = 0;
PL.fx = 1;
mp_aux.iterlim = 0;
$include mp_aux.gen
solve mp_aux using mcp;
mp_aux.iterlim = 10000;
$onecho > path.opt
convergence_tolerance 1e-13
$offecho
mp_aux.optfile = 1;

file res /mp_aux.csv/;
res.pw = 200;
$macro WR(sc) put res; put 'mp_aux,' sc ',X,,' X.l:0:15 /; put 'mp_aux,' sc ',Y,,' Y.l:0:15 /; put 'mp_aux,' sc ',PX,,' PX.l:0:15 /; put 'mp_aux,' sc ',PK,,' PK.l:0:15 /; put 'mp_aux,' sc ',PW,,' PW.l:0:15 /; put 'mp_aux,' sc ',CONS,,' CONS.l:0:15 /; put 'mp_aux,' sc ',GOVT,,' GOVT.l:0:15 /; put 'mp_aux,' sc ',TAU,,' TAU.l:0:15 /; put 'mp_aux,' sc ',U,,' U.l:0:15 /; put 'mp_aux,' sc ',XO,,' XO.l:0:15 /; put 'mp_aux,' sc ',XL,,' XL.l:0:15 /; put 'mp_aux,' sc ',CW,,' CW.l:0:15 /; put 'mp_aux,' sc ',WC,,' WC.l:0:15 /;

* less capital: the floor on the real wage binds
kend = 70;
$include mp_aux.gen
solve mp_aux using mcp;
WR('lesscap')
* more real revenue
kend = 90;
grev = 15;
$include mp_aux.gen
solve mp_aux using mcp;
WR('morerev')
