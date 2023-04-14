#!/usr/bin/env bash

set -e -o pipefail

if [[ -z "$BUILD_DIR" ]]; then
    BUILD_DIR="$(realpath -m ./builds/throughput)"
fi
if [[ -z "$FUZZING_REPETITIONS" ]]; then
    export FUZZING_REPETITIONS="20"
fi
if [[ -z "$FUZZING_TIME" ]]; then
    FUZZING_TIME="$(python -c 'print(60 * 10)')"
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
    FUZZ_MODES="2AT interp monly aonly"
fi


source scripts/common.sh

set -u

mkdir -p "$FUZZ_DIR" || true
CONTRACTS_DIR="$(realpath ./data/throughput/)"
EVM_DIR="$(realpath ./src/eEVM/)"
COV_SUMMARY=""

export AFL_BENCH_UNTIL_CRASH=1
export RUST_BACKTRACE=1
#export AFL_DEBUG=1

echo "[+] starting up - searching for fuzzing jobs"

echo " -> fuzz_all_builds"

fuzz_all_builds \
    "$BUILD_DIR" \
    "$CONTRACTS_DIR" \
    "$OUT_DIR" \
    "$FUZZ_MODES" \
    "$FUZZING_REPETITIONS"
        
echo "[+] done - no more fuzzing jobs"

exit 0
