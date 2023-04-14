#!/usr/bin/env bash

echo "WARNING: this script is deprecated, using the py version instead"
exec python3 scripts/run-tools-on-dataset.py $@




set -e

if [[ -z "$CLEAN_RUN" ]]; then
    CLEAN_RUN=0
fi

DOCKER="$(command -v docker || command -v podman)"
TOOLS=""
DATASET="$(realpath "$1")"

GLOBAL_TIMEOUT="$(python -c "print(60*60*48)")"
SOLVER_TIMEOUT_SEC=1920
SOLVER_TIMEOUT_MILLIS=1920000
MAX_CONTAINERS=$(($(nproc) - 1))
CPUS=1

TX_BOUND=32

set -u

echo "[+] building tools containers"
pushd docker/tools/
make -j8
popd

echo "[+] running $TOOLS on $DATASET"

#LASTCPU=$(($(nproc) - 1))
declare -a LAUNCHED_CONTAINERS
CONTAINER_COUNTER=0
DONE_CONTAINER_COUNTER=0

OUT_DIR="$(realpath -m "./results/tools-$(basename $DATASET)")"

function stop_containers_overtime {

    running=0
    echo "[+] checking ${#LAUNCHED_CONTAINERS[@]} containers for being global timeout limit"
    for container in "${LAUNCHED_CONTAINERS[@]}"; do
        cstatus="$($DOCKER inspect "$container" | jq -r '.[0].State.Status')"
        startedat="$($DOCKER inspect "$container" | jq -r '.[0].State.StartedAt')"
        if [[ "$cstatus" == "running" ]]; then
            running=$(($running + 1))
            #echo -n "$container, "
            pid="$($DOCKER inspect "$container" | jq -r '.[0].State.Pid')"
            runningtime="$(ps -o etimes= -p "$pid")"

            echo "$container started at $startedat (running time $runningtime seconds vs $GLOBAL_TIMEOUT sec timeout)"

            if [[ $runningtime -gt "$GLOBAL_TIMEOUT" ]]; then
                echo "$container is overt ime!!!!"
                $DOCKER stop $container
            fi
        fi
        if [[ "$cstatus" == "null" ]]; then
            echo "[W] tracked container '$container' neither running nor exited?"
        fi
    done

    echo "... done (tracked running tasks: $running; total tracked: ${#LAUNCHED_CONTAINERS[@]}; total up containers $(docker ps -q | wc -l))"

    return $running
}

function launch_in_docker {
    cname="$1.$2.$3"
    container="$1"
    contract="$2"
    shift; shift; shift;
    
    cstatus="$($DOCKER inspect "$cname" | jq -r '.[0].State.Status')"
    echo "container $cname => $cstatus"

    if [[ "$CLEAN_RUN" -eq 1 ]]; then
        docker stop "$cname" || true
        sleep 1
        docker rm "$cname" || true
        cstatus="null"
    fi

    if [[ "$cstatus" == "null" ]]; then

        while [[ "$(docker ps -q | wc -l)" -ge "$MAX_CONTAINERS" ]]; do
            echo "$(docker ps -q | wc -l) containers running"
            echo "$DONE_CONTAINER_COUNTER containers exited"
            echo "[+] CPU saturated. waiting..."
            stop_containers_overtime || true
            sleep 300
        done
        echo "$(docker ps -q | wc -l) containers running"

        echo "[+] starting next container $cname"
        set -x
        $DOCKER run \
            -v "$OUT_DIR":"$OUT_DIR":z \
            -v "$DATASET":"$DATASET":z \
            -w "$DATASET" \
            --cpus "$CPUS" \
            -d --name "$cname" \
            $container $@
        set +x
            #--cpuset-cpus=$LASTCPU \
        sleep 1

        CONTAINER_COUNTER=$(($CONTAINER_COUNTER + 1))
    fi
    
    LAUNCHED_CONTAINERS+=("$cname")

    if [[ "$cstatus" == "exited" ]]; then
        DONE_CONTAINER_COUNTER=$(($DONE_CONTAINER_COUNTER + 1))
    fi


    echo "[+] tracking ${#LAUNCHED_CONTAINERS[@]} containers"
    #echo "    => ${LAUNCHED_CONTAINERS[@]}"
}

pushd "$DATASET"
rm -rf out || true
mkdir out/ || true
for sol in *.sol; do
    contract="$(echo "$sol" | cut -d '.' -f 1)"
    echo "[+] building contract $contract from $sol"
    make "$contract" "$contract.combined.json"

    echo "[+] launching tools"

    for i in $(seq 3); do
        launch_in_docker "maian" "$contract" "$i" \
            --max_inv "$TX_BOUND" \
            --solve_timeout "$SOLVER_TIMEOUT_MILLIS" \
            -c 0 --bytecode "./$contract.bin-runtime"

        launch_in_docker "teether" "$contract" "$i" \
            "$contract.bin-runtime" \
            0xcafecafe 0xdeadbeef +1

        make "$contract.ethbmc.yml"
        launch_in_docker "ethbmc" "$contract" "$i" \
            --message-bound "$TX_BOUND" \
            --loop-bound 16 \
            --solver-timeout "$SOLVER_TIMEOUT_MILLIS" \
            --cores 1 \
            "./$contract.ethbmc.yml"

        launch_in_docker "manticoreprime" "$contract" "thorough.$i" \
            --maxt "$TX_BOUND" --smt.timeout "$SOLVER_TIMEOUT_SEC" \
            --timeout "$GLOBAL_TIMEOUT" \
            --propre 'echidna.*' --solc /usr/bin/solc-0.7.6 \
            --maxfail 1 \
            --thorough-mode \
            --contract_name "$contract" \
            --workspace.dir "$OUT_DIR/" --workspace.prefix "manticore_run${i}_${contract}_" \
            $sol

    done
done

for sol in *.sol; do
    contract="$(echo "$sol" | cut -d '.' -f 1)"
    for i in $(seq 10); do

        echidna_conf="$OUT_DIR/echidna_run${i}_$contract.config.yml"
        cat > "$echidna_conf" <<EOF
stopOnFail: true
coverage: true
timeout: $GLOBAL_TIMEOUT
testLimit: 4294967296
EOF
        launch_in_docker "echidnaprime" "$contract" "$i" \
            --contract "$contract" \
            --corpus-dir "$OUT_DIR/echidna_run${i}_$contract" \
            --format json \
            --config "$echidna_conf" \
            "$sol"

        launch_in_docker "confuzzius" "$contract" "$i" \
            --source "$sol" \
            --timeout "$GLOBAL_TIMEOUT" \
            --results "$OUT_DIR/confuzzius_run${i}_${contract}_results.json" \
            --run-until-first-bug \
            --max-individual-length "$TX_BOUND"

    done
done


echo "[+] all containers launched"
echo "$CONTAINER_COUNTER containers launched; $DONE_CONTAINER_COUNTER containers exited"
echo "$(docker ps -q | wc -l) containers running"

echo "[+] waiting for container termination"
while ! stop_containers_overtime ; do
    echo "...."
    sleep 300
done

sleep 10

echo "[+] finished, getting container outputs :)"
for container in "${LAUNCHED_CONTAINERS[@]}"; do
    echo -n "$container, "
    $DOCKER logs -t "$container" > "$OUT_DIR/$container.log" 2>&1
    $DOCKER inspect "$container" | jq '.[0].State' > "$OUT_DIR/$container.status"
    $DOCKER logs -t "$container" | grep -i "wall" | grep -i "clock" > "$OUT_DIR/$container.time"
done
echo ""

echo "[+] bye"
