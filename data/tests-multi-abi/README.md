# Test for Rudimentary Multi-Target/ABI Fuzzing Mode

The idea is simple: some attacks require to fuzz a combination of contracts
(i.e., two or more). This directory contains some rudimentary testcases that
require a multi-target fuzzing mode. To start fuzzing a combination of
contracts use the following commands:

```
make DoubleFetchExchange.state
cd ../../src/eEVM/
env AFL_BENCH_UNTIL_CRASH=1 \
    EVM_LOAD_STATE="$(pwd)/full.state.load.json" \
    EVM_TARGET_MULTIPLE_ADDRESSES=`cat ./addr_list.txt` \
    ABI_PATH=`cat abi_list.txt` \
    ./fuzz/launch-aflfuzz.sh DoubleFetchExchange
```

* We require state loading because we do not have a way to construct contract
  state for multiple contracts, except when one is constructed during the
  constructor of the target contract.
* We need to specify the addresses of the possible targets. They are put into
  an array and then the fuzzcases utilize a selector into this array.
* We supply a list of paths to the various ABI files. The ordering must be
  synched with the target address list. We also create a concatenated abi file
  which can be used when printing the fuzz case using e.g., the
  `efuzzcaseanalyzer` tool.
