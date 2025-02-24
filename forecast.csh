#!/bin/csh -f

date

# Process arguments
# =================
# ArgMember: int, ensemble member [>= 1]
set ArgMember = "$1"

# ArgFCIntervalHR: int, forecast output interval (hr)
set ArgFCIntervalHR = "$2"

# ArgFCLengthHR: int, total forecast duration
set ArgFCLengthHR = "$3"

# ArgIAU: bool, whether to engage IAU (True/False)
set ArgIAU = "$4"

# ArgMesh: str, mesh name, one of allMeshesJinja, only applicable to FirstCycleDate
set ArgMesh = "$5"

## arg checks
set test = `echo $ArgMember | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be an integer" > ./FAIL
  exit 1
endif
if ( $ArgMember < 1 ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be > 0" > ./FAIL
  exit 1
endif

# Setup environment
# =================
source config/workflow.csh
source config/experiment.csh
source config/externalanalyses.csh
source config/firstbackground.csh
source config/tools.csh
source config/model.csh
source config/builds.csh
source config/environmentJEDI.csh
source config/applications/forecast.csh "$ArgMesh"
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# mesh-dependent and thisValidDate-dependent settings
if ( ${thisValidDate} == ${FirstCycleDate} ) then
  set do_DAcycling = "false"
  if ("$ArgMesh" == "$outerMesh") then
    # templated work directory
    set self_WorkDir = $WorkDirsTEMPLATE[$ArgMember]
    set self_icStateDir = $ExternalAnalysisDirOuter
    set self_icStatePrefix = $externalanalyses__filePrefixOuter
    set nCells = $nCellsOuter
# not used presently
#  else if ("$ArgMesh" == "$innerMesh") then
#    set self_WorkDir = ${FirstBackgroundDirInner}
#    set self_icStateDir = $ExternalAnalysisDirInner
#    set self_icStatePrefix = $externalanalyses__filePrefixInner
#    set nCells = $nCellsInner
#  else if ("$ArgMesh" == "$ensembleMesh") then
#    set self_WorkDir = ${FirstBackgroundDirEnsemble}
#    set self_icStateDir = $ExternalAnalysisDirEnsemble
#    set self_icStatePrefix = $externalanalyses__filePrefixEnsemble
#    set nCells = $nCellsEnsemble
  endif
else
  ## ALL forecasts after the first cycle date use this sub-branch (must be outerMesh)
  set do_DAcycling = "true"

  # templated work directory
  set self_WorkDir = $WorkDirsTEMPLATE[$ArgMember]

  # other templated variables
  set self_icStateDir = $StateDirsTEMPLATE[$ArgMember]

  # static variables
  set self_icStatePrefix = ${ANFilePrefix}

  set nCells = $nCellsOuter
endif

set icFileExt = ${thisMPASFileDate}.nc
set initialState = ${self_icStateDir}/${self_icStatePrefix}.${icFileExt}

if ( ${thisValidDate} == ${FirstCycleDate} ) then
  # use cold-start IC for static stream
  set memberStaticFieldsFile = ${initialState}
else
  # use previously generated IC for static stream
  set StaticMemDir = `${memberDir} 2 $ArgMember "${staticMemFmt}"`
  set memberStaticFieldsFile = ${StaticFieldsDirOuter}${StaticMemDir}/${StaticFieldsFileOuter}
endif

echo "WorkDir = ${self_WorkDir}"
mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

# Default templated variables based on the input arguments.
set deleteZerothForecast = deleteZerothForecastTEMPLATE

# Input parameters can further change for the first DA cycle inside this script.
set self_FCIntervalHR = ${ArgFCIntervalHR}
set self_FCLengthHR   = ${ArgFCLengthHR}
set StartDate = ${thisMPASNamelistDate}


# ================================================================================================

## initial forecast file
set icFile = ${ICFilePrefix}.${icFileExt}
if( -e ${icFile} ) rm ./${icFile}
ln -sfv ${initialState} ./${icFile}

## static fields file
rm ${localStaticFieldsPrefix}*.nc
rm ${localStaticFieldsPrefix}*.nc-lock
set localStaticFieldsFile = ${localStaticFieldsFileOuter}
rm ${localStaticFieldsFile}
ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

# We can start IAU only from the second DA cycle (otherwise, 3hrly background forecast is not available yet.)
set self_IAU = False
set firstIAUDate = `$advanceCYMDH ${FirstCycleDate} ${IAUoutIntervalHR}`
if ($thisValidDate >= $firstIAUDate) then
  set self_IAU = ${ArgIAU}
endif
if ( ${self_IAU} == True ) then
  set IAUDate = `$advanceCYMDH ${thisCycleDate} -${IAUoutIntervalHR}`
  setenv IAUDate ${IAUDate}
  set BGFileExt = `$TimeFmtChange ${IAUDate}`.00.00.nc    # analysis - 3h [YYYY-MM-DD_HH.00.00]
  set BGFile   = ${prevCyclingFCDir}/${FCFilePrefix}.${BGFileExt}    # mpasout at (analysis - 3h)
  set BGFileA  = ${CyclingDAInDir}/${BGFilePrefix}.${icFileExt}	  # bg at the analysis time
  echo ""
  echo "IAU needs two background files:"
  echo "IC: ${BGFile}"
  echo "bg: ${BGFileA}"

  if ( -e ${BGFile} && -e ${BGFileA} ) then
    mv ./${icFile} ${icFile}_nonIAU

    echo "IAU starts from ${IAUDate}."
    set StartDate  = `$TimeFmtChange ${IAUDate}`:00:00      # YYYYMMDDHH => YYYY-MM-DD_HH:00:00
    # Compute analysis increments (AmB)
    ln -sfv ${initialState} ${ANFilePrefix}.${icFileExt}    # an.YYYY-MM-DD_HH.00.00.nc
    ln -sfv ${BGFileA}      ${BGFilePrefix}.${icFileExt}    # bg.YYYY-MM-DD_HH.00.00.nc
    setenv myCommand "${create_amb_in_nc} ${thisValidDate}" # ${IAU_window_s}"
    echo "$myCommand"
    ${myCommand}
    set famb = AmB.`$TimeFmtChange ${IAUDate}`.00.00.nc
    ls -lL $famb || exit 1
    # Initial condition (mpasin.YYYY-MM-DD_HH.00.00.nc)
    ln -sfv ${BGFile} ${ICFilePrefix}.${BGFileExt} || exit 1
  else		# either analysis or background does not exist; IAU is off.
    echo "IAU was on, but no input files. So it is off and initialized at ${thisValidDate}."
    set self_IAU          = False
    set self_FCLengthHR   = ${CyclingWindowHR}
  endif
endif

## link MPAS mesh graph info
rm ./x1.${nCells}.graph.info*
ln -sfv $GraphInfoDir/x1.${nCells}.graph.info* .

## link lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  rm ./*${fileGlob}
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

## link stream_list configs
foreach staticfile ( \
stream_list.${MPASCore}.surface \
stream_list.${MPASCore}.diagnostics \
)
  if( -e $staticfile ) rm ./$staticfile
  ln -sfv $ModelConfigDir/$AppName/$staticfile .
end

## copy/modify dynamic streams file
if( -e ${StreamsFile}) rm ${StreamsFile}
cp -v $ModelConfigDir/$AppName/${StreamsFile} .
sed -i 's@{{nCells}}@'${nCells}'@' ${StreamsFile}
sed -i 's@{{outputInterval}}@'${self_FCIntervalHR}':00:00@' ${StreamsFile}
sed -i 's@{{StaticFieldsPrefix}}@'${localStaticFieldsPrefix}'@' ${StreamsFile}
sed -i 's@{{ICFilePrefix}}@'${ICFilePrefix}'@' ${StreamsFile}
sed -i 's@{{FCFilePrefix}}@'${FCFilePrefix}'@' ${StreamsFile}
sed -i 's@{{PRECISION}}@'${model__precision}'@' ${StreamsFile}

## Update sea-surface variables from GFS/GEFS analyses
set localSeaUpdateFile = x1.${nCells}.sfc_update.nc
sed -i 's@{{surfaceUpdateFile}}@'${localSeaUpdateFile}'@' ${StreamsFile}

if ( "${updateSea}" == "True" ) then
  ## sea/ocean surface files
  # TODO: move sea directory configuration to yamls
  setenv seaMaxMembers 20
  setenv deterministicSeaAnaDir ${ExternalAnalysisDirOuter}
  setenv deterministicSeaMemFmt " "
  setenv deterministicSeaFilePrefix x1.${nCells}.init

  if ( $nMembers > 1 && "$firstbackground__resource" == "PANDAC.LaggedGEFS" ) then
    # using member-specific sst/xice data from GEFS, only works for this special case
    # 60km and 120km
    setenv SeaAnaDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/GEFS/surface/000hr/${model__precision}/${thisValidDate}
    setenv seaMemFmt "/{:02d}"
    setenv SeaFilePrefix x1.${nCells}.sfc_update
  else
    # otherwise use deterministic analysis for all members
    # 60km and 120km
    setenv SeaAnaDir ${deterministicSeaAnaDir}
    setenv seaMemFmt "${deterministicSeaMemFmt}"
    setenv SeaFilePrefix ${deterministicSeaFilePrefix}
  endif

  # first try member-specific state file (central GFS state when ArgMember==0)
  set seaMemDir = `${memberDir} 2 $ArgMember "${seaMemFmt}" -m ${seaMaxMembers}`
  set SeaFile = ${SeaAnaDir}${seaMemDir}/${SeaFilePrefix}.${icFileExt}
  ln -sfv ${SeaFile} ./${localSeaUpdateFile}
  set brokenLinks=( `find ${localSeaUpdateFile} -mindepth 0 -maxdepth 0 -type l -exec test ! -e {} \; -print` )
  set broken=0
  foreach l ($brokenLinks)
    @ broken++
  end

  #if link broken
  if ( $broken > 0 ) then
    echo "$0 (WARNING): file link broken to ${SeaFile}" >> ./WARNING

    # otherwise try deterministic state file
    set SeaFile = ${deterministicSeaAnaDir}/${deterministicSeaFilePrefix}.${icFileExt}
    ln -sfv ${SeaFile} ./${localSeaUpdateFile}
    set brokenLinks=( `find ${localSeaUpdateFile} -mindepth 0 -maxdepth 0 -type l -exec test ! -e {} \; -print` )
    set broken=0
    foreach l ($brokenLinks)
      @ broken++
    end

    #if link broken
    if ( $broken > 0 ) then
      echo "$0 (ERROR): file link broken to ${SeaFile}" >> ./FAIL
      exit 1
    endif
  endif

  # determine sea-update precision
  ncdump -h ${localSeaUpdateFile} | grep sst | grep double
  if ($status == 0) then
    set surfacePrecision=double
  else
    ncdump -h ${localSeaUpdateFile} | grep sst | grep float
    if ($status == 0) then
      set surfacePrecision=single
    else
      echo "$0 (ERROR): cannot determine surface input precision (${localSeaUpdateFile})" > ./FAIL
      exit 1
    endif
  endif
  sed -i 's@{{surfacePrecision}}@'${surfacePrecision}'@' ${StreamsFile}
  sed -i 's@{{surfaceInputInterval}}@initial_only@' ${StreamsFile}
else
  sed -i 's@{{surfacePrecision}}@'${model__precision}'@' ${StreamsFile}
  sed -i 's@{{surfaceInputInterval}}@none@' ${StreamsFile}
endif

## copy/modify dynamic namelist
if( -e ${NamelistFile}) rm ${NamelistFile}
cp -v $ModelConfigDir/$AppName/$NamelistFile .
sed -i 's@startTime@'${StartDate}'@' $NamelistFile
sed -i 's@fcLength@'${self_FCLengthHR}':00:00@' $NamelistFile
sed -i 's@nCells@'${nCells}'@' $NamelistFile
sed -i 's@modelDT@'${TimeStep}'@' $NamelistFile
sed -i 's@diffusionLengthScale@'${DiffusionLengthScale}'@' $NamelistFile
sed -i 's@configDODACycling@'${do_DAcycling}'@' $NamelistFile
if ( ${self_IAU} == True ) then
  sed -i 's@{{IAU}}@on@' $NamelistFile
  echo "$0 (INFO): IAU is turned on."
else
  sed -i 's@{{IAU}}@off@' $NamelistFile
  echo "$0 (INFO): IAU is turned off."
endif

if ( ${ArgFCLengthHR} == 0 ) then
  ## zero-length forecast case (NOT CURRENTLY USED)
  rm ./${icFile}_tmp
  mv ./${icFile} ./${icFile}_tmp
  rm ${FCFilePrefix}.${icFileExt}
  cp ${icFile}_tmp ${FCFilePrefix}.${icFileExt}
  rm ./${DIAGFilePrefix}.${icFileExt}
  ln -sfv ${self_icStateDir}/${DIAGFilePrefix}.${icFileExt} ./
else
  ## remove previously generated forecasts
  set fcDate = `$advanceCYMDH ${thisValidDate} ${self_FCIntervalHR}`
  set finalFCDate = `$advanceCYMDH ${thisValidDate} ${self_FCLengthHR}`
  while ( ${fcDate} <= ${finalFCDate} )
    set fcFileDate  = `$TimeFmtChange ${fcDate}`
    set fcFile = ${FCFilePrefix}.${fcFileDate}.00.00.nc

    if( -e ${fcFile} ) rm ${fcFile}

    set fcDate = `$advanceCYMDH ${fcDate} ${self_FCIntervalHR}`
    setenv fcDate ${fcDate}
  end

  # Run the executable
  # ==================
  if( -e ${ForecastEXE} ) rm ./${ForecastEXE}
  ln -sfv ${ForecastBuildDir}/${ForecastEXE} ./
  # mpiexec is for Open MPI, mpiexec_mpt is for MPT
  mpiexec ./${ForecastEXE}
  #mpiexec_mpt ./${ForecastEXE}


  # Check status
  # ============
  grep "Finished running the ${MPASCore} core" log.${MPASCore}.0000.out
  if ( $status != 0 ) then
    echo "ERROR in $0 : MPAS-Model forecast failed" > ./FAIL
    exit 1
  endif

  ## change static fields to a link, keeping for transparency
  rm ${localStaticFieldsFile}
  mv ${localStaticFieldsFile}${OrigFileSuffix} ${localStaticFieldsFile}
endif

if ( "$deleteZerothForecast" == "True" ) then
  # Optionally remove initial forecast file
  # =======================================
  set fcDate = ${thisValidDate}
  set fcFileDate  = `$TimeFmtChange ${fcDate}`
  set fcFile = ${FCFilePrefix}.${fcFileDate}.00.00.nc
  rm ${fcFile}
  set diagFile = ${DIAGFilePrefix}.${fcFileDate}.00.00.nc
  rm ${diagFile}
endif

date

exit 0
