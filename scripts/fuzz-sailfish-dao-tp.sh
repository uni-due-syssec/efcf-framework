#!/usr/bin/env bash

set -u -o pipefail

FUZZING_TIMEOUT="1500"
FUZZING_REPETITIONS="3"
OUT_DIR=./results/sailfish-dao-tp/
if ! test -e "$OUT_DIR"; then
    mkdir -p "$OUT_DIR"
fi

mkdir -p /tmp/efcf/builds/ || true
buildcache="$(mktemp -d -p /tmp/efcf/builds/ 'cache.XXXXXXXX')"
mkdir -p "$buildcache" || true
while IFS= read -r addr
do
    for i in $(seq 1 "$FUZZING_REPETITIONS"); do
        outpath="$OUT_DIR/$addr.livestate.$i.tar.xz";
        if test -e "$outpath" || test -e "$outpath" || test -e "$outpath"; then
            continue;
        fi
        touch "$outpath"
        # remove latest outpath if some errors occurs - avoids pointless empty files
        trap "sig=\$((\$?)); set -x; rm -f \"$outpath\"; exit \$sig" EXIT SIGTERM SIGINT
        mkdir -p "$buildcache" || true
        echo ">>>>> Fuzzing $addr"
        tmplog="$(mktemp).log"
        set -x
        efcfuzz \
            --quiet \
            --compress-builds=n \
            --build-cache "$buildcache" \
            --geth-url http://localhost:8545 \
            --include-address-deps=y \
            --ignore-initial-ether=y \
            --until-crash --timeout "$FUZZING_TIMEOUT" \
            --out "$outpath" \
            --live-state "$addr" 2>&1 | tee "$tmplog"
            # --include-mapping-deps=y \
        res=$?
        set +x
        if [[ "$res" -ne 0 ]]; then
            echo ">>>>> Fuzzing $addr failed with $res"
            rm "$outpath" || true
            cp "$tmplog" "$outpath.$(date --iso-8601=seconds).$res.err.log"
        else
            cp "$tmplog" "$outpath.$(date --iso-8601=seconds).log"
        fi
        # make sure the trap is gone if we succeeded
        trap - EXIT SIGTERM SIGINT
    done

    for i in $(seq 1 "$FUZZING_REPETITIONS"); do
        outpath="$OUT_DIR/$addr.source.$i.tar.xz";
        if test -e "$outpath" || test -e "$outpath" || test -e "$outpath"; then
            continue;
        fi
        touch "$outpath"
        # remove latest outpath if some errors occurs - avoids pointless empty files
        trap "sig=\$((\$?)); set -x; rm -f \"$outpath\"; exit \$sig" EXIT SIGTERM SIGINT

        solpath="./data/sailfish-dao-tp/$addr.sol"
        metapath="./data/sailfish-dao-tp/$addr.meta.json"
        if test -e "$solpath" && test -e "$metapath"; then
            # all good
            true
        else
            echo "[WARNING] no data found for address $addr"
            break
        fi

        contractname="$(jq -r '.[0].ContractName' "$metapath")"

        echo ">>>>> Fuzzing $addr"
        tmplog="$(mktemp).log"
        mkdir -p "$buildcache" || true
        set -x
        efcfuzz \
            --quiet \
            --compress-builds=n \
            --build-cache "$buildcache" \
            --until-crash --timeout "$FUZZING_TIMEOUT" \
            --out "$outpath" \
            --source "$solpath" \
            --name "$contractname" \
                2>&1 | tee "$tmplog"
        res=$?
        set +x
        if [[ "$res" -ne 0 ]]; then
            echo ">>>>> Fuzzing $addr failed with $res"
            rm "$outpath" || true
            cp "$tmplog" "$outpath.$(date --iso-8601=seconds).$res.err.log"
        else
            cp "$tmplog" "$outpath.$(date --iso-8601=seconds).log"
        fi
        # make sure the trap is gone if we succeeded
        trap - EXIT SIGTERM SIGINT
    done


    ls -A "$buildcache"
    cp "$buildcache"/*.log "$OUT_DIR/" >/dev/null || true
    rm -rf "$buildcache"
    mkdir -p "$buildcache" || true
done < ./data/sailfish-dao-tp/sailfish.dao.tp

exit 0
