* mp_inest.gms -- SYNTHETIC: Armington nests indexed by good, within a nest
* of imports and domestic goods named m, beside a nest of value added named
* va, in the form of MPSGE (version 0.46.0 of cge-stata; tests/test_mpsge.do
* reads the model between $ontext and $offtext with cge_mpsge using). Each
* good's nest has an elasticity of its own; imports are bought with foreign
* exchange that the consumer is given, and pay a tariff to the government.
* tools/gams/run_mpsge_check.py solves it with GAMS/MPSGE and writes the
* levels to tests/expected/mpsge_gams.csv. Labour is the numeraire.
Set g 'goods' /a, b/;
Parameter dd0(g) 'domestic goods' /a 50, b 40/, mm0(g) 'imports' /a 30, b 20/,
  ld0(g) 'labour' /a 30, b 25/, kd0(g) 'capital' /a 20, b 15/,
  sig(g) 'elasticity of substitution between imports and domestic goods' /a 4, b 1.5/,
  tm0(g) 'reference tariff' /a 0.1, b 0/, tm(g) 'tariff';
Scalar fxend 'foreign exchange' /50/;
tm(g) = tm0(g);

$ontext
$model:mp_inest
$sectors:
  C  Y(g)  M(g)
$commodities:
  PC  PD(g)  PM(g)  PL  PK  PFX
$consumers:
  RA  GOV
$prod:C  s:0.5  m:1.5  g.tl(m):sig(g)  va:1
  o:PC     q:(200 + sum(g, tm0(g) * mm0(g)))
  i:PD(g)  q:dd0(g)  g.tl:
  i:PM(g)  q:mm0(g)  p:(1+tm0(g))  g.tl:  a:GOV  t:tm(g)
  i:PL     q:40  va:
  i:PK     q:20  va:
$prod:Y(g)  s:1
  o:PD(g)  q:dd0(g)
  i:PL     q:ld0(g)
  i:PK     q:kd0(g)
$prod:M(g)
  o:PM(g)  q:mm0(g)
  i:PFX    q:mm0(g)
$demand:RA
  d:PC     q:200
  e:PL     q:95
  e:PK     q:55
  e:PFX    q:fxend
$demand:GOV
  d:PC     q:(sum(g, tm0(g) * mm0(g)))
$offtext
$sysinclude mpsgeset mp_inest

PL.fx = 1;
mp_inest.iterlim = 0;
$include mp_inest.gen
solve mp_inest using mcp;
mp_inest.iterlim = 10000;
$onecho > path.opt
convergence_tolerance 1e-13
$offecho
mp_inest.optfile = 1;

file res /mp_inest.csv/;
res.pw = 200;
$macro WR(sc) put res; put 'mp_inest,' sc ',C,,' C.l:0:15 /; loop(g, put 'mp_inest,' sc ',Y,' g.tl:0 ',' Y.l(g):0:15 /;); loop(g, put 'mp_inest,' sc ',M,' g.tl:0 ',' M.l(g):0:15 /;); put 'mp_inest,' sc ',PC,,' PC.l:0:15 /; loop(g, put 'mp_inest,' sc ',PD,' g.tl:0 ',' PD.l(g):0:15 /;); loop(g, put 'mp_inest,' sc ',PM,' g.tl:0 ',' PM.l(g):0:15 /;); put 'mp_inest,' sc ',PK,,' PK.l:0:15 /; put 'mp_inest,' sc ',PFX,,' PFX.l:0:15 /; put 'mp_inest,' sc ',RA,,' RA.l:0:15 /; put 'mp_inest,' sc ',GOV,,' GOV.l:0:15 /;

* less foreign exchange
fxend = 40;
$include mp_inest.gen
solve mp_inest using mcp;
WR('lessfx')
* free trade
fxend = 50;
tm(g) = 0;
$include mp_inest.gen
solve mp_inest using mcp;
WR('freetrade')
