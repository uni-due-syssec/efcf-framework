#!/usr/bin/env bash

set -e -o pipefail

source scripts/common.sh

set -u

DATASET="smartbugs-top-1000-balance"
BUILD_DIR="$(realpath -m "./builds/$DATASET/")"
CONTRACTS_DIR="$(realpath "./data/$DATASET/")"
EVM_DIR="$(realpath ./src/eEVM/)"

mkdir -p "$BUILD_DIR" || true

reset_evm_repo
setup_evm_build_cache "$BUILD_DIR"
echo "[+] using evm build cache $EVM_CACHE"

for sol in $CONTRACTS_DIR/*.sol; do

    echo "--------------------------------------------------"
    contract_id="$(basename "$sol" | cut -d '.' -f 1)"
    meta_json="${contract_id}.meta.json"
    constructor_file="${contract_id}.create-args"
    solc_version_file="${contract_id}.solc-version"

    OUT_PREFIX="$BUILD_DIR/$contract_id"
    OUT_PREFIX="$(realpath -m "$OUT_PREFIX")"
    export OUT_PREFIX

    if test -e "$OUT_PREFIX.build.tar.xz"; then
        echo "[+] $contract_id already built!"
        continue
    fi
    # we create the file to signal parallel build jobs that this is already
    # built
    touch "$OUT_PREFIX.build.tar.xz"
    # set up a trap in case anything goes wrong...
    trap "rm -f \"$OUT_PREFIX.build.tar.xz\"" EXIT SIGTERM SIGINT

    pushd "$CONTRACTS_DIR" >/dev/null

    echo "[+] preprocessing data"

    if ! test -e "$meta_json"; then
        xz --keep -d "${meta_json}.xz"
    fi

    python <<EOF
import json
with open("$meta_json") as f:
    meta = json.load(f)

    inp = meta[0]['ConstructorArguments']
    if inp.startswith("0x"):
        inp = inp[2:]
    with open("$constructor_file.bin", "w") as fx:
        fx.write(inp)
    inp = bytes.fromhex(inp)
    with open("$constructor_file", "wb") as fb:
        fb.write(inp)

    with open("$solc_version_file", "w") as f:
        x = meta[0]["CompilerVersion"]
        if x[0] == "v":
            x = x[1:]
        if "+" in x:
            x = x.split("+")[0]
        if "-" in x:
            x = x.split("-")[0]
        f.write(x)
EOF

    contract_name="$(cat "$meta_json" | jq -r '.[0]["ContractName"]')"

    echo "[+] Compiling solidity file $sol and looking for $contract_name" | tee "$OUT_PREFIX.build.log"
    if make \
        "$contract_id.combined.json" \
        SOLC_VERSION="$(cat "$solc_version_file")" \
        | tee -a "$OUT_PREFIX.build.log";
    then
        echo "1" > "$OUT_PREFIX.build.status"
    else
        echo "[WARNING] make/solc failed for $contract_id!"
        echo "0" > "$OUT_PREFIX.build.status"
        echo "solc" >> "$OUT_PREFIX.build.status"

        echo "=> skipping contract $contract_id"
        continue

    fi
    test -e "$contract_id.combined.json"

    if [[ -d "$EVM_CACHE" ]]; then
        cp -r --reflink=auto "$EVM_CACHE" "$OUT_PREFIX.dir"
        CUR_EVM_DIR="$OUT_PREFIX.dir"
    else
        reset_evm_repo
        CUR_EVM_DIR="$EVM_DIR"
    fi

    echo "[+] running evm2cpp" | tee -a "$OUT_PREFIX.build.log"

    if print_and_run /usr/bin/time -v -o "$OUT_PREFIX.translate.time" \
        evm2cpp \
        --evm-path="$CUR_EVM_DIR" \
        --contract-name="$contract_name" \
        --combined-json \
        "$contract_id" \
        "$CONTRACTS_DIR/$contract_id.combined.json" \
        | tee -a "$OUT_PREFIX.build.log";
    then
        echo "1" > "$OUT_PREFIX.build.status"
    else

        echo "[WARNING] evm2cpp translation seems to have failed for $contract_id!"
        echo "0" > "$OUT_PREFIX.build.status"
        echo "evm2cpp" >> "$OUT_PREFIX.build.status"

        echo "=> skipping contract $contract_id"
        continue
    fi
   
    # this is something we need!
    cp "$contract_id.create-args" "$CUR_EVM_DIR/contracts/"
    # these are somewhat useful for later analysis
    cp "$contract_id.combined.json" "$CUR_EVM_DIR/contracts/" || true
    cp "$contract_id.sol" "$CUR_EVM_DIR/contracts/" || true
   
    popd >/dev/null # $CONTRACTS_DIR

    echo "[+] Building EVM for contract $contract_id" | tee -a "$OUT_PREFIX.build.log"
    pushd "$CUR_EVM_DIR" >/dev/null

    if print_and_run /usr/bin/time -v -o "$OUT_PREFIX.build.time" \
        ./quick-build.sh afuzz "$contract_id" \
        | tee -a "$OUT_PREFIX.build.log";
    then
        echo "1" > "$OUT_PREFIX.build.status"
    else

        echo "[WARNING] Build seems to have failed for $contract_id!"
        echo "0" > "$OUT_PREFIX.build.status"
        echo "eevm" >> "$OUT_PREFIX.build.status"

        rm "$OUT_PREFIX.build.tar.xz"

        echo "skipping contract $contract_id"
        continue
    fi

    echo "[+] making build tarball"
    timed_print_and_run tar --exclude=".git" --exclude=".ccache" -hcf "$OUT_PREFIX.build.tar" .
    timed_print_and_run xz -f -3 -T 0 "$OUT_PREFIX.build.tar"

    if [[ -d "$EVM_CACHE" ]]; then
        rm -rf "$OUT_PREFIX.dir"
    fi

    popd >/dev/null # CUR_EVM_DIR
    echo "[+] build of $contract_id done"
    # override trap s.t., the build file is not removed
    trap "true;" EXIT SIGTERM SIGINT
done
