#!/usr/bin/env bash

set -e -o pipefail

DATASET="smartbugs-top-1000-balance"

if [[ -z "$BUILD_DIR" ]]; then
    BUILD_DIR="$(realpath -m "./builds/$DATASET")"
fi
if [[ -z "$FUZZING_REPETITIONS" ]]; then
    export FUZZING_REPETITIONS="1"
fi
if [[ -z "$FUZZING_TIME" ]]; then
    FUZZING_TIME="$(python -c 'print(45 * 60)')"
    export FUZZING_TIME
fi
echo "[+] setting default afl-fuzz timeout to $FUZZING_TIME sec with $FUZZING_REPETITIONS repetitions"

if [[ -z "$OUT_DIR" ]]; then
    OUT_DIR="$(realpath -m ./out/)"
fi

if [[ -z "$FUZZ_DIR" ]]; then
    FUZZ_DIR="/tmp/efcf-fuzz/"
fi

if [[ -z "$FUZZ_MODES" ]]; then
    FUZZ_MODES="2AT"
fi


source scripts/common.sh

set -u

mkdir -p "$FUZZ_DIR" || true
CONTRACTS_DIR="$(realpath "./data/$DATASET/")"
EVM_DIR="$(realpath ./src/eEVM/)"

# building is a separate step so the fuzzing launcher in the eEVM project
# should not attempt to rebuild the C++ project.
export FUZZ_LAUNCHER_DONT_REBUILD=1
#export AFL_BENCH_UNTIL_CRASH=1
export RUST_BACKTRACE=1
#export AFL_DEBUG=1
export SCRIPT_NAME="$0 $*"

echo "[+] starting up - searching for fuzzing jobs"

fuzz_all_builds \
    "$BUILD_DIR" \
    "$CONTRACTS_DIR" \
    "$OUT_DIR" \
    "$FUZZ_MODES" \
    "$FUZZING_REPETITIONS"
        
echo "[+] done - no more fuzzing jobs"
exit 0
