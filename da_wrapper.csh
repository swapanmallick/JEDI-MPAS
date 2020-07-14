#!/bin/csh

#
# Setup environment:
# =============================================
source ./setup.csh

#parent
setenv self_DependsOn     DependTypeArg

#self
setenv self_Date          DateArg
setenv self_WindowHR      WindowHRArg
set self_ObsList = ("${ObsListArg}")
setenv self_VARBCTable    VARBCTableArg
setenv self_bgStatePrefix bgStatePrefixArg
setenv self_DAType        DATypeArg
setenv self_DAMode        DAModeArg

#children
setenv self_DAJobScript   DAJobScriptArg
setenv self_VFJobScript   VFJobScriptArg


#
# Time info for namelist, yaml etc:
# =============================================
set yy = `echo ${self_Date} | cut -c 1-4`
set mm = `echo ${self_Date} | cut -c 5-6`
set dd = `echo ${self_Date} | cut -c 7-8`
set hh = `echo ${self_Date} | cut -c 9-10`
set FileDate = ${yy}-${mm}-${dd}_${hh}.00.00
set NMLDate = ${yy}-${mm}-${dd}_${hh}:00:00
set ConfDate = ${yy}-${mm}-${dd}T${hh}:00:00Z

set prevDate = `$advanceCYMDH ${self_Date} -${self_WindowHR}`
set yy = `echo ${prevDate} | cut -c 1-4`
set mm = `echo ${prevDate} | cut -c 5-6`
set dd = `echo ${prevDate} | cut -c 7-8`
set hh = `echo ${prevDate} | cut -c 9-10`
set prevFileDate = ${yy}-${mm}-${dd}_${hh}.00.00
#set prevNMLDate = ${yy}-${mm}-${dd}_${hh}:00:00
set prevConfDate = ${yy}-${mm}-${dd}T${hh}:00:00Z

#TODO: HALF STEP ONLY WORKS FOR INTEGER VALUES OF WindowHR
@ HALF_DT_HR = ${self_WindowHR} / 2
@ ODD_DT = ${self_WindowHR} % 2
@ HALF_mi_ = ${ODD_DT} * 30
set HALF_mi = $HALF_mi_
if ( $HALF_mi_ < 10 ) then
  set HALF_mi = 0$HALF_mi
endif

#@ HALF_DT_HR_PLUS = ${HALF_DT_HR}
@ HALF_DT_HR_MINUS = ${HALF_DT_HR} + ${ODD_DT}
set halfprevDate = `$advanceCYMDH ${self_Date} -${HALF_DT_HR_MINUS}`
set yy = `echo ${halfprevDate} | cut -c 1-4`
set mm = `echo ${halfprevDate} | cut -c 5-6`
set dd = `echo ${halfprevDate} | cut -c 7-8`
set hh = `echo ${halfprevDate} | cut -c 9-10`
set halfprevConfDate = ${yy}-${mm}-${dd}T${hh}:${HALF_mi}:00Z

# ============================================================
# ============================================================
# Copy/link files: BUMP B matrix, namelist, yaml, bg, obs data
# ============================================================
# ============================================================

# MPAS mesh graph info
ln -sf $GRAPHINFO_DIR/x1.${MPAS_NCELLS}.graph.info* .

# lookup tables
ln -sf ${MPASBUILDDIR}/src/core_atmosphere/physics/physics_wrf/files/* .

# Copy/revise time info in MPAS namelist
# ======================================
cp -v $DA_NML_DIR/* .

cp -v ${RESSPECIFICDIR}/namelist.atmosphere_da ./namelist.atmosphere
cp -v namelist.atmosphere orig_namelist.atmosphere
cat >! newnamelist << EOF
  /config_start_time /c\
   config_start_time      = '${NMLDate}'
EOF
sed -f newnamelist orig_namelist.atmosphere >! namelist.atmosphere
rm newnamelist

# =============
# OBSERVATIONS
# =============
mkdir -p ${InDBDir}
set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memDir = `${memberDir} $self_DAType $member`
  mkdir -p ${OutDBDir}${memDir}
  @ member++
end

# Link conventional data
# ======================
ln -fsv $CONV_OBS_DIR/${self_Date}/aircraft_obs*.nc4 ${InDBDir}/
ln -fsv $CONV_OBS_DIR/${self_Date}/gnssro_obs*.nc4 ${InDBDir}/
ln -fsv $CONV_OBS_DIR/${self_Date}/satwind_obs*.nc4 ${InDBDir}/
ln -fsv $CONV_OBS_DIR/${self_Date}/sfc_obs*.nc4 ${InDBDir}/
ln -fsv $CONV_OBS_DIR/${self_Date}/sondes_obs*.nc4 ${InDBDir}/

# Link AMSUA data
# ==============
ln -fsv $AMSUA_OBS_DIR/${self_Date}/amsua*_obs_*.nc4 ${InDBDir}/

# Link ABI data
# ============
ln -fsv $ABI_OBS_DIR/${self_Date}/abi*_obs_*.nc4 ${InDBDir}/

# Link AHI data
# ============
ln -fsv $AHI_OBS_DIR/${self_Date}/ahi*_obs_*.nc4 ${InDBDir}/

# Link VarBC prior
# ====================
ln -fsv ${self_VARBCTable} ${InDBDir}/satbias_crtm_bak


# Generate yaml
# =======================================

## Copy BASE MPAS-JEDI yaml
cp -v ${CONFIGDIR}/applicationBase/${self_DAType}.yaml orig_jedi0.yaml

set AnalyzeHydrometeors = 0

## Add selected observations (see setup.csh)
foreach obs ($self_ObsList)
  echo "Preparing YAML for ${obs} observations"
  set missing=0
  set SUBYAML=ObsTypePlugs/${self_DAMode}/${obs}
  if ( "$obs" =~ *"abi"* ) then
    find ${InDBDir}/abi*_obs_*.nc4 -mindepth 0 -maxdepth 0
    if ($? > 0) then
      set missing=1
    else
      set brokenLinks=( `find ${InDBDir}/abi*_obs_*.nc4 -mindepth 0 -maxdepth 0 -type l -exec test ! -e {} \; -print` )
      foreach link ($brokenLinks)
        set missing=1
      end
    endif
    if ($missing == 0) then
      echo "ABI data is present and selected; adding ABI to the YAML"
    else
      echo "ABI data is selected, but missing; NOT adding ABI to the YAML"
    endif
  else if ( "$obs" =~ *"conv"* ) then
    #KLUDGE to handle missing qv for sondes at single time
    if ( ${self_Date} == 2018043006 ) then
      set SUBYAML=${SUBYAML}-2018043006
    endif
  endif

  ## determine if hydrometeor variables will be analyzed
  if ( "$obs" =~ "all"* ) then
    set AnalyzeHydrometeors = 1
  endif

  if ($missing == 0) then
    cat ${CONFIGDIR}/${SUBYAML}.yaml >> orig_jedi0.yaml
  endif
end

## QC characteristics
sed -i 's@RADTHINDISTANCE@'${RADTHINDISTANCE}'@g' orig_jedi0.yaml
sed -i 's@RADTHINAMOUNT@'${RADTHINAMOUNT}'@g' orig_jedi0.yaml


## File naming
sed -i 's@CRTMTABLES@'${CRTMTABLES}'@g' orig_jedi0.yaml
sed -i 's@InDBDir@'${InDBDir}'@g' orig_jedi0.yaml
sed -i 's@OutDBDir@'${OutDBDir}'@g' orig_jedi0.yaml
sed -i 's@obsPrefix@'${obsPrefix}'@g' orig_jedi0.yaml
sed -i 's@geoPrefix@'${geoPrefix}'@g' orig_jedi0.yaml
sed -i 's@diagPrefix@'${diagPrefix}'@g' orig_jedi0.yaml
sed -i 's@DAMode@'${self_DAMode}'@g' orig_jedi0.yaml

if ( "$self_DAType" =~ *"eda"* ) then
  sed -i 's@OOPSMemberDir@/%{member}%@g' orig_jedi0.yaml
  sed -i 's@nEnsDAMembers@'${nEnsDAMembers}'@g' orig_jedi0.yaml
else
  sed -i 's@OOPSMemberDir@@g' orig_jedi0.yaml
endif
sed -i 's@bgStatePrefix@'${self_bgStatePrefix}'@g' orig_jedi0.yaml
sed -i 's@bgStateDir@'${bgDir}'@g' orig_jedi0.yaml
sed -i 's@anStatePrefix@'${anStatePrefix}'@g' orig_jedi0.yaml
sed -i 's@anStateDir@'${anDir}'@g' orig_jedi0.yaml

# TODO(JJG): revise these date replacements to loop over
#            all relevant dates to this application (e.g., 4DEnVar?)
## revise previous date
sed -i 's@2018-04-14_18.00.00@'${prevFileDate}'@g' orig_jedi0.yaml
sed -i 's@2018041418@'${prevDate}'@g' orig_jedi0.yaml
sed -i 's@2018-04-14T18:00:00Z@'${prevConfDate}'@g'  orig_jedi0.yaml

## revise current date
sed -i 's@2018-04-15_00.00.00@'${FileDate}'@g' orig_jedi0.yaml
sed -i 's@2018041500@'${self_Date}'@g' orig_jedi0.yaml
sed -i 's@2018-04-15T00:00:00Z@'${ConfDate}'@g' orig_jedi0.yaml

## revise window length
sed -i 's@PT6H@PT'${self_WindowHR}'H@g' orig_jedi0.yaml

## revise full line configs
cat >! fulllineSEDF.yaml << EOF
  /window_begin: /c\
  window_begin: '${halfprevConfDate}'
EOF

sed -f fulllineSEDF.yaml orig_jedi0.yaml >! orig_jedi1.yaml
rm fulllineSEDF.yaml

if ( "$self_DAType" =~ *"eda"* ) then
  set topEnsBDir = ${FCCY_WORK_DIR}
  set ensBMemFmt = "${oopsMemFmt}"
  set nEnsBMembers = ${nEnsDAMembers}
else
  set topEnsBDir = ${fixedEnsembleB}
  set ensBMemFmt = "${fixedEnsMemFmt}"
  set nEnsBMembers = ${nFixedMembers}
endif

## fill in ensemble B config
# TODO(JJG): how does self_ ensemble config generation need to be
#            modified for 4DEnVar?
sed -i 's@bumpLocDir@'${bumpLocDir}'@g' orig_jedi1.yaml
sed -i 's@bumpLocPrefix@'${bumpLocPrefix}'@g' orig_jedi1.yaml

set ensbsed = EnsembleBMembers
cat >! ${ensbsed}SEDF.yaml << EOF
/${ensbsed}/c\
EOF

set member = 1
while ( $member <= ${nEnsBMembers} )
  set memDir = `${memberDir} ens $member "${ensBMemFmt}"`
  set adate = adate
  if ( $member < ${nEnsBMembers} ) then
     set adate = ${adate}\\
  endif
cat >>! ${ensbsed}SEDF.yaml << EOF
      - filename: ${topEnsBDir}/${prevDate}${memDir}/${FCFilePrefix}.${FileDate}.nc\
        date: *${adate}
EOF

  @ member++
end
sed -f ${ensbsed}SEDF.yaml orig_jedi1.yaml >! orig_jedi2.yaml
rm ${ensbsed}SEDF.yaml


## fill in model and analysis variable configs
set JEDIANVars = ( \
  temperature \
  spechum \
  uReconstructZonal \
  uReconstructMeridional \
  surface_pressure \
)

if ( $AnalyzeHydrometeors == 1 ) then
  foreach hydro ($MPASHydroVars)
    set JEDIANVars = ($JEDIANVars index_$hydro)
  end
endif

set analysissed = AnalysisVariables
set modelsed = ModelVariables
cat >! ${analysissed}SEDF.yaml << EOF
/${analysissed}/c\
EOF

cat >! ${modelsed}SEDF.yaml << EOF
/${modelsed}/c\
EOF

set ivar = 1
while ( $ivar <= ${#JEDIANVars} )
  set var = $JEDIANVars[$ivar]
  if ( $ivar < ${#JEDIANVars} ) then
     set var = ${var}\\
  endif
cat >>! ${analysissed}SEDF.yaml << EOF
      - $var
EOF

cat >>! ${modelsed}SEDF.yaml << EOF
  - $var
EOF

  @ ivar++
end
sed -f ${analysissed}SEDF.yaml orig_jedi2.yaml >! orig_jedi3.yaml
rm ${analysissed}SEDF.yaml
sed -f ${modelsed}SEDF.yaml orig_jedi3.yaml >! jedi.yaml
rm ${modelsed}SEDF.yaml


# Submit DA job script
# =================================
#TODO: move all job control to top-level cycling/workflow scripts
set JALL=(`cat ${JOBCONTROL}/last_${self_DependsOn}_job`)
set JDEP = ''
foreach J ($JALL)
  if (${J} != "$nulljob" ) then
    set JDEP = ${JDEP}:${J}
  endif
end
set JDA = `qsub -W depend=afterok${JDEP} ${self_DAJobScript}`

echo "${JDA}" > ${JOBCONTROL}/last_${self_DAMode}_job

# Submit VF job script
# =================================
if ( ${VERIFYAFTERDA} > 0 && ${self_VFJobScript} != "None" ) then
  set JVF = `qsub -W depend=afterok:$JDA ${self_VFJobScript}`
endif

exit
