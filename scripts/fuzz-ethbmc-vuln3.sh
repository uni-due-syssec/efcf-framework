#!/usr/bin/env bash

set -u -o pipefail

OUT_DIR=./results/ethbmc-vuln3
if ! test -e "$OUT_DIR"; then
    mkdir -p "$OUT_DIR"
fi

for addr in \
    0x318a74cfb30fbc1747a60e9fd4dbc034d00da04d \
    0xcb2ab9fdb42de8955987304009494ee4c2a08852 \
    0x3e2bdb6b4545df4eb7547f8b8bd8a11bb29c1650 \
    0xcbcff2b9723ad8db38ba826af611e35bbbfc7ce3 \
    0x6ec9c5ba13c3eff74e5c0cd253be4a026a6ce6f2 \
    0x6e852ba3cbc51d6fdf83af554e1d2e633be3f3c1 \
    0xa1ec098c32bde89a29c330e62faa62f3fccce64e \
    0x3648ac92cf840488f5188fa3faa9091b651b4d92 \
    0x410b6d66bb9236bc524f46af4150aa5e16b49bbd \
    0xf57f51d516c1ba009482082811d86fea0fc22fcb \
    0x3c5a3436a52c65eb64613a2c345f90ba2899271e \
    0x7eae8e15f0a3380226ee351e32dc2e717d242463 \
    0x89e315a597dfce24b15197a450dff66db62dd3cb \
    0x357f216e0aab7046fb5e22a3e29c0ac19aa625ea \
    0x95eedba9114d72fdca00ba821efa883af189b112 \
    0x9c3fae2ab9c0079854dc3ab5808afbc4c4fa62ed \
    0xccfaee7dd7e330960d5241a980415cc94dbe59a4 \
    0xe1a7f57ce21f58d6f55939900809800dce699b8b;
do
    outpath="$OUT_DIR/$addr.tar.xz";
    if test -e "$outpath"; then
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
        --live-state-blocknumber 4649477 \
        --ignore-leaking \
        --report-dos-selfdestruct \
        --include-address-deps=y \
        --until-crash --timeout 3600 \
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
done

exit 0
