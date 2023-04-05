#!/bin/bash

set -euo pipefail

recursive_unminify_json() {
    target_dir="$1";
    pushd "$target_dir";
    find . -name "*.json" -print0 | while read -d $'\0' file
    do
        python3 -m json.tool --sort-keys "$file" "$file";
    done
    popd;
}

recursive_unminify_json $1;
recursive_unminify_json $2;

# git diff exits with a non-zero code when a diff is present,
# which we want to ignore.
set +euo pipefail

git diff --no-index "$1" "$2";

exit 0;
