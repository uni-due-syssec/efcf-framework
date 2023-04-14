#!/usr/bin/env fish

echo "[+] configuring PATH for fish"

echo "[+] setting up ethmutator"
pushd ./src/ethmutator
cargo build --release
set -a PATH (realpath $PWD/target/release)
popd

echo "[+] setting up evm2cpp"
pushd ./src/evm2cpp
cargo build --release
set -a PATH (realpath $PWD/target/release)
popd

echo "[+] setting up AFL++"
pushd ./src/AFLplusplus
test -e afl-fuzz || make source-only NO_NYX=1 NO_PYTHON=1 #NO_SPLICING=1
set -a PATH (realpath $PWD)
popd

echo "...done PATH configured for dev setup"

echo "[+] setting up system for AFL++ fuzzing"
echo "AFL_SKIP_CPUFREQ=1"
set -x AFL_SKIP_CPUFREQ 1
if test (sysctl -n kernel.core_pattern) != "core";
    sudo sysctl -w kernel.core_pattern=core
end
if test (sysctl -n kernel.core_uses_pid) != "0";
    sudo sysctl -w kernel.core_uses_pid=0
end

