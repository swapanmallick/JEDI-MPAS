#!/bin/csh
#PBS -N vfCDATE_EXPNAME
#PBS -A ACCOUNTNUM
#PBS -q QUEUENAME
#PBS -l select=1:ncpus=18:mpiprocs=18
#PBS -l walltime=0:15:00
#PBS -m ae
#PBS -k eod
#PBS -o vf.log.job.out 
#PBS -e vf.log.job.err

date

#
# Setup environment:
# ================
source ./setup.csh

module load python/3.7.5

setenv DATE CDATE
#
# Time info:
# ==========
set yy = `echo ${DATE} | cut -c 1-4`
set mm = `echo ${DATE} | cut -c 5-6`
set dd = `echo ${DATE} | cut -c 7-8`
set hh = `echo ${DATE} | cut -c 9-10`

set FILE_DATE  = ${yy}-${mm}-${dd}_${hh}.00.00


#
# collect obs-space diagnostic statistics into DB files:
# ======================================================
mkdir -p diagnostic_stats/obs
cd diagnostic_stats/obs

set mainScript="writediagstats_obsspace.py"
ln -fs ${pyObsDir}/*.py ./
ln -fs ${pyObsDir}/${mainScript} ./
set NUMPROC=`cat $PBS_NODEFILE | wc -l`

setenv success 1
while ( $success != 0 )
  mv diags.log diags.log_LAST

  ## MULTIPLE PROCESSORS
  python ${mainScript} -n ${NUMPROC} -p ../../${OutDBDir} -o ${obsPrefix} -g ${geoPrefix} -d ${diagPrefix} >& diags.log

  setenv success $?

  if ( $success != 0 ) then
    source /glade/u/apps/ch/opt/usr/bin/npl/ncar_pylib.csh
    sleep 3
  endif
end
cd -

date


#
# collect model-space diagnostic statistics into DB files:
# ========================================================
mkdir -p diagnostic_stats/model
cd diagnostic_stats/model
ln -sf ../${BG_FILE_PREFIX}.${FILE_DATE}.nc ../

set mainScript="writediag_modelspace.py"
ln -fs ${pyModelDir}/*.py ./
ln -fs ${pyModelDir}/${mainScript} ./

python ${mainScript} >& diags.log
cd -

date

exit
