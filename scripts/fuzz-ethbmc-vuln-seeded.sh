#!/usr/bin/env bash

set -u -o pipefail

RUN=1
TIMEOUT=1200
BLOCK=4649477
OUT_DIR=./results/ethbmc-vuln-seeded/
if ! test -e "$OUT_DIR"; then
    mkdir -p "$OUT_DIR"
fi

echo "=== Fuzzing with $0 run $RUN timeout $TIMEOUT block $BLOCK results $OUT_DIR"

while IFS= read -r addr
do
    outpath="$OUT_DIR/${addr}.b${BLOCK}_t${TIMEOUT}_run$RUN/";
    if test -e "$outpath" || test -e "$outpath" || test -e "$outpath"; then
        echo "skipping $addr"
        continue; 
    fi
    # remove latest outpath if some errors occurs - avoids pointless empty files
    trap "sig=\$((\$?)); set -x; rm -rf \"$outpath\"; exit \$sig" EXIT SIGTERM SIGINT
    mkdir -p "$outpath"
    echo ">>>>> Fuzzing $addr" 
    tmplog="$(mktemp).log"
    buildcache=/tmp/efcf/builds/
    mkdir -p "$buildcache" || true
    set -x
    efcfuzz \
        --verbose \
        --compress-builds=n \
        --build-cache "$buildcache" \
        --geth-url http://localhost:8545 \
        --geth-rate-limit \
        --ignore-leaking \
        --report-dos-selfdestruct \
        --include-address-deps=y \
        --until-crash --timeout "$TIMEOUT" \
        --live-state-blocknumber "$BLOCK" \
        --seed-from-ethbmc-attacks "$OUT_DIR/ethbmc_final_result.zip" \
        --out "$outpath" \
        --live-state "$addr" 2>&1 | tee "$tmplog"
    res=$?
    set +x
    if [[ "$res" -ne 0 ]]; then
        echo ">>>>> Fuzzing $addr failed with $res" 
        rm -rf "$outpath" || true
        cp "$tmplog" "$outpath.$(date --iso-8601=seconds).$res.err.log"
    else
        cp "$tmplog" "$outpath.$(date --iso-8601=seconds).log"
    fi
    # make sure the trap is gone if we succeeded
    trap - EXIT SIGTERM SIGINT
    cp "$buildcache"/*.log "$OUT_DIR/"
    ls -A  "$buildcache"
    rm -rf "$buildcache"
done < ./results/ethbmc-missedbugs-contracts.txt

exit 0
