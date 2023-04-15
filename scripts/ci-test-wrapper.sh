#!/usr/bin/env bash

if [[ -z "$EFCF_BUILD_CACHE" ]]; then
    EFCF_BUILD_CACHE="$(realpath -m ./efcf-build-cache)"
fi

if [[ -z "$FUZZING_TIME" ]]; then
    FUZZING_TIME=420
fi

export EFCF_BUILD_CACHE
export FUZZING_TIME
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES="1"

set -eu -o pipefail
set -x

mkdir -p out || true
rm -rf "$EFCF_BUILD_CACHE"
mkdir -p "$EFCF_BUILD_CACHE"
echo "using build cache $EFCF_BUILD_CACHE"
command -v efcfuzz
efcfuzz --verbose --version

echo "# ==== testing fuzzing source code ===="
efcfuzz --compress-builds n --verbose --until-crash --timeout $FUZZING_TIME --out ./out/basic_src_results/ --source ./data/tests/basic.sol
find ./out/basic_src_results/default/crashes/
test -n "$(ls -A ./out/basic_src_results/default/crashes/)"
pushd ./out/basic_src_results/
./r.sh ./default/crashes/id*
popd
rm -rf "$EFCF_BUILD_CACHE"

echo "# testing fuzzing with other cli flags"
efcfuzz --compress-builds n --quiet --until-crash --timeout $FUZZING_TIME --out ./out/basic_src_results/ --source ./data/tests/basic.sol
rm -rf "$EFCF_BUILD_CACHE"
efcfuzz --compress-builds n --quiet --print-progress --until-crash --timeout $FUZZING_TIME --out ./out/basic_src_results/ --source ./data/tests/basic.sol
rm -rf "$EFCF_BUILD_CACHE"
echo "cores: $(nproc)"
efcfuzz --compress-builds n --quiet --print-progress --cores "$(nproc)" --until-crash --timeout $FUZZING_TIME --out ./out/basic_src_results/ --source ./data/tests/basic.sol
rm -rf "$EFCF_BUILD_CACHE"

df -h . /tmp/ /dev/shm/ /tmp/efcf/

echo "# ==== testing fuzzing combined.json ===="
pushd ./data/tests/; make basic.combined.json; popd
efcfuzz --verbose --compress-builds n --until-crash --timeout $FUZZING_TIME --out ./out/basic_cj_results/ --bin-runtime ./data/tests/basic.combined.json
find ./out/basic_cj_results/default/crashes/
test -n "$(ls -A ./out/basic_cj_results/default/crashes/)"
pushd ./out/basic_cj_results/
./r.sh ./default/crashes/id*
popd
rm -rf "$EFCF_BUILD_CACHE"
df -h . /tmp/ /dev/shm/

echo "# ==== testing fuzzing plain bin-runtime, abi and bin ===="
pushd ./data/tests/; make basic; popd
efcfuzz --verbose --compress-builds n --until-crash --timeout $FUZZING_TIME --out ./out/basic_bin_results/ --bin-runtime ./data/tests/basic.bin-runtime --bin-deploy ./data/tests/basic.bin --abi ./data/tests/basic.abi
find ./out/basic_bin_results/default/crashes/
test -n "$(ls -A ./out/basic_bin_results/default/crashes/)"
pushd ./out/basic_bin_results/
./r.sh ./default/crashes/id*
popd
rm -rf "$EFCF_BUILD_CACHE"
df -h . /tmp/ /dev/shm/

echo "# ===== testing fuzzing source with properties ===="
efcfuzz --verbose  --compress-builds n --until-crash --timeout $FUZZING_TIME --out ./out/harvey_baz/ --source ./data/properties-tests/harvey_baz.sol --properties ./data/properties-tests/harvey_baz.signatures
find ./out/harvey_baz/default/crashes/
test -n "$(ls -A ./out/harvey_baz/default/crashes/)"
pushd ./out/harvey_baz/
./r.sh ./default/crashes/id*
popd
rm -rf "$EFCF_BUILD_CACHE"
df -h . /tmp/ /dev/shm/

echo "# ===== testing fuzzing source with event assertions ===="
efcfuzz --verbose --compress-builds n --until-crash --timeout $FUZZING_TIME  --out ./out/funwithnumbers --event-assertions --source ./data/assertions-tests/verifyfunwithnumbers.sol
find ./out/funwithnumbers/default/crashes/
test -n "$(ls -A ./out/funwithnumbers/default/crashes/)"
pushd ./out/funwithnumbers/
./r.sh ./default/crashes/id*
popd
rm -rf "$EFCF_BUILD_CACHE"
df -h . /tmp/ /dev/shm/

echo "# ===== testing fuzzing source with solidity panics ===="
efcfuzz --verbose --compress-builds n --until-crash --timeout $FUZZING_TIME --out ./out/overflow --sol-assertions --source ./data/assertions-tests/overflow.sol
find ./out/overflow/default/crashes/
test -n "$(ls -A ./out/overflow/default/crashes/)"
pushd ./out/overflow/
./r.sh ./default/crashes/id*
popd
rm -rf "$EFCF_BUILD_CACHE"
df -h . /tmp/ /dev/shm/

echo "# ==== testing fuzzing combined.json with compressed builds ===="
pushd ./data/tests/; make basic basic.combined.json; popd
efcfuzz --compress-builds y --verbose --until-crash --timeout $FUZZING_TIME --out ./out/basic_cj2_results/ --bin-runtime ./data/tests/basic.combined.json
find ./out/basic_cj2_results/default/crashes/
test -n "$(ls -A ./out/basic_cj2_results/default/crashes/)"
pushd ./out/basic_cj2_results/
./r.sh ./default/crashes/id*
popd
rm -rf "$EFCF_BUILD_CACHE"
df -h . /tmp/ /dev/shm/

echo "# ==== testing fuzzing of not vulnerable contracts ===="
efcfuzz --compress-builds n --verbose --until-crash --timeout 120 --out ./out/suicide_multitx_infeasible/ --source ./data/tests-not-vuln/suicide_multitx_infeasible.sol
find ./out/suicide_multitx_infeasible/ || true
test -z "$(ls -A ./out/suicide_multitx_infeasible/default/crashes/)"
rm -rf "$EFCF_BUILD_CACHE"
df -h . /tmp/ /dev/shm/

echo "# ==== testing fuzzing with git repo removed (fallback to tarball) ===="
ls -al $EFCF_INSTALL_DIR/ $EFCF_INSTALL_DIR/src/
rm -rf $EFCF_INSTALL_DIR/.git
pushd ./data/tests/; make basic basic.combined.json; popd
efcfuzz --compress-builds n --verbose --until-crash --timeout $FUZZING_TIME --out ./out/basic_cj2_results/ --bin-runtime ./data/tests/basic.combined.json
find ./out/basic_cj2_results/default/crashes/
test -n "$(ls -A ./out/basic_cj2_results/default/crashes/)"
pushd ./out/basic_cj2_results/
./r.sh ./default/crashes/id*
popd
rm -rf "$EFCF_BUILD_CACHE" || true


echo "# ==== testing fuzzing VulnBankBuggyLockHard example ===="
pushd ./examples/ReentrancyVulnBankBuggyLockHard/
efcfuzz --source victim.sol --cores `nproc` --name VulnBankBuggyLockHard --until-crash --quiet --print-progress --timeout "$FUZZING_TIME"
find ./efcf_out/crashes_min
test -n "$(ls -A ./efcf_out/crashes_min)"
pushd ./efcf_out/
./r.sh ./crashes_min/*
popd  # ./efcf_out/
popd  # ./examples/ReentrancyVulnBankBuggyLockHard/
rm -rf "$EFCF_BUILD_CACHE" || true
