#!/usr/bin/env bash

set -e -o pipefail

if [[ -z "$BUILD_DIR" ]]; then
    BUILD_DIR="$(realpath -m ./builds/reentrancy/)"
fi
if [[ -z "$FUZZING_REPETITIONS" ]]; then
    export FUZZING_REPETITIONS="10"
fi
if [[ -z "$FUZZING_TIME" ]]; then
    FUZZING_TIME="$(python -c 'print(60 * 60 * 12)')"
    export FUZZING_TIME
fi
echo "[+] using afl-fuzz timeout to $FUZZING_TIME sec with $FUZZING_REPETITIONS repetitions"

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
CONTRACTS_DIR="$(realpath ./data/reentrancy/)"
EVM_DIR="$(realpath ./src/eEVM/)"
COV_SUMMARY=""

export AFL_BENCH_UNTIL_CRASH=1
export RUST_BACKTRACE=1
#export AFL_DEBUG=1
export SCRIPT_NAME="$0 $*"
this_command=""
trap 'LAST_COMMAND=$this_command; this_command=$BASH_COMMAND' DEBUG
function on_exit {
    c="$LAST_COMMAND" r="$?"
    s="[$SCRIPT_NAME] exited after $CUR_ITER fuzzing jobs ($c -> $r)"
    echo "$s"
}
function on_err {
    c="$LAST_COMMAND" r="$?"
    s="[$SCRIPT_NAME] errored after $CUR_ITER fuzzing jobs ($c -> $r)"
    echo "$s"
}
set -E
trap on_exit EXIT
trap on_err ERR

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
