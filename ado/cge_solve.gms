* cge_solve.gms -- solve the model with the chosen solver (from version 0.4.3)
* $batinclude cge_solve.gms <model for --cgetype=mcp>
* --cgetype=cns (the default): a constrained nonlinear system, for PATH,
* CONOPT or KNITRO; --cgetype=nlp: the same equations with a constant
* objective, for NLP solvers such as CONOPT or IPOPT; --cgetype=mcp (from
* version 0.4.4): a mixed complementarity problem, for PATH, the model named
* as the argument (cgebase for the base, cgecon for a scenario with
* constraints). mstat keeps the model status, which cge_write.gms writes.
$ifthen.cgetype %cgetype% == nlp
option nlp = %cgesolver%;
solve cgenlp using nlp minimizing OBJ;
mstat = cgenlp.modelstat;
$elseif.cgetype %cgetype% == mcp
option mcp = %cgesolver%;
solve %1 using mcp;
mstat = %1.modelstat;
$else.cgetype
option cns = %cgesolver%;
solve cge using cns;
mstat = cge.modelstat;
$endif.cgetype
