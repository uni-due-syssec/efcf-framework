#!/usr/bin/env bash

# make sure that each fuzzer is bound to a cpu core for better perf - usually
# this is is set to 1 and binding to cpu cores is done externally via docker,
# but when we use all available cores in one container this does not make
# sense.
export AFL_NO_AFFINITY=0
unset AFL_NO_AFFINITY  # not sure how afl++ reads env vars... bette remove it alltogether

for i in $(seq 1 20); do
    efcfuzz --until-crash --quiet --print-progress \
        --out ./out/live_state/uniswap_b9600000/run_${i} \
        --live-state 0xFFcf45b540e6C9F094Ae656D2e34aD11cdfdb187,0x3212b29E33587A00FB1C83346f5dBFA69A458923,0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24 \
        --live-state-blocknumber 9600000 \
        --multi-target=y --include-address-deps=y \
        --compute-evm-cov=n --generate-cov-plots=n \
        --cleanup-kills=y \
        --remove-out-on-failure=n \
        --timeout 48h --cores 40

    #find . -name "*.log" -exec xz -z -e -T 16 \{\} \;
    find . -name "afl*.log" -delete
done
