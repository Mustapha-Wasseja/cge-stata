$title cge-stata model in GAMS: one scenario
$ontext
Restarts from the work file saved by cge_model.gms (base solution, base
parameters), changes parameters (%shockpar%, which may also choose the
closure), applies the closure, changes fixed variables (%shockvar%), solves
and writes the solution to %out%. For example:
  gams cge_scenario.gms r=work --name=tariff_removal --shockpar=p.inc --shockvar=v.inc --out=tariff_removal.csv
$offtext

$if not set name $abort "set --name=<scenario name>"
$if not set shockpar $abort "set --shockpar=<include file>"
$if not set shockvar $abort "set --shockvar=<include file>"
$if not set out $set out %name%.csv

$include "%shockpar%"
$include closure.gms
$include "%shockvar%"
solve cge using cns;

file rescen / '%out%' /;
$batinclude write.gms rescen %name%
