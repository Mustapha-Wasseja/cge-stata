* mp_sam3.gms -- SYNTHETIC: three sectors with intermediate inputs, labour and
* capital in a nest, taxes on output and labour paid to the government, two
* households with CES demands and Leontief government demand, written in
* MPSGE over sets (version 0.44.0 of cge-stata; tests/test_mpsge.do reads the
* model between $ontext and $offtext with cge_mpsge using).
* tools/gams/run_mpsge_check.py solves it with GAMS/MPSGE and writes the
* levels to tests/expected/mpsge_gams.csv. Labour is the numeraire.
Set s 'sectors and goods' /agr, man, ser/, f 'factors' /lab, cap/, h 'households' /rich, poor/;
Alias (s, g);
Table id0(g,s) 'intermediate inputs'
       agr  man  ser
agr     10   20    5
man     15   30   20
ser      5   15   25;
Table fd0(f,s) 'factor inputs, net of tax'
       agr  man  ser
lab     30   25   40
cap     20   30   35;
Parameter tf0(f,s) 'reference factor tax', tf(f,s) 'factor tax',
  y0(s) 'output' /agr 80, man 156.25, ser 125/,
  ty0(s) 'reference output tax' /man 0.2/, ty(s) 'output tax',
  esub(s) 'elasticity of value added' /agr 0.5, man 1, ser 1.5/,
  sh(h) 'elasticity of household demand' /rich 1.5, poor 0.8/,
  g0(g) 'government demand' /agr 5, man 11.25, ser 20/;
tf0("lab","man") = 0.2;
tf(f,s) = tf0(f,s);
ty(s) = ty0(s);
Table c0(g,h) 'household demand'
       rich  poor
agr     15    25
man     50    30
ser     40    20;
Table e0(f,h) 'endowments'
       rich  poor
lab     45    50
cap     60    25;

$ontext
$model:mp_sam3
$sectors:
  Y(s)
$commodities:
  P(s)  PF(f)
$consumers:
  HH(h)  GOV
$prod:Y(s)  s:0  va:esub(s)
  o:P(s)   q:y0(s)  p:(1-ty0(s))  a:GOV  t:ty(s)
  i:P(g)   q:id0(g,s)
  i:PF(f)  q:fd0(f,s)  p:(1+tf0(f,s))  va:  a:GOV  t:tf(f,s)
$demand:HH(h)  s:sh(h)
  d:P(g)   q:c0(g,h)
  e:PF(f)  q:e0(f,h)
$demand:GOV  s:0
  d:P(g)   q:g0(g)
$offtext
$sysinclude mpsgeset mp_sam3

PF.fx("lab") = 1;
mp_sam3.iterlim = 0;
$include mp_sam3.gen
solve mp_sam3 using mcp;
mp_sam3.iterlim = 10000;
$onecho > path.opt
convergence_tolerance 1e-13
$offecho
mp_sam3.optfile = 1;

file res /mp_sam3.csv/;
res.pw = 200;
$macro WR(sc) put res; loop(s, put 'mp_sam3,' sc ',Y,' s.tl:0 ',' Y.l(s):0:15 /;); loop(s, put 'mp_sam3,' sc ',P,' s.tl:0 ',' P.l(s):0:15 /;); put 'mp_sam3,' sc ',PF,cap,' PF.l("cap"):0:15 /; loop(h, put 'mp_sam3,' sc ',HH,' h.tl:0 ',' HH.l(h):0:15 /;); put 'mp_sam3,' sc ',GOV,,' GOV.l:0:15 /;

* no output tax on manufactures
ty("man") = 0;
$include mp_sam3.gen
solve mp_sam3 using mcp;
WR('notax')
* a labour tax of 50 per cent in manufactures, the output tax back
ty("man") = 0.2;
tf("lab","man") = 0.5;
$include mp_sam3.gen
solve mp_sam3 using mcp;
WR('labtax')
* more capital for the rich
tf("lab","man") = 0.2;
e0("cap","rich") = 72;
$include mp_sam3.gen
solve mp_sam3 using mcp;
WR('capital')
