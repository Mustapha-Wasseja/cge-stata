* mp_nest.gms -- SYNTHETIC: joint products with an elasticity of
* transformation, a Leontief resource and two levels of nests of inputs, a
* technology that does not pay at the reference prices, and nested
* household demand; the government's demand takes MPSGE's default
* elasticity, 0 (version 0.44.0 of cge-stata; tests/test_mpsge.do reads the
* model between $ontext and $offtext with cge_mpsge using).
* tools/gams/run_mpsge_check.py solves it with GAMS/MPSGE and writes the
* levels to tests/expected/mpsge_gams.csv. Labour is the numeraire.
Scalar te0 'reference export tax' /0.1/, te 'export tax' /0.1/,
  tl0 'reference labour tax' /0.2/, tl 'labour tax' /0.2/,
  zq 'inputs of technology Z' /6/, nend 'endowment of the resource' /20/;

$ontext
$model:mp_nest
$sectors:
  X  Y  Z
$commodities:
  PD  PE  PY  PL  PK  PN
$consumers:
  HH  GOV
$prod:X  s:0  t:2  va:1.2  kn(va):0.6
  o:PD  q:64
  o:PE  q:40  p:(1-te0)  a:GOV  t:te
  i:PN  q:20
  i:PL  q:25  p:(1+tl0)  va:  a:GOV  t:tl
  i:PK  q:30  kn:
  i:PY  q:20  kn:
$prod:Y  s:0.8
  o:PY  q:50
  i:PL  q:30
  i:PK  q:20
$prod:Z  s:1
  o:PY  q:10
  i:PL  q:zq
  i:PK  q:zq
$demand:HH  s:0.7  tr:1.5
  d:PD  q:64  tr:
  d:PE  q:36  tr:
  d:PY  q:25
  e:PL  q:55
  e:PK  q:50
  e:PN  q:nend
$demand:GOV
  d:PE  q:4
  d:PY  q:5
$offtext
$sysinclude mpsgeset mp_nest

PL.fx = 1;
Z.l = 0;
mp_nest.iterlim = 0;
$include mp_nest.gen
solve mp_nest using mcp;
mp_nest.iterlim = 10000;
$onecho > path.opt
convergence_tolerance 1e-13
$offecho
mp_nest.optfile = 1;

file res /mp_nest.csv/;
res.pw = 200;
$macro WR(sc) put res; put 'mp_nest,' sc ',X,,' X.l:0:15 /; put 'mp_nest,' sc ',Y,,' Y.l:0:15 /; put 'mp_nest,' sc ',Z,,' Z.l:0:15 /; put 'mp_nest,' sc ',PD,,' PD.l:0:15 /; put 'mp_nest,' sc ',PE,,' PE.l:0:15 /; put 'mp_nest,' sc ',PY,,' PY.l:0:15 /; put 'mp_nest,' sc ',PK,,' PK.l:0:15 /; put 'mp_nest,' sc ',PN,,' PN.l:0:15 /; put 'mp_nest,' sc ',HH,,' HH.l:0:15 /; put 'mp_nest,' sc ',GOV,,' GOV.l:0:15 /;

* a higher tax on exports: the resource becomes a free good
te = 0.3;
$include mp_nest.gen
solve mp_nest using mcp;
WR('extax')
* a larger endowment of the resource
te = 0.1;
nend = 25;
$include mp_nest.gen
solve mp_nest using mcp;
WR('freegood')
* technology Z pays, and Y shuts down
nend = 20;
zq = 4.5;
$include mp_nest.gen
solve mp_nest using mcp;
WR('newtech')
