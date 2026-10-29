#!/bin/bash

set -euo pipefail

usage() {
    echo
    echo "Usage:"
    echo "  $0 INPUT_DIR INPUT_LIST [OUTPUT_FILE]"
    echo
    echo "Examples:"
    echo "  $0 \\"
    echo "    /eos/.../QCD/output \\"
    echo "    input/input_QCD.txt"
    echo
    echo "  $0 \\"
    echo "    /eos/.../QCD/output \\"
    echo "    input/input_QCD.txt \\"
    echo "    /eos/.../QCD/ntuple_QCD_merged.root"
    echo
}

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    usage
    exit 1
fi

INPUT_DIR=$1
INPUT_LIST=$2
OUTPUT_FILE=${3:-"${INPUT_DIR}/ntuple_merged.root"}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CHECK_SCRIPT="${SCRIPT_DIR}/check_ak8_jobs.py"

echo "============================================================"
echo "AK8 NTUPLE MERGE"
echo "============================================================"
echo "Input directory : ${INPUT_DIR}"
echo "Input list      : ${INPUT_LIST}"
echo "Output file     : ${OUTPUT_FILE}"
echo

if [ ! -d "${INPUT_DIR}" ]; then
    echo "ERROR: input directory does not exist:"
    echo "  ${INPUT_DIR}"
    exit 1
fi

if [ ! -f "${INPUT_LIST}" ]; then
    echo "ERROR: input list does not exist:"
    echo "  ${INPUT_LIST}"
    exit 1
fi

if [ ! -f "${CHECK_SCRIPT}" ]; then
    echo "ERROR: check script not found:"
    echo "  ${CHECK_SCRIPT}"
    exit 1
fi

EXPECTED_FILES=$(
    awk '
        NF && $1 !~ /^#/ {
            count++
        }
        END {
            print count + 0
        }
    ' "${INPUT_LIST}"
)

if [ "${EXPECTED_FILES}" -eq 0 ]; then
    echo "ERROR: no valid entries found in input list."
    exit 1
fi

echo "Expected files  : ${EXPECTED_FILES}"
echo

echo "Running output validation..."
echo

python3 "${CHECK_SCRIPT}" \
    --output-dir "${INPUT_DIR}" \
    --input-list "${INPUT_LIST}"

echo
echo "Validation passed."
echo

shopt -s nullglob
INPUT_FILES=("${INPUT_DIR}"/ntuple_[0-9]*.root)
shopt -u nullglob

NFILES=${#INPUT_FILES[@]}

echo "Number of input files found: ${NFILES}"

if [ "${NFILES}" -ne "${EXPECTED_FILES}" ]; then
    echo "ERROR: expected ${EXPECTED_FILES} files, but found ${NFILES}."
    exit 1
fi

if [ -e "${OUTPUT_FILE}" ]; then
    echo "ERROR: output file already exists:"
    echo "  ${OUTPUT_FILE}"
    echo
    echo "Remove it first or provide a different output filename."
    exit 1
fi

OUTPUT_DIR=$(dirname "${OUTPUT_FILE}")
mkdir -p "${OUTPUT_DIR}"

echo
echo "Starting hadd..."
echo

hadd -f -k -j 8 "${OUTPUT_FILE}" "${INPUT_FILES[@]}"

echo
echo "Checking merged ROOT file..."

python3 - "${OUTPUT_FILE}" <<'PY'
import sys
import ROOT

path = sys.argv[1]

root_file = ROOT.TFile.Open(path)

if not root_file:
    print(f"ERROR: failed to open merged file: {path}")
    sys.exit(1)

if root_file.IsZombie():
    print(f"ERROR: merged file is a zombie: {path}")
    root_file.Close()
    sys.exit(1)

if root_file.GetNkeys() == 0:
    print(f"ERROR: merged file contains no ROOT keys: {path}")
    root_file.Close()
    sys.exit(1)

print(f"Merged ROOT file is valid: {path}")
root_file.Close()
PY

echo
echo "============================================================"
echo "Merge finished successfully"
echo "============================================================"
ls -lh "${OUTPUT_FILE}"
