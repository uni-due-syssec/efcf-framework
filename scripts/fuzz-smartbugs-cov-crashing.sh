#!/usr/bin/env bash

set -u -o pipefail

TIMEOUT="1200"
OUT_DIR=./results/smartbugs-cov-crashing/
if ! test -e "$OUT_DIR"; then
    mkdir -p "$OUT_DIR"
fi

# first we run efcf with the source as input, then for all crashes we attempt
# to identify the same crash on the live-state. If we cannot do that this is an
# indication for a false alarm.

while IFS= read -r addr
do
    solpath="./data/smartbugs-top-1000-balance/$addr.sol"
    metapath="./data/smartbugs-top-1000-balance/$addr.meta.json.xz"
    if test -e "$solpath" && test -e "$metapath"; then
        # all good
        true
    else
        echo "[WARNING] no data found for address $addr"
        continue
    fi

    contractname="$(xz -d < "$metapath" | jq -r '.[0].ContractName')"
    outpath="$OUT_DIR/$addr.tar.xz";
    if test -e "$outpath" || test -e "$outpath" || test -e "$outpath"; then
        echo "$outpath already exists"
        continue
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
        --until-crash --timeout "$TIMEOUT" \
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
    cp "$buildcache"/*.log "$OUT_DIR/"
    ls -A  "$buildcache"
    rm -rf "$buildcache"
done < ./data/smartbugs-cov-crashing/contracts.txt

if ! test -e "$OUT_DIR/crashing.txt"; then
    touch "$OUT_DIR/crashing.txt"
    echo "[+] sleep until potential parallel fuzzers are also done"
    sleep "$TIMEOUT"
    sleep 20

    echo "[+] making $OUT_DIR/crashing.txt"
    pushd "$OUT_DIR"
    rg --count 'total_crashes.*: [1-9]' *.log \
        | sed -E 's/(0x[0-9a-fA-F]+).*/\1/g' \
        | sort -u \
            > "$OUT_DIR/crashing.txt"
    popd
else
    sleep 2
    while [[ -z "$(cat "$OUT_DIR/crashing.txt")" ]]; do
        echo "[+] waiting for crashing.txt (20 sec)"
        sleep 20
    done
fi

while IFS= read -r addr
do
    outpath="$OUT_DIR/$addr.live.tar.xz";
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
        --live-state "$addr" \
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
    cp "$buildcache"/*.log "$OUT_DIR/"
    ls -A  "$buildcache"
    rm -rf "$buildcache"
done < "$OUT_DIR/crashing.txt"

exit 0
