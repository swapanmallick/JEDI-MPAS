#!/bin/csh -f

date

# Setup environment
# =================
source config/experiment.csh
source config/tools.csh
source config/builds.csh
source config/environmentJEDI.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set self_WorkDir = $MeanBackgroundDirs[1]
echo "WorkDir = ${self_WorkDir}"
mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

# other static variables
set self_StateDirs = ($prevCyclingFCDirs)
set self_StatePrefix = ${FCFilePrefix}
set memberPrefix = ${self_StatePrefix}.${thisMPASFileDate}mem
set meanName = ${self_StatePrefix}.$thisMPASFileDate.nc
set varianceName = ${self_StatePrefix}.$thisMPASFileDate.variance.nc

# ================================================================================================

## link background members
set member = 1
while ( $member <= ${nMembers} )
  set appMember = `${memberDir} 2 $member "{:03d}"`
# set appMember = printf "%03d" $member`
  ln -sfv $self_StateDirs[$member]/${meanName} ./${memberPrefix}${appMember}
  @ member++
end

if (${nMembers} == 1) then
  ## pass-through for mean
  ln -sfv $self_StateDirs[1]/${meanName} ./
else
  ## make copy for mean
  cp $self_StateDirs[1]/${meanName} ./

  ## make copy for variance
  cp $self_StateDirs[1]/${meanName} ./${varianceName}


  # Run the executable
  # ==================
  set arg1 = ${self_WorkDir}
  set arg2 = ${meanName}
  set arg3 = ${varianceName}
  set arg4 = ${memberPrefix}
  set arg5 = ${nMembers}

  ln -sfv ${meanStateBuildDir}/${meanStateExe} ./
  mpiexec ./${meanStateExe} "$arg1" "$arg2" "$arg3" "$arg4" "$arg5" >& log


  # Check status
  # ============
  grep 'All done' log
  if ( $status != 0 ) then
    echo "ERROR in $0 : mean state application failed" > ./FAIL
    exit 1
  endif
endif

date

exit 0
