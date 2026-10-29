#!/bin/bash

set -e

JOBID=$1
INPUTFILE=$2
OUTPUTDIR=$3

echo "===================================="
echo "JOBID     = ${JOBID}"
echo "INPUTFILE = ${INPUTFILE}"
echo "OUTPUTDIR = ${OUTPUTDIR}"
echo "HOSTNAME  = $(hostname)"
echo "DATE      = $(date)"
echo "===================================="

source /cvmfs/cms.cern.ch/cmsset_default.sh

export SCRAM_ARCH=el9_amd64_gcc13

CMSSW_BASE=/afs/cern.ch/work/s/sha/private/ServiceWork/JetMETTrigger/Phase_AK8JetSTudy/v2/CMSSW_16_1_0_pre4

cd ${CMSSW_BASE}/src
eval `scram runtime -sh`

echo "CMSSW_BASE=${CMSSW_BASE}"
echo "SCRAM_ARCH=${SCRAM_ARCH}"

WORKDIR=${_CONDOR_SCRATCH_DIR}/job_${JOBID}

mkdir -p ${WORKDIR}
cd ${WORKDIR}

echo "WORKDIR=${WORKDIR}"
echo "PWD=$(pwd)"

if [[ "${INPUTFILE}" == root://* || "${INPUTFILE}" == davs://* ]]; then
    INPUT_XRD="${INPUTFILE}"
else
    INPUT_XRD="root://cms-xrd-global.cern.ch//${INPUTFILE}"
fi

echo "INPUT_XRD=${INPUT_XRD}"

L1OUT="L1_output_${JOBID}.root"
OUTFILE="ntuple_${JOBID}.root"

echo "L1OUT=${L1OUT}"
echo "OUTFILE=${OUTFILE}"

echo "===================================="
echo "Step 1: Starting L1Only cmsRun"
echo "===================================="

cmsRun ${CMSSW_BASE}/src/JMETriggerAnalysis/NTuplizers/test/jmeTriggerNTuple_L1Only_cfg.py \
    inputFiles="${INPUT_XRD}" \
    output="${L1OUT}" \
    maxEvents=-1

L1_STATUS=$?

echo "===================================="
echo "L1Only cmsRun finished"
echo "Exit code = ${L1_STATUS}"
echo "===================================="

if [ ${L1_STATUS} -ne 0 ]; then
    echo "ERROR: L1Only cmsRun failed."
    exit ${L1_STATUS}
fi

if [ ! -f "${L1OUT}" ]; then
    echo "ERROR: L1 output file ${L1OUT} was not created."
    exit 1
fi

echo "Local L1 output:"
ls -lh "${L1OUT}"

echo "===================================="
echo "Step 2: Starting HLT + NTuplizer"
echo "===================================="

cmsRun ${CMSSW_BASE}/src/JMETriggerAnalysis/NTuplizers/test/jmeTriggerNTuple_cfg.py \
    inputFiles="file:${L1OUT}" \
    output="${OUTFILE}" \
    maxEvents=-1 \
    wantSummary=True

NTUPLE_STATUS=$?

echo "===================================="
echo "HLT + NTuplizer finished"
echo "Exit code = ${NTUPLE_STATUS}"
echo "===================================="

if [ ${NTUPLE_STATUS} -ne 0 ]; then
    echo "ERROR: HLT + NTuplizer failed."
    exit ${NTUPLE_STATUS}
fi

if [ ! -f "${OUTFILE}" ]; then
    echo "ERROR: NTuple output file ${OUTFILE} was not created."
    exit 1
fi

echo "Local NTuple output:"
ls -lh "${OUTFILE}"

mkdir -p "${OUTPUTDIR}"

echo "===================================="
echo "Copying NTuple output"
echo "===================================="

echo "Copying ${OUTFILE} to ${OUTPUTDIR}/ ..."

cp "${OUTFILE}" "${OUTPUTDIR}/"

COPY_STATUS=$?

if [ ${COPY_STATUS} -ne 0 ]; then
    echo "ERROR: failed to copy NTuple output."
    exit ${COPY_STATUS}
fi

echo "Copied output:"
ls -lh "${OUTPUTDIR}/${OUTFILE}"

rm -f "${OUTFILE}"
rm -f "${L1OUT}"

echo "===================================="
echo "JOB ${JOBID} FINISHED SUCCESSFULLY"
echo "===================================="

exit 0
