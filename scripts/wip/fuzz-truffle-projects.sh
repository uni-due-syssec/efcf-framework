#!/usr/bin/env bash

set -eu -o pipefail
export RUST_BACKTRACE=1

SUDO=""
if command -v sudo >/dev/null; then
    SUDO=sudo
fi


OUT_DIR="$(realpath -m ./out/)"
CONTRACTS_DIR="$(realpath ./data/smartest_benchmark/leaking_suicidal/)"
EVM_DIR="$(realpath ./src/eEVM/)"

FUZZING_REPETITIONS="5"
FUZZING_TIME="$(python -c 'print(20 * 60)')"
echo "setting default afl-fuzz timeout to $FUZZING_TIME sec"

#export AFL_DEBUG=1
export SCRIPT_NAME="$0 $*"
export COV_SUMMARY=""
export CUR_ITER=0
this_command=""
trap 'LAST_COMMAND=$this_command; this_command=$BASH_COMMAND' DEBUG
function on_exit {
    c="$LAST_COMMAND" r="$?"
    s="[$SCRIPT_NAME] exited after $CUR_ITER runs ($c -> $r)"
    if command -v slack-notify; then
        slack-notify "$s"
    fi
    echo "$s"
}
function on_err {
    c="$LAST_COMMAND" r="$?"
    s="[$SCRIPT_NAME] errored after $CUR_ITER runs ($c -> $r)"
    if command -v slack-notify; then
        slack-notify "$s"
    fi
    echo "$s"
}
set -E
trap on_exit EXIT
trap on_err ERR

function print_and_run {
    echo "exec: $*"
    $@
    return $?
}

mkdir -p "$OUT_DIR" || true

for sol in $CONTRACTS_DIR/*.sol; do
    echo "--------------------------------------------------"
    contract_id="$(basename "$sol" | cut -d '.' -f 1)"

    tar xf "${contract_id}.tar.xz"

    # given only the solidity file it is basically not possible to select the
    # right contract, if there are more than one inside of the solidity file
    # (e.g., often libraries such as SafeMath or ERC20 are copy pasted into the
    # solidity source and emitted by the solc compiler).

    # Fortunately, the ilf-preprocessed directories contain this information,
    # which we can grep for in the truffle/ganache/whatever deploy javascript
    # file.

    # additionally we parse the truffle build output

    deploy_js="$CONTRACTS_DIR/$contract_id/migrations/2_deploy.js"
    deploy_js=$(realpath "$deploy_js")
    contract_name="$(grep -Eo 'artifacts.require\("(.+)"\)' < "$deploy_js" | cut -f 2 -d '"')"
    contract_json="$CONTRACTS_DIR/$contract_id/build/contracts/$contract_name.json"
    processed_contract_json="$CONTRACTS_DIR/$contract_id/build/contracts/$contract_name.preprocessed.json"
    constructor_file="$CONTRACTS_DIR/$contract_id/create_tx_input.bin.evm"
    transactions_json="$CONTRACTS_DIR/$contract_id/transactions.json"

    # very annoying; the truffle json apparently stores the ABI as JSON, while
    # solidity outputs a string (which is actually json)... so we preprocess it
    # with python a bit... this is why we can't have nice things :(
    python > "$processed_contract_json" <<EOF
import json
with open("$contract_json") as f:
    data = json.load(f)

p = {
    "bin-runtime": data['deployedBytecode'],
    "bin": data['bytecode'],
    "abi": json.dumps(data['abi']),
}
print(json.dumps(p))
EOF

    # second annoying step: we need to parse out the create transaction input
    # to get the constructor arguments...
    python <<EOF
import json
with open("$transactions_json") as f:
    for line in f.readlines()[::-1]:
        tx = json.loads(line)
        assert 'to' in tx and 'input' in tx
        if tx['to'] == None and tx['input']:
            inp = tx['input']
            if inp.startswith("0x"):
                inp = inp[2:]
            inp = bytes.fromhex(inp)
            with open("$constructor_file", "wb") as fb:
                fb.write(inp)
                break
EOF

    # we use the pre-built bytecode, s.t., we do not have to deal with solidity
    # versions.

    #echo "[+] Compiling solidity file $sol and looking for $contract_name";
    #pushd "$CONTRACTS_DIR" >/dev/null
    #make "$contract_id.combined.json" || true
    #popd >/dev/null
    
    export TIMESTAMP="$(date +%Y-%m-%dT%H-%M-%S)"
    export OUT_PREFIX="$OUT_DIR/$contract_id.$TIMESTAMP"
    export OUT_PREFIX="$(realpath -m "$OUT_PREFIX")"

    echo "[+] running evm2cpp"
    
    print_and_run /usr/bin/time -v -o "$OUT_PREFIX.translate.time" \
        evm2cpp \
        --evm-path="$EVM_DIR" \
        --contract-name="$contract_name" \
        --single-combined-json \
        "$contract_id" "$processed_contract_json";
    

    echo "[+] Building contract $contract_id"
    pushd "$EVM_DIR" >/dev/null

    
    if print_and_run /usr/bin/time -v -o "$OUT_PREFIX.build.time" \
        ./quick-build.sh afuzz "$contract_id" \
        | tee "$OUT_PREFIX.build.log"; 
    then
        
        true
    else
        
        echo "[WARNING] Build seems to have failed for $contract_id!"
        echo "failure" > "$OUT_PREFIX.fuzz.status"

        if command -v slack-notify; then
            slack-notify "[$SCRIPT_NAME] WARNING: build for $contract_id failed!"
        fi

        echo "skipping contract $contract_id"
        continue
    fi

    echo "[+] contract $CUR_ITER launching fuzzer ($FUZZING_REPETITIONS repetitions)"
   
    export EVM_CREATE_TX_INPUT="$(realpath "$constructor_file")"
    test -e "$EVM_CREATE_TX_INPUT"

    for i in $(seq "$FUZZING_REPETITIONS"); do

        RUN_PREFIX="$OUT_PREFIX.$i"

        if print_and_run /usr/bin/time -v -o "$RUN_PREFIX.fuzz.time" \
            ./fuzz/launch-aflfuzz.sh "$contract_id" "$FUZZING_TIME" "$i" \
            | tee "$RUN_PREFIX.fuzz.log"; 
        then
            echo "success" > "$RUN_PREFIX.fuzz.status"
            
            # save some fuzzer stats/results in plaintext
            if pushd ./fuzz/out/${contract_id}_*_$i > /dev/null; then
                grep -E '(execs_done|execs_per_sec|unique)' \
                    < "./default/fuzzer_stats" \
                    | tee "$RUN_PREFIX.fuzz.results"
                echo "evm-coverage: $(cat "./coverage-percent-all.evmcov")" \
                    | tee -a "$RUN_PREFIX.fuzz.results"
                grep -E 'unique' < ./crashes_tx_summary \
                    | tee -a "$RUN_PREFIX.fuzz.results"

                export COV_SUMMARY="$COV_SUMMARY\n $contract_id => $(cat "./coverage-percent-all.evmcov") % cov; $(grep -E 'unique' < ./crashes_tx_summary | head -n 1) crashing tx sequences deduped"

                popd >/dev/null
            else
                echo "failed to pushd into "
                echo ./fuzz/out/${contract_id}_*_$i
            fi
        else
            echo "[WARNING] Fuzzer seems to have failed!"
            echo "failure" > "$RUN_PREFIX.fuzz.status"

            if command -v slack-notify; then
                slack-notify "[$SCRIPT_NAME] WARNING: fuzzing run for $contract_id ($i / $FUZZING_REPETITIONS) failed!"
            fi
        fi
    done

    echo "[+] build/fuzz results backup"
    
    print_and_run rm ./fuzz/out/*/build
    time print_and_run tar --exclude="fuzz/out/" -hcJf "$OUT_PREFIX.build.tar.xz" .
    time print_and_run tar -hcJf "$OUT_PREFIX.fuzz.tar.xz" ./fuzz/out/*

    echo "[+] resetting eEVM repo"
    
    print_and_run $SUDO umount ./fuzz/out/* || true
    print_and_run git reset --hard
    print_and_run rm -rf contracts include fuzz/out fuzz/build
    print_and_run git checkout .
    

    popd >/dev/null
    echo "[+] done"
    printf "[+] current summary:\n${COV_SUMMARY}\n"

    export CUR_ITER=$(( $CUR_ITER + 1 ))
done

if command -v slack-notify; then
    slack-notify "[$SCRIPT_NAME] done with all fuzz targets! results: $COV_SUMMARY"
fi
