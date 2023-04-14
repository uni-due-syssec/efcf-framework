#!/usr/bin/env bash

set -e -o pipefail

if [[ -z "$PROJECT_NAME" ]]; then
    PROJECT_NAME="efcf"
fi

if [[ -z "$CIT_COMMIT_TAG" ]]; then
    CI_COMMIT_TAG=$(git describe --tags --exact-match 2> /dev/null || git symbolic-ref -q --short HEAD)
    CI_COMMIT_SHORT_SHA=$(git rev-parse --short HEAD)
    EFCF_VERSION="$CI_COMMIT_TAG-$CI_COMMIT_SHORT_SHA"
    OUT_TARBALL="efcf-$EFCF_VERSION.tar.xz"
    CI_PROJECT_DIR=$PWD
fi

echo "Building version $EFCF_VERSION into tarball $OUT_TARBALL"

echo "This script is destructive! only perform on a fresh copy of the repository!"
echo "are you sure? (y/n)"
read choice
if [[ "$choice" != "y" ]]; then
    echo "ok.. aborting"
    exit 1
fi
echo "ok.. proceeding!"

echo "# save some files for later restore"
cp README.md /tmp/
echo "# cleanup"
set -x
rm -rf .git || true
rm -rf .gitmodules || true
rm -rf .gitlab-ci.yml || true
rm -rf scripts/anon-tarball.sh || true
rm -rf ./src/*/.git || true
rm -rf ./src/*/target || true
rm -rf ./data/smartest_benchmark || true
rm -rf ./data/sailfish-0days || true
rm -rf $(eval echo $(cat .dockerignore)) || true
set +x
echo "# search and replace of personal info"
export CENSOR_FILES="$(rg -uuu -i -l '(f0rki|Michael.*Rodler|uni-due|[dD]uisburg)')"
echo "# found files to censor:"
echo $CENSOR_FILES
echo "# censoring"
for file in $CENSOR_FILES; do
    file="./$file"
    test -e "$file" || (echo "censor file $file is gone o_O" && exit 1)
    echo "# censoring $file"
    sd \
        --flags i \
        '(contact@f0rki\.at|f0rki|[mM]ichael.*[rR]odler|paluno.uni-due.de|uni-due.de|uni-due-syssec|uni-due|Duisburg-Essen)' \
        '<anonymized>' \
        "$file"
done
set +x
echo "# double check"
if rg -uuu -i -l '(f0rki|Michael.*Rodler|uni-due)'; then
    echo "WARNING: still found some PII"
    exit 1
fi
echo "# fix false alarms"
mv /tmp/README.md .
echo "# create dummy dirs"
mkdir .git
echo "# make tarball"
cd "$CI_PROJECT_DIR/.."
mv "$CI_PROJECT_DIR" "$PROJECT_NAME"
tar -cJf "$OUT_TARBALL" "$PROJECT_NAME"
echo "# done"
ls -al "$OUT_TARBALL"
