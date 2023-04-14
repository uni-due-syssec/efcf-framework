#!/usr/bin/env bash

set -u -o pipefail

TIMEOUT="1200"
REPETITIONS="1"
OUT_DIR=./results/sailfish-dao
if ! test -e "$OUT_DIR"; then
    mkdir -p "$OUT_DIR"
fi

buildcache=/tmp/efcf/builds/
mkdir -p "$buildcache" || true
while IFS= read -r addr
do
    for i in $(seq 1 "$REPETITIONS"); do
        outpath="$OUT_DIR/$addr.$i.tar.xz";
        if test -e "$outpath" || test -e "$outpath" || test -e "$outpath"; then 
            continue; 
        fi
        # remove latest outpath if some errors occurs - avoids pointless empty files
        trap "sig=\$((\$?)); set -x; rm -f \"$outpath\"; exit \$sig" EXIT SIGTERM SIGINT
        touch "$outpath"
        echo ">>>>> Fuzzing $addr" 
        tmplog="$(mktemp).log"
        buildcache=/tmp/efcf/builds/
        mkdir -p "$buildcache" || true
        set -x
        efcfuzz \
            --quiet \
            --compress-builds=n \
            --build-cache "$buildcache" \
            --geth-url http://localhost:8545 \
            --include-address-deps=y \
            --until-crash --timeout "$TIMEOUT" \
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
    ls -A "$buildcache"
    cp "$buildcache"/*.log "$OUT_DIR/" >/dev/null || true
    rm -rf "$buildcache"
    mkdir -p "$buildcache" || true
done < ./data/sailfish-sailfish-dao/sailfish.dao

exit 0
