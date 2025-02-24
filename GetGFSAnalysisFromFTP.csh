#!/bin/csh -f
# Get GFS analysis (0-h forecast) for cold start initial conditions

# Process arguments
# =================
## args
# ArgDT: int, valid time offset beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$1"

set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

date

# Setup environment
# =================
source config/builds.csh
source config/experiment.csh
#source config/externalanalyses.csh
source config/tools.csh
set ccyymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${ccyymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`

source ./getCycleVars.csh

set ccyymmdd = `echo ${thisValidDate} | cut -c 1-8`
set hh = `echo ${thisValidDate} | cut -c 9-10`

set res = 0p25
set fhour = 000
# url for GFS data
set gfs_ftp = https://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod/gfs.${ccyymmdd}/${hh}/atmos
set gribFile = gfs.t${hh}z.pgrb2.${res}.f${fhour}

# static work directory
set WorkDir = ${ExternalAnalysisDir}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

set linkWPS = link_grib.csh
ln -sfv ${WPSBuildDir}/${linkWPS} .
rm -rf GRIBFILE.*

echo "Getting GFS analysis from the NCEP FTP"
# check if the GFS analysis is available
if ( ! -e ${gribFile}) then
  set gfs_ftp_file = ${gfs_ftp}/${gribFile}
  wget -S --spider $gfs_ftp_file >&! log_check_gfs_f000
  grep "HTTP/1.1 200 OK" log_check_gfs_f000
  # if the file exists then download it
  # otherwise, exit with failure
  if ( $status == 0 ) then
    echo "Downloading $gfs_ftp_file ..."
    wget -r -np -nd $gfs_ftp_file
  else
    echo "$gribFile not available yet -- exiting"
    exit 1
  endif
endif
# link ungribbed GFS
./${linkWPS} $gribFile

date

exit 0
