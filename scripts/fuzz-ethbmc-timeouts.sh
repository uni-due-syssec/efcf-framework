#!/usr/bin/env bash

set -u -o pipefail

OUT_DIR=./results/ethbmc-timeouts
if ! test -e "$OUT_DIR"; then
    mkdir -p "$OUT_DIR"
fi

while IFS= read -r addr
do
    outpath="$OUT_DIR/$addr.tar.xz";
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
        --geth-preset old \
        --geth-rate-limit \
        --ignore-leaking \
        --report-dos-selfdestruct \
        --include-address-deps=y \
        --until-crash --timeout 1200 \
        --out "$outpath" \
        --live-state "$addr" 2>&1 | tee "$tmplog"
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
    cp "$buildcache"/*.log "$OUT_DIR/"
    ls -A  "$buildcache"
    rm -rf "$buildcache"
done < ./data/ethbmc-timeouts/timeouts.txt

exit 0
