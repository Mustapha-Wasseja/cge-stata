* cge_solve.gms -- solve the model with the chosen solver (from version 0.4.3)
* $batinclude cge_solve.gms
* --cgetype=cns (the default): a constrained nonlinear system, for PATH,
* CONOPT or KNITRO; --cgetype=nlp: the same equations with a constant
* objective, for NLP solvers such as CONOPT or IPOPT. mstat keeps the model
* status, which cge_write.gms writes.
$ifthen.cgetype %cgetype% == nlp
option nlp = %cgesolver%;
solve cgenlp using nlp minimizing OBJ;
mstat = cgenlp.modelstat;
$else.cgetype
option cns = %cgesolver%;
solve cge using cns;
mstat = cge.modelstat;
$endif.cgetype
