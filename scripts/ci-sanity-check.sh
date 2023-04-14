#!/usr/bin/env bash

if [[ -z "$EFCF_BUILD_CACHE" ]]; then
    EFCF_BUILD_CACHE=./efcf-build-cache
fi

if [[ -z "$FUZZING_TIME" ]]; then
    FUZZING_TIME=420
fi

export EFCF_BUILD_CACHE
export FUZZING_TIME
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES="1"

set -eu -o pipefail

mkdir -p out || true
rm -rf "$EFCF_BUILD_CACHE"
mkdir -p "$EFCF_BUILD_CACHE"
echo "using build cache $EFCF_BUILD_CACHE"
command -v efcfuzz
efcfuzz --verbose --version

echo "# ==== testing fuzzing source code ===="
set -x
efcfuzz --compress-builds n --verbose --until-crash --timeout $FUZZING_TIME --out ./out/basic_src_results/ --source ./data/tests/basic.sol
set +x
find ./out/basic_src_results/default/crashes/
test -n "$(ls -A ./out/basic_src_results/default/crashes/)"
pushd ./out/basic_src_results/
./r.sh ./default/crashes/id*
popd
rm -rf "$EFCF_BUILD_CACHE" || true
