#!/bin/bash

set -euo pipefail

usage() {
    echo
    echo "Usage:"
    echo "  $0 STUDYNAME SAMPLENAME INPUT_LIST OUTPUT_DIR"
    echo "  $0 STUDYNAME SAMPLENAME INPUT_LIST OUTPUT_DIR --resubmit JOB_IDS"
    echo
    echo "Examples:"
    echo "  $0 BoostedHiggs XtoHH_MX500to1000 \\"
    echo "     input/input_XtoHH_MX500to1000.txt \\"
    echo "     /eos/.../XtoHH_MX500to1000/output"
    echo
    echo "  $0 BoostedHiggs XtoHH_MX500to1000 \\"
    echo "     input/input_XtoHH_MX500to1000.txt \\"
    echo "     /eos/.../XtoHH_MX500to1000/output \\"
    echo "     --resubmit 12,38,57"
    echo
}

if [ $# -ne 4 ] && [ $# -ne 6 ]; then
    usage
    exit 1
fi

STUDYNAME=$1
SAMPLENAME=$2
INPUTLIST=$3
OUTPUTDIR=$4

RESUBMIT_IDS=""

if [ $# -eq 6 ]; then
    if [ "$5" != "--resubmit" ]; then
        echo "ERROR: Unknown option: $5"
        usage
        exit 1
    fi

    RESUBMIT_IDS=$6
fi

if [ ! -f "${INPUTLIST}" ]; then
    echo "ERROR: Input list not found:"
    echo "  ${INPUTLIST}"
    exit 1
fi

# ------------------------------------------------------------
# Directory setup
# ------------------------------------------------------------

LOGDIR="logs/${STUDYNAME}/${SAMPLENAME}"

mkdir -p "${LOGDIR}/out"
mkdir -p "${LOGDIR}/err"
mkdir -p "${LOGDIR}/log"

mkdir -p "${OUTPUTDIR}"

# ------------------------------------------------------------
# Count valid input files
# ------------------------------------------------------------

NFILES=$(
    awk '
        NF && $1 !~ /^#/ {
            count++
        }
        END {
            print count + 0
        }
    ' "${INPUTLIST}"
)

if [ "${NFILES}" -eq 0 ]; then
    echo "ERROR: No valid input files found in:"
    echo "  ${INPUTLIST}"
    exit 1
fi

# ------------------------------------------------------------
# Submission record directory
# ------------------------------------------------------------

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

RECORDDIR="submit_records/${STUDYNAME}/${SAMPLENAME}/submit_${TIMESTAMP}"

mkdir -p "${RECORDDIR}"

QUEUEFILE="${RECORDDIR}/queue.txt"
ALL_QUEUEFILE="${RECORDDIR}/queue_all.txt"
SUBMISSION_INFO="${RECORDDIR}/submission.txt"

# ------------------------------------------------------------
# Build full queue
#
# Format:
#   jobid inputfile
#
# jobid corresponds to the ordering in the original input list.
# ------------------------------------------------------------

awk '
    BEGIN {
        jobid = 0
    }

    NF && $1 !~ /^#/ {
        print jobid, $0
        jobid++
    }
' "${INPUTLIST}" > "${ALL_QUEUEFILE}"

# ------------------------------------------------------------
# Full submission or resubmission
# ------------------------------------------------------------

if [ -n "${RESUBMIT_IDS}" ]; then

    REQUESTED_IDS="${RECORDDIR}/requested_job_ids.txt"

    echo "${RESUBMIT_IDS}" \
        | tr ',' '\n' \
        | sed '/^[[:space:]]*$/d' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        > "${REQUESTED_IDS}"

    # Validate requested job IDs
    while read -r JOBID; do

        if ! [[ "${JOBID}" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Invalid job ID:"
            echo "  ${JOBID}"
            exit 1
        fi

        if [ "${JOBID}" -ge "${NFILES}" ]; then
            echo "ERROR: Job ID ${JOBID} is outside valid range."
            echo "Valid range: 0-$((NFILES - 1))"
            exit 1
        fi

    done < "${REQUESTED_IDS}"

    # Select requested job IDs while preserving original IDs
    awk '
        NR == FNR {
            requested[$1] = 1
            next
        }

        $1 in requested {
            print
        }
    ' "${REQUESTED_IDS}" \
      "${ALL_QUEUEFILE}" \
      > "${QUEUEFILE}"

    MODE="resubmit"

else

    cp "${ALL_QUEUEFILE}" "${QUEUEFILE}"

    MODE="full submission"
fi

NJOBS=$(wc -l < "${QUEUEFILE}")

if [ "${NJOBS}" -eq 0 ]; then
    echo "ERROR: No jobs selected for submission."
    exit 1
fi

# ------------------------------------------------------------
# Save submission information
# ------------------------------------------------------------

cat > "${SUBMISSION_INFO}" <<EOF
Submission time : $(date)
Mode            : ${MODE}

Study name      : ${STUDYNAME}
Sample name     : ${SAMPLENAME}

Input list      : $(readlink -f "${INPUTLIST}")
Output directory: ${OUTPUTDIR}
Log directory   : $(readlink -f "${LOGDIR}")

Total inputs    : ${NFILES}
Submitted jobs  : ${NJOBS}
Resubmit IDs    : ${RESUBMIT_IDS:-none}

Queue file      : $(readlink -f "${QUEUEFILE}")
EOF

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo "============================================================"
echo "AK8 NTUPLE CONDOR SUBMISSION"
echo "============================================================"
echo "Study           : ${STUDYNAME}"
echo "Sample          : ${SAMPLENAME}"
echo "Mode            : ${MODE}"
echo
echo "Input list      : ${INPUTLIST}"
echo "Output directory: ${OUTPUTDIR}"
echo "Log directory   : ${LOGDIR}"
echo
echo "Total inputs    : ${NFILES}"
echo "Submitted jobs  : ${NJOBS}"

if [ -n "${RESUBMIT_IDS}" ]; then
    echo "Resubmit IDs    : ${RESUBMIT_IDS}"
fi

echo
echo "Submission record:"
echo "  ${RECORDDIR}"
echo
echo "============================================================"

# ------------------------------------------------------------
# Submit
# ------------------------------------------------------------

condor_submit \
    QUEUEFILE="$(readlink -f "${QUEUEFILE}")" \
    OUTPUTDIR="${OUTPUTDIR}" \
    LOGDIR="$(readlink -f "${LOGDIR}")" \
    submit_template.sub \
    | tee "${RECORDDIR}/condor_submit.log"

echo
echo "============================================================"
echo "Submission finished"
echo "============================================================"
echo
echo "Submission record saved in:"
echo "  ${RECORDDIR}"
