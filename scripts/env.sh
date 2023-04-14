#!/bin/sh
set -e

echo "[+] configuring PATH"

echo "[+] setting up ethmutator"
cd ./src/ethmutator
cargo build --release
export PATH=$PATH:$(realpath "$PWD/target/release")
cd ../../

echo "[+] setting up evm2cpp"
cd ./src/evm2cpp
cargo build --release
export PATH=$PATH:$(realpath "$PWD/target/release")
cd ../../

echo "[+] setting up AFL++"
cd ./src/AFLplusplus
make source-only NO_NYX=1 NO_PYTHON=1 #NO_SPLICING=1
export PATH=$PATH:$(realpath "$PWD")
cd ../../

echo "...done PATH configured for dev setup"

echo "[+] setting up system for AFL++ fuzzing"
echo "AFL_SKIP_CPUFREQ=1"
set -x AFL_SKIP_CPUFREQ 1
echo "kernel.core_pattern=core"
sudo sysctl -w kernel.core_pattern=core
echo "kernel.core_uses_pid=0"
sudo sysctl -w kernel.core_uses_pid=0
