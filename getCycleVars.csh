#!/bin/csh -f

source config/tools.csh
source config/workflow.csh
source config/experiment.csh

set prevCycleDate = `$advanceCYMDH ${thisCycleDate} -${CyclingWindowHR}`
#set nextCycleDate = `$advanceCYMDH ${thisCycleDate} ${CyclingWindowHR}`
setenv prevCycleDate ${prevCycleDate}
#setenv nextCycleDate ${nextCycleDate}

## setup cycle directory names
set ObsDir = ${ObsWorkDir}/${thisValidDate}
set CyclingDADir = ${CyclingDAWorkDir}/${thisCycleDate}
set CyclingDAInDir = $CyclingDADir/${bgDir}
set CyclingDAOutDir = $CyclingDADir/${anDir}
set CyclingDADirs = (${CyclingDADir})
set BenchmarkCyclingDADirs = (${BenchmarkCyclingDAWorkDir}/${thisCycleDate})

set ExternalAnalysisDir = ${ExternalAnalysisWorkDir}/${thisValidDate}
set ExternalAnalysisDirOuter = ${ExternalAnalysisWorkDirOuter}/${thisValidDate}
set ExternalAnalysisDirInner = ${ExternalAnalysisWorkDirInner}/${thisValidDate}
set ExternalAnalysisDirEnsemble = ${ExternalAnalysisWorkDirEnsemble}/${thisValidDate}

set prevCyclingDADir = ${CyclingDAWorkDir}/${prevCycleDate}
set CyclingFCDir = ${CyclingFCWorkDir}/${thisCycleDate}
set prevCyclingFCDir = ${CyclingFCWorkDir}/${prevCycleDate}
set ExtendedFCDir = ${ExtendedFCWorkDir}/${thisCycleDate}

set memDir = /mean
set MeanBackgroundDirs = (${CyclingDAInDir}${memDir})
set MeanAnalysisDirs = (${CyclingDAOutDir}${memDir})
set ExtendedMeanFCDirs = (${ExtendedFCDir}${memDir})
set VerifyEnsMeanBGDirs = (${VerificationWorkDir}/${bgDir}${memDir}/${thisCycleDate})
set VerifyMeanANDirs = (${VerificationWorkDir}/${anDir}${memDir}/${thisCycleDate})
set VerifyMeanFCDirs = (${VerificationWorkDir}/${fcDir}${memDir}/${thisCycleDate})

#set BenchmarkVerifyEnsMeanBGDirs = (${BenchmarkVerificationWorkDir}/${bgDir}${memDir}/${thisCycleDate})
#set BenchmarkVerifyMeanANDirs = (${BenchmarkVerificationWorkDir}/${anDir}${memDir}/${thisCycleDate})
#set BenchmarkVerifyMeanFCDirs = (${BenchmarkVerificationWorkDir}/${fcDir}${memDir}/${thisCycleDate})

set CyclingRTPPDir = ${RTPPWorkDir}/${thisCycleDate}
set CyclingABEInflationDir = ${ABEInflationWorkDir}/${thisCycleDate}

set CyclingDAInDirs = ()
set CyclingDAOutDirs = ()

set CyclingFCDirs = ()
set prevCyclingFCDirs = ()

set ExtendedEnsFCDirs = ()

set VerifyBGPrefix = ${VerificationWorkDir}/${bgDir}
set VerifyBGDirs = ()
set VerifyANPrefix = ${VerificationWorkDir}/${anDir}
set VerifyANDirs = ()
set VerifyEnsFCDirs = ()

set BenchmarkVerifyBGPrefix = ${BenchmarkVerificationWorkDir}/${bgDir}
set BenchmarkVerifyBGDirs = ()
set BenchmarkVerifyANPrefix = ${BenchmarkVerificationWorkDir}/${anDir}
set BenchmarkVerifyANDirs = ()
set BenchmarkVerifyEnsFCDirs = ()

set member = 1
while ( $member <= ${nMembers} )
  set memDir = `${memberDir} $nMembers $member`
  set CyclingDAInDirs = ($CyclingDAInDirs ${CyclingDAInDir}${memDir})
  set CyclingDAOutDirs = ($CyclingDAOutDirs ${CyclingDAOutDir}${memDir})

  set CyclingFCDirs = ($CyclingFCDirs ${CyclingFCDir}${memDir})
  set prevCyclingFCDirs = ($prevCyclingFCDirs ${prevCyclingFCDir}${memDir})

  set ExtendedEnsFCDirs = ($ExtendedEnsFCDirs ${ExtendedFCDir}${memDir})

  set VerifyANDirs = ($VerifyANDirs ${VerifyANPrefix}${memDir}/${thisCycleDate})
  set VerifyBGDirs = ($VerifyBGDirs ${VerifyBGPrefix}${memDir}/${thisCycleDate})
  set VerifyEnsFCDirs = ($VerifyEnsFCDirs ${VerificationWorkDir}/${fcDir}${memDir}/${thisCycleDate})

  set BenchmarkVerifyANDirs = ($BenchmarkVerifyANDirs ${BenchmarkVerifyANPrefix}${memDir}/${thisCycleDate})
  set BenchmarkVerifyBGDirs = ($BenchmarkVerifyBGDirs ${BenchmarkVerifyBGPrefix}${memDir}/${thisCycleDate})
  set BenchmarkVerifyEnsFCDirs = ($BenchmarkVerifyEnsFCDirs ${BenchmarkVerificationWorkDir}/${fcDir}${memDir}/${thisCycleDate})

  @ member++
end

# Universal time info for namelist, yaml etc
# ==========================================
set yy = `echo ${thisValidDate} | cut -c 1-4`
set mm = `echo ${thisValidDate} | cut -c 5-6`
set dd = `echo ${thisValidDate} | cut -c 7-8`
set hh = `echo ${thisValidDate} | cut -c 9-10`
set thisMPASFileDate = ${yy}-${mm}-${dd}_${hh}.00.00
set thisMPASNamelistDate = ${yy}-${mm}-${dd}_${hh}:00:00
set thisISO8601Date = ${yy}-${mm}-${dd}T${hh}:00:00Z
set ICfileDate = ${yy}-${mm}-${dd}_${hh}
