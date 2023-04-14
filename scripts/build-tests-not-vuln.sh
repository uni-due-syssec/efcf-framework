#!/usr/bin/env bash

set -e -o pipefail

if [[ -z "$BUILD_DIR" ]]; then
    BUILD_DIR="$(realpath -m ./builds/tests-not-vuln/)"
fi
if [[ -z "$CONTRACTS_DIR" ]]; then 
    CONTRACTS_DIR="$(realpath ./data/tests-not-vuln//)"
fi
if [[ -z "$EVM_DIR" ]]; then 
    EVM_DIR="$(realpath ./src/eEVM/)"
fi

source scripts/common.sh

set -u

mkdir -p "$BUILD_DIR" || true

echo "[+] Compiling all solidity files"
pushd "$CONTRACTS_DIR" >/dev/null
make clean
make
popd >/dev/null

SUCCESS=0
ATTEMPTS=0
for contract in $CONTRACTS_DIR/*.combined.json; do

    reset_evm_repo

    echo "--------------------------------------------------"
    contract_id="$(basename "$contract" | cut -d '.' -f 1)"

    OUT_PREFIX="$BUILD_DIR/$contract_id"
    OUT_PREFIX="$(realpath -m "$OUT_PREFIX")"

    if test -e "$OUT_PREFIX.build.tar.xz"; then
        echo "[+] already built!"
        continue
    fi

    echo "[+] running evm2cpp"

    pushd "$CONTRACTS_DIR" >/dev/null

    if print_and_run /usr/bin/time -v -o "$OUT_PREFIX.translate.time" \
        evm2cpp \
        --evm-path="$EVM_DIR" \
        "$contract_id" \
        "$contract" 2>&1 \
        | tee "$OUT_PREFIX.build.log";
    then
        echo "1" >"$OUT_PREFIX.build.status"
    else

        echo "[WARNING] evm2cpp seems to have failed for $contract_id!"
        echo "0" >"$OUT_PREFIX.build.status"

        echo "skipping contract $contract_id"
        continue
    fi
    popd >/dev/null

    echo "[+] Building contract $contract_id"

    pushd "$EVM_DIR" >/dev/null

    if print_and_run /usr/bin/time -v -o "$OUT_PREFIX.build.time" \
        ./quick-build.sh afuzz "$contract_id" \
        | tee -a "$OUT_PREFIX.build.log";
    then

        echo "1" >"$OUT_PREFIX.build.status"
        SUCCESS=$(($SUCCESS + 1))
    else

        echo "[WARNING] Build seems to have failed for $contract_id!"
        echo "0" >"$OUT_PREFIX.build.status"

        echo "skipping contract $contract_id"
        continue
    fi

    echo "[+] creating build tarball"
    timed_print_and_run tar --exclude=".git" --exclude=".ccache" -hcf "$OUT_PREFIX.build.tar" .
    timed_print_and_run xz -3 -T 0 "$OUT_PREFIX.build.tar"

    popd >/dev/null # EVM_DIR

    echo "[+] $contract_id done"
    ATTEMPTS=$(($ATTEMPTS + 1))
done

echo "[+] $SUCCESS successful builds of $ATTEMPTS attempted builds"
