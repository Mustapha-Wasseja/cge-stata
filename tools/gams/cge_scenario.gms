$title cge-stata model in GAMS: one scenario
$ontext
Restarts from the work file saved by cge_model.gms (base solution, base
parameters), changes parameters (%shockpar%, which may also choose the
closure), applies the closure, changes fixed variables (%shockvar%), adds any
constraints (%cons%, from version 0.4.4, which declares model cgecon and
needs --cgetype=mcp), solves and writes the solution to %out%. For example:
  gams cge_scenario.gms r=work --name=tariff_removal --shockpar=p.inc --shockvar=v.inc --out=tariff_removal.csv
$offtext

$if not set name $abort "set --name=<scenario name>"
$if not set shockpar $abort "set --shockpar=<include file>"
$if not set shockvar $abort "set --shockvar=<include file>"
$if not set out $set out %name%.csv
$if not set cgesolver $set cgesolver path
$if not set cgetype $set cgetype cns

$include "%shockpar%"
$include cge_closure.gms
$include "%shockvar%"
$ifthen set cons
$include "%cons%"
$else
model cgecon / cge /;
cgecon.optfile = cge.optfile;
$endif
$batinclude cge_solve.gms cgecon

file rescen / '%out%' /;
$batinclude cge_write.gms rescen %name%
