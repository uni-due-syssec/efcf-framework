#!/usr/bin/env bash

SUDO=""
if command -v sudo >/dev/null; then
    SUDO=sudo
fi

export CUR_ITER=0
export RUST_BACKTRACE=1
export FUZZER=afuzz
EVM_CACHE=""

function print_and_run {
    echo "exec: $*"
    $@
    return $?
}


function timed_print_and_run {
    echo "exec: $*"
    time $@
    return $?
}

function reset_evm_repo {
    echo "[+] resetting eEVM repo"

    pushd "$EVM_DIR" >/dev/null
    print_and_run $SUDO umount ./fuzz/out/* || true

    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo "=> restoring from git"
        print_and_run git reset --hard
        print_and_run rm -rf contracts include
        print_and_run rm -rf fuzz/build/*
        print_and_run rm -rf fuzz/out/*
        print_and_run git checkout .
        print_and_run rm -rf contracts/*
    else
        tarball="$EVM_DIR/../eEVM.orig.tar.xz"
        if [[ -e "$tarball" ]]; then
            echo "=> restoring from tarball"
            rm -rf ./*
            tar --strip-components=1 "$tarball"
        fi
    fi
    popd >/dev/null
}


function setup_evm_build_cache {
    target_dir="$(mktemp -du -p "$(realpath "$1")" .evm_build_cache.XXXXXX)"
    test -e "$target_dir" && { rm -rf "$target_dir" || true; }
    pushd "$EVM_DIR" >/dev/null
    popd >/dev/null
    cp -r --reflink=auto "$EVM_DIR" "$target_dir"
    export EVM_CACHE="$target_dir"
}


function remove_lock_on_abnormal_exit {
    lockfile="$1"
    if [[ "$(head -n 1 "$lockfile")" == "running" ]]; then
        echo "[WARNING] detected unfinished fuzzing run for $lockfile" >&2
        rm "$lockfile"
    fi
}

function afl_whatsup {
    # based on the summary mode of afl-whatsup by Michael Zalewski \
    # (see https://github.com/AFLplusplus/AFLplusplus/blob/stable/afl-whatsup)
    TOTAL_TIME=0
    TOTAL_EPS=0
    TOTAL_EXECS=0
    TOTAL_CRASHES=0
    TOTAL_HANGS=0
    RUN_UNIX=0
    fuzzers=0
    AVG_EPS=0

    for i in $(find . -maxdepth 2 -iname fuzzer_stats | sort); do
        fuzzers=$((fuzzers + 1))

        # OMG this is a dirty hack. but ok. thanks mr Zalewski for cursed
        # parser.
        TMP=`mktemp -t .afl-whatsup-XXXXXXXX` || exit 1
        sed 's/^command_line.*$/_skip:1/;s/[ ]*:[ ]*/="/;s/$/"/' "$i" >"$TMP"
        source "$TMP"
        rm -f "$TMP"

        RUN_UNIX="$run_time"
        EXEC_SEC=0
        test -z "$RUN_UNIX" -o "$RUN_UNIX" = 0 || EXEC_SEC=$((execs_done / RUN_UNIX))

        TOTAL_TIME=$((TOTAL_TIME + RUN_UNIX))
        TOTAL_EPS=$((TOTAL_EPS + EXEC_SEC))
        TOTAL_EXECS=$((TOTAL_EXECS + execs_done))
        TOTAL_CRASHES=$((TOTAL_CRASHES + saved_crashes))
        TOTAL_HANGS=$((TOTAL_HANGS + saved_hangs))
    done

    test "$fuzzers" -eq 0 || AVG_EPS=$((TOTAL_EPS / fuzzers))

    echo "time : $RUN_UNIX"
    echo "total_time : $TOTAL_TIME"
    echo "total_execs_done : $TOTAL_EXECS"
    echo "cumulative_execs_per_sec : $TOTAL_EPS"
    echo "average_execs_per_sec : $AVG_EPS"
    echo "total_crashes : $TOTAL_CRASHES"
    echo "total_hangs : $TOTAL_HANGS"
}


function fuzz_all_builds {

    BUILD_DIR="$1"
    CONTRACTS_DIR="$2"
    OUT_DIR="$3"
    FUZZ_MODES="$4"
    FUZZING_REPETITIONS="$5"

    COV_SUMMARY=""

    # avoid rebuilding/relinking the target project
    export FUZZ_LAUNCHER_DONT_REBUILD=1

    fuzzed=0

    finished=0
    while [[ "$finished" -ne 1 ]]; do
        finished=1

        echo "[+] processed $fuzzed fuzz jobs"

        for contract in $BUILD_DIR/*.build.status; do
            contract_id="$(basename "$contract" | cut -d '.' -f 1)"
            if [[ "$(cat "$contract")" -ne 1 ]]; then 
                echo "[WARNING] contract status file $contract indicates broken build"
                echo "...skipping contract $contract_id"
                continue
            fi

            export OUT_PREFIX="$OUT_DIR/$contract_id"
            export OUT_PREFIX="$(realpath -m "$OUT_PREFIX")"

            for mode in $FUZZ_MODES; do

                for i in $(seq "$FUZZING_REPETITIONS"); do

                    POSTFIX="mode-$mode.$i"
                    RUN_PREFIX="$OUT_PREFIX.$POSTFIX"
                    RUN_PREFIX_BASE="$(basename "$RUN_PREFIX")"
                    STATUS_FILE="$RUN_PREFIX.fuzz.status"

                    if test -e "$STATUS_FILE"; then
                        continue
                    fi

                    finished=0

                    LOCKFILE="$(mktemp "$OUT_DIR/.lock.$$.XXXXX")"
                    if ln "$LOCKFILE" "$STATUS_FILE"; then
                        echo "[+] acquired lock for $STATUS_FILE"
                        echo "running" > "$STATUS_FILE"
                    else
                        continue
                    fi

                    # let's try to remove the status file whenever something
                    # weird occurs and we're not done fuzzing yet.
                    trap "remove_lock_on_abnormal_exit $STATUS_FILE" EXIT SIGTERM SIGINT

                    echo "--------------------------------------------------"
                    echo "[+] launching fuzzing run with configuration"
                    echo "    mode => $mode"
                    echo "    rep  => $i"
                    echo "    run  => $RUN_PREFIX"


                    FUZZ_CWD="$(mktemp -d "$FUZZ_DIR/$RUN_PREFIX_BASE.XXXXXX.fuzz")"
                    echo "[+] extracting build files to $FUZZ_CWD"
                    pushd "$FUZZ_CWD" >/dev/null

                    for suffix in ".dir" ".tar" ".tar.xz"; do
                        build_suffix=.build
                        if [[ "$mode" == "interp" ]]; then
                            build_suffix=".interp.build"
                        fi
                        src="$(dirname "$contract")/${contract_id}${build_suffix}${suffix}"
                        echo "trying $src"
                        if test -e "$src"; then
                            echo "    from $src"
                            if [[ "$suffix" == ".tar"* ]]; then
                                tar xf "$src" || true
                            fi
                            if [[ "$suffix" == ".dir" ]]; then
                                cp -r "$src/"* . || true
                            fi
                            break
                        fi
                    done

                    # sanity check
                    if [[ -d "fuzz" && -e "fuzz/launch-aflfuzz.sh" && -e "fuzz/build/afuzz/$contract_id/fuzz_multitx" ]]
                    then
                        echo "[+] seemingly good fuzzing build for $contract_id "

                    else
                        echo "[W] WARNING: invalid build dir for $contract_id -> skipping "
                        echo "skipped" | tee "$STATUS_FILE"

                        # cleanup
                        rm "$LOCKFILE" || true
                        popd >/dev/null # FUZZ_CWD
                        rm -rf "$FUZZ_CWD" || true

                        # skip
                        continue
                    fi

                    unset AFL_CUSTOM_MUTATOR_ONLY || true
                    unset USE_CUSTOM_MUTATOR || true

                    if [[ "$mode" == "monly" ]]; then
                        export FUZZ_CMPLOG_ARG="none"
                        export AFL_CUSTOM_MUTATOR_ONLY=1
                        export USE_CUSTOM_MUTATOR=1
                    elif [[ "$mode" == "aonly" ]]; then
                        export USE_CUSTOM_MUTATOR=0
                        export FUZZ_CMPLOG_ARG="-l 2AT"
                    elif [[ "$mode" == "noabi" ]]; then
                        export USE_CUSTOM_MUTATOR=1
                        export FUZZ_CMPLOG_ARG="-l 2AT"
                        export IGNORE_ABI=1
                    else
                        export USE_CUSTOM_MUTATOR=1
                        if [[ "$mode" == "none" ]]; then
                            export FUZZ_CMPLOG_ARG="none"
                        elif [[ "$mode" == "interp" ]]; then
                            export FUZZ_CMPLOG_ARG="-l 2AT"
                        else
                            export FUZZ_CMPLOG_ARG="-l $mode"
                        fi
                    fi

                    echo "[+] killing potential remaining fuzzing processes"
                    pkill -KILL fuzz_multitx || true

                    echo "[+] preparing fuzz"
                    export FUZZ_USE_SHM=0
                    export FUZZ_USE_TMPFS=0
                    export FUZZ_LAUNCHER_DONT_REBUILD=1

                    echo "[+] checking for constructor and/or constructor args"
                    # first unset s.t., nothing remains in the environment resides
                    unset EVM_CREATE_TX_INPUT
                    EVM_CREATE_TX_INPUT=""
                    for EVM_CREATE_TX_INPUT in \
                        "$CONTRACTS_DIR/${contract_id}.create-input" \
                        "./contracts/${contract_id}.create-input";
                    do
                        if test -e "$EVM_CREATE_TX_INPUT"; then
                            EVM_CREATE_TX_INPUT="$(realpath "$EVM_CREATE_TX_INPUT")"
                            export EVM_CREATE_TX_INPUT
                            break
                        fi
                    done
                    unset EVM_CREATE_TX_ARGS
                    EVM_CREATE_TX_ARGS=""
                    for EVM_CREATE_TX_ARGS in \
                        "$CONTRACTS_DIR/${contract_id}.create-args" \
                        "./contracts/${contract_id}.create-args";
                    do
                        if test -e "$EVM_CREATE_TX_ARGS"; then
                            EVM_CREATE_TX_ARGS="$(realpath "$EVM_CREATE_TX_ARGS")"
                            export EVM_CREATE_TX_ARGS
                            break
                        fi
                    done

                    # we copy the latest launcher script in case
                    if test -e "$EVM_DIR/fuzz/launch-aflfuzz.sh"; then
                        cp "$EVM_DIR/fuzz/launch-aflfuzz.sh" ./fuzz/ || true
                    fi
                    # make sure we can execute those...
                    chmod +x ./fuzz/*.sh || true
                    chmod +x ./fuzz/build/*/*/fuzz_* || true

                    export FUZZ_EVMCOV=1
                    export FUZZ_PLOT=0

                    echo "[+] launching afl-fuzz"
                    set +e
                    print_and_run /usr/bin/time -v -o "$RUN_PREFIX.fuzz.time" \
                        ./fuzz/launch-aflfuzz.sh \
                        "$contract_id" "$FUZZING_TIME" "$POSTFIX" \
                            > "$RUN_PREFIX.fuzz.log" 2>&1
                    stat="$?"
                    echo "=> launch-aflfuzz exit code: $stat"
                    true
                    set -e

                    echo "[+] shortening log"
                    head -n 100 "$RUN_PREFIX.fuzz.log" > "$RUN_PREFIX.fuzz.short.log"
                    echo "----------- [SNIP] ------------" >> "$RUN_PREFIX.fuzz.short.log"
                    tail -n 100 "$RUN_PREFIX.fuzz.log" >> "$RUN_PREFIX.fuzz.short.log"

                    echo "[+] compressing fuzz log"
                    xz -f "$RUN_PREFIX.fuzz.log"

                    EVM_TOPLEVEL="$(pwd)"

                    echo "[+] saving some fuzzing related artifacts"
                    # save some fuzzer artifacts
                    if pushd ./fuzz/out/${contract_id}_*_${POSTFIX} >/dev/null; then

                        # those will be saved in the fuzz output tarball for better
                        # analysis
                        # we check whether some of these exist and save them
                        for f in "$CONTRACTS_DIR/${contract_id}.sol" \
                            "$CONTRACTS_DIR/${contract_id}.combined.json" \
                            "$CONTRACTS_DIR/${contract_id}.create-args" \
                            "$CONTRACTS_DIR/${contract_id}.create-input" \
                            "$CONTRACTS_DIR/${contract_id}.abi" \
                            "$CONTRACTS_DIR/${contract_id}.bin-runtime" \
                            "$CONTRACTS_DIR/${contract_id}.bin";
                        do
                            if test -e "$f"; then
                                cp "$f" . || true
                            fi
                        done

                        # we copy everything in the contracts directory since
                        # this should make analysis easier!
                        cp -r "$EVM_TOPLEVEL/contracts/"* . || true

                        # we definitly want to copy the binary for easy crash
                        # reproducing.
                        cp ./build/fuzz_multitx .

                        # if we have corresponding source file and rg is
                        # available we search for hardcoded ethereum
                        # addresses. This should allow us to quickly weed
                        # out certain false alarms...
                        solfile="./${contract_id}.sol"
                        if test -e "$solfile" && command -v rg >/dev/null;
                        then
                            rg --no-ignore -oN -r '$1' \
                                '(0x[a-fA-F0-9]{40})([^a-fA-F0-9]|$)' \
                                "$solfile" \
                                | sort | uniq \
                                > ./source_hardcoded_addresses \
                                || true
                        fi


                        cat /proc/cpuinfo > "$RUN_PREFIX.fuzz.cpu" || true

                        popd >/dev/null
                    else
                        echo "failed to pushd into " "./fuzz/out/${contract_id}_"*"_$i"
                        ls -l "./fuzz/out/${contract_id}_"*"_$i" || true
                    fi

                    echo "[+] checking fuzzing results"

                    result="failure"
                    if [[ "$stat" -eq 0 ]]
                    then
                        result="success"

                        # save some fuzzer stats/results in plaintext
                        if pushd ./fuzz/out/${contract_id}_*_${POSTFIX} >/dev/null; then

                            #grep -E '(execs_done|execs_per_sec|unique)' \
                            #    <"./default/fuzzer_stats" |
                            #    tee "$RUN_PREFIX.fuzz.results"

                            AFL_STATS="$(afl_whatsup)"
                            echo "$AFL_STATS" | tee "$RUN_PREFIX.fuzz.results"

                            if [[ -e ./coverage-percent-all.evmcov ]]; then

                                echo "evm-coverage: $(cat "./coverage-percent-all.evmcov")" |
                                    tee -a "$RUN_PREFIX.fuzz.results"

                                COV_SUMMARY="$COV_SUMMARY\n $contract_id (mode $mode) => $(cat "./coverage-percent-all.evmcov") % cov"
                            else
                                COV_SUMMARY="$COV_SUMMARY\n $contract_id (mode $mode) => NO COVERAGE PRESENT!"
                            fi

                            for thing in crashes queue; do
                                sumpath="./${thing}_tx_summary"
                                if test -s "$sumpath"; then
                                    echo -n "$thing - " >> "$RUN_PREFIX.fuzz.results"
                                    wat="$(grep -E 'unique' < "$sumpath" | grep -v "consecutive")"
                                    if [[ -n "$wat" ]]; then
                                        echo "$wat" | tee -a "$RUN_PREFIX.fuzz.results"
                                    else
                                        echo ": 0" | tee -a "$RUN_PREFIX.fuzz.results"
                                    fi

                                    export COV_SUMMARY="$COV_SUMMARY ; $thing deduped: $(grep -E 'unique' <"$sumpath" | head -n 1 | cut -d ':' -f 2)"
                                else
                                    echo -n "$thing - : 0" >> "$RUN_PREFIX.fuzz.results"
                                    export COV_SUMMARY="$COV_SUMMARY ; $thing deduped: 0"
                                fi
                            done

                            COV_SUMMARY="$COV_SUMMARY ; $(echo "$AFL_STATS" | grep -E 'execs_done' | head -n 1 | awk '{print $3}') execs"
                            COV_SUMMARY="$COV_SUMMARY ; $(grep -i 'wall clock' < "$RUN_PREFIX.fuzz.time" | head -n 1)"

                            popd >/dev/null
                        else
                            echo "failed to pushd into " "./fuzz/out/${contract_id}_"*"_$i"
                            ls -l "./fuzz/out/${contract_id}_"*"_$i" || true
                        fi

                    else
                        echo "[WARNING] Fuzzer seems to have failed!"
                        result="failure"

                        COV_SUMMARY="$COV_SUMMARY\n $contract_id (mode $mode) => FAILURE"

                    fi

                    echo "[+] cleaning up core files"
                    rm ./core.* || true
                    rm ./core || true

                    pushd fuzz/out >/dev/null
                    timed_print_and_run tar --exclude="*/build" -hcJf "$RUN_PREFIX.fuzz.tar.xz" ./*
                    popd >/dev/null
                    timed_print_and_run rm -rf ./fuzz/out/*

                    echo "$result" | tee "$STATUS_FILE"

                    echo "[+] cleaning up fuzzing working directory"
                    popd >/dev/null #  "$FUZZ_CWD"
                    rm -rf "$FUZZ_CWD" || true

                    rm "$LOCKFILE" || true
                    fuzzed=$(( $fuzzed + 1 ))

                    echo -e "[+] current results summary ($fuzzed fuzzed):\n$COV_SUMMARY\n"

                    echo "[+] waiting a bit before attempting the next fuzzing job"
                    sleep 5

                done  # modes
            done  # fuzzing repetitions
        done  # contracts

        echo "[+] processed $fuzzed fuzz jobs - finished? $finished"

    done  # finished

    trap "" EXIT SIGTERM SIGINT

    return 0
}



