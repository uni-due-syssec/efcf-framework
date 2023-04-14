#!/usr/bin/env bash
set -eu -o pipefail
if ! test -d ./src/; then 
    echo "Run in project root directory!"
    exit 1
fi

for repo in ./src/*; do
    echo "[+] Updating $repo"
    pushd "$repo" > /dev/null

    if [[ "$repo" == *AFL* ]]; then
        git checkout efcf-v3
        git pull
    elif [[ "$repo" == "./src/launcher" ]]; then
        echo "ignore $repo"
    else
        git checkout master
        git pull
    fi

    popd >/dev/null
done

echo "[+] update done - git add'ing"
git add src/*

echo "[+] git status =>"
git status
