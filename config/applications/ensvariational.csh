#!/bin/csh -f

if ( $?config_ensvariational ) exit 0
setenv config_ensvariational 1

source config/model.csh
source config/applications/variational.csh
source config/scenario.csh ensvariational

## job
$setLocal job.${outerMesh}.baseSeconds
$setLocal job.${outerMesh}.secondsPerEnVarMember

@ seconds = $secondsPerEnVarMember * $ensPbNMembers + $baseSeconds
setenv ensvariational__seconds $seconds

$setLocal job.${outerMesh}.nodesPerMember
@ nodes = $nodesPerMember * $EDASize
setenv ensvariational__nodes $nodes
$setNestedEnsvariational job.${outerMesh}.PEPerNode
$setNestedEnsvariational job.${outerMesh}.memory
